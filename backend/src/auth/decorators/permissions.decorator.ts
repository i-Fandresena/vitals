import { SetMetadata } from '@nestjs/common';
import { Permission } from '../permissions';

export const PERMISSIONS_KEY = 'permissions';

/**
 * Restreint une route aux profils qui détiennent **toutes** les permissions
 * listées.
 *
 * À préférer à `@Roles(...)` : une route déclare ce qu'elle fait, pas qui a le
 * droit de le faire. Ajouter un profil ne demande alors que de modifier
 * `permissions.ts`, sans repasser sur chaque contrôleur.
 */
export const RequirePermissions = (...permissions: Permission[]) =>
  SetMetadata(PERMISSIONS_KEY, permissions);
