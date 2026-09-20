import 'package:flutter_test/flutter_test.dart';
import 'package:vitals/domain/enums/user_role.dart';
import 'package:vitals/domain/permissions.dart';

/// Vérifie que le modèle de permissions de l'application dit **exactement** la
/// même chose que celui du serveur (`backend/src/auth/permissions.ts`).
///
/// Une divergence produit l'un de deux défauts également mauvais : un bouton
/// qui échoue au moment de l'enregistrement, ou une action possible dans
/// l'interface que le serveur refusera devant le patient.
void main() {
  group('Agent communautaire', () {
    const role = UserRole.agentCommunautaire;

    test("voit l'identité et peut créer un dossier", () {
      expect(role.permissions, contains(Permission.beneficiaryViewIdentity));
      expect(role.permissions, contains(Permission.beneficiaryCreate));
      expect(role.permissions, contains(Permission.communityDataRecord));
    });

    test("n'accède jamais au contenu clinique", () {
      expect(
        role.permissions,
        isNot(contains(Permission.beneficiaryViewCareHistory)),
      );
      expect(role.permissions, isNot(contains(Permission.consultationRecord)));
      expect(role.permissions, isNot(contains(Permission.vaccinationRecord)));
      expect(role.permissions, isNot(contains(Permission.antenatalRecord)));
    });
  });

  group('Infirmier et CPN', () {
    test("ne saisit pas les CPN dans un centre pourvu d'une sage-femme", () {
      final granted = permissionsFor(UserRole.infirmier);
      expect(granted, isNot(contains(Permission.antenatalRecord)));
    });

    test("saisit les CPN quand le centre n'a pas de sage-femme", () {
      final granted = permissionsFor(
        UserRole.infirmier,
        csbAllowsNurseAntenatalCare: true,
      );
      expect(granted, contains(Permission.antenatalRecord));
      expect(granted, contains(Permission.postnatalRecord));
    });

    test("le réglage du centre n'est pas une promotion déguisée", () {
      final granted = permissionsFor(
        UserRole.infirmier,
        csbAllowsNurseAntenatalCare: true,
      );
      expect(granted, isNot(contains(Permission.dashboardCsb)));
      expect(granted, isNot(contains(Permission.manageCsbUsers)));
      expect(granted, isNot(contains(Permission.beneficiaryArchive)));
    });

    test('le réglage ne change rien pour les autres profils', () {
      for (final role in UserRole.values) {
        if (role == UserRole.infirmier) continue;
        expect(
          permissionsFor(role, csbAllowsNurseAntenatalCare: true),
          equals(role.permissions),
          reason: 'Le réglage du centre ne doit concerner que les infirmiers',
        );
      }
    });
  });

  group('Administration nationale', () {
    test("n'accède à aucun dossier individuel", () {
      // CDC §5 : les niveaux supérieurs ne voient que des indicateurs agrégés.
      const role = UserRole.adminNational;
      expect(
        role.permissions,
        isNot(contains(Permission.beneficiaryViewIdentity)),
      );
      expect(role.permissions, isNot(contains(Permission.beneficiaryCreate)));
      expect(
        role.permissions,
        isNot(contains(Permission.beneficiaryViewCareHistory)),
      );
    });

    test('voit les indicateurs agrégés', () {
      // CDC §5 : les niveaux supérieurs voient des totaux. L'oubli de cette
      // permission renvoyait un 403 sur le tableau de bord, découvert en
      // production.
      expect(
        UserRole.adminNational.permissions,
        contains(Permission.dashboardAggregated),
      );
    });

    test('le drapeau du rôle est cohérent avec ses permissions', () {
      for (final role in UserRole.values) {
        expect(
          role.accessesIndividualRecords,
          role.permissions.contains(Permission.beneficiaryViewIdentity),
          reason: '$role : accessesIndividualRecords contredit la matrice',
        );
      }
    });
  });

  group('Invariants', () {
    test('un seul profil peut archiver', () {
      final canArchive = UserRole.values
          .where((r) => r.permissions.contains(Permission.beneficiaryArchive))
          .toList();
      expect(canArchive, [UserRole.responsableCsb]);
    });

    test("voir le contenu clinique implique de voir l'identité", () {
      for (final role in UserRole.values) {
        if (role.permissions.contains(Permission.beneficiaryViewCareHistory)) {
          expect(
            role.permissions,
            contains(Permission.beneficiaryViewIdentity),
            reason: '$role voit le soin sans voir la personne',
          );
        }
      }
    });

    test('enregistrer un soin implique de voir le contenu clinique', () {
      const careActions = [
        Permission.consultationRecord,
        Permission.vaccinationRecord,
        Permission.familyPlanningRecord,
        Permission.antenatalRecord,
        Permission.postnatalRecord,
      ];

      for (final role in UserRole.values) {
        final records = careActions.any(role.permissions.contains);
        if (records) {
          expect(
            role.permissions,
            contains(Permission.beneficiaryViewCareHistory),
            reason: '$role enregistre un soin sans pouvoir le relire',
          );
        }
      }
    });

    test('aucun profil ne détient toutes les permissions', () {
      // Un rôle qui pourrait tout faire rendrait la matrice décorative.
      for (final role in UserRole.values) {
        expect(
          role.permissions.length,
          lessThan(Permission.values.length),
          reason: '$role détient la totalité des permissions',
        );
      }
    });
  });
}
