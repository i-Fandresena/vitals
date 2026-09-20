/// Nomenclatures de saisie.
///
/// ⚠️ **Propositions à faire valider par un référent du ministère de la Santé
/// avant toute collecte réelle.** Les codes sont figés dans les données une
/// fois saisis : les changer après coup rendrait incomparables les actes
/// d'avant et d'après.
///
/// Les listes sont volontairement courtes. Un menu de quarante motifs serait
/// plus complet et moins utilisé : le personnel choisirait « Autre » par
/// lassitude, et la donnée perdrait sa valeur statistique. Mieux vaut douze
/// motifs réellement sélectionnés qu'une nomenclature exhaustive contournée.
library;

/// Motif de consultation.
enum MotifConsultation {
  fievre('FIEVRE', 'Fièvre'),
  paludismeSuspect('PALUDISME_SUSPECT', 'Paludisme suspecté'),
  toux('TOUX', 'Toux, difficulté respiratoire'),
  diarrhee('DIARRHEE', 'Diarrhée'),
  douleurAbdominale('DOULEUR_ABDOMINALE', 'Douleur abdominale'),
  plaie('PLAIE', 'Plaie, traumatisme'),
  infectionCutanee('INFECTION_CUTANEE', 'Problème de peau'),
  malnutrition('MALNUTRITION', 'Malnutrition suspectée'),
  suiviGrossesse('SUIVI_GROSSESSE', 'Suivi de grossesse'),
  suiviEnfant('SUIVI_ENFANT', "Suivi de l'enfant"),
  controle('CONTROLE', 'Contrôle, suite de soins'),
  autre('AUTRE', 'Autre motif');

  const MotifConsultation(this.code, this.label);
  final String code;
  final String label;

  static MotifConsultation? tryParse(String? code) =>
      MotifConsultation.values.where((v) => v.code == code).firstOrNull;
}

/// Facteur de risque relevé pendant une consultation prénatale.
///
/// Ce sont ceux qui déclenchent une référence vers un niveau supérieur : la
/// liste sert à décider, pas à décrire.
enum FacteurRisqueCpn {
  ageJeune('AGE_JEUNE', 'Moins de 18 ans'),
  ageEleve('AGE_ELEVE', 'Plus de 35 ans'),
  grandeMultipare('GRANDE_MULTIPARE', 'Cinq grossesses ou plus'),
  petiteTaille('PETITE_TAILLE', 'Taille inférieure à 1,50 m'),
  hypertension('HYPERTENSION', 'Tension élevée'),
  anemie('ANEMIE', 'Pâleur, anémie suspectée'),
  saignement('SAIGNEMENT', 'Saignement'),
  oedemes('OEDEMES', 'Œdèmes'),
  cesarienne('CESARIENNE', 'Césarienne antérieure'),
  grossesseMultiple('GROSSESSE_MULTIPLE', 'Grossesse multiple'),
  presentationAnormale('PRESENTATION_ANORMALE', 'Présentation anormale'),
  autre('AUTRE_RISQUE', 'Autre facteur de risque');

  const FacteurRisqueCpn(this.code, this.label);
  final String code;
  final String label;

  static FacteurRisqueCpn? tryParse(String? code) =>
      FacteurRisqueCpn.values.where((v) => v.code == code).firstOrNull;
}

/// Calendrier vaccinal du PEV.
///
/// L'âge indicatif sert à proposer la bonne dose par défaut, jamais à
/// l'imposer : un enfant rattrapé à trois ans reçoit le BCG qu'il n'a pas eu
/// à la naissance, et l'application ne doit pas l'en empêcher.
extension CalendrierPev on Object {
  /// Doses habituelles par antigène.
  static const Map<String, int> dosesParAntigene = {
    'BCG': 1,
    'VPO': 4,
    'VPI': 1,
    'PENTA': 3,
    'PNEUMO': 3,
    'ROTA': 2,
    'VAR': 1,
    'RR': 2,
    'VAT': 5,
  };

  /// Âge indicatif de la dose, en semaines depuis la naissance.
  static const Map<String, List<int>> agesIndicatifs = {
    'BCG': [0],
    'VPO': [0, 6, 10, 14],
    'VPI': [14],
    'PENTA': [6, 10, 14],
    'PNEUMO': [6, 10, 14],
    'ROTA': [6, 10],
    'VAR': [39],
    'RR': [39, 78],
  };
}
