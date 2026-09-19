import 'package:device_info_plus/device_info_plus.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/authenticated_user.dart';
import '../local/app_database.dart';
import '../remote/api_client.dart';
import '../secure/token_store.dart';

/// Authentification et cycle de vie de la session.
///
/// Principe directeur : **le réseau ne conditionne jamais l'ouverture de
/// l'application.** Les jetons vivent dans le coffre du système, le profil de
/// l'utilisateur dans la base locale. Au démarrage, la session se rétablit sans
/// aucun appel réseau ; le renouvellement du jeton se fait en arrière-plan et
/// son échec ne déconnecte personne (CDC §6).
class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required TokenStore tokenStore,
    required AppDatabase database,
  }) : _api = apiClient,
       _tokens = tokenStore,
       _db = database;

  final ApiClient _api;
  final TokenStore _tokens;
  final AppDatabase _db;

  /// Identifiant de l'appareil, stable d'une session à l'autre.
  ///
  /// Généré une fois puis conservé. Volontairement pas un identifiant matériel
  /// (IMEI, ANDROID_ID) : ce sont des données personnelles, ils exigent des
  /// permissions et survivent à une réinitialisation, sans rien apporter ici.
  Future<String> deviceId() async {
    final existing = await _tokens.readDeviceId();
    if (existing != null) return existing;

    final generated = const Uuid().v4();
    await _tokens.saveDeviceId(generated);
    return generated;
  }

  /// Libellé lisible de l'appareil. Affiché côté serveur dans la liste des
  /// appareils : « Tecno Spark 8 » est plus utile qu'un UUID au moment de
  /// révoquer un téléphone perdu.
  Future<String> deviceLabel() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return '${info.manufacturer} ${info.model}'.trim();
    } catch (_) {
      return 'Appareil Android';
    }
  }

  Future<AuthenticatedUser> login({
    required String username,
    required String password,
  }) async {
    final json = await _api.post(
      '/auth/login',
      authenticated: false,
      body: {
        'username': username.trim(),
        'password': password,
        'deviceId': await deviceId(),
        'deviceLabel': await deviceLabel(),
      },
    );

    final userJson = json['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const ServerException('Réponse de connexion inattendue');
    }

    final user = AuthenticatedUser.fromJson(userJson);

    _api.accessToken = json['accessToken'] as String?;
    await _tokens.save(_tokensFrom(json), userId: user.id);
    await _cacheUser(user);

    return user;
  }

  /// Rétablit la session au démarrage, sans appel réseau.
  ///
  /// Renvoie `null` s'il n'y a pas de session utilisable. Si le jeton d'accès
  /// est expiré, un renouvellement est tenté — mais son échec pour cause de
  /// réseau laisse la session ouverte : l'application doit rester utilisable
  /// hors ligne, qui est le cas normal sur le terrain.
  Future<AuthenticatedUser?> restoreSession() async {
    final stored = await _tokens.read();
    if (stored == null) return null;

    final userId = await _tokens.readUserId();
    if (userId == null) return null;

    final user = await _cachedUser(userId);
    if (user == null) {
      // Jetons présents mais profil absent : état incohérent, on repart propre.
      await _tokens.clear();
      return null;
    }

    _api.accessToken = stored.accessToken;

    if (stored.isAccessExpired(margin: AppConfig.tokenRefreshMargin)) {
      final stillValid = await _tryRefresh(stored, userId);
      // Session révoquée côté serveur : les jetons viennent d'être effacés,
      // rendre l'utilisateur ici le laisserait dans une session fantôme.
      if (!stillValid) return null;
    }

    return user;
  }

  /// Renouvelle le jeton d'accès. Ne lève pas : l'appel est opportuniste.
  ///
  /// Renvoie `true` si la session est toujours valide côté serveur, `false` si
  /// elle a été révoquée (l'utilisateur est alors déconnecté).
  Future<bool> _tryRefresh(SessionTokens stored, String userId) async {
    try {
      final json = await _api.post(
        '/auth/refresh',
        authenticated: false,
        body: {
          'refreshToken': stored.refreshToken,
          'deviceId': await deviceId(),
        },
      );

      _api.accessToken = json['accessToken'] as String?;
      await _tokens.save(_tokensFrom(json), userId: userId);
      return true;
    } on NetworkException {
      // Hors ligne : on garde la session. Seule la synchronisation attendra.
      return true;
    } on AuthException {
      // Jeton refusé — appareil révoqué ou compte désactivé. Session terminée.
      await logout();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on AppException {
      // Sans réseau, la révocation côté serveur attendra la prochaine
      // synchronisation. Ce qui compte pour l'utilisateur qui rend l'appareil,
      // c'est que les jetons disparaissent d'ici.
    }
    _api.accessToken = null;
    await _tokens.clear();
  }

  /// Met le profil en cache local pour permettre un démarrage hors ligne.
  /// Aucun mot de passe n'est stocké, seulement l'identité et le rôle.
  Future<void> _cacheUser(AuthenticatedUser user) async {
    await _db
        .into(_db.localUsers)
        .insertOnConflictUpdate(
          LocalUsersCompanion.insert(
            id: user.id,
            username: user.username,
            fullName: user.fullName,
            role: user.role,
            csbId: Value(user.csbId),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );

    if (user.csbId != null && user.csbName != null) {
      await _db
          .into(_db.csbs)
          .insertOnConflictUpdate(
            CsbsCompanion.insert(
              id: user.csbId!,
              // Le code du CSB arrive avec le référentiel complet au ticket 3.1 ;
              // en attendant, l'identifiant sert de valeur de repli.
              code: user.csbId!,
              name: user.csbName!,
            ),
          );
    }
  }

  Future<AuthenticatedUser?> _cachedUser(String userId) async {
    final row = await (_db.select(
      _db.localUsers,
    )..where((u) => u.id.equals(userId))).getSingleOrNull();

    if (row == null) return null;

    String? csbName;
    if (row.csbId != null) {
      final csb = await (_db.select(
        _db.csbs,
      )..where((c) => c.id.equals(row.csbId!))).getSingleOrNull();
      csbName = csb?.name;
    }

    return AuthenticatedUser(
      id: row.id,
      username: row.username,
      fullName: row.fullName,
      role: row.role,
      csbId: row.csbId,
      csbName: csbName,
    );
  }

  SessionTokens _tokensFrom(Map<String, dynamic> json) {
    final expiresIn = json['expiresIn'];
    final seconds = expiresIn is int ? expiresIn : 900;

    return SessionTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      accessExpiresAt: DateTime.now().add(Duration(seconds: seconds)),
    );
  }
}
