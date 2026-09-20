import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../auth/auth_controller.dart';
import '../shell/ui_kit.dart';
import '../sync/sync_controller.dart';

/// Profil de l'utilisateur connecté.
///
/// Regroupe ce qui était dispersé : qui je suis, où en est la synchronisation,
/// et la déconnexion. Cette dernière quitte le haut de l'écran d'accueil —
/// c'est une action rare et irréversible dans la journée, elle n'a rien à
/// faire à portée de pouce à côté des gestes courants.
class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthSignedIn) return const SizedBox.shrink();

    final user = auth.user;
    final sync = ref.watch(syncControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          children: [
            HeroCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Text(
                      user.initials,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppDimens.space4),
                        StatusPill(user.role.label, tone: StatusTone.info),
                        if (user.csbName != null) ...[
                          const SizedBox(height: AppDimens.space8),
                          Text(
                            user.csbName!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.space24),

            const SectionHeader(titre: 'Synchronisation'),
            AppCard(
              onTap: sync.enCours
                  ? null
                  : () => ref.read(syncControllerProvider.notifier).synchroniser(),
              child: Row(
                children: [
                  TileIcon(
                    sync.horsLigne
                        ? Icons.cloud_off_outlined
                        : Icons.cloud_done_outlined,
                    taille: 40,
                  ),
                  const SizedBox(width: AppDimens.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sync.enCours
                              ? 'Synchronisation en cours…'
                              : (sync.horsLigne ? 'Hors ligne' : 'À jour'),
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppDimens.space2),
                        Text(
                          _detailSynchro(sync),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (sync.enCours)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else
                    Icon(Icons.refresh, color: theme.colorScheme.outline),
                ],
              ),
            ),

            if (sync.enEchec > 0) ...[
              const SizedBox(height: AppDimens.space12),
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StatusPill(
                      'Refusé',
                      tone: StatusTone.alerte,
                      icone: Icons.error_outline,
                    ),
                    const SizedBox(width: AppDimens.space12),
                    Expanded(
                      child: Text(
                        '${sync.enEchec} enregistrement'
                        '${sync.enEchec > 1 ? 's ont' : ' a'} été refusé'
                        '${sync.enEchec > 1 ? 's' : ''} par le serveur. '
                        'Signalez-le au responsable du centre.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppDimens.space32),
            OutlinedButton.icon(
              onPressed: () => _confirmerDeconnexion(context, ref),
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
            ),
            const SizedBox(height: AppDimens.space32),
          ],
        ),
      ),
    );
  }

  String _detailSynchro(SyncState sync) {
    if (sync.enAttente > 0) {
      return '${sync.enAttente} enregistrement'
          '${sync.enAttente > 1 ? 's' : ''} en attente d\'envoi. '
          'Rien n\'est perdu.';
    }
    if (sync.derniere == null) return 'Jamais synchronisé sur cet appareil.';

    final ecart = DateTime.now().difference(sync.derniere!);
    if (ecart.inMinutes < 2) return 'Dernier échange à l\'instant.';
    if (ecart.inHours < 1) return 'Dernier échange il y a ${ecart.inMinutes} min.';
    if (ecart.inDays < 1) return 'Dernier échange il y a ${ecart.inHours} h.';
    return 'Dernier échange il y a ${ecart.inDays} jour'
        '${ecart.inDays > 1 ? 's' : ''}.';
  }

  Future<void> _confirmerDeconnexion(BuildContext context, WidgetRef ref) async {
    final enAttente = ref.read(syncControllerProvider).enAttente;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: Text(
          enAttente > 0
              // L'avertir avant, pas après : ces enregistrements restent sur
              // l'appareil, mais personne d'autre ne les enverra.
              ? '$enAttente enregistrement${enAttente > 1 ? 's' : ''} '
                    'attend${enAttente > 1 ? 'ent' : ''} encore d\'être '
                    'envoyé${enAttente > 1 ? 's' : ''} au serveur.\n\n'
                    'Synchronisez avant de vous déconnecter si vous le pouvez.'
              : 'Vous devrez saisir à nouveau votre identifiant et votre mot '
                    'de passe.',
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

    if (confirme ?? false) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}
