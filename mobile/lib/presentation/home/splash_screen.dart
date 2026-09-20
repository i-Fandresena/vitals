import 'package:flutter/material.dart';

/// Écran d'attente pendant la relecture du coffre sécurisé au démarrage.
///
/// Sans libellé : l'attente se compte en dizaines de millisecondes, un texte
/// n'aurait pas le temps d'être lu et produirait un clignotement.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
