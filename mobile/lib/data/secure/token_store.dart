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
  static const _keySyncCursor = 'sync.cursor';
  static const _keyLastSync = 'sync.last';

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
      // Le curseur part aussi : un autre soignant peut se connecter sur le
      // même téléphone, et il ne doit pas hériter d'un curseur qui lui ferait
      // sauter tout ce qui a changé avant son arrivée.
      _storage.delete(key: _keySyncCursor),
      _storage.delete(key: _keyLastSync),
    ]);
  }

  /// Identifiant de l'appareil, créé au premier lancement puis conservé.
  Future<String?> readDeviceId() => _storage.read(key: _keyDeviceId);

  Future<void> saveDeviceId(String deviceId) =>
      _storage.write(key: _keyDeviceId, value: deviceId);

  /// Curseur de synchronisation : l'horodatage serveur du dernier lot reçu.
  ///
  /// Rangé ici plutôt qu'en base parce qu'un re-téléchargement est sans
  /// conséquence — les enregistrements s'écrivent par clé primaire — et qu'il
  /// n'a donc pas besoin de partager la transaction des données.
  ///
  /// C'est l'heure du **serveur**, jamais celle de l'appareil : c'est elle qui
  /// ordonne les changements, et l'horloge d'un téléphone peut dériver.
  Future<String?> readSyncCursor() => _storage.read(key: _keySyncCursor);

  Future<void> saveSyncCursor(String cursor) =>
      _storage.write(key: _keySyncCursor, value: cursor);

  /// Date de la dernière synchronisation réussie, pour l'affichage.
  Future<DateTime?> readLastSync() async {
    final brut = await _storage.read(key: _keyLastSync);
    return brut == null ? null : DateTime.tryParse(brut);
  }

  Future<void> saveLastSync(DateTime quand) =>
      _storage.write(key: _keyLastSync, value: quand.toIso8601String());
}
