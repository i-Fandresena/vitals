import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_dimens.dart';
import '../../domain/permissions.dart';
import '../auth/permissions_provider.dart';
import '../sync/sync_controller.dart';
import 'beneficiary_search_controller.dart';
import 'widgets/beneficiary_tile.dart';

/// Recherche d'un dossier.
///
/// Un seul champ, qui accepte indifféremment un nom ou un identifiant : le
/// personnel tape ce qu'il a sous les yeux sans avoir à choisir un mode de
/// recherche au préalable. Le scan de QR code est immédiatement à côté, et la
/// création d'un dossier est proposée quand la recherche ne donne rien — c'est
/// exactement le moment où elle devient utile.
class BeneficiarySearchScreen extends ConsumerStatefulWidget {
  const BeneficiarySearchScreen({super.key});

  @override
  ConsumerState<BeneficiarySearchScreen> createState() =>
      _BeneficiarySearchScreenState();
}

class _BeneficiarySearchScreenState
    extends ConsumerState<BeneficiarySearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Une synchronisation qui se termine peut avoir ramené des dossiers : la
    // liste affichée serait périmée sans cette relecture.
    ref.listen<SyncState>(syncControllerProvider, (avant, apres) {
      if (avant?.enCours == true && !apres.enCours) {
        ref.read(beneficiarySearchProvider.notifier).refresh();
      }
    });

    final state = ref.watch(beneficiarySearchProvider);
    final theme = Theme.of(context);
    final canCreate = ref
        .watch(permissionsProvider)
        .contains(Permission.beneficiaryCreate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher une personne'),
        actions: [
          IconButton(
            onPressed: () => context.push(Routes.scan),
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scanner un QR code',
            iconSize: 28,
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                AppDimens.space8,
                AppDimens.screenPadding,
                AppDimens.space12,
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.words,
                onChanged: ref
                    .read(beneficiarySearchProvider.notifier)
                    .onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Nom ou identifiant',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Effacer',
                          onPressed: () {
                            _controller.clear();
                            ref
                                .read(beneficiarySearchProvider.notifier)
                                .onQueryChanged('');
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),

            Expanded(
              child: _Results(state: state, canCreate: canCreate),
            ),
          ],
        ),
      ),

      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _createBeneficiary(context),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nouveau dossier'),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            )
          : null,
    );
  }

  void _createBeneficiary(BuildContext context) {
    final typed = _controller.text.trim();
    // Le nom déjà saisi est transmis au formulaire : l'agent vient de le taper,
    // le lui faire retaper serait une étape gratuite.
    final path = typed.isEmpty
        ? Routes.newBeneficiary
        : '${Routes.newBeneficiary}?nom=${Uri.encodeQueryComponent(typed)}';
    context.push(path);
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.canCreate});

  final BeneficiarySearchState state;
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (state.error != null) {
      return _Message(icon: Icons.error_outline, text: state.error!);
    }

    if (state.isLoading && state.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.isEmptySearch) {
      return _Message(
        icon: Icons.person_search_outlined,
        text:
            'Aucun dossier ne correspond à « ${state.query.trim()} ».\n'
            'Vérifiez l\'orthographe, ou créez un nouveau dossier.',
      );
    }

    if (state.results.isEmpty) {
      return const _Message(
        icon: Icons.folder_open_outlined,
        text:
            'Aucun dossier dans ce centre pour le moment.\n'
            'Créez le premier avec le bouton ci-dessous.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        0,
        AppDimens.screenPadding,
        // Dégage la place du bouton flottant, qui masquerait la dernière ligne.
        AppDimens.space48 * 2,
      ),
      itemCount: state.results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          final count = state.results.length;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.space8),
            child: Text(
              state.query.trim().isEmpty
                  ? 'Dossiers récents'
                  : '$count résultat${count > 1 ? 's' : ''}',
              style: theme.textTheme.labelSmall,
            ),
          );
        }

        final beneficiary = state.results[index - 1];
        return BeneficiaryTile(
          beneficiary: beneficiary,
          onTap: () => context.push(Routes.beneficiaryPath(beneficiary.id)),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

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
