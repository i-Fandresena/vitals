import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'presentation/home/build_invalide_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // L'application se tient à une main, souvent debout, parfois d'une seule
  // main occupée : la rotation n'apporte rien et déplace les repères.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Un APK de release construit sans `--dart-define=API_BASE_URL` ne peut
  // joindre aucun serveur. Le dire tout de suite vaut mieux que de le laisser
  // découvrir après trente secondes d'attente, sur un message qui accuse le
  // réseau. En debug on laisse passer : l'adresse par défaut vise l'émulateur,
  // ce qui est justement ce qu'on veut.
  if (kReleaseMode && AppConfig.adresseManquante) {
    runApp(const BuildInvalideScreen());
    return;
  }

  runApp(const ProviderScope(child: VitalsApp()));
}
