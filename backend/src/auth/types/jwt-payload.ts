import { UserRole } from '@prisma/client';

/** Contenu du jeton d'accès. Aucune donnée personnelle n'y figure. */
export interface JwtPayload {
  /** Identifiant de l'utilisateur */
  sub: string;
  role: UserRole;
  /** CSB de rattachement, nul pour ADMIN_NATIONAL */
  csbId: string | null;
  deviceId: string;
}

/** Utilisateur authentifié, tel qu'attaché à la requête par la stratégie JWT. */
export interface AuthenticatedUser {
  id: string;
  role: UserRole;
  csbId: string | null;
  deviceId: string;
}
