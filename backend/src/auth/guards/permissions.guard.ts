import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { PrismaService } from '../../prisma/prisma.service';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { Permission, permissionsFor } from '../permissions';
import { AuthenticatedUser } from '../types/jwt-payload';

/**
 * Applique la matrice des droits (`docs/01-matrice-droits.md`) côté serveur.
 *
 * C'est le point qui rend le ticket 2.2 réel : masquer un bouton dans
 * l'application ne protège rien. Un appel direct à l'API avec un jeton valide
 * mais un rôle insuffisant est rejeté ici.
 */
@Injectable()
export class PermissionsGuard implements CanActivate {
  /** Permissions dont l'attribution dépend du centre et non du seul rôle. */
  private static readonly CSB_DEPENDENT = new Set<Permission>([
    Permission.AntenatalRecord,
    Permission.PostnatalRecord,
  ]);

  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<Permission[] | undefined>(PERMISSIONS_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!required || required.length === 0) {
      return true;
    }

    const user = context.switchToHttp().getRequest<{ user?: AuthenticatedUser }>().user;

    if (!user) {
      throw new ForbiddenException('Action non autorisée pour votre profil');
    }

    // La configuration du centre n'est lue que lorsqu'elle peut changer la
    // réponse : inutile d'interroger la base à chaque requête.
    const needsCsbContext = required.some((p) => PermissionsGuard.CSB_DEPENDENT.has(p));

    const granted = permissionsFor(user.role, {
      csbAllowsNurseAntenatalCare: needsCsbContext
        ? await this.csbAllowsNurseAntenatalCare(user.csbId)
        : false,
    });

    if (!required.every((permission) => granted.has(permission))) {
      // Message volontairement vague : ne pas indiquer quelle permission
      // manque, ni quel profil l'aurait.
      throw new ForbiddenException('Action non autorisée pour votre profil');
    }

    return true;
  }

  private async csbAllowsNurseAntenatalCare(csbId: string | null): Promise<boolean> {
    if (!csbId) return false;

    const csb = await this.prisma.csb.findUnique({
      where: { id: csbId },
      select: { allowsNurseAntenatalCare: true },
    });

    return csb?.allowsNurseAntenatalCare ?? false;
  }
}
