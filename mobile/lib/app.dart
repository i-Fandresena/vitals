import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class MbolaTsaraApp extends ConsumerWidget {
  const MbolaTsaraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MbolaTsara',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Thème clair imposé pour le MVP : l'application s'utilise surtout
      // dehors, où un fond sombre est moins lisible en plein soleil. Le thème
      // sombre existe et sera proposé en option après les tests terrain.
      themeMode: ThemeMode.light,

      // Interface entièrement en français, y compris les libellés système
      // (sélecteurs de date, menus d'édition de texte).
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
