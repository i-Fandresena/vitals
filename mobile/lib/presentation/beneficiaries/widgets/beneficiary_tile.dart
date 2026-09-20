import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/beneficiary_display.dart';
import '../../../domain/enums/clinical_enums.dart';
import '../../shell/ui_kit.dart';

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
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppDimens.space12),
        child: Row(
          children: [
            TileIcon(
              beneficiary.sex == Sex.f
                  ? Icons.woman_rounded
                  : Icons.man_rounded,
              taille: 44,
            ),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    beneficiary.displayName,
                    style: theme.textTheme.titleSmall,
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
            // avertissement : travailler hors ligne est le régime normal, et
            // le mot compte plus que la couleur en plein soleil.
            if (beneficiary.isPendingSync)
              const StatusPill(
                'À envoyer',
                tone: StatusTone.attente,
                icone: Icons.cloud_off_outlined,
              )
            else
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}
