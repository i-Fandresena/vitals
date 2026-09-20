import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/authenticated_user.dart';
import '../providers.dart';

/// État de la session.
sealed class AuthState {
  const AuthState();
}

/// Démarrage : on relit le coffre sécurisé. Très bref, mais il faut éviter
/// d'afficher l'écran de connexion à quelqu'un qui est déjà connecté.
///
/// **Ne sert qu'au démarrage.** Une connexion en cours n'est pas cet état : le
/// routeur renvoie `AuthLoading` vers l'écran de démarrage, ce qui arracherait
/// l'utilisateur à son formulaire dès l'appui sur le bouton — et l'y laisserait
/// bloqué si la connexion échouait autrement que prévu.
class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.error});

  /// Message à montrer après un échec de connexion.
  final String? error;
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);

  final AuthenticatedUser user;
}

/// Pilote la session : restauration au démarrage, connexion, déconnexion.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // La restauration est asynchrone ; l'état initial est donc « en cours ».
    Future.microtask(_restore);
    return const AuthLoading();
  }

  Future<void> _restore() async {
    try {
      final user = await ref.read(authRepositoryProvider).restoreSession();
      state = user == null ? const AuthSignedOut() : AuthSignedIn(user);
    } on Object catch (error) {
      // Rester sur `AuthLoading` laisserait l'application figée sur l'écran de
      // démarrage, sans rien à lire ni à faire. Mieux vaut l'écran de
      // connexion et un message : au pire l'utilisateur ressaisit son mot de
      // passe, au mieux il sait quoi signaler.
      state = AuthSignedOut(error: _messageInattendu(error));
    }
  }

  /// Indique qu'une connexion est en cours, pour désactiver le bouton.
  bool _busy = false;
  bool get isBusy => _busy;

  /// Tente une connexion. Renvoie vrai en cas de succès.
  ///
  /// L'état ne passe volontairement pas par [AuthLoading] : l'écran de
  /// connexion suit lui-même sa progression et reste affiché, ce qui garde le
  /// message d'erreur là où l'utilisateur vient d'agir.
  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    if (_busy) return false;
    _busy = true;

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(username: username, password: password);
      state = AuthSignedIn(user);
      return true;
    } on AppException catch (error) {
      state = AuthSignedOut(error: error.message);
      return false;
    } on StateError catch (error) {
      // Rôle inconnu : l'application est plus ancienne que le serveur.
      state = AuthSignedOut(error: error.message);
      return false;
    } on Object catch (error) {
      // Filet de sécurité. Sans lui, une panne qu'on n'a pas prévue — coffre
      // du système, ouverture de la base chiffrée — ne produit aucun message :
      // l'écran tourne indéfiniment et rien n'indique où chercher.
      state = AuthSignedOut(error: _messageInattendu(error));
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<void> signOut() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } on Object {
      // Une déconnexion doit aboutir même si le nettoyage échoue : la garder
      // ouverte sur un appareil qu'on rend ou qu'on prête serait pire.
    }
    state = const AuthSignedOut();
  }

  /// Message pour une panne non prévue.
  ///
  /// Le détail technique y figure : sans appareil branché, c'est la seule
  /// chose qui permette à quelqu'un sur le terrain de dire ce qui s'est passé.
  /// Il ne peut pas contenir de donnée patient — aucun dossier n'est lu avant
  /// l'ouverture de session.
  String _messageInattendu(Object error) {
    final detail = error.toString();
    final abrege = detail.length > 180 ? '${detail.substring(0, 180)}…' : detail;
    return 'La connexion a échoué pour une raison inattendue.\n\n'
        'Signalez ce message au responsable :\n$abrege';
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
