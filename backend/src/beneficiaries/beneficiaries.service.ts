import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, Beneficiary, Prisma } from '@prisma/client';
import { uuidv7 } from 'uuidv7';

import { Permission, hasPermission } from '../auth/permissions';
import { AuthenticatedUser } from '../auth/types/jwt-payload';
import { PrismaService } from '../prisma/prisma.service';
import { CreateBeneficiaryDto } from './dto/create-beneficiary.dto';

/** Vue d'un dossier, filtrée selon ce que l'appelant a le droit de voir. */
export interface BeneficiaryView {
  id: string;
  localId: string;
  firstName: string;
  lastName: string;
  sex: string;
  birthDate: string;
  birthDateIsEstimated: boolean;
  fokontany: string | null;
  phone?: string | null;
  address?: string | null;
  archivedAt: Date | null;
  version: number;
  serverUpdatedAt: Date;
}

@Injectable()
export class BeneficiariesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Enregistre un dossier créé sur un appareil.
   *
   * Idempotent : l'identifiant vient de l'appareil, donc rejouer l'envoi d'un
   * dossier déjà reçu renvoie l'existant au lieu d'échouer. C'est indispensable
   * pour la file de synchronisation, qui peut renvoyer une mutation dont la
   * réponse s'est perdue (ticket 3.1).
   */
  async create(user: AuthenticatedUser, dto: CreateBeneficiaryDto): Promise<BeneficiaryView> {
    const csbId = this.requireCsb(user);

    const existing = await this.prisma.beneficiary.findUnique({ where: { id: dto.id } });

    if (existing) {
      // Un dossier déjà enregistré par un autre centre n'est pas « déjà reçu » :
      // c'est une tentative d'écrire hors de son périmètre.
      if (existing.csbId !== csbId) {
        throw new ForbiddenException('Action non autorisée pour votre profil');
      }
      return this.toView(existing, user);
    }

    const created = await this.prisma.beneficiary.create({
      data: {
        id: dto.id,
        localId: dto.localId,
        firstName: dto.firstName.trim(),
        lastName: dto.lastName.trim(),
        sex: dto.sex,
        birthDate: new Date(dto.birthDate),
        birthDateIsEstimated: dto.birthDateIsEstimated,
        phone: dto.phone?.trim() || null,
        fokontany: dto.fokontany?.trim() || null,
        address: dto.address?.trim() || null,
        csbId,
        version: dto.version ?? 1,
        deviceUpdatedAt: new Date(dto.deviceUpdatedAt),
        createdByUserId: user.id,
      },
    });

    await this.audit(user, AuditAction.CREATE, created.id, []);

    return this.toView(created, user);
  }

  /**
   * Recherche, toujours limitée au centre de l'appelant.
   *
   * Le cloisonnement n'est pas un filtre d'affichage : le `csbId` vient du
   * jeton, jamais de la requête. Un client ne peut donc pas demander les
   * dossiers d'un autre centre, même en forgeant l'appel.
   */
  async search(user: AuthenticatedUser, query?: string, limit = 50): Promise<BeneficiaryView[]> {
    const csbId = this.requireCsb(user);

    const where: Prisma.BeneficiaryWhereInput = {
      csbId,
      archivedAt: null,
      ...(query?.trim()
        ? {
            OR: [
              { lastName: { contains: query.trim(), mode: 'insensitive' } },
              { firstName: { contains: query.trim(), mode: 'insensitive' } },
              { localId: { equals: query.trim().toUpperCase() } },
            ],
          }
        : {}),
    };

    const rows = await this.prisma.beneficiary.findMany({
      where,
      orderBy: [{ lastName: 'asc' }, { firstName: 'asc' }],
      take: Math.min(limit, 200),
    });

    return rows.map((row) => this.toView(row, user));
  }

  async findOne(user: AuthenticatedUser, id: string): Promise<BeneficiaryView> {
    const csbId = this.requireCsb(user);

    const row = await this.prisma.beneficiary.findFirst({ where: { id, csbId } });

    if (!row) {
      // Même réponse qu'un dossier réellement inexistant : distinguer les deux
      // permettrait de savoir qu'une personne est suivie dans un autre centre.
      throw new NotFoundException('Dossier introuvable');
    }

    return this.toView(row, user);
  }

  /**
   * Restreint les champs renvoyés selon les droits de l'appelant.
   *
   * L'agent communautaire voit l'identité mais pas le contact ni l'adresse :
   * il oriente vers le CSB, et son appareil est le plus exposé. Le filtrage se
   * fait ici, pas dans l'application : ce qui n'est pas envoyé ne peut pas
   * fuiter.
   */
  private toView(row: Beneficiary, user: AuthenticatedUser): BeneficiaryView {
    const base: BeneficiaryView = {
      id: row.id,
      localId: row.localId,
      firstName: row.firstName,
      lastName: row.lastName,
      sex: row.sex,
      birthDate: row.birthDate.toISOString().slice(0, 10),
      birthDateIsEstimated: row.birthDateIsEstimated,
      fokontany: row.fokontany,
      archivedAt: row.archivedAt,
      version: row.version,
      serverUpdatedAt: row.serverUpdatedAt,
    };

    if (hasPermission(user.role, Permission.BeneficiaryViewCareHistory)) {
      return { ...base, phone: row.phone, address: row.address };
    }

    return base;
  }

  /**
   * Un utilisateur sans rattachement n'accède à aucun dossier individuel
   * (CDC §5). Le garde de permissions couvre déjà le cas, mais le service ne
   * doit pas dépendre de l'ordre des gardes pour rester sûr.
   */
  private requireCsb(user: AuthenticatedUser): string {
    if (!user.csbId) {
      throw new ForbiddenException("Votre profil n'accède pas aux dossiers individuels");
    }
    return user.csbId;
  }

  private async audit(
    user: AuthenticatedUser,
    action: AuditAction,
    entityId: string,
    changedFields: string[],
  ): Promise<void> {
    await this.prisma.auditLog.create({
      data: {
        id: uuidv7(),
        userId: user.id,
        csbId: user.csbId,
        action,
        entityType: 'Beneficiary',
        entityId,
        // Uniquement des noms de champs, jamais leurs valeurs : un journal qui
        // recopierait les données de santé deviendrait lui-même une base de
        // données de santé.
        changedFields,
        deviceId: user.deviceId,
      },
    });
  }
}
