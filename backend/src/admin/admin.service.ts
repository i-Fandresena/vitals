import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuditAction, UserRole } from '@prisma/client';
import * as argon2 from 'argon2';
import { uuidv7 } from 'uuidv7';

import { AuthenticatedUser } from '../auth/types/jwt-payload';
import { PrismaService } from '../prisma/prisma.service';
import {
  CreateCsbDto,
  CreateUserDto,
  ResetPasswordDto,
  UpdateCsbDto,
  UpdateUserDto,
} from './dto/admin.dto';

/** Vue d'un compte. Ne contient jamais le hachage du mot de passe. */
const USER_FIELDS = {
  id: true,
  username: true,
  fullName: true,
  role: true,
  phone: true,
  csbId: true,
  isActive: true,
  lastLoginAt: true,
  createdAt: true,
} as const;

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  // ---------------------------------------------------------------------
  // Centres de santé
  // ---------------------------------------------------------------------

  /**
   * Liste les centres.
   *
   * Un responsable de CSB ne voit que le sien : la gestion des centres est
   * réservée à l'administration nationale, et lui montrer les autres n'aurait
   * aucun usage.
   */
  async listCsbs(user: AuthenticatedUser) {
    const where =
      user.role === UserRole.ADMIN_NATIONAL ? undefined : { id: user.csbId ?? '' };

    const rows = await this.prisma.csb.findMany({
      where,
      orderBy: { name: 'asc' },
      include: {
        district: { select: { name: true, region: { select: { name: true } } } },
        _count: { select: { users: true, beneficiaries: true } },
      },
    });

    return rows.map((csb) => ({
      id: csb.id,
      code: csb.code,
      name: csb.name,
      commune: csb.commune,
      districtId: csb.districtId,
      districtName: csb.district.name,
      regionName: csb.district.region.name,
      allowsNurseAntenatalCare: csb.allowsNurseAntenatalCare,
      userCount: csb._count.users,
      beneficiaryCount: csb._count.beneficiaries,
    }));
  }

  async createCsb(user: AuthenticatedUser, dto: CreateCsbDto) {
    const district = await this.prisma.district.findUnique({
      where: { id: dto.districtId },
    });
    if (!district) {
      throw new BadRequestException('District inconnu');
    }

    const existing = await this.prisma.csb.findUnique({ where: { code: dto.code } });
    if (existing) {
      // Le code sert de préfixe aux identifiants de dossier : un doublon
      // ferait collision entre deux centres.
      throw new ConflictException(`Le code ${dto.code} est déjà utilisé`);
    }

    const csb = await this.prisma.csb.create({
      data: {
        id: uuidv7(),
        code: dto.code,
        name: dto.name.trim(),
        commune: dto.commune?.trim() || null,
        districtId: dto.districtId,
        allowsNurseAntenatalCare: dto.allowsNurseAntenatalCare ?? false,
      },
    });

    await this.audit(user, AuditAction.CREATE, 'Csb', csb.id, []);
    return csb;
  }

  async updateCsb(user: AuthenticatedUser, id: string, dto: UpdateCsbDto) {
    const csb = await this.prisma.csb.findUnique({ where: { id } });
    if (!csb) throw new NotFoundException('Centre introuvable');

    // Le code n'est volontairement pas modifiable : il est figé dans les
    // identifiants lisibles des dossiers déjà créés (CSB-0142-26-00731).
    const updated = await this.prisma.csb.update({
      where: { id },
      data: {
        name: dto.name?.trim(),
        commune: dto.commune?.trim(),
        allowsNurseAntenatalCare: dto.allowsNurseAntenatalCare,
      },
    });

    await this.audit(user, AuditAction.UPDATE, 'Csb', id, Object.keys(dto));
    return updated;
  }

  // ---------------------------------------------------------------------
  // Comptes
  // ---------------------------------------------------------------------

  listUsers(user: AuthenticatedUser, csbId?: string) {
    const scope =
      user.role === UserRole.ADMIN_NATIONAL
        ? csbId
          ? { csbId }
          : undefined
        : { csbId: user.csbId ?? '' };

    return this.prisma.user.findMany({
      where: scope,
      orderBy: [{ isActive: 'desc' }, { fullName: 'asc' }],
      select: USER_FIELDS,
    });
  }

  async createUser(user: AuthenticatedUser, dto: CreateUserDto) {
    const csbId = this.resolveCsbId(user, dto.role, dto.csbId);
    this.assertMayAssignRole(user, dto.role);

    const existing = await this.prisma.user.findUnique({
      where: { username: dto.username },
    });
    if (existing) {
      throw new ConflictException(`L'identifiant ${dto.username} est déjà pris`);
    }

    const created = await this.prisma.user.create({
      data: {
        id: uuidv7(),
        username: dto.username,
        fullName: dto.fullName.trim(),
        role: dto.role,
        phone: dto.phone?.trim() || null,
        csbId,
        passwordHash: await argon2.hash(dto.password, { type: argon2.argon2id }),
      },
      select: USER_FIELDS,
    });

    await this.audit(user, AuditAction.CREATE, 'User', created.id, []);
    return created;
  }

  async updateUser(user: AuthenticatedUser, id: string, dto: UpdateUserDto) {
    const target = await this.requireManageableUser(user, id);

    if (dto.role) {
      this.assertMayAssignRole(user, dto.role);
      this.assertMayAssignRole(user, target.role);
    }

    // Se retirer soi-même ses propres droits, ou désactiver son propre compte,
    // laisserait potentiellement un centre sans personne pour gérer ses
    // comptes. Le refus est immédiat et explicite.
    if (target.id === user.id && (dto.isActive === false || dto.role)) {
      throw new BadRequestException(
        'Vous ne pouvez pas modifier votre propre rôle ni désactiver votre compte',
      );
    }

    const updated = await this.prisma.user.update({
      where: { id },
      data: {
        fullName: dto.fullName?.trim(),
        role: dto.role,
        phone: dto.phone?.trim(),
        isActive: dto.isActive,
      },
      select: USER_FIELDS,
    });

    await this.audit(user, AuditAction.UPDATE, 'User', id, Object.keys(dto));
    return updated;
  }

  /**
   * Réinitialise un mot de passe et révoque toutes les sessions du compte.
   *
   * La révocation est le point essentiel : un mot de passe réinitialisé parce
   * qu'un téléphone a été perdu ne sert à rien si les jetons de cet appareil
   * restent valides trente jours.
   */
  async resetPassword(user: AuthenticatedUser, id: string, dto: ResetPasswordDto) {
    const target = await this.requireManageableUser(user, id);

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: target.id },
        data: {
          passwordHash: await argon2.hash(dto.password, { type: argon2.argon2id }),
        },
      }),
      this.prisma.refreshToken.updateMany({
        where: { userId: target.id, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);

    await this.audit(user, AuditAction.UPDATE, 'User', target.id, ['passwordHash']);
    return { ok: true };
  }

  // ---------------------------------------------------------------------
  // Garde-fous
  // ---------------------------------------------------------------------

  /**
   * Empêche l'escalade de privilèges.
   *
   * Un responsable de CSB gère les soignants de son centre — c'est l'objet de
   * sa permission. Le laisser créer un autre responsable, ou pire un compte
   * d'administration nationale, lui permettrait de s'attribuer indirectement
   * des droits qu'il n'a pas.
   */
  private assertMayAssignRole(user: AuthenticatedUser, role: UserRole): void {
    if (user.role === UserRole.ADMIN_NATIONAL) return;

    const assignable: UserRole[] = [
      UserRole.AGENT_COMMUNAUTAIRE,
      UserRole.INFIRMIER,
      UserRole.SAGE_FEMME,
      UserRole.MEDECIN,
    ];

    if (!assignable.includes(role)) {
      throw new ForbiddenException(
        "Vous ne pouvez pas attribuer ce profil. Demandez à l'administration nationale.",
      );
    }
  }

  /** Un responsable ne gère que les comptes de son propre centre. */
  private async requireManageableUser(user: AuthenticatedUser, id: string) {
    const target = await this.prisma.user.findUnique({
      where: { id },
      select: { id: true, role: true, csbId: true },
    });

    if (!target) throw new NotFoundException('Compte introuvable');

    if (user.role !== UserRole.ADMIN_NATIONAL) {
      if (!user.csbId || target.csbId !== user.csbId) {
        // Même réponse qu'un compte inexistant : distinguer les deux
        // permettrait d'énumérer les comptes des autres centres.
        throw new NotFoundException('Compte introuvable');
      }
      this.assertMayAssignRole(user, target.role);
    }

    return target;
  }

  /**
   * Détermine le centre de rattachement et refuse les combinaisons
   * incohérentes plutôt que de les corriger en silence.
   */
  private resolveCsbId(
    user: AuthenticatedUser,
    role: UserRole,
    requested?: string,
  ): string | null {
    if (role === UserRole.ADMIN_NATIONAL) {
      // Ce profil n'accède à aucun dossier individuel (CDC §5) : le rattacher
      // à un centre n'aurait pas de sens.
      return null;
    }

    if (user.role === UserRole.ADMIN_NATIONAL) {
      if (!requested) {
        throw new BadRequestException('Indiquez le centre de rattachement');
      }
      return requested;
    }

    // Un responsable ne crée des comptes que dans son propre centre, quel que
    // soit le `csbId` envoyé.
    if (!user.csbId) {
      throw new ForbiddenException("Votre profil n'est rattaché à aucun centre");
    }
    if (requested && requested !== user.csbId) {
      throw new ForbiddenException(
        'Vous ne pouvez créer des comptes que dans votre centre',
      );
    }
    return user.csbId;
  }

  private async audit(
    user: AuthenticatedUser,
    action: AuditAction,
    entityType: string,
    entityId: string,
    changedFields: string[],
  ): Promise<void> {
    await this.prisma.auditLog.create({
      data: {
        id: uuidv7(),
        userId: user.id,
        csbId: user.csbId,
        action,
        entityType,
        entityId,
        // Uniquement des noms de champs, jamais leurs valeurs — et surtout
        // pas un mot de passe, même haché.
        changedFields,
        deviceId: user.deviceId,
      },
    });
  }
}
