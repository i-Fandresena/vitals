/// Énumérations cliniques.
///
/// Chaque valeur porte le `code` échangé avec le serveur (identique à
/// l'énumération Prisma correspondante) et le `label` affiché en français.
///
/// ⚠️ Les listes d'antigènes, de méthodes de planification familiale et
/// d'issues de grossesse sont des propositions. Elles doivent être alignées sur
/// les nomenclatures du ministère de la Santé avant toute collecte réelle
/// (voir `docs/02-modele-donnees.md`).
library;

enum Sex {
  f('F', 'Féminin'),
  m('M', 'Masculin');

  const Sex(this.code, this.label);
  final String code;
  final String label;

  static Sex? tryParse(String? code) =>
      Sex.values.where((v) => v.code == code).firstOrNull;
}

enum ConsultationType {
  curative('CURATIVE', 'Consultation curative'),
  enfant('ENFANT', "Consultation de l'enfant"),
  postnatale('POSTNATALE', 'Consultation postnatale'),
  autre('AUTRE', 'Autre');

  const ConsultationType(this.code, this.label);
  final String code;
  final String label;

  static ConsultationType? tryParse(String? code) =>
      ConsultationType.values.where((v) => v.code == code).firstOrNull;
}

/// Antigènes du Programme Élargi de Vaccination.
enum VaccineCode {
  bcg('BCG', 'BCG'),
  vpo('VPO', 'Polio oral (VPO)'),
  vpi('VPI', 'Polio injectable (VPI)'),
  penta('PENTA', 'Pentavalent'),
  pneumo('PNEUMO', 'Pneumocoque'),
  rota('ROTA', 'Rotavirus'),
  var_('VAR', 'Rougeole'),
  rr('RR', 'Rougeole-Rubéole'),
  vat('VAT', 'Tétanos (VAT)'),
  autre('AUTRE', 'Autre');

  const VaccineCode(this.code, this.label);
  final String code;
  final String label;

  static VaccineCode? tryParse(String? code) =>
      VaccineCode.values.where((v) => v.code == code).firstOrNull;
}

enum FamilyPlanningMethod {
  pilule('PILULE', 'Pilule'),
  injectable('INJECTABLE', 'Injectable'),
  implant('IMPLANT', 'Implant'),
  diu('DIU', 'DIU'),
  preservatifMasculin('PRESERVATIF_MASCULIN', 'Préservatif masculin'),
  preservatifFeminin('PRESERVATIF_FEMININ', 'Préservatif féminin'),
  collierDuCycle('COLLIER_DU_CYCLE', 'Collier du cycle'),
  mama('MAMA', 'MAMA (allaitement)'),
  ligatureTubaire('LIGATURE_TUBAIRE', 'Ligature des trompes'),
  vasectomie('VASECTOMIE', 'Vasectomie'),
  contraceptionUrgence('CONTRACEPTION_URGENCE', "Contraception d'urgence"),
  autre('AUTRE', 'Autre');

  const FamilyPlanningMethod(this.code, this.label);
  final String code;
  final String label;

  static FamilyPlanningMethod? tryParse(String? code) =>
      FamilyPlanningMethod.values.where((v) => v.code == code).firstOrNull;
}

enum FamilyPlanningActType {
  nouvelleAdherente('NOUVELLE_ADHERENTE', 'Nouvelle adhérente'),
  renouvellement('RENOUVELLEMENT', 'Renouvellement'),
  changementMethode('CHANGEMENT_METHODE', 'Changement de méthode'),
  arret('ARRET', 'Arrêt');

  const FamilyPlanningActType(this.code, this.label);
  final String code;
  final String label;

  static FamilyPlanningActType? tryParse(String? code) =>
      FamilyPlanningActType.values.where((v) => v.code == code).firstOrNull;
}

enum PregnancyOutcome {
  enCours('EN_COURS', 'Grossesse en cours'),
  accouchementVivant('ACCOUCHEMENT_VIVANT', 'Naissance vivante'),
  mortNe('MORT_NE', 'Mort-né'),
  avortement('AVORTEMENT', 'Avortement'),
  perdueDeVue('PERDUE_DE_VUE', 'Perdue de vue');

  const PregnancyOutcome(this.code, this.label);
  final String code;
  final String label;

  static PregnancyOutcome? tryParse(String? code) =>
      PregnancyOutcome.values.where((v) => v.code == code).firstOrNull;
}

/// Opérations placées dans la file de synchronisation.
enum SyncOperation {
  create('CREATE'),
  update('UPDATE'),
  cancel('CANCEL'),
  archive('ARCHIVE');

  const SyncOperation(this.code);
  final String code;
}

/// État d'une entrée de la file de synchronisation.
enum SyncStatus {
  /// En attente d'envoi.
  pending('PENDING'),

  /// Envoi en cours.
  inFlight('IN_FLIGHT'),

  /// Rejetée par le serveur de façon définitive (droits, donnée invalide).
  /// Distinguée d'un simple échec réseau : réessayer ne servirait à rien,
  /// il faut une intervention humaine.
  failed('FAILED');

  const SyncStatus(this.code);
  final String code;
}
