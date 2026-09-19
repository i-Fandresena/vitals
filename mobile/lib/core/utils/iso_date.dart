/// Conversion des dates « calendaires » (sans heure).
///
/// Les dates d'acte — date de consultation, de vaccination, de naissance — sont
/// stockées en texte ISO `AAAA-MM-JJ`, pas en horodatage.
///
/// La raison est un piège classique et coûteux : un horodatage « minuit local »
/// converti en UTC recule d'un jour pour toute la zone est de Greenwich.
/// Madagascar étant à UTC+3, une vaccination du 1er du mois serait comptée le
/// dernier jour du mois précédent — et les indicateurs mensuels du CDC §4
/// seraient faux, de façon discrète et difficile à repérer.
///
/// Le texte ISO n'a pas ce problème : il se trie, se compare et s'interroge par
/// intervalle exactement comme une date, sans fuseau horaire.
abstract final class IsoDate {
  const IsoDate._();

  /// Convertit une date en `AAAA-MM-JJ`, en conservant le jour local.
  static String from(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  /// Aujourd'hui, dans le fuseau de l'appareil.
  static String today() => from(DateTime.now());

  /// Relit une date ISO. Renvoie `null` si le format est invalide.
  static DateTime? parse(String? iso) {
    if (iso == null || iso.length != 10) return null;
    return DateTime.tryParse(iso);
  }

  /// Vrai si la chaîne est une date ISO valide.
  static bool isValid(String? iso) => parse(iso) != null;
}
