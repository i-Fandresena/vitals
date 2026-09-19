import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { UserRole } from '@prisma/client';

import { ROLES_KEY } from '../decorators/roles.decorator';
import { AuthenticatedUser } from '../types/jwt-payload';

/**
 * Applique la matrice des droits (docs/01-matrice-droits.md) côté serveur.
 *
 * Le ticket 2.2 l'exige explicitement : masquer un bouton dans l'application
 * n'est pas une permission. Un appel direct à l'API avec un jeton valide mais
 * un rôle insuffisant doit être rejeté ici.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<UserRole[] | undefined>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!required || required.length === 0) {
      return true;
    }

    const user = context.switchToHttp().getRequest<{ user?: AuthenticatedUser }>().user;

    if (!user || !required.includes(user.role)) {
      // Message volontairement vague : ne pas indiquer quel rôle serait requis.
      throw new ForbiddenException('Action non autorisée pour votre profil');
    }

    return true;
  }
}
