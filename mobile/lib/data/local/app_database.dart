import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

// Importés pour le code généré ci-dessous (`part`), qui manipule directement
// ces types et ces convertisseurs.
import '../../domain/enums/clinical_enums.dart';
import '../../domain/enums/user_role.dart';
import 'converters.dart';
import 'daos/beneficiary_dao.dart';
import 'tables/beneficiary_tables.dart';
import 'tables/care_event_tables.dart';
import 'tables/reference_tables.dart';
import 'tables/sync_tables.dart';

part 'app_database.g.dart';

/// Base locale de l'application — **source de vérité** (CDC §6).
///
/// Toute écriture passe ici d'abord, puis part dans la file de synchronisation.
/// L'application est pleinement utilisable sans réseau ; le serveur est une
/// destination, pas une dépendance.
///
/// Le modèle est le miroir de `backend/prisma/schema.prisma`. Voir
/// `docs/02-modele-donnees.md` pour les principes.
@DriftDatabase(
  tables: [
    Csbs,
    LocalUsers,
    Beneficiaries,
    Consultations,
    Vaccinations,
    FamilyPlanningActivities,
    Pregnancies,
    PrenatalVisits,
    SyncQueueEntries,
    AuditEntries,
  ],
  daos: [BeneficiaryDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Schéma initial. Toute évolution incrémente ce numéro **et** ajoute une
  /// étape dans [migration] : des appareils déployés en CSB porteront des
  /// données qu'on ne peut pas recréer.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    beforeOpen: (details) async {
      // Les clés étrangères ne sont pas actives par défaut dans SQLite.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Index dictés par les trois parcours quotidiens : retrouver une personne
  /// par son nom, ouvrir son historique, compter les actes d'une période.
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_beneficiaries_name '
      'ON beneficiaries (last_name, first_name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_beneficiaries_local_id '
      'ON beneficiaries (local_id)',
    );
    // Le tableau de bord filtre par période (CDC §4) : l'index porte sur la
    // date de l'acte, pas sur la date de saisie.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_consultations_beneficiary '
      'ON consultations (beneficiary_id, occurred_on)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_consultations_date ON consultations (occurred_on)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_vaccinations_beneficiary '
      'ON vaccinations (beneficiary_id, occurred_on)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_vaccinations_date ON vaccinations (occurred_on)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_fp_beneficiary '
      'ON family_planning_activities (beneficiary_id, occurred_on)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_fp_date ON family_planning_activities (occurred_on)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pregnancies_beneficiary '
      'ON pregnancies (beneficiary_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_prenatal_pregnancy '
      'ON prenatal_visits (pregnancy_id, occurred_on)',
    );
    // La file est lue en permanence : « que reste-t-il à envoyer ? »
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_status ON sync_queue_entries (status, id)',
    );
  }
}

/// Ouvre la base de l'application.
///
/// `driftDatabase` place le fichier dans le répertoire de données privé de
/// l'application et applique les contournements nécessaires aux anciennes
/// versions d'Android — ce qui compte ici, les appareils des CSB étant souvent
/// anciens (`minSdk 24`).
///
/// ⚠️ **Le chiffrement au repos n'est pas encore activé** : c'est l'objet du
/// ticket 3.3. Tant qu'il n'est pas livré, l'application ne doit contenir
/// aucune donnée réelle de patient.
///
/// Les bibliothèques SQLCipher sont déjà embarquées par `drift_flutter`, donc
/// le ticket 3.3 se limitera à générer une clé, la ranger dans le coffre
/// sécurisé du système et l'appliquer ici : le point de bascule est
/// volontairement isolé dans cette seule fonction.
QueryExecutor openAppDatabase({String name = 'vitals'}) {
  return driftDatabase(
    name: name,
    native: const DriftNativeOptions(
      // Isole la base des autres fichiers de l'application.
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );
}
