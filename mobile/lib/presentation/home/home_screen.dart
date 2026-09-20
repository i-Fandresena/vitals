import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_dimens.dart';
import '../../domain/permissions.dart';
import '../auth/auth_controller.dart';
import '../auth/permissions_provider.dart';
import '../sync/sync_banner.dart';

/// Accueil.
///
/// Les actions sont rangées par fréquence d'usage réelle, pas par ordre
/// logique : sur une journée de CSB, on cherche un dossier existant bien plus
/// souvent qu'on n'en crée un. « Rechercher » occupe donc la première place et
/// la plus grande surface (CDC §7).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthSignedIn) return const SizedBox.shrink();

    final user = auth.user;
    final theme = Theme.of(context);
    final can = ref.watch(permissionsProvider);

    // Un profil sans accès aux dossiers individuels — l'administration
    // nationale — n'a rien à faire sur cet écran (CDC §5).
    if (!can.contains(Permission.beneficiaryViewIdentity)) {
      return _NoRecordAccessScreen(
        fullName: user.fullName,
        roleLabel: user.role.label,
        onSignOut: () => _confirmSignOut(context, ref),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vitals'),
        actions: [
          IconButton(
            onPressed: () => _confirmSignOut(context, ref),
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
          ),
        ],
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          children: [
            const SyncBanner(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.space16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        user.initials,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.space16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppDimens.space2),
                          Text(
                            user.role.label,
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (user.csbName != null) ...[
                            const SizedBox(height: AppDimens.space2),
                            Text(
                              user.csbName!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimens.space24),

            _PrimaryAction(
              icon: Icons.search,
              label: 'Rechercher une personne',
              description: 'Par nom, identifiant ou QR code',
              onTap: () => context.push(Routes.search),
            ),
            const SizedBox(height: AppDimens.space12),

            if (can.contains(Permission.beneficiaryCreate)) ...[
              _SecondaryAction(
                icon: Icons.person_add_alt_1,
                label: 'Nouveau dossier',
                onTap: () => context.push(Routes.newBeneficiary),
              ),
              const SizedBox(height: AppDimens.space12),
            ],

            _SecondaryAction(
              icon: Icons.qr_code_scanner,
              label: 'Scanner une carte',
              onTap: () => context.push(Routes.scan),
            ),
            const SizedBox(height: AppDimens.space32),

            Text('Bientôt disponible', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppDimens.space8),

            // Annoncées seulement à qui pourra les utiliser : promettre une
            // fonction qu'un profil n'aura jamais est une fausse promesse.
            if (can.contains(Permission.consultationRecord))
              const _PlannedAction(
                icon: Icons.assignment_outlined,
                label: 'Enregistrer une consultation',
                ticket: 'Ticket 2.4',
              ),
            if (can.contains(Permission.antenatalRecord))
              const _PlannedAction(
                icon: Icons.pregnant_woman_outlined,
                label: 'Suivi de grossesse',
                ticket: 'Ticket 2.5',
              ),
            if (can.contains(Permission.vaccinationRecord))
              const _PlannedAction(
                icon: Icons.vaccines_outlined,
                label: 'Enregistrer une vaccination',
                ticket: 'Ticket 2.6',
              ),
            if (can.contains(Permission.dashboardCsb))
              const _PlannedAction(
                icon: Icons.insights_outlined,
                label: 'Tableau de bord du centre',
                ticket: 'Ticket 2.8',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez saisir à nouveau votre identifiant et votre mot de '
          'passe. Les dossiers déjà enregistrés restent sur cet appareil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

/// Action principale — grande cible, contraste fort.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.space24),
          child: Row(
            children: [
              Icon(icon, size: 36, color: scheme.onPrimary),
              const SizedBox(width: AppDimens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: scheme.onPrimary),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppDimens.listRowHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space16,
            vertical: AppDimens.space12,
          ),
          child: Row(
            children: [
              Icon(icon, size: 28, color: scheme.onSurface),
              const SizedBox(width: AppDimens.space16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Action annoncée mais pas encore disponible.
///
/// Volontairement visible et désactivée plutôt qu'absente : pendant les tests
/// terrain, les utilisateurs doivent savoir ce que l'application fera, et
/// l'équipe doit pouvoir vérifier que l'ordre correspond à leur façon de
/// travailler.
class _PlannedAction extends StatelessWidget {
  const _PlannedAction({
    required this.icon,
    required this.label,
    required this.ticket,
  });

  final IconData icon;
  final String label;
  final String ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space8),
      child: Opacity(
        opacity: 0.55,
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(ticket),
          enabled: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space16,
            vertical: AppDimens.space4,
          ),
        ),
      ),
    );
  }
}

/// Écran des profils qui n'accèdent à aucun dossier individuel.
///
/// L'administration nationale ne consulte que des indicateurs agrégés
/// (CDC §5). Plutôt qu'un accueil vide dont elle ne comprendrait pas la
/// pauvreté, on dit explicitement pourquoi il n'y a rien et où aller.
class _NoRecordAccessScreen extends StatelessWidget {
  const _NoRecordAccessScreen({
    required this.fullName,
    required this.roleLabel,
    required this.onSignOut,
  });

  final String fullName;
  final String roleLabel;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vitals'),
        actions: [
          IconButton(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.space32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insights_outlined,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: AppDimens.space16),
                Text(fullName, style: theme.textTheme.titleMedium),
                Text(roleLabel, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppDimens.space16),
                Text(
                  'Ce profil ne consulte pas les dossiers individuels, '
                  'seulement des indicateurs agrégés.\n\n'
                  'La gestion des centres et des comptes se fait depuis '
                  "l'espace d'administration, sur ordinateur.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
