import 'package:drift/drift.dart';

import '../converters.dart';

/// File des mutations en attente d'envoi au serveur.
///
/// N'existe que sur l'appareil. Toute écriture métier ajoute une entrée ici
/// dans la même transaction que l'écriture elle-même : si l'application est
/// tuée entre les deux, la donnée ne peut pas exister sans être programmée pour
/// la synchronisation.
///
/// La logique de rejeu est l'objet du ticket 3.1 ; cette table en est le socle.
class SyncQueueEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Nom de la table concernée (`beneficiaries`, `consultations`…).
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text().map(const SyncOperationConverter())();

  /// Charge utile JSON. Contient des données de santé : cette table est donc
  /// couverte par le chiffrement de la base (ticket 3.3) au même titre que les
  /// tables métier.
  TextColumn get payload => text()();

  TextColumn get status =>
      text().map(const SyncStatusConverter()).withDefault(const Constant('PENDING'))();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  /// Message de la dernière erreur, pour diagnostic. Ne doit jamais contenir
  /// la charge utile.
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  /// Horodatage de l'appareil au moment de la saisie. Arbitre les conflits, et
  /// permet de mesurer la dérive d'horloge à la réception.
  DateTimeColumn get deviceCreatedAt => dateTime()();

  @override
  List<String> get customConstraints => [
        // Une seule mutation en attente par enregistrement : la suivante
        // remplace la précédente plutôt que de s'empiler, sinon une fiche
        // corrigée trois fois hors ligne enverrait trois versions successives.
        'UNIQUE (entity_type, entity_id, operation)',
      ];
}

/// Journal d'audit local (CDC §8, ticket 3.4).
///
/// Doublon volontaire du journal serveur : l'appareil doit pouvoir tracer qui a
/// fait quoi même sans réseau, et ces entrées partent ensuite dans la file de
/// synchronisation.
///
/// `changedFields` ne contient que des **noms de champs, jamais de valeurs** :
/// un journal qui recopierait les données de santé deviendrait lui-même une
/// base de données de santé.
class AuditEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get action => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text().nullable()();

  TextColumn get changedFields =>
      text().map(const StringListConverter()).withDefault(const Constant(''))();

  DateTimeColumn get deviceTimestamp => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
