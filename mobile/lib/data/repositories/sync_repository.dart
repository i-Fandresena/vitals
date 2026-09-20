import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/enums/clinical_enums.dart';
import '../local/app_database.dart';
import '../remote/api_client.dart';
import '../secure/token_store.dart';

/// Résultat d'une synchronisation, pour affichage.
class SyncResult {
  const SyncResult({
    required this.envoyees,
    required this.rejetees,
    required this.recues,
    this.erreur,
  });

  const SyncResult.echec(String message)
    : envoyees = 0,
      rejetees = 0,
      recues = 0,
      erreur = message;

  final int envoyees;
  final int rejetees;
  final int recues;
  final String? erreur;

  bool get reussie => erreur == null;
  bool get aChange => envoyees > 0 || recues > 0;
}

/// Synchronisation entre la base locale et le serveur (ticket 3.1).
///
/// **L'appareil n'attend jamais le serveur pour travailler.** La base locale
/// reste la source de vérité : cette classe ne fait que rattraper le retard
/// dans les deux sens quand la connexion le permet (CDC §6).
///
/// Ordre volontaire : on envoie avant de recevoir. Sinon un dossier corrigé
/// localement mais pas encore envoyé serait écrasé par la version du serveur,
/// et la correction serait perdue sans que personne ne s'en aperçoive.
class SyncRepository {
  SyncRepository({
    required ApiClient apiClient,
    required AppDatabase database,
    required TokenStore tokenStore,
  }) : _api = apiClient,
       _db = database,
       _tokens = tokenStore;

  final ApiClient _api;
  final AppDatabase _db;
  final TokenStore _tokens;

  /// Taille des lots envoyés. Bornée pour qu'un appareil resté trois semaines
  /// hors ligne n'essaie pas de tout pousser en une requête sur une 2G.
  static const int _tailleLot = 50;

  /// Nombre de tentatives au-delà duquel une mutation cesse d'être réessayée.
  ///
  /// Sans cette borne, une donnée que le serveur refuse pour une raison
  /// permanente serait renvoyée à chaque synchronisation, indéfiniment, en
  /// retardant tout ce qui la suit.
  static const int _tentativesMax = 5;

  Future<SyncResult> synchroniser() async {
    try {
      final envoi = await _envoyer();
      final reception = await _recevoir();

      return SyncResult(
        envoyees: envoi.$1,
        rejetees: envoi.$2,
        recues: reception,
      );
    } on NetworkException catch (e) {
      // Hors ligne : ce n'est pas une panne, c'est le régime normal.
      return SyncResult.echec(e.message);
    } on AuthException catch (e) {
      return SyncResult.echec(e.message);
    } on AppException catch (e) {
      return SyncResult.echec(e.message);
    }
  }

  /// Nombre de mutations en attente d'envoi.
  Future<int> enAttente() async {
    final compte = _db.syncQueueEntries.id.count();
    final requete = _db.selectOnly(_db.syncQueueEntries)
      ..addColumns([compte])
      ..where(_db.syncQueueEntries.status.equalsValue(SyncStatus.pending));

    return (await requete.getSingle()).read(compte) ?? 0;
  }

  /// Mutations définitivement refusées, qui demandent une intervention.
  Future<int> enEchec() async {
    final compte = _db.syncQueueEntries.id.count();
    final requete = _db.selectOnly(_db.syncQueueEntries)
      ..addColumns([compte])
      ..where(_db.syncQueueEntries.status.equalsValue(SyncStatus.failed));

    return (await requete.getSingle()).read(compte) ?? 0;
  }

  Future<DateTime?> derniereSynchro() => _tokens.readLastSync();

  // -------------------------------------------------------------------
  // Envoi
  // -------------------------------------------------------------------

  /// Renvoie (acceptées, rejetées).
  Future<(int, int)> _envoyer() async {
    var acceptees = 0;
    var rejetees = 0;

    while (true) {
      final lot =
          await (_db.select(_db.syncQueueEntries)
                ..where((e) => e.status.equalsValue(SyncStatus.pending))
                ..orderBy([(e) => OrderingTerm(expression: e.id)])
                ..limit(_tailleLot))
              .get();

      if (lot.isEmpty) break;

      final reponse = await _api.post(
        '/sync/push',
        body: {
          'mutations': [
            for (final e in lot)
              {
                'entityType': e.entityType,
                'entityId': e.entityId,
                'operation': e.operation.code,
                'payload': jsonDecode(e.payload),
                'deviceCreatedAt': e.deviceCreatedAt.toUtc().toIso8601String(),
              },
          ],
        },
      );

      final resultats = (reponse['resultats'] as List?) ?? const [];
      final parId = {
        for (final r in resultats.cast<Map<String, dynamic>>())
          r['entityId'] as String: r,
      };

      for (final entree in lot) {
        final resultat = parId[entree.entityId];
        final statut = resultat?['statut'] as String?;

        if (statut == 'accepte' || statut == 'ignore') {
          // « ignore » veut dire que le serveur détient déjà mieux : la
          // mutation a fait son temps, elle sort de la file sans erreur.
          await (_db.delete(
            _db.syncQueueEntries,
          )..where((e) => e.id.equals(entree.id))).go();
          if (statut == 'accepte') acceptees++;
        } else {
          rejetees += await _marquerEchec(
            entree,
            (resultat?['motif'] as String?) ?? 'Refusée par le serveur',
            definitif: statut == 'rejete',
          );
        }
      }

      if (lot.length < _tailleLot) break;
    }

    return (acceptees, rejetees);
  }

  /// Renvoie 1 si la mutation est définitivement abandonnée, 0 sinon.
  Future<int> _marquerEchec(
    SyncQueueEntry entree,
    String motif, {
    required bool definitif,
  }) async {
    final tentatives = entree.attemptCount + 1;
    final abandonne = definitif || tentatives >= _tentativesMax;

    await (_db.update(
      _db.syncQueueEntries,
    )..where((e) => e.id.equals(entree.id))).write(
      SyncQueueEntriesCompanion(
        status: Value(abandonne ? SyncStatus.failed : SyncStatus.pending),
        attemptCount: Value(tentatives),
        // Le motif seul, jamais la charge utile : elle contient des données
        // de santé.
        lastError: Value(motif),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );

    return abandonne ? 1 : 0;
  }

  // -------------------------------------------------------------------
  // Réception
  // -------------------------------------------------------------------

  Future<int> _recevoir() async {
    var total = 0;
    var curseur = await _tokens.readSyncCursor();

    // Le serveur signale par `hasMore` qu'un lot était plein. Sans cette
    // boucle, un appareil neuf ne recevrait que les 500 premiers
    // enregistrements et croirait être à jour.
    for (var page = 0; page < 40; page++) {
      final reponse = await _api.get(
        '/sync/pull',
        query: curseur == null
            ? const <String, dynamic>{}
            : <String, dynamic>{'since': curseur},
      );

      total += await _appliquer(reponse);

      curseur = reponse['serverTime'] as String?;
      if (curseur != null) {
        // Le curseur est enregistré après chaque page : une coupure en cours
        // de rattrapage ne fait pas tout recommencer.
        await _tokens.saveSyncCursor(curseur);
      }

      if (reponse['hasMore'] != true) break;
    }

    await _tokens.saveLastSync(DateTime.now());
    return total;
  }

  Future<int> _appliquer(Map<String, dynamic> reponse) async {
    var compte = 0;

    List<Map<String, dynamic>> lot(String cle) =>
        ((reponse[cle] as List?) ?? const []).cast<Map<String, dynamic>>();

    // Tout dans une transaction : un rattrapage interrompu ne doit pas laisser
    // une consultation sans son dossier.
    await _db.transaction(() async {
      for (final b in lot('beneficiaries')) {
        await _db
            .into(_db.beneficiaries)
            .insertOnConflictUpdate(_versDossier(b));
        compte++;
      }
      for (final c in lot('consultations')) {
        await _db
            .into(_db.consultations)
            .insertOnConflictUpdate(_versConsultation(c));
        compte++;
      }
      for (final v in lot('vaccinations')) {
        await _db
            .into(_db.vaccinations)
            .insertOnConflictUpdate(_versVaccination(v));
        compte++;
      }
      for (final f in lot('familyPlanning')) {
        await _db
            .into(_db.familyPlanningActivities)
            .insertOnConflictUpdate(_versPlanification(f));
        compte++;
      }
      for (final g in lot('pregnancies')) {
        await _db
            .into(_db.pregnancies)
            .insertOnConflictUpdate(_versGrossesse(g));
        compte++;
      }
      for (final v in lot('prenatalVisits')) {
        await _db.into(_db.prenatalVisits).insertOnConflictUpdate(_versCpn(v));
        compte++;
      }
    });

    return compte;
  }

  // -------------------------------------------------------------------
  // Conversion des réponses du serveur
  // -------------------------------------------------------------------

  BeneficiariesCompanion _versDossier(Map<String, dynamic> j) {
    return BeneficiariesCompanion(
      id: Value(j['id'] as String),
      localId: Value(j['localId'] as String),
      firstName: Value(j['firstName'] as String),
      lastName: Value(j['lastName'] as String),
      sex: Value(Sex.tryParse(j['sex'] as String?) ?? Sex.f),
      birthDate: Value(j['birthDate'] as String),
      birthDateIsEstimated: Value(j['birthDateIsEstimated'] == true),
      phone: Value(j['phone'] as String?),
      fokontany: Value(j['fokontany'] as String?),
      address: Value(j['address'] as String?),
      csbId: Value(j['csbId'] as String),
      archivedAt: Value(_instant(j['archivedAt'])),
      version: Value((j['version'] as num?)?.toInt() ?? 1),
      deviceUpdatedAt: Value(_instant(j['deviceUpdatedAt']) ?? DateTime.now()),
      serverUpdatedAt: Value(_instant(j['serverUpdatedAt'])),
      createdByUserId: Value(j['createdByUserId'] as String),
      createdAt: Value(_instant(j['createdAt']) ?? DateTime.now()),
    );
  }

  ConsultationsCompanion _versConsultation(Map<String, dynamic> j) {
    return ConsultationsCompanion(
      id: Value(j['id'] as String),
      beneficiaryId: Value(j['beneficiaryId'] as String),
      type: Value(
        ConsultationType.tryParse(j['type'] as String?) ??
            ConsultationType.autre,
      ),
      occurredOn: Value(j['occurredOn'] as String),
      motiveCode: Value(j['motiveCode'] as String? ?? ''),
      diagnosisCode: Value(j['diagnosisCode'] as String?),
      weightKg: Value((j['weightKg'] as num?)?.toDouble()),
      temperatureC: Value((j['temperatureC'] as num?)?.toDouble()),
      bloodPressureSys: Value((j['bloodPressureSys'] as num?)?.toInt()),
      bloodPressureDia: Value((j['bloodPressureDia'] as num?)?.toInt()),
      treatmentGiven: Value(j['treatmentGiven'] == true),
      referred: Value(j['referred'] == true),
      referredTo: Value(j['referredTo'] as String?),
      notes: Value(j['notes'] as String?),
      cancelledAt: Value(_instant(j['cancelledAt'])),
      cancelReason: Value(j['cancelReason'] as String?),
      recordedByUserId: Value(j['recordedByUserId'] as String),
      createdAt: Value(_instant(j['createdAt']) ?? DateTime.now()),
      serverUpdatedAt: Value(_instant(j['createdAt'])),
    );
  }

  VaccinationsCompanion _versVaccination(Map<String, dynamic> j) {
    return VaccinationsCompanion(
      id: Value(j['id'] as String),
      beneficiaryId: Value(j['beneficiaryId'] as String),
      vaccine: Value(
        VaccineCode.tryParse(j['vaccine'] as String?) ?? VaccineCode.autre,
      ),
      doseNumber: Value((j['doseNumber'] as num?)?.toInt() ?? 1),
      occurredOn: Value(j['occurredOn'] as String),
      lotNumber: Value(j['lotNumber'] as String?),
      cancelledAt: Value(_instant(j['cancelledAt'])),
      cancelReason: Value(j['cancelReason'] as String?),
      recordedByUserId: Value(j['recordedByUserId'] as String),
      createdAt: Value(_instant(j['createdAt']) ?? DateTime.now()),
      serverUpdatedAt: Value(_instant(j['createdAt'])),
    );
  }

  FamilyPlanningActivitiesCompanion _versPlanification(Map<String, dynamic> j) {
    return FamilyPlanningActivitiesCompanion(
      id: Value(j['id'] as String),
      beneficiaryId: Value(j['beneficiaryId'] as String),
      method: Value(
        FamilyPlanningMethod.tryParse(j['method'] as String?) ??
            FamilyPlanningMethod.autre,
      ),
      actType: Value(
        FamilyPlanningActType.tryParse(j['actType'] as String?) ??
            FamilyPlanningActType.renouvellement,
      ),
      occurredOn: Value(j['occurredOn'] as String),
      quantity: Value((j['quantity'] as num?)?.toInt()),
      cancelledAt: Value(_instant(j['cancelledAt'])),
      cancelReason: Value(j['cancelReason'] as String?),
      recordedByUserId: Value(j['recordedByUserId'] as String),
      createdAt: Value(_instant(j['createdAt']) ?? DateTime.now()),
      serverUpdatedAt: Value(_instant(j['createdAt'])),
    );
  }

  PregnanciesCompanion _versGrossesse(Map<String, dynamic> j) {
    return PregnanciesCompanion(
      id: Value(j['id'] as String),
      beneficiaryId: Value(j['beneficiaryId'] as String),
      lastPeriodDate: Value(j['lastPeriodDate'] as String?),
      expectedDeliveryOn: Value(j['expectedDeliveryOn'] as String?),
      gravida: Value((j['gravida'] as num?)?.toInt()),
      para: Value((j['para'] as num?)?.toInt()),
      outcome: Value(
        PregnancyOutcome.tryParse(j['outcome'] as String?) ??
            PregnancyOutcome.enCours,
      ),
      outcomeDate: Value(j['outcomeDate'] as String?),
      version: Value((j['version'] as num?)?.toInt() ?? 1),
      deviceUpdatedAt: Value(_instant(j['deviceUpdatedAt']) ?? DateTime.now()),
      serverUpdatedAt: Value(_instant(j['serverUpdatedAt'])),
      createdByUserId: Value(j['createdByUserId'] as String),
      createdAt: Value(_instant(j['createdAt']) ?? DateTime.now()),
    );
  }

  PrenatalVisitsCompanion _versCpn(Map<String, dynamic> j) {
    return PrenatalVisitsCompanion(
      id: Value(j['id'] as String),
      pregnancyId: Value(j['pregnancyId'] as String),
      visitNumber: Value((j['visitNumber'] as num?)?.toInt() ?? 1),
      occurredOn: Value(j['occurredOn'] as String),
      gestationalAgeWeeks: Value((j['gestationalAgeWeeks'] as num?)?.toInt()),
      weightKg: Value((j['weightKg'] as num?)?.toDouble()),
      bloodPressureSys: Value((j['bloodPressureSys'] as num?)?.toInt()),
      bloodPressureDia: Value((j['bloodPressureDia'] as num?)?.toInt()),
      fundalHeightCm: Value((j['fundalHeightCm'] as num?)?.toDouble()),
      fetalHeartRate: Value((j['fetalHeartRate'] as num?)?.toInt()),
      tetanusVaccineGiven: Value(j['tetanusVaccineGiven'] == true),
      ironFolateGiven: Value(j['ironFolateGiven'] == true),
      malariaPreventionGiven: Value(j['malariaPreventionGiven'] == true),
      insecticideNetGiven: Value(j['insecticideNetGiven'] == true),
      riskFactorCodes: Value(
        ((j['riskFactorCodes'] as List?) ?? const []).cast<String>(),
      ),
      referred: Value(j['referred'] == true),
      referredTo: Value(j['referredTo'] as String?),
      notes: Value(j['notes'] as String?),
      cancelledAt: Value(_instant(j['cancelledAt'])),
      cancelReason: Value(j['cancelReason'] as String?),
      recordedByUserId: Value(j['recordedByUserId'] as String),
      createdAt: Value(_instant(j['createdAt']) ?? DateTime.now()),
      serverUpdatedAt: Value(_instant(j['createdAt'])),
    );
  }

  DateTime? _instant(dynamic valeur) =>
      valeur is String ? DateTime.tryParse(valeur) : null;
}
