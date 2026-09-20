/// Espacements, rayons et tailles de cible.
///
/// Les valeurs partent d'une contrainte physique, pas d'une grille esthétique :
/// l'application se manipule debout, souvent à une main, parfois avec des gants
/// ou les mains humides. Les recommandations Material (48 dp) sont un plancher,
/// pas une cible.
abstract final class AppDimens {
  const AppDimens._();

  // --- Espacements, échelle de 4 ---
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  /// Dégagement sous une liste que la barre de navigation flottante recouvre.
  /// Sans lui, la dernière ligne reste inatteignable sous la barre.
  static const double bottomBarClearance = 96;

  /// Marge latérale des écrans.
  static const double screenPadding = space16;

  // --- Cibles tactiles ---

  /// Plancher absolu, jamais descendre en dessous.
  static const double minTouchTarget = 48;

  /// Hauteur des champs de saisie et des boutons secondaires.
  static const double fieldHeight = 56;

  /// Actions principales — « Enregistrer », « Nouveau dossier ». Plus hautes
  /// que la norme : ce sont les gestes répétés des dizaines de fois par jour.
  static const double primaryActionHeight = 60;

  /// Hauteur d'une ligne de liste (résultat de recherche, entrée d'historique).
  /// Assez grande pour être touchée sans viser.
  static const double listRowHeight = 72;

  // --- Rayons ---
  //
  // Plus généreux que la norme Material, repris du gabarit mobile : des angles
  // marqués rendent une interface dense, et celle-ci est déjà chargée
  // d'informations cliniques.
  static const double radiusSmall = 10;
  static const double radiusMedium = 14;
  static const double radiusLarge = 20;

  /// Rayon des pastilles et de la barre de navigation flottante.
  static const double radiusPill = 999;

  // --- Bordures ---

  /// Bordure de champ au repos. Épaisse volontairement : une bordure d'un pixel
  /// disparaît sur un écran sale ou éclairé de biais.
  static const double borderWidth = 1.5;
  static const double borderWidthFocused = 2.5;

  // --- Contenu ---

  /// Au-delà, le texte devient difficile à balayer sur une tablette.
  static const double maxContentWidth = 560;
}
