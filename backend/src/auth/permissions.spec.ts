import { UserRole } from '@prisma/client';

import { Permission, ROLE_PERMISSIONS, hasPermission, permissionsFor } from './permissions';

/**
 * Vérifie la matrice de `docs/01-matrice-droits.md`.
 *
 * Ces tests sont volontairement écrits comme des affirmations métier plutôt
 * que comme des comparaisons d'ensembles : une modification des droits doit
 * faire échouer un test dont le nom dit ce qui a changé, pas un diff opaque.
 */
describe('Matrice des droits', () => {
  describe('Agent communautaire', () => {
    const role = UserRole.AGENT_COMMUNAUTAIRE;

    it("voit l'identité et peut créer un dossier", () => {
      expect(hasPermission(role, Permission.BeneficiaryViewIdentity)).toBe(true);
      expect(hasPermission(role, Permission.BeneficiaryCreate)).toBe(true);
      expect(hasPermission(role, Permission.CommunityDataRecord)).toBe(true);
    });

    it("n'accède jamais au contenu clinique", () => {
      // C'est la ligne que ce profil ne franchit pas : il oriente vers le CSB,
      // il ne soigne pas. C'est aussi le profil le plus exposé — appareil
      // partagé, usage hors du centre.
      expect(hasPermission(role, Permission.BeneficiaryViewCareHistory)).toBe(false);
      expect(hasPermission(role, Permission.ConsultationRecord)).toBe(false);
      expect(hasPermission(role, Permission.VaccinationRecord)).toBe(false);
      expect(hasPermission(role, Permission.FamilyPlanningRecord)).toBe(false);
      expect(hasPermission(role, Permission.AntenatalRecord)).toBe(false);
    });

    it('ne modifie ni ne consulte les indicateurs', () => {
      expect(hasPermission(role, Permission.BeneficiaryUpdateIdentity)).toBe(false);
      expect(hasPermission(role, Permission.DashboardCsb)).toBe(false);
      expect(hasPermission(role, Permission.DataExport)).toBe(false);
    });
  });

  describe('Infirmier', () => {
    const role = UserRole.INFIRMIER;

    it('enregistre consultations, vaccinations et PF', () => {
      expect(hasPermission(role, Permission.ConsultationRecord)).toBe(true);
      expect(hasPermission(role, Permission.VaccinationRecord)).toBe(true);
      expect(hasPermission(role, Permission.FamilyPlanningRecord)).toBe(true);
    });

    it("ne saisit pas les CPN dans un centre pourvu d'une sage-femme", () => {
      expect(hasPermission(role, Permission.AntenatalRecord)).toBe(false);
    });

    it('saisit les CPN quand le centre n\'a pas de sage-femme', () => {
      // Beaucoup de CSB n'en ont pas. L'interdire y bloquerait le suivi de
      // grossesse précisément là où il manque le plus de personnel.
      const granted = permissionsFor(role, { csbAllowsNurseAntenatalCare: true });
      expect(granted.has(Permission.AntenatalRecord)).toBe(true);
      expect(granted.has(Permission.PostnatalRecord)).toBe(true);
    });

    it('le réglage du centre ne débloque rien d\'autre', () => {
      const withSetting = permissionsFor(role, { csbAllowsNurseAntenatalCare: true });
      // Le drapeau ne doit pas devenir une promotion déguisée.
      expect(withSetting.has(Permission.DashboardCsb)).toBe(false);
      expect(withSetting.has(Permission.ManageCsbUsers)).toBe(false);
      expect(withSetting.has(Permission.BeneficiaryArchive)).toBe(false);
    });

    it('ne voit que les indicateurs de sa propre activité', () => {
      expect(hasPermission(role, Permission.DashboardOwnActivity)).toBe(true);
      expect(hasPermission(role, Permission.DashboardCsb)).toBe(false);
    });
  });

  describe('Sage-femme', () => {
    const role = UserRole.SAGE_FEMME;

    it('saisit les CPN sans condition', () => {
      expect(hasPermission(role, Permission.AntenatalRecord)).toBe(true);
      expect(hasPermission(role, Permission.PostnatalRecord)).toBe(true);
    });

    it('ne gère ni les comptes ni le tableau de bord du centre', () => {
      expect(hasPermission(role, Permission.ManageCsbUsers)).toBe(false);
      expect(hasPermission(role, Permission.DashboardCsb)).toBe(false);
    });
  });

  describe('Responsable du CSB', () => {
    const role = UserRole.RESPONSABLE_CSB;

    it('voit le tableau de bord complet, exporte et gère les comptes', () => {
      expect(hasPermission(role, Permission.DashboardCsb)).toBe(true);
      expect(hasPermission(role, Permission.DataExport)).toBe(true);
      expect(hasPermission(role, Permission.ManageCsbUsers)).toBe(true);
      expect(hasPermission(role, Permission.ViewAuditLog)).toBe(true);
    });

    it('est le seul à pouvoir archiver un dossier', () => {
      const canArchive = Object.values(UserRole).filter((r) =>
        hasPermission(r, Permission.BeneficiaryArchive),
      );
      expect(canArchive).toEqual([UserRole.RESPONSABLE_CSB]);
    });

    it('ne gère pas les centres eux-mêmes', () => {
      expect(hasPermission(role, Permission.ManageCsbs)).toBe(false);
    });
  });

  describe('Administration nationale', () => {
    const role = UserRole.ADMIN_NATIONAL;

    it("n'accède à aucun dossier individuel", () => {
      // CDC §5 : les niveaux supérieurs ne voient que des indicateurs agrégés.
      // L'absence totale de permission « bénéficiaire » est voulue.
      expect(hasPermission(role, Permission.BeneficiaryViewIdentity)).toBe(false);
      expect(hasPermission(role, Permission.BeneficiaryViewCareHistory)).toBe(false);
      expect(hasPermission(role, Permission.BeneficiaryCreate)).toBe(false);
      expect(hasPermission(role, Permission.BeneficiaryUpdateIdentity)).toBe(false);
      expect(hasPermission(role, Permission.BeneficiaryArchive)).toBe(false);
    });

    it('gère les centres et les comptes', () => {
      expect(hasPermission(role, Permission.ManageCsbs)).toBe(true);
      expect(hasPermission(role, Permission.ManageCsbUsers)).toBe(true);
    });

    it('voit les indicateurs agrégés', () => {
      // CDC §5 : les niveaux supérieurs voient des totaux. L'oubli de cette
      // permission renvoyait un 403 sur le tableau de bord, découvert en
      // production.
      expect(hasPermission(role, Permission.DashboardAggregated)).toBe(true);
    });
  });

  describe('Invariants', () => {
    it('aucun profil ne peut supprimer un dossier', () => {
      // La suppression n'existe pas dans l'énumération : les données de santé
      // s'archivent, sinon la traçabilité du CDC §8 serait contournable.
      const names = Object.values(Permission).map((p) => p.toString());
      expect(names.filter((n) => n.includes('delete'))).toEqual([]);
    });

    it('tout rôle connu a une entrée dans la matrice', () => {
      // Un rôle ajouté sans droits associés vaudrait « accès à rien », ce qui
      // est sûr — mais silencieux. Ce test force à y penser.
      for (const role of Object.values(UserRole)) {
        expect(ROLE_PERMISSIONS[role]).toBeDefined();
      }
    });

    it('voir le contenu clinique implique de voir l\'identité', () => {
      for (const role of Object.values(UserRole)) {
        if (hasPermission(role, Permission.BeneficiaryViewCareHistory)) {
          expect(hasPermission(role, Permission.BeneficiaryViewIdentity)).toBe(true);
        }
      }
    });

    it('enregistrer un soin implique de voir le contenu clinique', () => {
      const careActions = [
        Permission.ConsultationRecord,
        Permission.VaccinationRecord,
        Permission.FamilyPlanningRecord,
        Permission.AntenatalRecord,
        Permission.PostnatalRecord,
      ];

      for (const role of Object.values(UserRole)) {
        const records = careActions.some((p) => hasPermission(role, p));
        if (records) {
          expect(hasPermission(role, Permission.BeneficiaryViewCareHistory)).toBe(true);
        }
      }
    });
  });
});
