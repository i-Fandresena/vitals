import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

/// Thème de l'application.
///
/// Trois partis pris, tous dictés par le CDC §7 et les conditions de terrain :
///
/// 1. **Police système, aucune police téléchargée.** Une police personnalisée
///    alourdit l'APK et n'apporte rien de lisible en plus.
/// 2. **Texte plus grand que la norme Material.** Le corps de texte est à 16
///    au lieu de 14 : l'application se lit à bout de bras, parfois par des
///    personnes qui n'ont pas de lunettes à portée.
/// 3. **Aucune surface translucide ni ombre portée marquée.** Coûteux à
///    afficher sur les appareils d'entrée de gamme, et illisible au soleil.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    );

    return _base(scheme);
  }

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.darkOnPrimary,
      primaryContainer: Color(0xFF005145),
      onPrimaryContainer: AppColors.primaryContainer,
      secondary: Color(0xFFB4CCC4),
      onSecondary: Color(0xFF1F352F),
      secondaryContainer: Color(0xFF354B45),
      onSecondaryContainer: Color(0xFFD0E8E0),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkOnSurface,
      surfaceContainer: AppColors.darkSurfaceContainer,
      surfaceContainerHigh: Color(0xFF242E2A),
      onSurfaceVariant: AppColors.darkOnSurfaceVariant,
      outline: AppColors.darkOutline,
      outlineVariant: Color(0xFF3C4A46),
    );

    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final textTheme = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),

      // Champs de saisie : bordure visible en permanence. Les champs
      // « soulignés » ou sans contour obligent à chercher où écrire.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space16,
          vertical: AppDimens.space16,
        ),
        border: _fieldBorder(scheme.outline),
        enabledBorder: _fieldBorder(scheme.outline),
        focusedBorder: _fieldBorder(
          scheme.primary,
          AppDimens.borderWidthFocused,
        ),
        errorBorder: _fieldBorder(scheme.error),
        focusedErrorBorder: _fieldBorder(
          scheme.error,
          AppDimens.borderWidthFocused,
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.primary,
        ),
        errorStyle: textTheme.bodyMedium?.copyWith(color: scheme.error),
        // Le texte saisi doit être plus lisible que l'étiquette.
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppDimens.primaryActionHeight),
          textStyle: textTheme.titleMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppDimens.fieldHeight),
          textStyle: textTheme.titleMedium,
          side: BorderSide(color: scheme.outline, width: AppDimens.borderWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppDimens.minTouchTarget,
            AppDimens.minTouchTarget,
          ),
          textStyle: textTheme.titleSmall,
        ),
      ),

      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppDimens.space12,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space16,
        ),
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.onSurface,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: scheme.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  static OutlineInputBorder _fieldBorder(
    Color color, [
    double width = AppDimens.borderWidth,
  ]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Échelle typographique resserrée : six styles utilisés, pas treize.
  /// Un nombre limité de tailles rend la hiérarchie lisible d'un coup d'œil.
  static TextTheme _textTheme(ColorScheme scheme) {
    final onSurface = scheme.onSurface;
    final variant = scheme.onSurfaceVariant;

    return TextTheme(
      // Titre d'écran
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: onSurface,
      ),
      // Titre de section
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: onSurface,
      ),
      // Libellé de bouton, titre de ligne de liste
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: onSurface,
      ),
      // Corps de texte et saisie — 16 et non 14
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: onSurface),
      // Texte secondaire, aide de champ
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: variant),
      // Étiquette de donnée, horodatage
      labelSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: variant,
      ),
    );
  }
}
