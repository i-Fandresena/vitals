import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/enums/clinical_enums.dart';
import '../app_database.dart';
import '../tables/beneficiary_tables.dart';
import '../tables/care_event_tables.dart';
import '../tables/sync_tables.dart';

part 'care_event_dao.g.dart';

/// Une entrée de l'historique d'un dossier, quelle que soit sa nature.
///
/// Les quatre familles d'actes ne partagent aucune table : les fusionner
/// aurait imposé une table fourre-tout aux colonnes majoritairement nulles.
/// Elles se rejoignent ici, au moment de l'affichage, qui est le seul endroit
/// où l'on veut les voir ensemble.
class CareEvent {
  const CareEvent({
    required this.id,
    required this.kind,
    required this.occurredOn,
    required this.title,
    required this.detail,
    required this.recordedByUserId,
    this.cancelledAt,
    this.isPendingSync = false,
  });

  final String id;
  final CareEventKind kind;

  /// Date ISO de l'acte, pas de sa saisie.
  final String occurredOn;
  final String title;
  final String? detail;
  final String recordedByUserId;
  final DateTime? cancelledAt;
  final bool isPendingSync;

  bool get isCancelled => cancelledAt != null;
}

enum CareEventKind { consultation, vaccination, familyPlanning, antenatal }

/// Écriture et lecture des événements de soin (tickets 2.3 à 2.6).
///
/// Chaque création suit la même règle que les dossiers : l'acte et son entrée
/// dans la file de synchronisation sont écrits **dans la même transaction**.
/// Si l'application est tuée entre les deux, aucun des deux n'existe — il ne
/// peut donc pas rester un acte qui ne serait jamais envoyé.
@DriftAccessor(
  tables: [
    Beneficiaries,
    Consultations,
    Vaccinations,
    FamilyPlanningActivities,
    Pregnancies,
    PrenatalVisits,
    SyncQueueEntries,
  ],
)
class CareEventDao extends DatabaseAccessor<AppDatabase>
    with _$CareEventDaoMixin {
  CareEventDao(super.db);

  // -------------------------------------------------------------------
  // Consultations (ticket 2.4)
  // -------------------------------------------------------------------

  Future<Consultation> createConsultation({
    required String id,
    required String beneficiaryId,
    required ConsultationType type,
    required String occurredOn,
    required String motiveCode,
    required String recordedByUserId,
    double? weightKg,
    double? temperatureC,
    int? bloodPressureSys,
    int? bloodPressureDia,
    bool treatmentGiven = false,
    bool referred = false,
    String? referredTo,
    String? notes,
  }) {
    return transaction(() async {
      final now = DateTime.now();

      await into(consultations).insert(
        ConsultationsCompanion.insert(
          id: id,
          beneficiaryId: beneficiaryId,
          type: type,
          occurredOn: occurredOn,
          motiveCode: motiveCode,
          weightKg: Value(weightKg),
          temperatureC: Value(temperatureC),
          bloodPressureSys: Value(bloodPressureSys),
          bloodPressureDia: Value(bloodPressureDia),
          treatmentGiven: Value(treatmentGiven),
          referred: Value(referred),
          referredTo: Value(referredTo?.trim()),
          notes: Value(notes?.trim()),
          recordedByUserId: recordedByUserId,
          createdAt: now,
        ),
      );

      final cree = await (select(
        consultations,
      )..where((c) => c.id.equals(id))).getSingle();

      await _enqueue('consultations', id, {
        'id': cree.id,
        'beneficiaryId': cree.beneficiaryId,
        'type': cree.type.code,
        'occurredOn': cree.occurredOn,
        'motiveCode': cree.motiveCode,
        'weightKg': cree.weightKg,
        'temperatureC': cree.temperatureC,
        'bloodPressureSys': cree.bloodPressureSys,
        'bloodPressureDia': cree.bloodPressureDia,
        'treatmentGiven': cree.treatmentGiven,
        'referred': cree.referred,
        'referredTo': cree.referredTo,
        'notes': cree.notes,
        'recordedByUserId': cree.recordedByUserId,
        'createdAt': cree.createdAt.toIso8601String(),
      }, now);

      // Fait remonter le dossier dans les « récents » : on vient de s'en
      // occuper, il y a de bonnes chances qu'on y revienne.
      await _toucherDossier(beneficiaryId, now);

      return cree;
    });
  }

  // -------------------------------------------------------------------
  // Vaccinations (ticket 2.6)
  // -------------------------------------------------------------------

  /// Enregistre une vaccination.
  ///
  /// Lève [VaccinationDejaEnregistree] si le même antigène, à la même dose et
  /// le même jour, existe déjà pour cette personne. C'est la double saisie la
  /// plus probable — deux soignants, ou un retour en arrière dans le
  /// formulaire — et la contrainte la rattrape avant l'écriture pour pouvoir
  /// l'expliquer plutôt que d'afficher une erreur de base de données.
  Future<Vaccination> createVaccination({
    required String id,
    required String beneficiaryId,
    required VaccineCode vaccine,
    required int doseNumber,
    required String occurredOn,
    required String recordedByUserId,
    String? lotNumber,
  }) {
    return transaction(() async {
      final doublon =
          await (select(vaccinations)..where(
                (v) =>
                    v.beneficiaryId.equals(beneficiaryId) &
                    v.vaccine.equalsValue(vaccine) &
                    v.doseNumber.equals(doseNumber) &
                    v.occurredOn.equals(occurredOn) &
                    v.cancelledAt.isNull(),
              ))
              .getSingleOrNull();

      if (doublon != null) {
        throw VaccinationDejaEnregistree(vaccine, doseNumber);
      }

      final now = DateTime.now();

      await into(vaccinations).insert(
        VaccinationsCompanion.insert(
          id: id,
          beneficiaryId: beneficiaryId,
          vaccine: vaccine,
          doseNumber: doseNumber,
          occurredOn: occurredOn,
          lotNumber: Value(lotNumber?.trim()),
          recordedByUserId: recordedByUserId,
          createdAt: now,
        ),
      );

      final cree = await (select(
        vaccinations,
      )..where((v) => v.id.equals(id))).getSingle();

      await _enqueue('vaccinations', id, {
        'id': cree.id,
        'beneficiaryId': cree.beneficiaryId,
        'vaccine': cree.vaccine.code,
        'doseNumber': cree.doseNumber,
        'occurredOn': cree.occurredOn,
        'lotNumber': cree.lotNumber,
        'recordedByUserId': cree.recordedByUserId,
        'createdAt': cree.createdAt.toIso8601String(),
      }, now);

      await _toucherDossier(beneficiaryId, now);
      return cree;
    });
  }

  /// Doses déjà administrées, par antigène.
  ///
  /// Sert à proposer la dose suivante et à montrer ce qui manque : un carnet
  /// perdu est fréquent, et l'historique de l'application devient alors la
  /// seule trace.
  Future<Map<VaccineCode, List<Vaccination>>> vaccinationsParAntigene(
    String beneficiaryId,
  ) async {
    final lignes =
        await (select(vaccinations)
              ..where(
                (v) =>
                    v.beneficiaryId.equals(beneficiaryId) &
                    v.cancelledAt.isNull(),
              )
              ..orderBy([(v) => OrderingTerm(expression: v.occurredOn)]))
            .get();

    final parAntigene = <VaccineCode, List<Vaccination>>{};
    for (final v in lignes) {
      parAntigene.putIfAbsent(v.vaccine, () => []).add(v);
    }
    return parAntigene;
  }

  // -------------------------------------------------------------------
  // Grossesse et CPN (ticket 2.5)
  // -------------------------------------------------------------------

  /// Grossesse en cours, s'il y en a une.
  Future<Pregnancy?> grossesseEnCours(String beneficiaryId) {
    return (select(pregnancies)
          ..where(
            (g) =>
                g.beneficiaryId.equals(beneficiaryId) &
                g.outcome.equalsValue(PregnancyOutcome.enCours),
          )
          ..orderBy([
            (g) => OrderingTerm(
              expression: g.createdAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Pregnancy> createPregnancy({
    required String id,
    required String beneficiaryId,
    required String createdByUserId,
    String? lastPeriodDate,
    String? expectedDeliveryOn,
    int? gravida,
    int? para,
  }) {
    return transaction(() async {
      final now = DateTime.now();

      await into(pregnancies).insert(
        PregnanciesCompanion.insert(
          id: id,
          beneficiaryId: beneficiaryId,
          lastPeriodDate: Value(lastPeriodDate),
          expectedDeliveryOn: Value(expectedDeliveryOn),
          gravida: Value(gravida),
          para: Value(para),
          outcome: PregnancyOutcome.enCours,
          deviceUpdatedAt: now,
          createdByUserId: createdByUserId,
          createdAt: now,
        ),
      );

      final cree = await (select(
        pregnancies,
      )..where((g) => g.id.equals(id))).getSingle();

      await _enqueue('pregnancies', id, {
        'id': cree.id,
        'beneficiaryId': cree.beneficiaryId,
        'lastPeriodDate': cree.lastPeriodDate,
        'expectedDeliveryOn': cree.expectedDeliveryOn,
        'gravida': cree.gravida,
        'para': cree.para,
        'outcome': cree.outcome.code,
        'version': cree.version,
        'deviceUpdatedAt': cree.deviceUpdatedAt.toIso8601String(),
        'createdByUserId': cree.createdByUserId,
        'createdAt': cree.createdAt.toIso8601String(),
      }, now);

      await _toucherDossier(beneficiaryId, now);
      return cree;
    });
  }

  /// Consultations prénatales déjà enregistrées pour une grossesse.
  Future<List<PrenatalVisit>> cpnDe(String pregnancyId) {
    return (select(prenatalVisits)
          ..where(
            (v) => v.pregnancyId.equals(pregnancyId) & v.cancelledAt.isNull(),
          )
          ..orderBy([(v) => OrderingTerm(expression: v.visitNumber)]))
        .get();
  }

  Future<PrenatalVisit> createPrenatalVisit({
    required String id,
    required String pregnancyId,
    required String beneficiaryId,
    required int visitNumber,
    required String occurredOn,
    required String recordedByUserId,
    int? gestationalAgeWeeks,
    double? weightKg,
    int? bloodPressureSys,
    int? bloodPressureDia,
    double? fundalHeightCm,
    int? fetalHeartRate,
    bool tetanusVaccineGiven = false,
    bool ironFolateGiven = false,
    bool malariaPreventionGiven = false,
    bool insecticideNetGiven = false,
    List<String> riskFactorCodes = const [],
    bool referred = false,
    String? referredTo,
    String? notes,
  }) {
    return transaction(() async {
      final now = DateTime.now();

      await into(prenatalVisits).insert(
        PrenatalVisitsCompanion.insert(
          id: id,
          pregnancyId: pregnancyId,
          visitNumber: visitNumber,
          occurredOn: occurredOn,
          gestationalAgeWeeks: Value(gestationalAgeWeeks),
          weightKg: Value(weightKg),
          bloodPressureSys: Value(bloodPressureSys),
          bloodPressureDia: Value(bloodPressureDia),
          fundalHeightCm: Value(fundalHeightCm),
          fetalHeartRate: Value(fetalHeartRate),
          tetanusVaccineGiven: Value(tetanusVaccineGiven),
          ironFolateGiven: Value(ironFolateGiven),
          malariaPreventionGiven: Value(malariaPreventionGiven),
          insecticideNetGiven: Value(insecticideNetGiven),
          riskFactorCodes: Value(riskFactorCodes),
          referred: Value(referred),
          referredTo: Value(referredTo?.trim()),
          notes: Value(notes?.trim()),
          recordedByUserId: recordedByUserId,
          createdAt: now,
        ),
      );

      final cree = await (select(
        prenatalVisits,
      )..where((v) => v.id.equals(id))).getSingle();

      await _enqueue('prenatal_visits', id, {
        'id': cree.id,
        'pregnancyId': cree.pregnancyId,
        'visitNumber': cree.visitNumber,
        'occurredOn': cree.occurredOn,
        'gestationalAgeWeeks': cree.gestationalAgeWeeks,
        'weightKg': cree.weightKg,
        'bloodPressureSys': cree.bloodPressureSys,
        'bloodPressureDia': cree.bloodPressureDia,
        'fundalHeightCm': cree.fundalHeightCm,
        'fetalHeartRate': cree.fetalHeartRate,
        'tetanusVaccineGiven': cree.tetanusVaccineGiven,
        'ironFolateGiven': cree.ironFolateGiven,
        'malariaPreventionGiven': cree.malariaPreventionGiven,
        'insecticideNetGiven': cree.insecticideNetGiven,
        'riskFactorCodes': cree.riskFactorCodes,
        'referred': cree.referred,
        'referredTo': cree.referredTo,
        'notes': cree.notes,
        'recordedByUserId': cree.recordedByUserId,
        'createdAt': cree.createdAt.toIso8601String(),
      }, now);

      await _toucherDossier(beneficiaryId, now);
      return cree;
    });
  }

  // -------------------------------------------------------------------
  // Historique (ticket 2.3)
  // -------------------------------------------------------------------

  /// Historique complet d'un dossier, du plus récent au plus ancien.
  ///
  /// Les quatre familles sont lues séparément puis fusionnées en mémoire.
  /// Une union SQL serait plus élégante mais imposerait de faire coïncider
  /// des colonnes qui n'ont rien à voir, et l'historique d'une personne se
  /// compte en dizaines de lignes, pas en milliers.
  Future<List<CareEvent>> historique(String beneficiaryId) async {
    final grossesses = await (select(
      pregnancies,
    )..where((g) => g.beneficiaryId.equals(beneficiaryId))).get();
    final idsGrossesses = grossesses.map((g) => g.id).toList();

    final resultats = await Future.wait([
      (select(consultations)
            ..where((c) => c.beneficiaryId.equals(beneficiaryId)))
          .get(),
      (select(vaccinations)
            ..where((v) => v.beneficiaryId.equals(beneficiaryId)))
          .get(),
      (select(familyPlanningActivities)
            ..where((f) => f.beneficiaryId.equals(beneficiaryId)))
          .get(),
      if (idsGrossesses.isNotEmpty)
        (select(prenatalVisits)
              ..where((v) => v.pregnancyId.isIn(idsGrossesses)))
            .get()
      else
        Future.value(<PrenatalVisit>[]),
    ]);

    final evenements = <CareEvent>[
      for (final c in resultats[0].cast<Consultation>())
        CareEvent(
          id: c.id,
          kind: CareEventKind.consultation,
          occurredOn: c.occurredOn,
          title: c.type.label,
          detail: c.referred ? 'Référé — ${c.motiveCode}' : c.motiveCode,
          recordedByUserId: c.recordedByUserId,
          cancelledAt: c.cancelledAt,
          isPendingSync: c.serverUpdatedAt == null,
        ),
      for (final v in resultats[1].cast<Vaccination>())
        CareEvent(
          id: v.id,
          kind: CareEventKind.vaccination,
          occurredOn: v.occurredOn,
          title: v.vaccine.label,
          detail: 'Dose ${v.doseNumber}',
          recordedByUserId: v.recordedByUserId,
          cancelledAt: v.cancelledAt,
          isPendingSync: v.serverUpdatedAt == null,
        ),
      for (final f in resultats[2].cast<FamilyPlanningActivity>())
        CareEvent(
          id: f.id,
          kind: CareEventKind.familyPlanning,
          occurredOn: f.occurredOn,
          title: f.method.label,
          detail: f.actType.label,
          recordedByUserId: f.recordedByUserId,
          cancelledAt: f.cancelledAt,
          isPendingSync: f.serverUpdatedAt == null,
        ),
      for (final v in resultats[3].cast<PrenatalVisit>())
        CareEvent(
          id: v.id,
          kind: CareEventKind.antenatal,
          occurredOn: v.occurredOn,
          title: 'CPN ${v.visitNumber}',
          detail: v.referred
              ? 'Référée'
              : (v.riskFactorCodes.isNotEmpty
                    ? '${v.riskFactorCodes.length} facteur(s) de risque'
                    : null),
          recordedByUserId: v.recordedByUserId,
          cancelledAt: v.cancelledAt,
          isPendingSync: v.serverUpdatedAt == null,
        ),
    ];

    // Du plus récent au plus ancien : c'est ce qu'on veut voir en ouvrant un
    // dossier. Les dates ISO se trient comme des dates.
    evenements.sort((a, b) => b.occurredOn.compareTo(a.occurredOn));
    return evenements;
  }

  // -------------------------------------------------------------------
  // Interne
  // -------------------------------------------------------------------

  Future<void> _enqueue(
    String entityType,
    String entityId,
    Map<String, dynamic> payload,
    DateTime at,
  ) {
    return into(syncQueueEntries).insertOnConflictUpdate(
      SyncQueueEntriesCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operation: SyncOperation.create,
        payload: jsonEncode(payload),
        deviceCreatedAt: at,
      ),
    );
  }

  /// Marque le dossier comme touché, sans incrémenter sa version.
  ///
  /// `deviceUpdatedAt` sert à l'ordre des « dossiers récents ». L'incrémenter
  /// en version créerait un faux conflit de synchronisation : l'identité n'a
  /// pas changé, seul un acte s'y est rattaché.
  Future<void> _toucherDossier(String beneficiaryId, DateTime at) {
    return (update(beneficiaries)
          ..where((b) => b.id.equals(beneficiaryId)))
        .write(BeneficiariesCompanion(deviceUpdatedAt: Value(at)));
  }
}

/// Le même antigène, à la même dose et le même jour, est déjà enregistré.
class VaccinationDejaEnregistree implements Exception {
  const VaccinationDejaEnregistree(this.vaccine, this.doseNumber);

  final VaccineCode vaccine;
  final int doseNumber;

  String get message =>
      '${vaccine.label}, dose $doseNumber, est déjà enregistrée '
      'pour cette personne à cette date.';

  @override
  String toString() => message;
}
