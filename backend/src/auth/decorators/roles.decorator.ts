import { SetMetadata } from '@nestjs/common';
import { UserRole } from '@prisma/client';

export const ROLES_KEY = 'roles';

/**
 * Restreint une route à certains rôles.
 * Le détail des permissions est spécifié dans docs/01-matrice-droits.md.
 */
export const Roles = (...roles: UserRole[]) => SetMetadata(ROLES_KEY, roles);
