import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Importés pour le code généré ci-dessous (`part`), qui manipule directement
// ces types et ces convertisseurs.
import '../../domain/enums/clinical_enums.dart';
import '../../domain/enums/user_role.dart';
import 'converters.dart';
import 'daos/beneficiary_dao.dart';
import 'daos/care_event_dao.dart';
import 'database_key.dart';
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
  daos: [BeneficiaryDao, CareEventDao],
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

/// Ouvre la base de l'application, **chiffrée** (ticket 3.3).
///
/// Le fichier SQLite d'une application Android est extractible dès que
/// l'appareil est déverrouillé ou rooté. Sans chiffrement, les dossiers de
/// santé d'un téléphone perdu se lisent avec n'importe quel éditeur.
///
/// La clé est tirée au premier lancement et rangée dans le coffre du système
/// (voir [DatabaseKey]). Elle n'est ni dérivée d'un mot de passe, ni transmise
/// au serveur, ni sauvegardée.
Future<QueryExecutor> openAppDatabase({String name = 'vitals'}) async {
  final cles = DatabaseKey();
  final cle = await cles.obtenir();

  // Écarte la base non chiffrée d'avant le ticket 3.3.
  //
  // Sûr par construction : le chiffrement EST la condition posée à la saisie
  // de données réelles, donc une base antérieure ne contient que des données
  // de test. Tenter de l'ouvrir avec une clé échouerait de toute façon, avec
  // une erreur « file is not a database » incompréhensible pour l'utilisateur.
  if (await cles.premierChiffrement()) {
    await _ecarterBaseNonChiffree(name);
    await cles.marquerChiffre();
  }

  return driftDatabase(
    name: name,
    native: DriftNativeOptions(
      // Isole la base des autres fichiers de l'application.
      databaseDirectory: getApplicationSupportDirectory,
      setup: (db) {
        // L'ordre compte, et il est l'inverse de l'intuition.
        //
        // `PRAGMA cipher` doit venir EN PREMIER : SQLite3 Multiple Ciphers
        // dérive la clé avec le chiffre sélectionné au moment où on la pose.
        // Poser la clé d'abord la dérive avec le chiffre par défaut, et le
        // `PRAGMA cipher` qui suit n'y change plus rien — la base s'ouvre,
        // tout semble marcher, mais elle n'est pas au format annoncé.
        //
        // Ce n'est pas un détail cosmétique : corriger l'ordre après un
        // déploiement rendrait illisibles les bases déjà créées sur les
        // téléphones des centres.
        db.execute('PRAGMA cipher = sqlcipher;');

        // Format SQLCipher 4, le plus répandu : une base produite ici reste
        // lisible par les outils standard, ce qui compte le jour où il faudra
        // expertiser un appareil ou récupérer des données.
        db.execute(DatabaseKey.instructionCle(cle));

        // Vérifie immédiatement que la clé est la bonne. Sans cette lecture,
        // l'erreur ne surgirait qu'à la première requête métier, loin de sa
        // cause.
        db.execute('SELECT count(*) FROM sqlite_master;');
      },
    ),
  );
}

/// Supprime une base laissée par une version antérieure au chiffrement.
Future<void> _ecarterBaseNonChiffree(String name) async {
  try {
    final dossier = await getApplicationSupportDirectory();
    for (final suffixe in ['', '-wal', '-shm']) {
      final fichier = File(p.join(dossier.path, '$name.sqlite$suffixe'));
      if (fichier.existsSync()) await fichier.delete();
    }
  } on FileSystemException {
    // Une base impossible à supprimer empêchera l'ouverture juste après, avec
    // un message plus parlant que celui qu'on produirait ici.
  }
}
