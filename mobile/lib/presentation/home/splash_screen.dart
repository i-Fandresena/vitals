import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';

/// Écran d'attente pendant la relecture du coffre sécurisé au démarrage.
///
/// Sans libellé au départ : l'attente se compte normalement en dizaines de
/// millisecondes, un texte n'aurait pas le temps d'être lu et produirait un
/// clignotement.
///
/// Mais un tourniquet nu qui dure est un cul-de-sac : rien à lire, rien à
/// faire, et depuis le terrain rien à rapporter d'autre que « ça charge ».
/// Passé quelques secondes, l'écran dit donc ce qu'il attend.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _seuil = Duration(seconds: 8);

  Timer? _minuteur;
  bool _tropLong = false;

  @override
  void initState() {
    super.initState();
    _minuteur = Timer(_seuil, () {
      if (mounted) setState(() => _tropLong = true);
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.space32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (_tropLong) ...[
                const SizedBox(height: AppDimens.space24),
                Text(
                  "L'application met plus de temps que prévu à démarrer.\n\n"
                  'Si cet écran ne disparaît pas, fermez complètement '
                  "l'application et rouvrez-la. Vos dossiers restent sur "
                  "l'appareil.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
