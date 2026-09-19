import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Jetons de session d'un appareil.
class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;

  bool isAccessExpired({Duration margin = Duration.zero}) =>
      DateTime.now().add(margin).isAfter(accessExpiresAt);
}

/// Stockage des jetons dans le coffre du système.
///
/// Sur Android, `flutter_secure_storage` s'appuie sur le Keystore : la clé de
/// chiffrement ne quitte pas le matériel sécurisé et les jetons ne sont pas
/// lisibles en extrayant le stockage de l'application.
///
/// Ce qui n'est **jamais** écrit ici : le mot de passe de l'utilisateur. Il
/// sert à obtenir des jetons et est immédiatement oublié. Un appareil perdu
/// expose au pire une session révocable, jamais un mot de passe.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyAccess = 'auth.access_token';
  static const _keyRefresh = 'auth.refresh_token';
  static const _keyExpiry = 'auth.access_expires_at';
  static const _keyUserId = 'auth.user_id';
  static const _keyDeviceId = 'device.id';

  Future<void> save(SessionTokens tokens, {required String userId}) async {
    await Future.wait([
      _storage.write(key: _keyAccess, value: tokens.accessToken),
      _storage.write(key: _keyRefresh, value: tokens.refreshToken),
      _storage.write(
        key: _keyExpiry,
        value: tokens.accessExpiresAt.toIso8601String(),
      ),
      _storage.write(key: _keyUserId, value: userId),
    ]);
  }

  Future<SessionTokens?> read() async {
    final access = await _storage.read(key: _keyAccess);
    final refresh = await _storage.read(key: _keyRefresh);
    final expiry = await _storage.read(key: _keyExpiry);

    if (access == null || refresh == null || expiry == null) return null;

    final expiresAt = DateTime.tryParse(expiry);
    if (expiresAt == null) return null;

    return SessionTokens(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: expiresAt,
    );
  }

  Future<String?> readUserId() => _storage.read(key: _keyUserId);

  /// Efface la session. N'efface pas l'identifiant d'appareil : il doit rester
  /// stable d'une session à l'autre pour que le serveur reconnaisse le
  /// téléphone et puisse le révoquer s'il est perdu.
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _keyAccess),
      _storage.delete(key: _keyRefresh),
      _storage.delete(key: _keyExpiry),
      _storage.delete(key: _keyUserId),
    ]);
  }

  /// Identifiant de l'appareil, créé au premier lancement puis conservé.
  Future<String?> readDeviceId() => _storage.read(key: _keyDeviceId);

  Future<void> saveDeviceId(String deviceId) =>
      _storage.write(key: _keyDeviceId, value: deviceId);
}
