import 'package:flutter/material.dart';

/// Jetons de couleur de l'application.
///
/// Palette de marque Maternal AI :
///
/// | Rôle | Couleur | Code |
/// |---|---|---|
/// | Primaire | Bleu Médical | `#1A4F76` |
/// | Accent | Rouge Corail | `#FF5E5B` |
/// | Fond | Blanc Cassé | `#F8FAFC` |
/// | Texte | Gris Ardoise | `#334155` |
///
/// **Le corail de marque ne porte jamais de texte.** Mesuré, `#FF5E5B` donne
/// 3,00:1 avec du blanc et 2,87:1 sur le fond clair, là où l'accessibilité en
/// demande 4,5:1. Ce n'est pas un détail de conformité : l'application se
/// consulte dehors, en plein soleil, et un libellé à 3:1 y devient illisible.
///
/// Le corail est donc décliné en trois usages, tous vérifiés :
///
/// - [accent] `#FF5E5B` — pastilles, points de notification, barres
///   d'indicateur, traits de soulignement. Jamais de texte dessus ni dessous.
/// - [accentAction] `#CC4A45` — boutons et étiquettes portant du texte blanc
///   (4,53:1). Assombri juste ce qu'il faut pour passer, et pas plus : au-delà
///   il vire au rouge pur et perd le caractère corail de la marque.
/// - [accentContainer] `#F9E7E9` — fonds d'alerte, avec texte ardoise
///   (8,70:1).
abstract final class AppColors {
  const AppColors._();

  // --- Primaire : Bleu Médical ---

  /// `#1A4F76`. Barre de navigation, titres, boutons principaux.
  /// 8,66:1 avec du blanc — très au-delà du minimum.
  static const Color primary = Color(0xFF1A4F76);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Teinte claire du bleu, pour les surfaces d'accueil et les pastilles.
  static const Color primaryContainer = Color(0xFFD4E4F2);
  static const Color onPrimaryContainer = Color(0xFF0A2740);

  /// Bleu assombri, pour l'état pressé et les bordures accentuées.
  static const Color primaryDark = Color(0xFF123A57);

  // --- Accent : Rouge Corail ---

  /// Accent de marque. **Aucun texte dessus.**
  static const Color accent = Color(0xFFFF5E5B);

  /// Corail utilisable sous du texte blanc (4,53:1).
  static const Color accentAction = Color(0xFFCC4A45);
  static const Color onAccentAction = Color(0xFFFFFFFF);

  /// Fond d'alerte, sous texte ardoise (8,70:1).
  static const Color accentContainer = Color(0xFFF9E7E9);
  static const Color onAccentContainer = Color(0xFF4A1512);

  // --- Fond et texte ---

  /// `#F8FAFC`, Blanc Cassé. Évite la fatigue visuelle d'un blanc pur.
  static const Color surface = Color(0xFFF8FAFC);

  /// Surfaces surélevées : cartes, lignes de liste.
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceContainer = Color(0xFFEEF2F6);
  static const Color surfaceContainerHigh = Color(0xFFE3E9F0);

  /// `#334155`, Gris Ardoise. 9,90:1 sur le fond — lisible au soleil.
  static const Color onSurface = Color(0xFF334155);

  /// Texte secondaire. Assez sombre pour rester lisible dehors : un gris de
  /// maquette classique disparaîtrait.
  static const Color onSurfaceVariant = Color(0xFF5A6B80);

  /// Bordure de champ et de carte. `#708093` et non un gris plus clair : les
  /// composants d'interface demandent 3:1, et une bordure plus pâle
  /// disparaîtrait sur un écran sale ou éclairé de biais.
  static const Color outline = Color(0xFF708093);

  /// Séparateurs discrets, jamais porteurs d'information à eux seuls.
  static const Color outlineVariant = Color(0xFFC3CEDB);

  // --- Couleurs d'état ---
  //
  // Jamais employées seules pour porter une information : elles accompagnent
  // toujours un texte ou une icône. Le daltonisme touche une part notable des
  // utilisateurs, et un écran délavé par le soleil aplatit les teintes.

  /// Erreur et alerte. Reprend la famille corail de la marque plutôt qu'un
  /// rouge étranger : une seule famille chaude pour l'accent et l'alerte.
  static const Color error = accentAction;
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = accentContainer;
  static const Color onErrorContainer = onAccentContainer;

  /// Confirmation d'enregistrement, indicateur atteint.
  static const Color success = Color(0xFF0F7A4D);
  static const Color successContainer = Color(0xFFD6F1E3);
  static const Color onSuccessContainer = Color(0xFF042014);

  /// Facteur de risque, donnée incomplète, synchronisation en attente.
  static const Color warning = Color(0xFF9A6300);
  static const Color warningContainer = Color(0xFFFDEFD3);
  static const Color onWarningContainer = Color(0xFF2E1C00);

  /// Hors ligne : état d'information, pas une erreur. C'est le régime normal
  /// de fonctionnement sur le terrain et l'interface ne doit pas alarmer.
  static const Color offline = Color(0xFF4A6280);
  static const Color offlineContainer = Color(0xFFE4EBF3);

  // --- Thème sombre ---

  static const Color darkPrimary = Color(0xFF8FC2E8);
  static const Color darkOnPrimary = Color(0xFF07243C);
  static const Color darkSurface = Color(0xFF101922);
  static const Color darkSurfaceCard = Color(0xFF17222E);
  static const Color darkOnSurface = Color(0xFFE2E8F0);
  static const Color darkSurfaceContainer = Color(0xFF1C2836);
  static const Color darkOnSurfaceVariant = Color(0xFFA9B8CA);
  static const Color darkOutline = Color(0xFF64748B);
}
