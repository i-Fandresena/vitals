import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../domain/entities/authenticated_user.dart';
import '../auth/auth_controller.dart';

/// Accueil.
///
/// **Écran provisoire du ticket 1.4** : il confirme seulement que la session
/// est ouverte et que le profil est correctement rétabli, y compris après
/// fermeture de l'application.
///
/// Les actions réelles — rechercher un dossier, en créer un, enregistrer une
/// consultation — arrivent en Phase 2. Elles seront placées ici par ordre de
/// fréquence d'usage, pas par ordre logique : le CDC §7 demande que le
/// professionnel comprenne immédiatement où chercher une personne.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.user});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

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

            Text('Prochaines étapes', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppDimens.space8),
            Text(
              'Le socle technique est en place : base locale, authentification '
              'et session. Les fonctions métier arrivent en Phase 2.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppDimens.space16),

            const _PlannedAction(
              icon: Icons.search,
              label: 'Rechercher un dossier',
              ticket: 'Ticket 2.1',
            ),
            const _PlannedAction(
              icon: Icons.person_add_outlined,
              label: 'Nouveau dossier',
              ticket: 'Ticket 2.1',
            ),
            const _PlannedAction(
              icon: Icons.assignment_outlined,
              label: 'Enregistrer une consultation',
              ticket: 'Ticket 2.4',
            ),
            const _PlannedAction(
              icon: Icons.vaccines_outlined,
              label: 'Enregistrer une vaccination',
              ticket: 'Ticket 2.6',
            ),
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
          'Vous devrez saisir à nouveau votre identifiant et votre mot de passe.',
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

/// Action annoncée mais pas encore disponible.
///
/// Volontairement visible et désactivée plutôt qu'absente : pendant les tests
/// terrain, les utilisateurs doivent savoir ce que l'application fera, et
/// l'équipe doit pouvoir vérifier que l'ordre des actions correspond à leur
/// façon de travailler.
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
          subtitle: Text('Bientôt disponible · $ticket'),
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
