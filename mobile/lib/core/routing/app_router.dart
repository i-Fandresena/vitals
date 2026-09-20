import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/permissions.dart';
import '../../presentation/auth/auth_controller.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/permissions_provider.dart';
import '../../presentation/beneficiaries/beneficiary_detail_screen.dart';
import '../../presentation/beneficiaries/beneficiary_form_screen.dart';
import '../../presentation/beneficiaries/beneficiary_search_screen.dart';
import '../../presentation/beneficiaries/qr_scan_screen.dart';
import '../../presentation/care/antenatal_form_screen.dart';
import '../../presentation/care/consultation_form_screen.dart';
import '../../presentation/care/vaccination_form_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/home/profil_screen.dart';
import '../../presentation/home/splash_screen.dart';

/// Chemins de l'application, nommés en français comme le reste du code.
abstract final class Routes {
  const Routes._();

  static const String splash = '/demarrage';
  static const String login = '/connexion';
  static const String home = '/';
  static const String search = '/recherche';
  static const String newBeneficiary = '/nouveau-dossier';
  static const String scan = '/scan';
  static const String profil = '/profil';

  /// `/dossier/<uuid>`
  static const String beneficiary = '/dossier';

  /// Saisies rattachées à un dossier : `<route>/<uuid du dossier>`.
  static const String consultation = '/consultation';
  static const String antenatal = '/cpn';
  static const String vaccination = '/vaccination';

  static String beneficiaryPath(String id) => '$beneficiary/$id';
}

/// Relaie les changements d'état d'authentification au routeur.
///
/// `GoRouter` attend un `Listenable` ; Riverpod expose un flux. Cette classe
/// fait le pont, sans recréer le routeur à chaque changement — ce qui
/// effacerait la pile de navigation.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    debugLogDiagnostics: false,

    // L'aiguillage est centralisé ici : aucun écran n'a à vérifier lui-même
    // que l'utilisateur est connecté, et une route ajoutée plus tard est
    // protégée par défaut.
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      switch (auth) {
        case AuthLoading():
          return location == Routes.splash ? null : Routes.splash;
        case AuthSignedOut():
          return location == Routes.login ? null : Routes.login;
        case AuthSignedIn():
          if (location == Routes.login || location == Routes.splash) {
            return Routes.home;
          }
      }

      // Une route atteinte autrement que par un bouton — lien profond,
      // historique de navigation après un changement de rôle — doit être
      // refusée comme les autres. Le serveur refuserait de toute façon, mais
      // l'utilisateur ne doit pas se retrouver devant un formulaire voué à
      // échouer.
      final granted = ref.read(permissionsProvider);

      if (location == Routes.newBeneficiary &&
          !granted.contains(Permission.beneficiaryCreate)) {
        return Routes.home;
      }

      if (!granted.contains(Permission.beneficiaryViewIdentity) &&
          (location == Routes.search ||
              location == Routes.scan ||
              location.startsWith(Routes.beneficiary))) {
        return Routes.home;
      }

      // Les saisies de soin exigent l'accès au contenu clinique. Le serveur
      // refuserait de toute façon, mais l'utilisateur ne doit pas se retrouver
      // devant un formulaire voué à échouer.
      final saisiesDeSoin = {
        Routes.consultation: Permission.consultationRecord,
        Routes.antenatal: Permission.antenatalRecord,
        Routes.vaccination: Permission.vaccinationRecord,
      };
      for (final entree in saisiesDeSoin.entries) {
        if (location.startsWith(entree.key) && !granted.contains(entree.value)) {
          return Routes.home;
        }
      }

      return null;
    },

    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.search,
        builder: (context, state) => const BeneficiarySearchScreen(),
      ),
      GoRoute(
        path: Routes.newBeneficiary,
        builder: (context, state) {
          // Un nom deviné depuis la recherche infructueuse est pré-rempli :
          // l'agent vient de le taper, le retaper serait une perte de temps.
          final prefill = state.uri.queryParameters['nom'];
          return BeneficiaryFormScreen(prefilledName: prefill);
        },
      ),
      GoRoute(
        path: Routes.scan,
        builder: (context, state) => const QrScanScreen(),
      ),
      GoRoute(
        path: '${Routes.beneficiary}/:id',
        builder: (context, state) =>
            BeneficiaryDetailScreen(beneficiaryId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.profil,
        builder: (context, state) => const ProfilScreen(),
      ),

      // Saisies de soin. Elles portent l'identifiant du dossier dans l'URL
      // plutôt qu'un objet en mémoire : une reprise après mise en veille
      // retrouve ainsi le bon dossier.
      GoRoute(
        path: '${Routes.consultation}/:id',
        builder: (context, state) =>
            ConsultationFormScreen(beneficiaryId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${Routes.antenatal}/:id',
        builder: (context, state) =>
            AntenatalFormScreen(beneficiaryId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${Routes.vaccination}/:id',
        builder: (context, state) =>
            VaccinationFormScreen(beneficiaryId: state.pathParameters['id']!),
      ),
    ],

    errorBuilder: (context, state) => const _RouteNotFound(),
  );
});

/// Écran de repli. Ne devrait jamais s'afficher, mais vaut mieux qu'une page
/// technique en anglais devant un utilisateur de CSB.
class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cet écran est introuvable.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(Routes.home),
                child: const Text("Revenir à l'accueil"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
