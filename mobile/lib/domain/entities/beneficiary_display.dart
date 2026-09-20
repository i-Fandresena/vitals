import '../../core/utils/iso_date.dart';
import '../../data/local/app_database.dart';

/// Présentation d'un dossier bénéficiaire.
///
/// Les extensions portent sur la classe générée par Drift plutôt que sur une
/// entité de domaine recopiée : le modèle local est déjà la source de vérité,
/// et un calque supplémentaire n'apporterait que du code de recopie.
extension BeneficiaryDisplay on Beneficiary {
  /// Nom affiché. Le nom de famille d'abord, comme sur les registres papier :
  /// c'est l'ordre dans lequel le personnel cherche.
  String get displayName => '$lastName $firstName'.trim();

  /// Âge en années révolues, ou `null` si la date est illisible.
  int? get ageInYears {
    final birth = IsoDate.parse(birthDate);
    if (birth == null) return null;

    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age < 0 ? null : age;
  }

  /// Âge en mois révolus, ou `null` si la date est illisible.
  int? get ageInMonths {
    final birth = IsoDate.parse(birthDate);
    if (birth == null) return null;

    final now = DateTime.now();
    var months = (now.year - birth.year) * 12 + (now.month - birth.month);
    if (now.day < birth.day) months--;
    return months < 0 ? null : months;
  }

  /// Âge tel qu'il doit être lu par un soignant.
  ///
  /// L'unité change avec l'âge parce que la décision clinique en dépend :
  /// le calendrier vaccinal d'un nourrisson se raisonne en semaines puis en
  /// mois, alors qu'« 0 an » ne dit rien. Au-delà de deux ans, l'année suffit.
  ///
  /// Le préfixe « ~ » signale une date de naissance estimée, pour qu'une
  /// approximation ne soit jamais lue comme une donnée fiable.
  String get ageLabel {
    final months = ageInMonths;
    if (months == null) return 'âge inconnu';

    final prefix = birthDateIsEstimated ? '~' : '';

    if (months < 1) {
      final birth = IsoDate.parse(birthDate)!;
      final days = DateTime.now().difference(birth).inDays;
      if (days < 0) return 'date à vérifier';
      return '$prefix$days jour${days > 1 ? 's' : ''}';
    }

    if (months < 24) {
      return '$prefix$months mois';
    }

    final years = ageInYears ?? (months ~/ 12);
    return '$prefix$years ans';
  }

  /// Vrai si la date de naissance est dans le futur — saisie manifestement
  /// erronée, à signaler plutôt qu'à afficher telle quelle.
  bool get hasImpossibleBirthDate {
    final birth = IsoDate.parse(birthDate);
    return birth != null && birth.isAfter(DateTime.now());
  }

  bool get isArchived => archivedAt != null;

  /// Vrai tant que le dossier n'a jamais atteint le serveur.
  bool get isPendingSync => serverUpdatedAt == null;
}
