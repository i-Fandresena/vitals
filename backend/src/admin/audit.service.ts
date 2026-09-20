import { Injectable } from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';

import { AuthenticatedUser } from '../auth/types/jwt-payload';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Journal d'audit (CDC §8, ticket 3.4).
 *
 * En lecture seule, et pour cause : un journal qu'on peut modifier ou effacer
 * ne prouve rien. Aucune route d'écriture ni de suppression n'est exposée.
 *
 * Les entrées ne contiennent que des **noms de champs modifiés**, jamais leurs
 * valeurs. Un journal qui recopierait les données de santé deviendrait
 * lui-même une base de données de santé, avec les mêmes obligations et une
 * surface d'exposition de plus.
 */
@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async list(
    user: AuthenticatedUser,
    options: { limit?: number; avant?: string; action?: string } = {},
  ) {
    // Un responsable ne voit que ce qui s'est passé dans son centre.
    const restreint = user.role !== UserRole.ADMIN_NATIONAL;

    const where: Prisma.AuditLogWhereInput = {
      ...(restreint ? { csbId: user.csbId ?? '' } : {}),
      ...(options.action ? { action: options.action as Prisma.EnumAuditActionFilter } : {}),
      ...(options.avant ? { serverTimestamp: { lt: new Date(options.avant) } } : {}),
    };

    const rows = await this.prisma.auditLog.findMany({
      where,
      orderBy: { serverTimestamp: 'desc' },
      take: Math.min(options.limit ?? 100, 500),
      include: {
        user: { select: { username: true, fullName: true, role: true } },
        csb: { select: { name: true, code: true } },
      },
    });

    return rows.map((row) => ({
      id: row.id,
      action: row.action,
      entityType: row.entityType,
      entityId: row.entityId,
      changedFields: row.changedFields,
      auteur: row.user
        ? { username: row.user.username, fullName: row.user.fullName, role: row.user.role }
        : null,
      csb: row.csb ? { code: row.csb.code, name: row.csb.name } : null,
      deviceId: row.deviceId,
      deviceTimestamp: row.deviceTimestamp,
      serverTimestamp: row.serverTimestamp,
    }));
  }

  /**
   * Compte les tentatives de connexion échouées récentes.
   *
   * C'est le signal le plus simple d'une attaque en cours ou d'un agent bloqué
   * dehors, et le responsable du centre doit pouvoir le voir sans lire tout le
   * journal.
   */
  async connexionsEchouees(user: AuthenticatedUser, heures = 24) {
    const depuis = new Date(Date.now() - heures * 3_600_000);
    const restreint = user.role !== UserRole.ADMIN_NATIONAL;

    return this.prisma.auditLog.count({
      where: {
        action: 'LOGIN_FAILED',
        serverTimestamp: { gte: depuis },
        ...(restreint ? { csbId: user.csbId ?? '' } : {}),
      },
    });
  }
}
