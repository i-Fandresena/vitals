import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../domain/permissions.dart';
import '../auth/permissions_provider.dart';

/// Barre de navigation flottante, reprise du gabarit mobile fourni.
///
/// Elle remplace les actions en haut d'écran, et ce n'est pas qu'une question
/// de goût : l'application se tient **à une main, debout**, souvent l'autre
/// occupée. Le bas de l'écran est la seule zone qu'un pouce atteint sans
/// changer de prise.
///
/// Le bouton central est surélevé et porte l'action qui revient le plus
/// souvent dans une journée de CSB : ouvrir un dossier en scannant sa carte.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.onglet});

  final Widget child;
  final ShellTab onglet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final droits = ref.watch(permissionsProvider);
    final peutCreer = droits.contains(Permission.beneficiaryCreate);

    return Scaffold(
      // La barre flotte au-dessus du contenu : la liste continue derrière
      // elle, ce qui évite une bande vide en bas d'un écran déjà petit.
      extendBody: true,
      body: child,
      bottomNavigationBar: _BarreFlottante(
        onglet: onglet,
        peutCreer: peutCreer,
      ),
    );
  }
}

enum ShellTab { accueil, recherche, scan, nouveau, profil }

class _BarreFlottante extends StatelessWidget {
  const _BarreFlottante({required this.onglet, required this.peutCreer});

  final ShellTab onglet;
  final bool peutCreer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppDimens.space16,
        0,
        AppDimens.space16,
        AppDimens.space12,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space8,
            vertical: AppDimens.space8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Onglet(
                icone: Icons.home_rounded,
                libelle: 'Accueil',
                actif: onglet == ShellTab.accueil,
                onTap: () => context.go(Routes.home),
              ),
              _Onglet(
                icone: Icons.search_rounded,
                libelle: 'Chercher',
                actif: onglet == ShellTab.recherche,
                onTap: () => context.go(Routes.search),
              ),

              // Action centrale surélevée : scanner une carte est le geste le
              // plus fréquent devant une personne qui se présente.
              _BoutonCentral(
                actif: onglet == ShellTab.scan,
                onTap: () => context.push(Routes.scan),
              ),

              _Onglet(
                icone: Icons.person_add_alt_1_rounded,
                libelle: 'Nouveau',
                actif: onglet == ShellTab.nouveau,
                // Masqué plutôt que désactivé pour un profil sans le droit :
                // un bouton grisé qu'on ne pourra jamais utiliser est du bruit.
                masque: !peutCreer,
                onTap: () => context.push(Routes.newBeneficiary),
              ),
              _Onglet(
                icone: Icons.account_circle_rounded,
                libelle: 'Profil',
                actif: onglet == ShellTab.profil,
                onTap: () => context.push(Routes.profil),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({
    required this.icone,
    required this.libelle,
    required this.actif,
    required this.onTap,
    this.masque = false,
  });

  final IconData icone;
  final String libelle;
  final bool actif;
  final VoidCallback onTap;
  final bool masque;

  @override
  Widget build(BuildContext context) {
    if (masque) return const SizedBox(width: 56);

    return Semantics(
      selected: actif,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: Container(
          width: 60,
          constraints: const BoxConstraints(minHeight: AppDimens.minTouchTarget),
          padding: const EdgeInsets.symmetric(vertical: AppDimens.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icone,
                size: 24,
                // Le blanc plein contre un bleu clair : l'état actif se lit
                // au contraste, pas à une nuance de teinte.
                color: actif ? Colors.white : AppColors.primaryContainer,
              ),
              const SizedBox(height: AppDimens.space2),
              Text(
                libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
                  color: actif ? Colors.white : AppColors.primaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoutonCentral extends StatelessWidget {
  const _BoutonCentral({required this.actif, required this.onTap});

  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Scanner une carte',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.space4),
        child: Material(
          color: actif ? Colors.white : AppColors.accentAction,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 28,
                color: actif ? AppColors.primaryDark : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
