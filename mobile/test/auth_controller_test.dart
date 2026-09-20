import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitals/core/errors/app_exception.dart';
import 'package:vitals/data/repositories/auth_repository.dart';
import 'package:vitals/domain/entities/authenticated_user.dart';
import 'package:vitals/domain/enums/user_role.dart';
import 'package:vitals/presentation/auth/auth_controller.dart';
import 'package:vitals/presentation/providers.dart';

// Lever autre chose qu'une `Exception` est justement le cas que ces tests
// reproduisent : une panne native remonte parfois une chaîne nue.
// ignore_for_file: only_throw_errors

/// Dépôt d'authentification dont on choisit l'issue.
class _DepotFactice implements AuthRepository {
  _DepotFactice({this.echec, this.utilisateur});

  /// Ce que `login` lève, le cas échéant.
  final Object? echec;
  final AuthenticatedUser? utilisateur;

  @override
  Future<AuthenticatedUser> login({
    required String username,
    required String password,
  }) async {
    if (echec != null) throw echec!;
    return utilisateur!;
  }

  @override
  Future<AuthenticatedUser?> restoreSession() async {
    if (echec != null) throw echec!;
    return utilisateur;
  }

  @override
  Future<void> logout() async {
    if (echec != null) throw echec!;
  }

  @override
  Future<String> deviceId() async => 'appareil-test';

  @override
  Future<String> deviceLabel() async => 'Appareil de test';

  // Les membres privés du dépôt réel ne sont pas utilisés par le contrôleur.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

const _utilisateur = AuthenticatedUser(
  id: 'u1',
  username: 'test',
  fullName: 'Agent Test',
  role: UserRole.infirmier,
);

ProviderContainer _conteneur(_DepotFactice depot) {
  final c = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(depot)],
  );
  addTearDown(c.dispose);
  return c;
}

/// Attend que la restauration initiale, lancée en micro-tâche, soit terminée.
Future<void> _laisserDemarrer(ProviderContainer c) async {
  c.read(authControllerProvider);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('Échec de connexion', () {
    // L'invariant qui compte : quoi qu'il arrive, l'état sort de
    // `AuthLoading`. Y rester bloque l'application sur l'écran de démarrage,
    // sans message ni moyen de revenir — c'est la panne la plus difficile à
    // diagnostiquer depuis le terrain, parce qu'elle ne dit rien.
    test('un identifiant refusé ramène à l\'écran de connexion', () async {
      final c = _conteneur(
        _DepotFactice(echec: const AuthException('Identifiants incorrects')),
      );
      await _laisserDemarrer(c);

      await c
          .read(authControllerProvider.notifier)
          .signIn(username: 'a', password: 'b');

      final etat = c.read(authControllerProvider);
      expect(etat, isA<AuthSignedOut>());
      expect((etat as AuthSignedOut).error, 'Identifiants incorrects');
    });

    test('une panne imprévue ne laisse pas l\'écran tourner', () async {
      // Le cas réel : ouverture de la base chiffrée, coffre du système, ou
      // n'importe quoi d'autre qui n'est pas une AppException.
      final c = _conteneur(
        _DepotFactice(echec: StateError('coffre du système indisponible')),
      );
      await _laisserDemarrer(c);

      await c
          .read(authControllerProvider.notifier)
          .signIn(username: 'a', password: 'b');

      expect(c.read(authControllerProvider), isA<AuthSignedOut>());
    });

    test('une exception de type inconnu produit quand même un message', () async {
      final c = _conteneur(_DepotFactice(echec: 'panne native opaque'));
      await _laisserDemarrer(c);

      await c
          .read(authControllerProvider.notifier)
          .signIn(username: 'a', password: 'b');

      final etat = c.read(authControllerProvider);
      expect(etat, isA<AuthSignedOut>());
      // Le détail technique est repris : sans appareil branché, c'est la seule
      // chose qu'un agent puisse rapporter.
      expect((etat as AuthSignedOut).error, contains('panne native opaque'));
    });

    test('la connexion ne passe jamais par AuthLoading', () async {
      // `AuthLoading` renvoie au démarrage via le routeur. S'en servir pour
      // une connexion en cours arracherait l'utilisateur à son formulaire.
      final c = _conteneur(_DepotFactice(utilisateur: _utilisateur));
      await _laisserDemarrer(c);

      final vus = <AuthState>[];
      c.listen(authControllerProvider, (_, apres) => vus.add(apres));

      await c
          .read(authControllerProvider.notifier)
          .signIn(username: 'a', password: 'b');

      expect(vus.whereType<AuthLoading>(), isEmpty);
      expect(c.read(authControllerProvider), isA<AuthSignedIn>());
    });
  });

  group('Démarrage', () {
    test('une restauration qui échoue mène à la connexion, pas au vide', () async {
      final c = _conteneur(_DepotFactice(echec: StateError('base illisible')));
      await _laisserDemarrer(c);

      final etat = c.read(authControllerProvider);
      expect(etat, isA<AuthSignedOut>());
      expect((etat as AuthSignedOut).error, isNotNull);
    });

    test('sans session enregistrée, on arrive à la connexion sans erreur', () async {
      final c = _conteneur(_DepotFactice());
      await _laisserDemarrer(c);

      final etat = c.read(authControllerProvider);
      expect(etat, isA<AuthSignedOut>());
      expect((etat as AuthSignedOut).error, isNull);
    });
  });

  test('une déconnexion aboutit même si le nettoyage échoue', () async {
    // Laisser une session ouverte sur un appareil qu'on rend ou qu'on prête
    // serait pire que de perdre le nettoyage.
    final c = _conteneur(_DepotFactice(echec: StateError('coffre verrouillé')));
    await _laisserDemarrer(c);

    await c.read(authControllerProvider.notifier).signOut();

    expect(c.read(authControllerProvider), isA<AuthSignedOut>());
  });
}
