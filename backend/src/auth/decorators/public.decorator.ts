import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/**
 * Rend une route accessible sans authentification.
 *
 * L'authentification est active par défaut sur toute l'API : il faut une
 * déclaration explicite pour ouvrir une route, jamais l'inverse. Oublier un
 * garde ne doit pas exposer des données de santé.
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
