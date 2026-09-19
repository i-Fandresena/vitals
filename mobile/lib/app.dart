import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'presentation/auth/auth_controller.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/home/home_screen.dart';

class VitalsApp extends StatelessWidget {
  const VitalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitals',
      debugShowCheckedModeBanner: false,
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

      home: const _AuthGate(),
    );
  }
}

/// Aiguille entre connexion et accueil selon l'état de la session.
///
/// Pas de routeur pour l'instant : deux destinations mutuellement exclusives,
/// choisies par l'état d'authentification et non par une adresse. Un routeur
/// sera introduit au ticket 2.1, quand la navigation entre dossiers,
/// consultations et tableau de bord le justifiera.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);

    return switch (state) {
      AuthLoading() => const _SplashScreen(),
      AuthSignedOut() => const LoginScreen(),
      AuthSignedIn(:final user) => HomeScreen(user: user),
    };
  }
}

/// Écran d'attente pendant la relecture du coffre sécurisé.
///
/// Sans libellé : l'attente se compte en dizaines de millisecondes, un texte
/// n'aurait pas le temps d'être lu et produirait un clignotement.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
