/// Erreurs présentables à l'utilisateur.
///
/// Le message est en français et décrit ce qui s'est passé **du point de vue de
/// l'utilisateur**, pas du point de vue technique : « Pas de connexion » et non
/// « SocketException ». Le personnel d'un CSB n'a pas à interpréter un message
/// de pile d'appels pour savoir s'il peut continuer à travailler.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Aucun réseau, ou serveur injoignable.
///
/// Ce n'est pas une erreur au sens strict : c'est le régime de fonctionnement
/// normal sur le terrain. L'interface doit informer, pas alarmer.
class NetworkException extends AppException {
  const NetworkException([super.message = 'Pas de connexion au serveur']);
}

/// Identifiants refusés, ou session expirée.
class AuthException extends AppException {
  const AuthException(super.message);
}

/// Droits insuffisants pour l'action demandée.
class ForbiddenException extends AppException {
  const ForbiddenException([super.message = 'Action non autorisée pour votre profil']);
}

/// Saisie invalide renvoyée par le serveur.
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Panne serveur ou cas non prévu.
class ServerException extends AppException {
  const ServerException([super.message = 'Le serveur a rencontré un problème']);
}
