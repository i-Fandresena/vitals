/// Configuration de l'application, fournie au build.
///
/// Aucune valeur sensible ici : ce fichier est compilé dans l'APK et donc
/// lisible par quiconque le décompresse. Les secrets restent côté serveur.
abstract final class AppConfig {
  const AppConfig._();

  /// Adresse de l'API.
  ///
  /// `10.0.2.2` est l'alias de la machine hôte vu depuis l'émulateur Android —
  /// `localhost` y désignerait l'émulateur lui-même.
  ///
  /// Sur un appareil réel, passer l'adresse du serveur au build :
  /// ```
  /// flutter build apk --dart-define=API_BASE_URL=https://api.exemple.org/api/v1
  /// ```
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  /// Délais réseau volontairement longs : sur une connexion 2G de brousse, une
  /// requête peut mettre plusieurs dizaines de secondes à aboutir. Abandonner
  /// au bout de 10 secondes ferait échouer des synchronisations qui auraient
  /// fini par passer.
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);

  /// Marge de sécurité avant l'expiration du jeton d'accès : il est renouvelé
  /// un peu avant l'échéance, pour éviter qu'une requête parte avec un jeton
  /// expiré entre-temps.
  static const Duration tokenRefreshMargin = Duration(minutes: 2);
}
