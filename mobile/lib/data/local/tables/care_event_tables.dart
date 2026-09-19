/// Les tables de ce fichier décrivent des **événements de soin**.
///
/// Elles sont immuables : un enregistrement est créé, jamais modifié. Une
/// correction passe par `cancelledAt` + un nouvel enregistrement, ce qui
/// préserve l'historique exigé au CDC §8 et rend ces tables insensibles aux
/// conflits de synchronisation.
///
/// Toutes partagent la même colonne `occurredOn` (date ISO de l'acte), distincte
/// de `createdAt` (date de saisie) : un acte fait hors ligne peut être saisi le
/// lendemain, et les indicateurs doivent compter la date de l'acte.
library;

import 'package:drift/drift.dart';

import '../converters.dart';

class Consultations extends Table {
  TextColumn get id => text()();
  TextColumn get beneficiaryId => text()();

  TextColumn get type => text().map(const ConsultationTypeConverter())();
  TextColumn get occurredOn => text().withLength(min: 10, max: 10)();

  /// Champs codés : le texte libre n'est pas exploitable en statistiques.
  TextColumn get motiveCode => text()();
  TextColumn get diagnosisCode => text().nullable()();

  RealColumn get weightKg => real().nullable()();
  RealColumn get temperatureC => real().nullable()();
  IntColumn get bloodPressureSys => integer().nullable()();
  IntColumn get bloodPressureDia => integer().nullable()();

  BoolColumn get treatmentGiven =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get referred => boolean().withDefault(const Constant(false))();
  TextColumn get referredTo => text().nullable()();

  /// Observation libre, jamais agrégée.
  TextColumn get notes => text().nullable()();

  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get cancelReason => text().nullable()();

  TextColumn get recordedByUserId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Vaccinations extends Table {
  TextColumn get id => text()();
  TextColumn get beneficiaryId => text()();

  TextColumn get vaccine => text().map(const VaccineCodeConverter())();
  IntColumn get doseNumber => integer()();
  TextColumn get occurredOn => text().withLength(min: 10, max: 10)();

  TextColumn get lotNumber => text().nullable()();

  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get cancelReason => text().nullable()();

  TextColumn get recordedByUserId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /// Protège du doublon le plus probable en pratique : une double saisie, ou
  /// un rejeu de la file de synchronisation. Même contrainte côté serveur.
  @override
  List<String> get customConstraints => [
    'UNIQUE (beneficiary_id, vaccine, dose_number, occurred_on)',
  ];
}

class FamilyPlanningActivities extends Table {
  TextColumn get id => text()();
  TextColumn get beneficiaryId => text()();

  TextColumn get method => text().map(const FamilyPlanningMethodConverter())();
  TextColumn get actType =>
      text().map(const FamilyPlanningActTypeConverter())();
  TextColumn get occurredOn => text().withLength(min: 10, max: 10)();

  /// Quantité distribuée. Décrit l'acte, pas l'inventaire : le suivi de stock
  /// est hors périmètre MVP (CDC §10).
  IntColumn get quantity => integer().nullable()();

  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get cancelReason => text().nullable()();

  TextColumn get recordedByUserId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Grossesse suivie.
///
/// Exception dans ce fichier : c'est un dossier ouvert dans la durée, pas un
/// fait ponctuel. Son issue est mise à jour à l'accouchement, elle porte donc
/// `version` comme le dossier bénéficiaire.
class Pregnancies extends Table {
  TextColumn get id => text()();
  TextColumn get beneficiaryId => text()();

  /// Date des dernières règles, base du calcul du terme.
  TextColumn get lastPeriodDate => text().nullable()();
  TextColumn get expectedDeliveryOn => text().nullable()();

  IntColumn get gravida => integer().nullable()();
  IntColumn get para => integer().nullable()();

  TextColumn get outcome => text().map(const PregnancyOutcomeConverter())();
  TextColumn get outcomeDate => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get deviceUpdatedAt => dateTime()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  TextColumn get createdByUserId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class PrenatalVisits extends Table {
  TextColumn get id => text()();
  TextColumn get pregnancyId => text()();

  /// Rang de la consultation prénatale : CPN1, CPN2…
  IntColumn get visitNumber => integer()();
  TextColumn get occurredOn => text().withLength(min: 10, max: 10)();

  IntColumn get gestationalAgeWeeks => integer().nullable()();
  RealColumn get weightKg => real().nullable()();
  IntColumn get bloodPressureSys => integer().nullable()();
  IntColumn get bloodPressureDia => integer().nullable()();
  RealColumn get fundalHeightCm => real().nullable()();
  IntColumn get fetalHeartRate => integer().nullable()();

  /// Interventions systématiques du suivi prénatal. Booléens dédiés plutôt
  /// qu'une liste d'actes : ce sont exactement les indicateurs à remonter.
  BoolColumn get tetanusVaccineGiven =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get ironFolateGiven =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get malariaPreventionGiven =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get insecticideNetGiven =>
      boolean().withDefault(const Constant(false))();

  TextColumn get riskFactorCodes =>
      text().map(const StringListConverter()).withDefault(const Constant(''))();

  BoolColumn get referred => boolean().withDefault(const Constant(false))();
  TextColumn get referredTo => text().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get cancelReason => text().nullable()();

  TextColumn get recordedByUserId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
