import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/sync_repository.dart';
import '../auth/auth_controller.dart';
import '../providers.dart';

/// État de la synchronisation, tel qu'il est montré à l'utilisateur.
class SyncState {
  const SyncState({
    this.enCours = false,
    this.enAttente = 0,
    this.enEchec = 0,
    this.derniere,
    this.message,
    this.horsLigne = false,
  });

  /// Une synchronisation est en train de tourner.
  final bool enCours;

  /// Mutations qui attendent d'être envoyées.
  final int enAttente;

  /// Mutations définitivement refusées. Demandent une intervention humaine.
  final int enEchec;

  final DateTime? derniere;
  final String? message;
  final bool horsLigne;

  SyncState copyWith({
    bool? enCours,
    int? enAttente,
    int? enEchec,
    DateTime? derniere,
    String? message,
    bool? horsLigne,
    bool effacerMessage = false,
  }) {
    return SyncState(
      enCours: enCours ?? this.enCours,
      enAttente: enAttente ?? this.enAttente,
      enEchec: enEchec ?? this.enEchec,
      derniere: derniere ?? this.derniere,
      message: effacerMessage ? null : (message ?? this.message),
      horsLigne: horsLigne ?? this.horsLigne,
    );
  }
}

/// Pilote la synchronisation.
///
/// Elle se déclenche seule dans trois cas : à l'ouverture d'une session, au
/// retour de la connexion, et à la demande. Rien n'est jamais bloqué en
/// attendant : l'application reste utilisable hors ligne, la file se vide
/// quand elle peut (CDC §6).
class SyncController extends Notifier<SyncState> {
  StreamSubscription<List<ConnectivityResult>>? _reseau;
  Timer? _periodique;

  @override
  SyncState build() {
    ref.onDispose(() {
      _reseau?.cancel();
      _periodique?.cancel();
    });

    // Une session qui s'ouvre déclenche un rattrapage ; une session qui se
    // ferme arrête tout, sinon on interrogerait le serveur sans utilisateur.
    ref.listen<AuthState>(authControllerProvider, (avant, apres) {
      if (apres is AuthSignedIn && avant is! AuthSignedIn) {
        _demarrer();
      } else if (apres is! AuthSignedIn) {
        _arreter();
      }
    });

    if (ref.read(authControllerProvider) is AuthSignedIn) {
      _demarrer();
    }

    return const SyncState();
  }

  void _demarrer() {
    unawaited(rafraichirCompteurs());
    unawaited(synchroniser());

    _reseau?.cancel();
    _reseau = Connectivity().onConnectivityChanged.listen((resultats) {
      final horsLigne =
          resultats.isEmpty ||
          resultats.every((r) => r == ConnectivityResult.none);

      state = state.copyWith(horsLigne: horsLigne);

      // Le retour du réseau est le meilleur moment pour vider la file : c'est
      // exactement ce qu'attendait l'agent qui a saisi en brousse.
      if (!horsLigne) unawaited(synchroniser());
    });

    // Filet de sécurité : un réseau qui n'émet aucun changement d'état, ou une
    // application restée ouverte toute la journée, ne doivent pas laisser la
    // file stagner.
    _periodique?.cancel();
    _periodique = Timer.periodic(
      const Duration(minutes: 15),
      (_) => unawaited(synchroniser()),
    );
  }

  void _arreter() {
    _reseau?.cancel();
    _reseau = null;
    _periodique?.cancel();
    _periodique = null;
    state = const SyncState();
  }

  /// Relit les compteurs sans toucher au réseau.
  Future<void> rafraichirCompteurs() async {
    final depot = ref.read(syncRepositoryProvider);
    state = state.copyWith(
      enAttente: await depot.enAttente(),
      enEchec: await depot.enEchec(),
      derniere: await depot.derniereSynchro(),
    );
  }

  Future<void> synchroniser() async {
    if (state.enCours) return;
    if (ref.read(authControllerProvider) is! AuthSignedIn) return;

    state = state.copyWith(enCours: true, effacerMessage: true);

    final resultat = await ref.read(syncRepositoryProvider).synchroniser();

    await rafraichirCompteurs();

    state = state.copyWith(
      enCours: false,
      horsLigne: !resultat.reussie,
      message: resultat.reussie ? _resume(resultat) : resultat.erreur,
    );
  }

  String? _resume(SyncResult r) {
    if (!r.aChange) return null;

    final parties = <String>[
      if (r.envoyees > 0) '${r.envoyees} envoyé${r.envoyees > 1 ? 's' : ''}',
      if (r.recues > 0) '${r.recues} reçu${r.recues > 1 ? 's' : ''}',
    ];
    return parties.join(' · ');
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);
