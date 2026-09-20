import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../auth/auth_controller.dart';
import '../providers.dart';

/// Résultat d'une recherche de dossier.
class BeneficiarySearchState {
  const BeneficiarySearchState({
    this.results = const [],
    this.query = '',
    this.isLoading = false,
    this.error,
  });

  final List<Beneficiary> results;
  final String query;
  final bool isLoading;
  final String? error;

  /// Vrai quand une recherche a été saisie mais n'a rien donné — distinct de
  /// l'écran d'accueil vide, qui affiche les dossiers récents.
  bool get isEmptySearch =>
      query.trim().isNotEmpty && results.isEmpty && !isLoading;

  BeneficiarySearchState copyWith({
    List<Beneficiary>? results,
    String? query,
    bool? isLoading,
    String? error,
  }) {
    return BeneficiarySearchState(
      results: results ?? this.results,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class BeneficiarySearchController extends Notifier<BeneficiarySearchState> {
  Timer? _debounce;

  @override
  BeneficiarySearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(() => _run(''));
    return const BeneficiarySearchState(isLoading: true);
  }

  /// Relance la recherche après une courte pause.
  ///
  /// 250 ms : assez pour ne pas interroger la base à chaque lettre sur un
  /// appareil lent, assez court pour que la liste paraisse suivre la frappe.
  void onQueryChanged(String query) {
    state = state.copyWith(query: query, isLoading: true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(query));
  }

  Future<void> refresh() => _run(state.query);

  Future<void> _run(String query) async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthSignedIn) return;

    final csbId = auth.user.csbId;
    if (csbId == null) {
      // Profil sans rattachement : l'administration nationale n'accède à aucun
      // dossier individuel (CDC §5). Ce n'est pas une erreur technique.
      state = state.copyWith(
        results: const [],
        isLoading: false,
        error: "Votre profil n'accède pas aux dossiers individuels.",
      );
      return;
    }

    try {
      final results = await ref
          .read(beneficiaryRepositoryProvider)
          .search(csbId: csbId, query: query);

      // Une recherche plus ancienne peut se terminer après une plus récente :
      // on ignore son résultat plutôt que d'afficher une liste périmée.
      if (query != state.query) return;

      state = state.copyWith(results: results, isLoading: false);
    } on Object catch (_) {
      state = state.copyWith(
        results: const [],
        isLoading: false,
        error: 'La recherche a échoué. Réessayez.',
      );
    }
  }
}

final beneficiarySearchProvider =
    NotifierProvider<BeneficiarySearchController, BeneficiarySearchState>(
      BeneficiarySearchController.new,
    );
