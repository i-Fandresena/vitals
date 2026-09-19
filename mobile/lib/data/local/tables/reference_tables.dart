import 'package:drift/drift.dart';

import '../converters.dart';

/// Centre de santé de base.
///
/// Copie locale du référentiel serveur : l'application doit pouvoir afficher le
/// nom du centre et générer des identifiants de dossier sans réseau.
class Csbs extends Table {
  TextColumn get id => text()();

  /// Préfixe des identifiants lisibles de dossier (`CSB-0142-26-00731`).
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get commune => text().nullable()();
  TextColumn get districtId => text().nullable()();
  TextColumn get districtName => text().nullable()();
  TextColumn get regionName => text().nullable()();

  /// Vrai quand le centre n'a pas de sage-femme : les infirmiers sont alors
  /// autorisés à saisir les CPN (voir `docs/01-matrice-droits.md`).
  BoolColumn get allowsNurseAntenatalCare =>
      boolean().withDefault(const Constant(false))();

  /// Dernière séquence attribuée pour l'année en cours, utilisée pour générer
  /// l'identifiant lisible du prochain dossier sans interroger le serveur.
  IntColumn get lastLocalSequence => integer().withDefault(const Constant(0))();
  IntColumn get lastLocalSequenceYear =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Utilisateur connu de l'appareil.
///
/// Ne contient **jamais** de mot de passe ni de hachage : l'authentification se
/// fait contre le serveur, et la session repose sur les jetons stockés dans le
/// coffre sécurisé du système. Cette table ne sert qu'à afficher le nom et le
/// rôle de l'utilisateur, et à attribuer un auteur aux données saisies hors
/// ligne.
class LocalUsers extends Table {
  TextColumn get id => text()();
  TextColumn get username => text()();
  TextColumn get fullName => text()();
  TextColumn get role => text().map(const UserRoleConverter())();
  TextColumn get csbId => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
