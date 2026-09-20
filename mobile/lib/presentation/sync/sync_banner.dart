import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import 'sync_controller.dart';

/// Bandeau d'état de la synchronisation.
///
/// Deux règles de ton, dictées par l'usage réel :
///
/// - **Hors ligne n'est pas une erreur.** C'est le régime normal d'un CSB. Le
///   bandeau informe en bleu, jamais en rouge, et dit toujours que le travail
///   est conservé.
/// - **Le silence vaut mieux qu'un message.** Quand tout est à jour et qu'il
///   n'y a rien en attente, rien ne s'affiche : un bandeau permanent finit par
///   ne plus être lu.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(syncControllerProvider);
    final theme = Theme.of(context);

    // Rien à signaler : on n'occupe pas l'écran.
    if (!etat.enCours &&
        etat.enAttente == 0 &&
        etat.enEchec == 0 &&
        !etat.horsLigne) {
      return const SizedBox.shrink();
    }

    final (fond, teinte, icone, titre, detail) = _apparence(etat);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space12),
      child: Material(
        color: fond,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: InkWell(
          onTap: etat.enCours
              ? null
              : () => ref.read(syncControllerProvider.notifier).synchroniser(),
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.space12),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: etat.enCours
                      ? CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: teinte,
                        )
                      : Icon(icone, size: 24, color: teinte),
                ),
                const SizedBox(width: AppDimens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre, style: theme.textTheme.titleSmall),
                      if (detail != null) ...[
                        const SizedBox(height: AppDimens.space2),
                        Text(detail, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
                if (!etat.enCours)
                  Icon(
                    Icons.refresh,
                    size: 20,
                    color: theme.colorScheme.outline,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color, IconData, String, String?) _apparence(SyncState etat) {
    if (etat.enCours) {
      return (
        AppColors.offlineContainer,
        AppColors.offline,
        Icons.sync,
        'Synchronisation…',
        etat.enAttente > 0 ? '${etat.enAttente} en attente d\'envoi' : null,
      );
    }

    // Les échecs définitifs passent devant : ils ne se résoudront pas seuls.
    if (etat.enEchec > 0) {
      return (
        AppColors.accentContainer,
        AppColors.accentAction,
        Icons.error_outline,
        '${etat.enEchec} enregistrement${etat.enEchec > 1 ? 's' : ''} refusé'
            '${etat.enEchec > 1 ? 's' : ''}',
        'Le serveur les a rejetés. Signalez-le au responsable du centre.',
      );
    }

    if (etat.horsLigne) {
      return (
        AppColors.offlineContainer,
        AppColors.offline,
        Icons.cloud_off_outlined,
        'Hors ligne',
        etat.enAttente > 0
            ? '${etat.enAttente} enregistrement${etat.enAttente > 1 ? 's' : ''} '
                  'en attente. Rien n\'est perdu.'
            : 'Vous pouvez continuer à travailler normalement.',
      );
    }

    return (
      AppColors.offlineContainer,
      AppColors.offline,
      Icons.cloud_upload_outlined,
      '${etat.enAttente} enregistrement${etat.enAttente > 1 ? 's' : ''} à envoyer',
      'Touchez pour synchroniser maintenant.',
    );
  }
}
