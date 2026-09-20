import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../domain/permissions.dart';
import '../auth/permissions_provider.dart';
import '../shell/ui_kit.dart';
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
///
/// L'écran vit dans la coquille de navigation : il n'a donc ni barre de titre
/// ni bouton flottant, qui entreraient en collision avec la barre du bas.
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
    final canCreate = ref
        .watch(permissionsProvider)
        .contains(Permission.beneficiaryCreate);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              AppDimens.space12,
              AppDimens.screenPadding,
              AppDimens.space12,
            ),
            child: Row(
              children: [
                Expanded(child: _ChampRecherche(controller: _controller)),
                const SizedBox(width: AppDimens.space8),
                Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  child: InkWell(
                    onTap: () => context.push(Routes.scan),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                    child: const SizedBox(
                      width: AppDimens.fieldHeight,
                      height: AppDimens.fieldHeight,
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
          ),

          Expanded(
            child: _Resultats(
              state: state,
              canCreate: canCreate,
              onCreer: () => _creerDossier(context),
            ),
          ),
        ],
      ),
    );
  }

  void _creerDossier(BuildContext context) {
    final saisi = _controller.text.trim();
    // Le nom déjà saisi est transmis au formulaire : l'agent vient de le taper,
    // le lui faire retaper serait une étape gratuite.
    final chemin = saisi.isEmpty
        ? Routes.newBeneficiary
        : '${Routes.newBeneficiary}?nom=${Uri.encodeQueryComponent(saisi)}';
    context.push(chemin);
  }
}

class _ChampRecherche extends ConsumerStatefulWidget {
  const _ChampRecherche({required this.controller});

  final TextEditingController controller;

  @override
  ConsumerState<_ChampRecherche> createState() => _ChampRechercheState();
}

class _ChampRechercheState extends ConsumerState<_ChampRecherche> {
  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(beneficiarySearchProvider.notifier);

    return TextField(
      controller: widget.controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      textCapitalization: TextCapitalization.words,
      onChanged: (valeur) {
        notifier.onQueryChanged(valeur);
        // Fait apparaître ou disparaître la croix d'effacement.
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: 'Nom ou identifiant',
        prefixIcon: const Icon(Icons.search_rounded),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainer,
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear_rounded),
                tooltip: 'Effacer',
                onPressed: () {
                  widget.controller.clear();
                  notifier.onQueryChanged('');
                  setState(() {});
                },
              ),
      ),
    );
  }
}

class _Resultats extends StatelessWidget {
  const _Resultats({
    required this.state,
    required this.canCreate,
    required this.onCreer,
  });

  final BeneficiarySearchState state;
  final bool canCreate;
  final VoidCallback onCreer;

  @override
  Widget build(BuildContext context) {
    if (state.error != null) {
      return _Message(icone: Icons.error_outline, texte: state.error!);
    }

    if (state.isLoading && state.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.isEmptySearch) {
      return _Message(
        icone: Icons.person_search_outlined,
        texte:
            'Aucun dossier ne correspond à « ${state.query.trim()} ».\n'
            "Vérifiez l'orthographe, ou créez le dossier.",
        // Proposée ici et pas en permanence : c'est le seul moment où créer
        // un dossier est la suite logique de ce que l'agent vient de faire.
        action: canCreate ? 'Créer ce dossier' : null,
        onAction: onCreer,
      );
    }

    if (state.results.isEmpty) {
      return _Message(
        icone: Icons.folder_open_outlined,
        texte: 'Aucun dossier dans ce centre pour le moment.',
        action: canCreate ? 'Créer le premier dossier' : null,
        onAction: onCreer,
      );
    }

    final nombre = state.results.length;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.screenPadding,
        0,
        AppDimens.screenPadding,
        // Dégage la barre de navigation, qui masquerait la dernière ligne.
        AppDimens.bottomBarClearance,
      ),
      itemCount: nombre + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return SectionHeader(
            titre: state.query.trim().isEmpty
                ? 'Dossiers récents'
                : '$nombre résultat${nombre > 1 ? 's' : ''}',
          );
        }

        final dossier = state.results[index - 1];
        return BeneficiaryTile(
          beneficiary: dossier,
          onTap: () => context.push(Routes.beneficiaryPath(dossier.id)),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icone,
    required this.texte,
    this.action,
    this.onAction,
  });

  final IconData icone;
  final String texte;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.space32,
          AppDimens.space32,
          AppDimens.space32,
          AppDimens.bottomBarClearance,
        ),
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
            if (action != null) ...[
              const SizedBox(height: AppDimens.space24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(action!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
