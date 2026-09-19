import 'package:flutter/material.dart';

/// Jetons de couleur de l'application.
///
/// Les valeurs sont contraintes par les conditions d'usage décrites au CDC §7 :
/// écrans bon marché, souvent consultés dehors en plein jour. Les contrastes
/// texte/fond visent donc au minimum 7:1 (AAA) sur le texte courant, au lieu du
/// 4,5:1 habituel — une nuance de gris élégante devient illisible au soleil.
abstract final class AppColors {
  const AppColors._();

  // --- Identité ---

  /// Vert-bleu profond : registre médical sans l'austérité du bleu hôpital,
  /// et suffisamment sombre pour porter du texte blanc.
  static const Color primary = Color(0xFF0B6B5E);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFB8EFE3);
  static const Color onPrimaryContainer = Color(0xFF00201B);

  static const Color secondary = Color(0xFF3F5B54);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD5E8E0);
  static const Color onSecondaryContainer = Color(0xFF0D1F1A);

  // --- Surfaces ---

  static const Color surface = Color(0xFFFAFCFB);
  static const Color onSurface = Color(0xFF12100E);
  static const Color surfaceContainer = Color(0xFFEFF3F1);
  static const Color surfaceContainerHigh = Color(0xFFE6EBE9);

  /// Texte secondaire. Volontairement plus sombre qu'un gris de maquette
  /// classique : il doit rester lisible dehors.
  static const Color onSurfaceVariant = Color(0xFF3C4A46);
  static const Color outline = Color(0xFF6B7A75);
  static const Color outlineVariant = Color(0xFFC3CECA);

  // --- Couleurs sémantiques ---
  //
  // Jamais employées seules pour porter une information : elles accompagnent
  // toujours un texte ou une icône. Le daltonisme touche une part notable des
  // utilisateurs, et un écran délavé par le soleil aplatit les teintes.

  static const Color error = Color(0xFFB3261E);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFF9DEDC);
  static const Color onErrorContainer = Color(0xFF410E0B);

  /// Confirmation d'enregistrement, indicateur atteint.
  static const Color success = Color(0xFF1B6B3A);
  static const Color successContainer = Color(0xFFCDEFD9);
  static const Color onSuccessContainer = Color(0xFF002110);

  /// Facteur de risque, donnée incomplète, synchronisation en attente.
  static const Color warning = Color(0xFF8A5300);
  static const Color warningContainer = Color(0xFFFFEAC8);
  static const Color onWarningContainer = Color(0xFF2B1700);

  /// Hors ligne : état d'information, pas une erreur. C'est le régime normal
  /// de fonctionnement sur le terrain et l'interface ne doit pas alarmer.
  static const Color offline = Color(0xFF46557F);
  static const Color offlineContainer = Color(0xFFDDE2F9);

  // --- Thème sombre ---

  static const Color darkPrimary = Color(0xFF6FD9C6);
  static const Color darkOnPrimary = Color(0xFF00382F);
  static const Color darkSurface = Color(0xFF0E1513);
  static const Color darkOnSurface = Color(0xFFE6EBE9);
  static const Color darkSurfaceContainer = Color(0xFF1A2320);
  static const Color darkOnSurfaceVariant = Color(0xFFBDC9C5);
  static const Color darkOutline = Color(0xFF87938F);
}
