import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/iso_date.dart';
import '../../core/utils/local_id.dart';
import '../../data/local/app_database.dart';
import '../../domain/entities/beneficiary_display.dart';
import '../auth/auth_controller.dart';
import '../providers.dart';

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

/// Fiche d'un dossier bénéficiaire.
///
/// **Écran partiel du ticket 2.1** : identité, identifiant et QR code.
/// L'historique chronologique des soins est l'objet du ticket 2.3, et les
/// actions de saisie arrivent avec les tickets 2.4 à 2.7.
class BeneficiaryDetailScreen extends ConsumerWidget {
  const BeneficiaryDetailScreen({super.key, required this.beneficiaryId});

  final String beneficiaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(beneficiaryProvider(beneficiaryId));

    return Scaffold(
      appBar: AppBar(title: const Text('Dossier')),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _Centered(
            text: "Ce dossier n'a pas pu être ouvert.",
            icon: Icons.error_outline,
          ),
          data: (beneficiary) => beneficiary == null
              ? const _Centered(
                  text:
                      'Ce dossier est introuvable dans votre centre.\n'
                      'Il appartient peut-être à un autre CSB.',
                  icon: Icons.folder_off_outlined,
                )
              : _Content(beneficiary: beneficiary),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.beneficiary});

  final Beneficiary beneficiary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      children: [
        Text(beneficiary.displayName, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppDimens.space4),
        Text(
          '${beneficiary.sex.label} · ${beneficiary.ageLabel}',
          style: theme.textTheme.bodyLarge,
        ),

        if (beneficiary.hasImpossibleBirthDate) ...[
          const SizedBox(height: AppDimens.space12),
          const _Warning(
            message:
                'La date de naissance enregistrée est dans le futur. '
                'Elle doit être corrigée.',
          ),
        ],

        if (beneficiary.isPendingSync) ...[
          const SizedBox(height: AppDimens.space12),
          const _OfflineNotice(),
        ],

        const SizedBox(height: AppDimens.space24),

        _IdentityCard(beneficiary: beneficiary),
        const SizedBox(height: AppDimens.space24),

        _QrCard(beneficiary: beneficiary),
        const SizedBox(height: AppDimens.space24),

        Text('Suite du dossier', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppDimens.space8),
        Text(
          "L'historique des soins et la saisie des consultations, vaccinations "
          'et activités de planification familiale arrivent en Phase 2 '
          '(tickets 2.3 à 2.7).',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: AppDimens.space32),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.beneficiary});

  final Beneficiary beneficiary;

  @override
  Widget build(BuildContext context) {
    final birth = IsoDate.parse(beneficiary.birthDate);
    final birthLabel = birth == null
        ? 'Inconnue'
        : '${birth.day.toString().padLeft(2, '0')}/'
              '${birth.month.toString().padLeft(2, '0')}/${birth.year}'
              '${beneficiary.birthDateIsEstimated ? ' (estimée)' : ''}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.space16),
        child: Column(
          children: [
            _Field(label: 'Identifiant', value: beneficiary.localId),
            _Field(label: 'Date de naissance', value: birthLabel),
            if (beneficiary.fokontany != null &&
                beneficiary.fokontany!.isNotEmpty)
              _Field(label: 'Fokontany', value: beneficiary.fokontany!),
            if (beneficiary.phone != null && beneficiary.phone!.isNotEmpty)
              _Field(label: 'Téléphone', value: beneficiary.phone!),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

/// Carte du QR code.
///
/// Le code n'encode que l'UUID du dossier — ni nom, ni date de naissance, ni
/// donnée de santé. C'est ce qui permet de le coller sur un carnet remis à la
/// personne : perdu ou photographié, il ne révèle rien et n'est exploitable que
/// depuis l'application, par quelqu'un d'authentifié.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.beneficiary});

  final Beneficiary beneficiary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = LocalId.toQrPayload(beneficiary.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.space16),
        child: Column(
          children: [
            Text('Code du dossier', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppDimens.space16),

            // Fond blanc imposé, quel que soit le thème : un QR code sur fond
            // teinté devient illisible pour beaucoup de lecteurs.
            Container(
              padding: const EdgeInsets.all(AppDimens.space12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
              ),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                // Correction haute : le code sera imprimé, plié, sali et lu
                // dans de mauvaises conditions.
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
            const SizedBox(height: AppDimens.space16),

            SelectableText(
              beneficiary.localId,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimens.space4),
            Text(
              'À reporter sur le carnet de la personne',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.space12),

            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: beneficiary.localId),
                );
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
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.space12),
      decoration: BoxDecoration(
        color: AppColors.offlineContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.offline),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Text(
              'Enregistré sur cet appareil. Sera envoyé au serveur dès que '
              'la connexion sera disponible.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.message});

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
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.onWarningContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: AppDimens.space16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
