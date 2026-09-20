import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { UserRole } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { Permission } from '../permissions';
import { AuthenticatedUser } from '../types/jwt-payload';
import { PermissionsGuard } from './permissions.guard';

/**
 * Vérifie que le refus vient bien du serveur.
 *
 * C'est l'exigence explicite du ticket 2.2 : masquer un bouton dans
 * l'application ne protège rien, un appel direct à l'API doit échouer.
 */
describe('PermissionsGuard', () => {
  let reflector: { getAllAndOverride: jest.Mock };
  let prisma: { csb: { findUnique: jest.Mock } };
  let guard: PermissionsGuard;

  const user = (role: UserRole, csbId: string | null = 'csb-1'): AuthenticatedUser => ({
    id: 'user-1',
    role,
    csbId,
    deviceId: 'device-1',
  });

  const contextFor = (authenticated?: AuthenticatedUser): ExecutionContext =>
    ({
      getHandler: () => undefined,
      getClass: () => undefined,
      switchToHttp: () => ({ getRequest: () => ({ user: authenticated }) }),
    }) as unknown as ExecutionContext;

  beforeEach(() => {
    reflector = { getAllAndOverride: jest.fn() };
    prisma = { csb: { findUnique: jest.fn() } };
    guard = new PermissionsGuard(
      reflector as unknown as Reflector,
      prisma as unknown as PrismaService,
    );
  });

  it('laisse passer une route sans permission déclarée', async () => {
    reflector.getAllAndOverride.mockReturnValue(undefined);

    await expect(guard.canActivate(contextFor(user(UserRole.INFIRMIER)))).resolves.toBe(true);
  });

  it('laisse passer un profil qui détient la permission', async () => {
    reflector.getAllAndOverride.mockReturnValue([Permission.ConsultationRecord]);

    await expect(guard.canActivate(contextFor(user(UserRole.SAGE_FEMME)))).resolves.toBe(true);
  });

  it('refuse un agent communautaire sur une action clinique', async () => {
    reflector.getAllAndOverride.mockReturnValue([Permission.ConsultationRecord]);

    await expect(
      guard.canActivate(contextFor(user(UserRole.AGENT_COMMUNAUTAIRE))),
    ).rejects.toThrow(ForbiddenException);
  });

  it("refuse l'administration nationale sur un dossier individuel", async () => {
    reflector.getAllAndOverride.mockReturnValue([Permission.BeneficiaryViewIdentity]);

    await expect(
      guard.canActivate(contextFor(user(UserRole.ADMIN_NATIONAL, null))),
    ).rejects.toThrow(ForbiddenException);
  });

  it('refuse une requête sans utilisateur authentifié', async () => {
    reflector.getAllAndOverride.mockReturnValue([Permission.BeneficiaryViewIdentity]);

    await expect(guard.canActivate(contextFor(undefined))).rejects.toThrow(ForbiddenException);
  });

  it('exige toutes les permissions listées, pas une seule', async () => {
    reflector.getAllAndOverride.mockReturnValue([
      Permission.BeneficiaryViewIdentity,
      Permission.DashboardCsb,
    ]);

    // L'infirmier détient la première mais pas la seconde.
    await expect(guard.canActivate(contextFor(user(UserRole.INFIRMIER)))).rejects.toThrow(
      ForbiddenException,
    );
  });

  it('ne divulgue pas quelle permission manque', async () => {
    reflector.getAllAndOverride.mockReturnValue([Permission.DataExport]);

    await expect(
      guard.canActivate(contextFor(user(UserRole.INFIRMIER))),
    ).rejects.toThrow('Action non autorisée pour votre profil');
  });

  describe('CPN selon la configuration du centre', () => {
    it("refuse l'infirmier quand le centre a une sage-femme", async () => {
      reflector.getAllAndOverride.mockReturnValue([Permission.AntenatalRecord]);
      prisma.csb.findUnique.mockResolvedValue({ allowsNurseAntenatalCare: false });

      await expect(guard.canActivate(contextFor(user(UserRole.INFIRMIER)))).rejects.toThrow(
        ForbiddenException,
      );
    });

    it("autorise l'infirmier quand le centre n'en a pas", async () => {
      reflector.getAllAndOverride.mockReturnValue([Permission.AntenatalRecord]);
      prisma.csb.findUnique.mockResolvedValue({ allowsNurseAntenatalCare: true });

      await expect(guard.canActivate(contextFor(user(UserRole.INFIRMIER)))).resolves.toBe(true);
    });

    it("n'interroge pas la base quand la permission n'en dépend pas", async () => {
      reflector.getAllAndOverride.mockReturnValue([Permission.ConsultationRecord]);

      await guard.canActivate(contextFor(user(UserRole.INFIRMIER)));

      // Une requête par appel d'API sur une information qui ne change presque
      // jamais serait un coût inutile sur chaque requête.
      expect(prisma.csb.findUnique).not.toHaveBeenCalled();
    });

    it('traite un centre introuvable comme sans autorisation', async () => {
      reflector.getAllAndOverride.mockReturnValue([Permission.AntenatalRecord]);
      prisma.csb.findUnique.mockResolvedValue(null);

      await expect(guard.canActivate(contextFor(user(UserRole.INFIRMIER)))).rejects.toThrow(
        ForbiddenException,
      );
    });
  });
});
