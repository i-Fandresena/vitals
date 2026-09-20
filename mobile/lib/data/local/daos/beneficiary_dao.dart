import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/utils/local_id.dart';
import '../../../domain/enums/clinical_enums.dart';
import '../app_database.dart';
import '../tables/beneficiary_tables.dart';
import '../tables/reference_tables.dart';
import '../tables/sync_tables.dart';

part 'beneficiary_dao.g.dart';

/// Accès aux dossiers bénéficiaires dans la base locale.
@DriftAccessor(tables: [Beneficiaries, Csbs, SyncQueueEntries])
class BeneficiaryDao extends DatabaseAccessor<AppDatabase>
    with _$BeneficiaryDaoMixin {
  BeneficiaryDao(super.db);

  /// Crée un dossier.
  ///
  /// Trois écritures dans **une seule transaction** : l'attribution du numéro
  /// de séquence du centre, le dossier lui-même, et son entrée dans la file de
  /// synchronisation. Si l'application est tuée au milieu, rien n'est écrit —
  /// il ne peut donc pas exister de dossier qui ne serait jamais synchronisé,
  /// ni deux dossiers portant le même numéro lisible.
  Future<Beneficiary> create({
    required String id,
    required String firstName,
    required String lastName,
    required Sex sex,
    required String birthDate,
    required bool birthDateIsEstimated,
    required String csbId,
    required String createdByUserId,
    String? phone,
    String? fokontany,
    String? address,
  }) {
    return transaction(() async {
      final localId = await _nextLocalId(csbId);
      final now = DateTime.now();

      final row = BeneficiariesCompanion.insert(
        id: id,
        localId: localId,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        sex: sex,
        birthDate: birthDate,
        birthDateIsEstimated: Value(birthDateIsEstimated),
        phone: Value(phone?.trim()),
        fokontany: Value(fokontany?.trim()),
        address: Value(address?.trim()),
        csbId: csbId,
        deviceUpdatedAt: now,
        createdByUserId: createdByUserId,
        createdAt: now,
      );

      await into(beneficiaries).insert(row);
      final created = await (select(
        beneficiaries,
      )..where((b) => b.id.equals(id))).getSingle();

      await _enqueue(created, SyncOperation.create, now);

      return created;
    });
  }

  /// Attribue le prochain numéro lisible du centre.
  ///
  /// Le compteur repart à 1 au changement d'année : `CSB-0142-26-00001`,
  /// `…-00002`, puis `CSB-0142-27-00001` en janvier.
  ///
  /// Le compteur stocké ne fait pas foi à lui seul. Il est confronté au plus
  /// grand numéro réellement présent en base pour l'année, parce que l'horloge
  /// de l'appareil n'est pas fiable : un téléphone dont la date recule d'un an
  /// puis revient ferait repartir le compteur à 1 et produirait un identifiant
  /// déjà attribué. La contrainte d'unicité l'arrêterait, mais par une erreur
  /// SQLite incompréhensible, au milieu d'une consultation.
  ///
  /// À appeler uniquement depuis une transaction.
  Future<String> _nextLocalId(String csbId) async {
    final csb = await (select(
      csbs,
    )..where((c) => c.id.equals(csbId))).getSingleOrNull();

    if (csb == null) {
      throw StateError(
        'Centre de santé inconnu en base locale ($csbId). '
        'Reconnectez-vous pour rafraîchir les informations du centre.',
      );
    }

    final year = DateTime.now().year;
    final fromCounter = csb.lastLocalSequenceYear == year
        ? csb.lastLocalSequence
        : 0;

    final sequence =
        max(fromCounter, await _maxSequenceInUse(csbId, csb.code, year)) + 1;

    await (update(csbs)..where((c) => c.id.equals(csbId))).write(
      CsbsCompanion(
        lastLocalSequence: Value(sequence),
        lastLocalSequenceYear: Value(year),
      ),
    );

    return LocalId.format(csbCode: csb.code, year: year, sequence: sequence);
  }

  /// Plus grand numéro déjà attribué pour ce centre et cette année, 0 si aucun.
  ///
  /// La séquence étant complétée à cinq chiffres, l'ordre alphabétique des
  /// identifiants est aussi leur ordre numérique : `MAX` suffit, et l'index
  /// sur `local_id` rend la requête immédiate.
  Future<int> _maxSequenceInUse(String csbId, String csbCode, int year) async {
    final prefix = LocalId.format(csbCode: csbCode, year: year, sequence: 0);
    // Retire la séquence pour ne garder que `CSB-<code>-<AA>-`.
    final like = '${prefix.substring(0, prefix.length - 5)}%';

    final highest = beneficiaries.localId.max();
    final query = selectOnly(beneficiaries)
      ..addColumns([highest])
      ..where(
        beneficiaries.csbId.equals(csbId) & beneficiaries.localId.like(like),
      );

    final value = (await query.getSingle()).read(highest);
    if (value == null || value.length < 5) return 0;

    return int.tryParse(value.substring(value.length - 5)) ?? 0;
  }

  /// Recherche par nom ou prénom, limitée au centre de l'utilisateur.
  ///
  /// Les dossiers archivés sont exclus : ils restent en base pour l'historique
  /// (CDC §8) mais n'encombrent pas la recherche courante.
  Future<List<Beneficiary>> searchByName({
    required String csbId,
    required String query,
    int limit = 50,
  }) {
    final pattern = '%${query.trim()}%';

    return (select(beneficiaries)
          ..where(
            (b) =>
                b.csbId.equals(csbId) &
                b.archivedAt.isNull() &
                (b.lastName.like(pattern) | b.firstName.like(pattern)),
          )
          ..orderBy([
            (b) => OrderingTerm(expression: b.lastName),
            (b) => OrderingTerm(expression: b.firstName),
          ])
          ..limit(limit))
        .get();
  }

  /// Recherche par identifiant lisible exact.
  Future<Beneficiary?> findByLocalId({
    required String csbId,
    required String localId,
  }) {
    return (select(beneficiaries)..where(
          (b) =>
              b.csbId.equals(csbId) &
              b.localId.equals(LocalId.normalize(localId)),
        ))
        .getSingleOrNull();
  }

  /// Recherche par UUID, utilisée après un scan de QR code.
  ///
  /// Le cloisonnement par centre s'applique aussi ici : scanner la carte d'une
  /// personne suivie ailleurs ne donne pas accès à son dossier.
  Future<Beneficiary?> findById({required String csbId, required String id}) {
    return (select(
      beneficiaries,
    )..where((b) => b.csbId.equals(csbId) & b.id.equals(id))).getSingleOrNull();
  }

  /// Derniers dossiers touchés, pour l'écran de recherche vide.
  ///
  /// Le personnel revient souvent sur les mêmes personnes dans la journée ;
  /// proposer les dossiers récents évite de retaper un nom.
  Future<List<Beneficiary>> recent({required String csbId, int limit = 20}) {
    return (select(beneficiaries)
          ..where((b) => b.csbId.equals(csbId) & b.archivedAt.isNull())
          ..orderBy([
            (b) => OrderingTerm(
              expression: b.deviceUpdatedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit))
        .get();
  }

  Future<int> countForCsb(String csbId) async {
    final count = countAll();
    final query = selectOnly(beneficiaries)
      ..addColumns([count])
      ..where(
        beneficiaries.csbId.equals(csbId) & beneficiaries.archivedAt.isNull(),
      );

    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Ajoute une mutation à la file de synchronisation.
  ///
  /// La charge utile contient des données de santé : elle est écrite en base
  /// locale, jamais journalisée.
  Future<void> _enqueue(Beneficiary row, SyncOperation operation, DateTime at) {
    return into(syncQueueEntries).insertOnConflictUpdate(
      SyncQueueEntriesCompanion.insert(
        entityType: 'beneficiaries',
        entityId: row.id,
        operation: operation,
        payload: jsonEncode(_payloadOf(row)),
        deviceCreatedAt: at,
      ),
    );
  }

  Map<String, dynamic> _payloadOf(Beneficiary row) => {
    'id': row.id,
    'localId': row.localId,
    'firstName': row.firstName,
    'lastName': row.lastName,
    'sex': row.sex.code,
    'birthDate': row.birthDate,
    'birthDateIsEstimated': row.birthDateIsEstimated,
    'phone': row.phone,
    'fokontany': row.fokontany,
    'address': row.address,
    'csbId': row.csbId,
    'version': row.version,
    'deviceUpdatedAt': row.deviceUpdatedAt.toIso8601String(),
    'createdByUserId': row.createdByUserId,
    'createdAt': row.createdAt.toIso8601String(),
  };
}
