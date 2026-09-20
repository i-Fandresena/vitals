import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/permissions.dart';
import 'auth_controller.dart';

/// Permissions de l'utilisateur connecté.
///
/// Sert à **ne pas proposer l'impossible** : masquer une action qu'un profil
/// n'a pas le droit d'effectuer évite une erreur au moment le plus gênant,
/// devant le patient. Ce n'est pas une protection — c'est le serveur qui
/// refuse (`backend/src/auth/permissions.ts`).
final permissionsProvider = Provider<Set<Permission>>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth is! AuthSignedIn) return const {};

  return permissionsFor(
    auth.user.role,
    // ⚠️ Le référentiel complet du centre arrive avec la synchronisation
    // (ticket 3.1). En attendant, l'application ne connaît pas encore le
    // réglage `allowsNurseAntenatalCare` : les infirmiers d'un centre sans
    // sage-femme ne verront donc pas encore la saisie des CPN, même si le
    // serveur l'autoriserait. Sans effet tant que le ticket 2.5 n'est pas
    // livré, mais à reprendre avec lui.
    csbAllowsNurseAntenatalCare: false,
  );
});

/// Raccourci de lecture dans un widget.
extension PermissionCheck on WidgetRef {
  bool can(Permission permission) =>
      watch(permissionsProvider).contains(permission);
}
