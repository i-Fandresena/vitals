import '../enums/user_role.dart';

/// Utilisateur connecté.
class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.csbId,
    this.csbName,
  });

  final String id;
  final String username;
  final String fullName;
  final UserRole role;

  /// CSB de rattachement. Nul pour l'administration nationale, qui n'accède à
  /// aucun dossier individuel (CDC §5).
  final String? csbId;
  final String? csbName;

  factory AuthenticatedUser.fromJson(Map<String, dynamic> json) {
    final roleCode = json['role'] as String?;
    final role = UserRole.tryParse(roleCode);

    if (role == null) {
      // Un rôle inconnu signifie que le serveur est plus récent que
      // l'application. Refuser la session est préférable à l'ouvrir avec des
      // droits mal interprétés.
      throw StateError(
        'Rôle "$roleCode" inconnu de cette version de l\'application. '
        'Mettez à jour Vitals.',
      );
    }

    return AuthenticatedUser(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['fullName'] as String,
      role: role,
      csbId: json['csbId'] as String?,
      csbName: json['csbName'] as String?,
    );
  }

  /// Initiales, pour l'accueil.
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
