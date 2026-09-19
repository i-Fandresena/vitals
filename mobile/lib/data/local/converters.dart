import 'package:drift/drift.dart';

import '../../domain/enums/clinical_enums.dart';
import '../../domain/enums/user_role.dart';

/// Convertisseurs d'énumérations pour Drift.
///
/// Drift sait stocker une énumération nativement (`textEnum`), mais il écrit
/// alors le **nom Dart** de la valeur (`sageFemme`). Ces convertisseurs écrivent
/// le `code` (`SAGE_FEMME`) à la place, pour deux raisons :
///
/// - c'est la valeur exacte échangée avec le serveur, donc une donnée locale et
///   la même donnée synchronisée se lisent de façon identique ;
/// - renommer une valeur d'énumération en Dart ne corrompt pas les données déjà
///   enregistrées sur les appareils déployés.
///
/// Une valeur illisible lève plutôt que de retomber sur une valeur par défaut :
/// sur des données de santé, un rôle ou un antigène silencieusement remplacé
/// est pire qu'une erreur visible.

Never _unknown(String enumName, String code) =>
    throw StateError('Valeur $enumName inconnue en base locale : "$code"');

class UserRoleConverter extends TypeConverter<UserRole, String> {
  const UserRoleConverter();

  @override
  UserRole fromSql(String fromDb) =>
      UserRole.tryParse(fromDb) ?? _unknown('UserRole', fromDb);

  @override
  String toSql(UserRole value) => value.code;
}

class SexConverter extends TypeConverter<Sex, String> {
  const SexConverter();

  @override
  Sex fromSql(String fromDb) => Sex.tryParse(fromDb) ?? _unknown('Sex', fromDb);

  @override
  String toSql(Sex value) => value.code;
}

class ConsultationTypeConverter extends TypeConverter<ConsultationType, String> {
  const ConsultationTypeConverter();

  @override
  ConsultationType fromSql(String fromDb) =>
      ConsultationType.tryParse(fromDb) ?? _unknown('ConsultationType', fromDb);

  @override
  String toSql(ConsultationType value) => value.code;
}

class VaccineCodeConverter extends TypeConverter<VaccineCode, String> {
  const VaccineCodeConverter();

  @override
  VaccineCode fromSql(String fromDb) =>
      VaccineCode.tryParse(fromDb) ?? _unknown('VaccineCode', fromDb);

  @override
  String toSql(VaccineCode value) => value.code;
}

class FamilyPlanningMethodConverter extends TypeConverter<FamilyPlanningMethod, String> {
  const FamilyPlanningMethodConverter();

  @override
  FamilyPlanningMethod fromSql(String fromDb) =>
      FamilyPlanningMethod.tryParse(fromDb) ?? _unknown('FamilyPlanningMethod', fromDb);

  @override
  String toSql(FamilyPlanningMethod value) => value.code;
}

class FamilyPlanningActTypeConverter extends TypeConverter<FamilyPlanningActType, String> {
  const FamilyPlanningActTypeConverter();

  @override
  FamilyPlanningActType fromSql(String fromDb) =>
      FamilyPlanningActType.tryParse(fromDb) ?? _unknown('FamilyPlanningActType', fromDb);

  @override
  String toSql(FamilyPlanningActType value) => value.code;
}

class PregnancyOutcomeConverter extends TypeConverter<PregnancyOutcome, String> {
  const PregnancyOutcomeConverter();

  @override
  PregnancyOutcome fromSql(String fromDb) =>
      PregnancyOutcome.tryParse(fromDb) ?? _unknown('PregnancyOutcome', fromDb);

  @override
  String toSql(PregnancyOutcome value) => value.code;
}

class SyncOperationConverter extends TypeConverter<SyncOperation, String> {
  const SyncOperationConverter();

  @override
  SyncOperation fromSql(String fromDb) =>
      SyncOperation.values.where((v) => v.code == fromDb).firstOrNull ??
      _unknown('SyncOperation', fromDb);

  @override
  String toSql(SyncOperation value) => value.code;
}

class SyncStatusConverter extends TypeConverter<SyncStatus, String> {
  const SyncStatusConverter();

  @override
  SyncStatus fromSql(String fromDb) =>
      SyncStatus.values.where((v) => v.code == fromDb).firstOrNull ??
      _unknown('SyncStatus', fromDb);

  @override
  String toSql(SyncStatus value) => value.code;
}

/// Liste de codes stockée en texte séparé par des virgules.
///
/// Utilisée pour les facteurs de risque d'une CPN. Une table de liaison serait
/// plus orthodoxe, mais le référentiel n'est pas figé (voir
/// `docs/02-modele-donnees.md`) et la liste ne sert pas de critère de jointure.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      fromDb.isEmpty ? const [] : fromDb.split(',');

  @override
  String toSql(List<String> value) => value.join(',');
}
