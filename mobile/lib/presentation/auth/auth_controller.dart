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
    final user = await ref.read(authRepositoryProvider).restoreSession();
    state = user == null ? const AuthSignedOut() : AuthSignedIn(user);
  }

  /// Indique qu'une connexion est en cours, pour désactiver le bouton.
  bool _busy = false;
  bool get isBusy => _busy;

  Future<void> signIn({required String username, required String password}) async {
    if (_busy) return;
    _busy = true;
    state = const AuthLoading();

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(username: username, password: password);
      state = AuthSignedIn(user);
    } on AppException catch (error) {
      state = AuthSignedOut(error: error.message);
    } on StateError catch (error) {
      // Rôle inconnu : l'application est plus ancienne que le serveur.
      state = AuthSignedOut(error: error.message);
    } finally {
      _busy = false;
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthSignedOut();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
