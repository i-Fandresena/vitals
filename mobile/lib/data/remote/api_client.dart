import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';

/// Client HTTP de l'application.
///
/// Il ne journalise ni corps de requête ni corps de réponse : ils transportent
/// des données de santé, et les journaux d'un appareil Android sont lisibles
/// par d'autres applications sur les anciennes versions du système.
class ApiClient {
  ApiClient({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
              contentType: Headers.jsonContentType,
              // Les codes d'erreur sont traduits ici en exceptions métier,
              // plutôt que levés bruts par Dio.
              validateStatus: (status) => status != null && status < 500,
            ),
          );

  final Dio dio;

  String? _accessToken;

  // ignore: avoid_setters_without_getters
  set accessToken(String? token) => _accessToken = token;

  Options get _authorized => Options(
    headers: _accessToken == null
        ? null
        : {'Authorization': 'Bearer $_accessToken'},
  );

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    return _guard(() async {
      final response = await dio.post<dynamic>(
        path,
        data: body,
        options: authenticated ? _authorized : null,
      );
      return _unwrap(response);
    });
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) async {
    return _guard(() async {
      final response = await dio.get<dynamic>(
        path,
        queryParameters: query,
        options: authenticated ? _authorized : null,
      );
      return _unwrap(response);
    });
  }

  Map<String, dynamic> _unwrap(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    final data = response.data;

    if (status >= 200 && status < 300) {
      if (data is Map<String, dynamic>) return data;
      if (data == null || (data is String && data.isEmpty)) return const {};
      return {'data': data};
    }

    // Le message du serveur est repris tel quel : il est déjà rédigé en
    // français et pensé pour être montré à l'utilisateur.
    final message = data is Map<String, dynamic> ? data['message'] : null;
    final text = message is List ? message.join('\n') : message?.toString();

    throw switch (status) {
      400 || 422 => ValidationException(text ?? 'Saisie invalide'),
      401 => AuthException(text ?? 'Session expirée, reconnexion nécessaire'),
      403 => ForbiddenException(
        text ?? 'Action non autorisée pour votre profil',
      ),
      404 => const ServerException('Ressource introuvable'),
      429 => const AuthException('Trop de tentatives, patientez une minute'),
      _ => ServerException(text ?? 'Le serveur a rencontré un problème'),
    };
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => const NetworkException(
          'Le serveur met trop de temps à répondre',
        ),
        DioExceptionType.connectionError ||
        DioExceptionType.unknown => const NetworkException(),
        DioExceptionType.badCertificate => const NetworkException(
          'Connexion au serveur non sécurisée',
        ),
        _ => const ServerException(),
      };
    }
  }
}
