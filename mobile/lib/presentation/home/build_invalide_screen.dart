import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Écran affiché quand l'APK a été construit sans adresse de serveur.
///
/// Sans lui, l'application démarre normalement, l'agent saisit son mot de
/// passe, attend trente secondes et lit « le serveur met trop de temps à
/// répondre ». Le message accuse le réseau alors que l'APK est en cause : on
/// vérifie la couverture, le serveur, le compte — tout sauf le build.
///
/// Un APK dans cet état ne doit jamais atteindre un centre. L'écran s'adresse
/// donc à celui qui l'a construit, pas au personnel de santé.
class BuildInvalideScreen extends StatelessWidget {
  const BuildInvalideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.space32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.build_circle_outlined,
                    size: 56,
                    color: AppColors.accentAction,
                  ),
                  const SizedBox(height: AppDimens.space16),
                  const Text(
                    'APK construit sans adresse de serveur',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppDimens.space12),
                  const Text(
                    "Cette version cherche le serveur sur l'adresse de "
                    "l'émulateur, qui n'existe pas sur un téléphone. Aucune "
                    'connexion ne peut aboutir.\n\n'
                    'Ne pas distribuer cet APK. Le reconstruire avec :',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppDimens.space16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimens.space12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusMedium,
                      ),
                    ),
                    child: const SelectableText(
                      'flutter build apk --release --split-per-abi \\\n'
                      '  --dart-define=API_BASE_URL=https://votre-serveur/api/v1',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.space16),
                  const Text(
                    'Adresse compilée : ${AppConfig.apiBaseUrl}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
