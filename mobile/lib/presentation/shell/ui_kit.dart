/// Composants visuels repris des gabarits fournis.
///
/// Trois emprunts, retenus parce qu'ils servent le terrain et pas seulement
/// l'allure :
///
/// - **Carte « héros » foncée** pour l'information qu'on vient chercher en
///   premier. Le contraste fort la rend lisible en plein soleil, là où une
///   carte claire de plus se fondrait dans la page.
/// - **Pastilles d'état** plutôt que des phrases. Elles se repèrent en
///   balayant une liste, et portent toujours un mot en plus de leur couleur —
///   un écran délavé aplatit les teintes.
/// - **Ligne de temps** pour l'historique de soin. C'est la forme qui montre
///   d'un coup l'espacement entre deux actes, ce qu'une liste ne fait pas.
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Carte de contenu standard : blanche, arrondie, bordée plutôt qu'ombrée.
///
/// Une ombre portée coûte une passe de rendu supplémentaire sur les appareils
/// d'entrée de gamme, et disparaît de toute façon en plein jour. La bordure
/// tient le même rôle pour rien.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.space16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rayon = BorderRadius.circular(AppDimens.radiusLarge);

    final contenu = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: rayon,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );

    if (onTap == null) return contenu;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: rayon, child: contenu),
    );
  }
}

/// Carte mise en avant, sur fond de marque.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rayon = BorderRadius.circular(AppDimens.radiusLarge);

    final contenu = Container(
      padding: const EdgeInsets.all(AppDimens.space20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: rayon,
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.white),
          child: child,
        ),
      ),
    );

    if (onTap == null) return contenu;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: rayon, child: contenu),
    );
  }
}

/// Ton d'une pastille d'état.
enum StatusTone { neutre, succes, info, alerte, attente }

/// Pastille d'état.
///
/// Toujours un mot, jamais une couleur seule : le daltonisme touche une part
/// notable des utilisateurs, et un écran au soleil aplatit les teintes.
class StatusPill extends StatelessWidget {
  const StatusPill(this.texte, {super.key, this.tone = StatusTone.neutre, this.icone});

  final String texte;
  final StatusTone tone;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final (fond, encre) = switch (tone) {
      StatusTone.neutre => (
        Theme.of(context).colorScheme.surfaceContainer,
        AppColors.onSurfaceVariant,
      ),
      StatusTone.succes => (AppColors.successContainer, AppColors.onSuccessContainer),
      StatusTone.info => (AppColors.primaryContainer, AppColors.onPrimaryContainer),
      StatusTone.alerte => (AppColors.accentContainer, AppColors.onAccentContainer),
      StatusTone.attente => (AppColors.offlineContainer, AppColors.offline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space12,
        vertical: AppDimens.space4,
      ),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 14, color: encre),
            const SizedBox(width: AppDimens.space4),
          ],
          Text(
            texte,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: encre,
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête de section avec une action à droite.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.titre,
    this.actionLibelle,
    this.onAction,
  });

  final String titre;
  final String? actionLibelle;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space12),
      child: Row(
        children: [
          Expanded(
            child: Text(titre, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (actionLibelle != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLibelle!)),
        ],
      ),
    );
  }
}

/// Icône dans un carré arrondi teinté, comme sur les tuiles du gabarit.
class TileIcon extends StatelessWidget {
  const TileIcon(this.icone, {super.key, this.fond, this.encre, this.taille = 44});

  final IconData icone;
  final Color? fond;
  final Color? encre;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: fond ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Icon(
        icone,
        size: taille * 0.5,
        color: encre ?? scheme.onPrimaryContainer,
      ),
    );
  }
}

/// Une entrée de ligne de temps.
class TimelineEntry {
  const TimelineEntry({
    required this.titre,
    required this.date,
    this.detail,
    this.icone,
    this.tone = StatusTone.neutre,
    this.pastille,
    this.onTap,
  });

  final String titre;
  final String date;
  final String? detail;
  final IconData? icone;
  final StatusTone tone;
  final String? pastille;
  final VoidCallback? onTap;
}

/// Historique en ligne de temps.
///
/// Le trait vertical relie les actes : il montre d'un coup qu'une personne est
/// venue trois fois en un mois, ou qu'elle a disparu six mois — ce qu'une
/// liste plate n'exprime pas.
class Timeline extends StatelessWidget {
  const Timeline({super.key, required this.entrees});

  final List<TimelineEntry> entrees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        for (var i = 0; i < entrees.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colonne du trait et du point.
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: AppDimens.space16),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _couleurPoint(entrees[i].tone, scheme),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i != entrees.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(
                              vertical: AppDimens.space4,
                            ),
                            color: scheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.space12),
                    child: AppCard(
                      onTap: entrees[i].onTap,
                      padding: const EdgeInsets.all(AppDimens.space12),
                      child: Row(
                        children: [
                          if (entrees[i].icone != null) ...[
                            TileIcon(entrees[i].icone!, taille: 36),
                            const SizedBox(width: AppDimens.space12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entrees[i].titre,
                                  style: theme.textTheme.titleSmall,
                                ),
                                if (entrees[i].detail != null)
                                  Text(
                                    entrees[i].detail!,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                const SizedBox(height: AppDimens.space2),
                                Text(
                                  entrees[i].date,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          if (entrees[i].pastille != null)
                            StatusPill(
                              entrees[i].pastille!,
                              tone: entrees[i].tone,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _couleurPoint(StatusTone tone, ColorScheme scheme) => switch (tone) {
    StatusTone.succes => AppColors.success,
    StatusTone.alerte => AppColors.accentAction,
    StatusTone.attente => AppColors.offline,
    StatusTone.info => scheme.primary,
    StatusTone.neutre => scheme.outline,
  };
}
