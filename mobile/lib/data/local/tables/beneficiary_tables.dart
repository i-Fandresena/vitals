import 'package:drift/drift.dart';

import '../converters.dart';

/// Dossier bénéficiaire.
///
/// Seule entité réellement modifiable du modèle, donc seule source de conflit
/// de synchronisation. C'est pour cela qu'elle porte `version` et
/// `deviceUpdatedAt`, absents des tables d'événements de soin.
class Beneficiaries extends Table {
  /// UUID v7 généré sur l'appareil : création possible hors ligne, sans risque
  /// de collision entre centres.
  TextColumn get id => text()();

  /// Identifiant lisible `CSB-0142-26-00731`, dit à voix haute et reporté sur
  /// le registre papier pendant la transition.
  TextColumn get localId => text()();

  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get sex => text().map(const SexConverter())();

  /// Date ISO `AAAA-MM-JJ` — voir `core/utils/iso_date.dart` pour la raison
  /// du stockage en texte plutôt qu'en horodatage.
  TextColumn get birthDate => text().withLength(min: 10, max: 10)();

  /// Beaucoup de bénéficiaires ne connaissent pas leur date de naissance.
  /// L'âge est alors estimé à la saisie ; ce drapeau évite que l'analyse
  /// traite une approximation comme une donnée fiable.
  BoolColumn get birthDateIsEstimated =>
      boolean().withDefault(const Constant(false))();

  TextColumn get phone => text().nullable()();
  TextColumn get fokontany => text().nullable()();
  TextColumn get address => text().nullable()();

  TextColumn get csbId => text()();

  /// Les dossiers s'archivent, ils ne se suppriment jamais (CDC §8).
  DateTimeColumn get archivedAt => dateTime().nullable()();

  // --- Synchronisation ---
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deviceUpdatedAt => dateTime()();

  /// Nul tant que l'enregistrement n'a jamais atteint le serveur. Sert à
  /// distinguer « jamais synchronisé » de « modifié depuis la dernière synchro ».
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  TextColumn get createdByUserId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE (local_id)'];
}
