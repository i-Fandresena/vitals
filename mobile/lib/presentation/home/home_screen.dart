import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/local/app_database.dart';
import '../../domain/entities/beneficiary_display.dart';
import '../../domain/enums/clinical_enums.dart';
import '../../domain/permissions.dart';
import '../auth/auth_controller.dart';
import '../auth/permissions_provider.dart';
import '../providers.dart';
import '../shell/ui_kit.dart';
import '../sync/sync_controller.dart';

/// Les quelques dossiers ouverts en dernier, sur cet appareil.
///
/// L'accueil les montre parce qu'une même personne revient souvent dans la
/// journée : pesée, puis vaccination, puis carnet à remplir. Les retrouver
/// sans retaper leur nom épargne la recherche la plus fréquente.
final dossiersRecentsProvider = FutureProvider.autoDispose<List<Beneficiary>>((
  ref,
) async {
  final auth = ref.watch(authControllerProvider);
  if (auth is! AuthSignedIn) return const [];

  final csbId = auth.user.csbId;
  if (csbId == null) return const [];

  return ref.watch(beneficiaryRepositoryProvider).recent(csbId: csbId);
});

/// Accueil.
///
/// La mise en page suit le gabarit fourni : un en-tête léger, une carte
/// d'entrée qui porte l'action dominante, une carte d'état, puis des sections
/// courtes. L'ordre reste dicté par la fréquence d'usage réelle — sur une
/// journée de CSB, on ouvre un dossier existant bien plus souvent qu'on n'en
/// crée un (CDC §7).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthSignedIn) return const SizedBox.shrink();

    final user = auth.user;
    final can = ref.watch(permissionsProvider);

    // Un profil sans accès aux dossiers individuels — l'administration
    // nationale — n'a rien à faire sur cet écran (CDC §5).
    if (!can.contains(Permission.beneficiaryViewIdentity)) {
      return _EcranSansDossier(
        fullName: user.fullName,
        roleLabel: user.role.label,
      );
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await ref.read(syncControllerProvider.notifier).synchroniser();
          ref.invalidate(dossiersRecentsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.screenPadding,
            AppDimens.space12,
            AppDimens.screenPadding,
            // Laisse passer la barre flottante : la liste défile derrière elle.
            AppDimens.bottomBarClearance,
          ),
          children: [
            _EnTete(
              initiales: user.initials,
              nom: user.fullName,
              centre: user.csbName,
            ),
            const SizedBox(height: AppDimens.space20),

            const _CarteOuverture(),
            const SizedBox(height: AppDimens.space16),

            const _CarteSynchronisation(),
            const SizedBox(height: AppDimens.space24),

            SectionHeader(
              titre: 'Dossiers récents',
              actionLibelle: 'Tout voir',
              onAction: () => context.go(Routes.search),
            ),
            const _DossiersRecents(),

            if (can.contains(Permission.beneficiaryCreate) ||
                can.contains(Permission.dashboardCsb)) ...[
              const SizedBox(height: AppDimens.space24),
              const SectionHeader(titre: 'Autres actions'),
              if (can.contains(Permission.beneficiaryCreate))
                _LigneAction(
                  icone: Icons.person_add_alt_1_rounded,
                  libelle: 'Créer un nouveau dossier',
                  detail: 'Pour une personne qui vient pour la première fois',
                  onTap: () => context.push(Routes.newBeneficiary),
                ),
              if (can.contains(Permission.dashboardCsb))
                const _LigneAction(
                  icone: Icons.insights_outlined,
                  libelle: 'Tableau de bord du centre',
                  detail: 'Ticket 2.8 — pas encore disponible',
                  onTap: null,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// En-tête : qui est connecté, et où.
///
/// Remplace la barre de titre. Le nom du centre y figure parce qu'un même
/// appareil peut passer de main en main, et qu'une saisie dans le mauvais
/// centre ne se rattrape pas depuis le terrain.
class _EnTete extends StatelessWidget {
  const _EnTete({required this.initiales, required this.nom, this.centre});

  final String initiales;
  final String nom;
  final String? centre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primaryContainer,
          child: Text(
            initiales,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(width: AppDimens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nom,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (centre != null)
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: AppDimens.space4),
                    Expanded(
                      child: Text(
                        centre!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Carte d'entrée : ouvrir un dossier.
///
/// Le champ n'est pas un vrai champ de saisie — il mène à l'écran de
/// recherche, qui gère la frappe, le tri et l'historique. Le faire ressembler
/// à un champ évite d'expliquer qu'il faut d'abord appuyer sur « Rechercher ».
class _CarteOuverture extends StatelessWidget {
  const _CarteOuverture();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppDimens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ouvrir un dossier', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppDimens.space2),
          Text(
            'Par nom, par identifiant, ou en scannant la carte',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppDimens.space16),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  child: InkWell(
                    onTap: () => context.go(Routes.search),
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                    child: Container(
                      height: AppDimens.minTouchTarget,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.space16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: AppDimens.space12),
                          Text(
                            'Nom ou identifiant',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.space8),
              Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                child: InkWell(
                  onTap: () => context.push(Routes.scan),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  child: const SizedBox(
                    width: AppDimens.minTouchTarget,
                    height: AppDimens.minTouchTarget,
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      semanticLabel: 'Scanner une carte',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// État de la synchronisation, en carte pleine couleur.
///
/// C'est l'information qu'un soignant doit pouvoir lire d'un coup d'œil avant
/// de partir en tournée : ce qui reste sur l'appareil n'est encore vu par
/// personne d'autre. Elle porte l'accent visuel de l'écran pour cette raison.
class _CarteSynchronisation extends ConsumerWidget {
  const _CarteSynchronisation();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    final theme = Theme.of(context);

    final (titre, detail) = switch (sync) {
      _ when sync.enCours => ('Envoi en cours…', 'Ne quittez pas le réseau.'),
      _ when sync.enAttente > 0 => (
        '${sync.enAttente} en attente',
        'Enregistré sur l\'appareil, pas encore envoyé.',
      ),
      _ when sync.horsLigne => (
        'Hors ligne',
        'Vous pouvez continuer à travailler normalement.',
      ),
      _ => ('Tout est envoyé', 'Le serveur a bien reçu vos saisies.'),
    };

    return HeroCard(
      onTap: sync.enCours
          ? null
          : () => ref.read(syncControllerProvider.notifier).synchroniser(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: sync.enCours
                ? const Padding(
                    padding: EdgeInsets.all(AppDimens.space12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    sync.horsLigne
                        ? Icons.cloud_off_rounded
                        : (sync.enAttente > 0
                              ? Icons.cloud_upload_outlined
                              : Icons.cloud_done_rounded),
                    color: Colors.white,
                  ),
          ),
          const SizedBox(width: AppDimens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppDimens.space2),
                Text(
                  detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (!sync.enCours)
            const Icon(Icons.refresh_rounded, color: Colors.white70),
        ],
      ),
    );
  }
}

class _DossiersRecents extends ConsumerWidget {
  const _DossiersRecents();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(dossiersRecentsProvider);
    final theme = Theme.of(context);

    return recents.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.space24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => AppCard(
        child: Text(
          'Les dossiers récents n\'ont pas pu être lus.',
          style: theme.textTheme.bodyLarge,
        ),
      ),
      data: (dossiers) {
        if (dossiers.isEmpty) {
          return AppCard(
            child: Row(
              children: [
                const TileIcon(Icons.folder_open_outlined, taille: 40),
                const SizedBox(width: AppDimens.space12),
                Expanded(
                  child: Text(
                    'Aucun dossier sur cet appareil pour le moment.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (final d in dossiers.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.space8),
                child: AppCard(
                  padding: const EdgeInsets.all(AppDimens.space12),
                  onTap: () => context.push(Routes.beneficiaryPath(d.id)),
                  child: Row(
                    children: [
                      TileIcon(
                        d.sex == Sex.f
                            ? Icons.woman_rounded
                            : Icons.man_rounded,
                        taille: 40,
                      ),
                      const SizedBox(width: AppDimens.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.displayName,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${d.ageLabel} · ${d.localId}',
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (d.isPendingSync)
                        const StatusPill(
                          'À envoyer',
                          tone: StatusTone.attente,
                        )
                      else
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.outline,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LigneAction extends StatelessWidget {
  const _LigneAction({
    required this.icone,
    required this.libelle,
    required this.detail,
    required this.onTap,
  });

  final IconData icone;
  final String libelle;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indisponible = onTap == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space8),
      child: Opacity(
        // Annoncée mais grisée : pendant les tests terrain, les utilisateurs
        // doivent savoir ce que l'application fera ensuite.
        opacity: indisponible ? 0.55 : 1,
        child: AppCard(
          padding: const EdgeInsets.all(AppDimens.space12),
          onTap: onTap,
          child: Row(
            children: [
              TileIcon(icone, taille: 40),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(libelle, style: theme.textTheme.titleSmall),
                    Text(detail, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (!indisponible)
                Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
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
class _EcranSansDossier extends StatelessWidget {
  const _EcranSansDossier({required this.fullName, required this.roleLabel});

  final String fullName;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
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
    );
  }
}
