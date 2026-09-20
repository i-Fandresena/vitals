import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/beneficiary_display.dart';

/// Ligne de dossier dans une liste de résultats.
///
/// Trois informations seulement : le nom, le sexe et l'âge, l'identifiant
/// lisible. C'est ce qui permet de confirmer qu'on a bien la personne présente
/// devant soi. Tout le reste attend l'ouverture du dossier.
class BeneficiaryTile extends StatelessWidget {
  const BeneficiaryTile({
    super.key,
    required this.beneficiary,
    required this.onTap,
  });

  final Beneficiary beneficiary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space8),
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppDimens.listRowHeight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.space16,
              vertical: AppDimens.space12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        beneficiary.displayName,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.space2),
                      Text(
                        '${beneficiary.sex.label} · ${beneficiary.ageLabel}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppDimens.space2),
                      Text(
                        beneficiary.localId,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),

                // Signale un dossier encore absent du serveur. Information, pas
                // avertissement : travailler hors ligne est le régime normal.
                if (beneficiary.isPendingSync)
                  const Padding(
                    padding: EdgeInsets.only(left: AppDimens.space8),
                    child: Tooltip(
                      message: 'Pas encore synchronisé',
                      child: Icon(
                        Icons.cloud_off_outlined,
                        size: 20,
                        color: AppColors.offline,
                      ),
                    ),
                  ),

                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
