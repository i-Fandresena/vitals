import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/iso_date.dart';
import '../../core/utils/local_id.dart';
import '../../data/local/app_database.dart';
import '../../data/local/daos/care_event_dao.dart';
import '../../domain/entities/beneficiary_display.dart';
import '../../domain/permissions.dart';
import '../auth/auth_controller.dart';
import '../auth/permissions_provider.dart';
import '../providers.dart';
import '../shell/ui_kit.dart';

/// Charge un dossier depuis la base locale.
final beneficiaryProvider = FutureProvider.family<Beneficiary?, String>((
  ref,
  id,
) async {
  final auth = ref.watch(authControllerProvider);
  if (auth is! AuthSignedIn) return null;

  final csbId = auth.user.csbId;
  if (csbId == null) return null;

  return ref.read(beneficiaryRepositoryProvider).findById(csbId: csbId, id: id);
});

/// Historique de soin d'un dossier (ticket 2.3).
final historiqueProvider = FutureProvider.family<List<CareEvent>, String>((
  ref,
  id,
) async {
  return ref.read(careEventRepositoryProvider).historique(id);
});

/// Fiche d'un dossier bénéficiaire.
///
/// Trois strates, dans l'ordre où un soignant les consulte : qui est cette
/// personne, que lui a-t-on fait, que puis-je faire maintenant. L'identité en
/// carte de marque parce que c'est ce qu'on vérifie d'abord — a-t-on bien la
/// bonne personne devant soi.
class BeneficiaryDetailScreen extends ConsumerWidget {
  const BeneficiaryDetailScreen({super.key, required this.beneficiaryId});

  final String beneficiaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(beneficiaryProvider(beneficiaryId));
    final droits = ref.watch(permissionsProvider);
    final voitLeSoin = droits.contains(Permission.beneficiaryViewCareHistory);

    return Scaffold(
      appBar: AppBar(title: const Text('Dossier')),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _Centre(
            texte: "Ce dossier n'a pas pu être ouvert.",
            icone: Icons.error_outline,
          ),
          data: (dossier) => dossier == null
              ? const _Centre(
                  texte:
                      'Ce dossier est introuvable dans votre centre.\n'
                      'Il appartient peut-être à un autre CSB.',
                  icone: Icons.folder_off_outlined,
                )
              : _Contenu(
                  dossier: dossier,
                  voitLeSoin: voitLeSoin,
                  droits: droits,
                ),
        ),
      ),
    );
  }
}

class _Contenu extends ConsumerWidget {
  const _Contenu({
    required this.dossier,
    required this.voitLeSoin,
    required this.droits,
  });

  final Beneficiary dossier;
  final bool voitLeSoin;
  final Set<Permission> droits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      children: [
        _CarteIdentite(dossier: dossier),
        const SizedBox(height: AppDimens.space16),

        if (dossier.hasImpossibleBirthDate) ...[
          const _Avertissement(
            message:
                'La date de naissance enregistrée est dans le futur. '
                'Elle doit être corrigée.',
          ),
          const SizedBox(height: AppDimens.space16),
        ],

        if (voitLeSoin) ...[
          _Actions(dossier: dossier, droits: droits),
          const SizedBox(height: AppDimens.space24),
          _Historique(beneficiaryId: dossier.id),
          const SizedBox(height: AppDimens.space24),
        ] else ...[
          AppCard(
            child: Row(
              children: [
                const TileIcon(Icons.lock_outline, taille: 36),
                const SizedBox(width: AppDimens.space12),
                Expanded(
                  child: Text(
                    "Votre profil consulte l'identité des personnes pour les "
                    'orienter vers le centre. Le contenu médical du dossier '
                    'ne vous est pas accessible.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.space24),
        ],

        _CarteQr(dossier: dossier),
        const SizedBox(height: AppDimens.space32),
      ],
    );
  }
}

/// Identité, en carte de marque : c'est ce qu'on vérifie en premier.
class _CarteIdentite extends StatelessWidget {
  const _CarteIdentite({required this.dossier});

  final Beneficiary dossier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final naissance = IsoDate.parse(dossier.birthDate);

    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dossier.displayName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              if (dossier.isPendingSync)
                const StatusPill(
                  'À envoyer',
                  tone: StatusTone.attente,
                  icone: Icons.cloud_off_outlined,
                ),
            ],
          ),
          const SizedBox(height: AppDimens.space12),
          Wrap(
            spacing: AppDimens.space8,
            runSpacing: AppDimens.space8,
            children: [
              StatusPill(dossier.sex.label, tone: StatusTone.info),
              StatusPill(dossier.ageLabel, tone: StatusTone.info),
              if (naissance != null)
                StatusPill(
                  '${naissance.day.toString().padLeft(2, '0')}/'
                  '${naissance.month.toString().padLeft(2, '0')}/'
                  '${naissance.year}'
                  '${dossier.birthDateIsEstimated ? " estimée" : ""}',
                  tone: StatusTone.info,
                ),
              if (dossier.fokontany != null && dossier.fokontany!.isNotEmpty)
                StatusPill(dossier.fokontany!, tone: StatusTone.info),
            ],
          ),
          const SizedBox(height: AppDimens.space16),
          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 18),
              const SizedBox(width: AppDimens.space8),
              SelectableText(
                dossier.localId,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ce qu'on peut faire, maintenant.
///
/// Les actions les plus fréquentes en premier, et seulement celles que le
/// profil peut réellement effectuer — proposer un bouton qui refusera est
/// une fausse promesse faite devant le patient.
class _Actions extends ConsumerWidget {
  const _Actions({required this.dossier, required this.droits});

  final Beneficiary dossier;
  final Set<Permission> droits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Le suivi de grossesse n'est proposé qu'aux femmes en âge de procréer :
    // l'afficher partout noierait les actions utiles.
    final ageAns = dossier.ageInYears ?? 0;
    final grossessePossible =
        dossier.sex.code == 'F' && ageAns >= 10 && ageAns <= 55;

    final actions = <(IconData, String, String)>[
      if (droits.contains(Permission.consultationRecord))
        (Icons.assignment_outlined, 'Consultation', Routes.consultation),
      if (droits.contains(Permission.antenatalRecord) && grossessePossible)
        (Icons.pregnant_woman_outlined, 'CPN', Routes.antenatal),
      if (droits.contains(Permission.vaccinationRecord))
        (Icons.vaccines_outlined, 'Vaccination', Routes.vaccination),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(titre: 'Enregistrer'),
        Row(
          children: [
            for (final (icone, libelle, route) in actions) ...[
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.space16,
                    horizontal: AppDimens.space8,
                  ),
                  onTap: () async {
                    final cree = await context.push<bool>(
                      '$route/${dossier.id}',
                    );
                    if (cree == true) {
                      // L'historique vient de changer : on le relit plutôt que
                      // d'afficher une liste périmée.
                      ref.invalidate(historiqueProvider(dossier.id));
                      ref.invalidate(beneficiaryProvider(dossier.id));
                    }
                  },
                  child: Column(
                    children: [
                      TileIcon(icone),
                      const SizedBox(height: AppDimens.space8),
                      Text(
                        libelle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
              if (route != actions.last.$3)
                const SizedBox(width: AppDimens.space12),
            ],
          ],
        ),
      ],
    );
  }
}

/// Historique de soin, en ligne de temps (ticket 2.3).
class _Historique extends ConsumerWidget {
  const _Historique({required this.beneficiaryId});

  final String beneficiaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historiqueProvider(beneficiaryId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(titre: 'Historique'),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppDimens.space24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => AppCard(
            child: Text(
              "L'historique n'a pas pu être chargé.",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          data: (evenements) => evenements.isEmpty
              ? AppCard(
                  child: Row(
                    children: [
                      const TileIcon(Icons.history, taille: 36),
                      const SizedBox(width: AppDimens.space12),
                      Expanded(
                        child: Text(
                          'Aucun soin enregistré pour cette personne.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                )
              : Timeline(
                  entrees: [
                    for (final e in evenements)
                      TimelineEntry(
                        titre: e.title,
                        detail: e.detail,
                        date: _formaterDate(e.occurredOn),
                        icone: _icone(e.kind),
                        tone: e.isCancelled
                            ? StatusTone.neutre
                            : _ton(e.kind),
                        pastille: e.isCancelled
                            ? 'Annulé'
                            : (e.isPendingSync ? 'À envoyer' : null),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  IconData _icone(CareEventKind kind) => switch (kind) {
    CareEventKind.consultation => Icons.assignment_outlined,
    CareEventKind.vaccination => Icons.vaccines_outlined,
    CareEventKind.familyPlanning => Icons.favorite_outline,
    CareEventKind.antenatal => Icons.pregnant_woman_outlined,
  };

  StatusTone _ton(CareEventKind kind) => switch (kind) {
    CareEventKind.consultation => StatusTone.info,
    CareEventKind.vaccination => StatusTone.succes,
    CareEventKind.familyPlanning => StatusTone.neutre,
    CareEventKind.antenatal => StatusTone.alerte,
  };

  String _formaterDate(String iso) {
    final d = IsoDate.parse(iso);
    if (d == null) return iso;
    const mois = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    return '${d.day} ${mois[d.month - 1]} ${d.year}';
  }
}

/// Carte du QR code.
///
/// Le code n'encode que l'UUID du dossier — ni nom, ni date de naissance, ni
/// donnée de santé. C'est ce qui permet de le coller sur un carnet remis à la
/// personne : perdu ou photographié, il ne révèle rien.
class _CarteQr extends StatelessWidget {
  const _CarteQr({required this.dossier});

  final Beneficiary dossier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        children: [
          Text('Code du dossier', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppDimens.space16),

          // Fond blanc imposé : un QR code sur fond teinté devient illisible
          // pour beaucoup de lecteurs.
          Container(
            padding: const EdgeInsets.all(AppDimens.space12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
            ),
            child: QrImageView(
              data: LocalId.toQrPayload(dossier.id),
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
              // Correction haute : le code sera imprimé, plié, sali et lu dans
              // de mauvaises conditions.
              errorCorrectionLevel: QrErrorCorrectLevel.H,
            ),
          ),
          const SizedBox(height: AppDimens.space12),
          Text(
            'À reporter sur le carnet de la personne',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.space12),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: dossier.localId));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Identifiant copié')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text("Copier l'identifiant"),
          ),
        ],
      ),
    );
  }
}

class _Avertissement extends StatelessWidget {
  const _Avertissement({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.space12),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined, color: AppColors.warning),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onWarningContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Centre extends StatelessWidget {
  const _Centre({required this.texte, required this.icone});

  final String texte;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: AppDimens.space16),
            Text(
              texte,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
