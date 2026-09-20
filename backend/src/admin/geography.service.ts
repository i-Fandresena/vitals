import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction } from '@prisma/client';
import { uuidv7 } from 'uuidv7';

import { AuthenticatedUser } from '../auth/types/jwt-payload';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDistrictDto, CreateRegionDto, UpdateGeographyDto } from './dto/geography.dto';

/**
 * Régions et districts.
 *
 * Ce découpage conditionne tout le reste : un centre appartient à un district,
 * un district à une région, et les indicateurs remontent par cette hiérarchie
 * (CDC §5). C'est aussi la clé de rapprochement avec les unités
 * d'organisation de DHIS2.
 */
@Injectable()
export class GeographyService {
  constructor(private readonly prisma: PrismaService) {}

  async listRegions() {
    const rows = await this.prisma.region.findMany({
      orderBy: { name: 'asc' },
      include: { _count: { select: { districts: true } } },
    });

    return rows.map((r) => ({
      id: r.id,
      code: r.code,
      name: r.name,
      districtCount: r._count.districts,
    }));
  }

  async listDistricts(regionId?: string) {
    const rows = await this.prisma.district.findMany({
      where: regionId ? { regionId } : undefined,
      orderBy: { name: 'asc' },
      include: {
        region: { select: { name: true } },
        _count: { select: { csbs: true } },
      },
    });

    return rows.map((d) => ({
      id: d.id,
      code: d.code,
      name: d.name,
      regionId: d.regionId,
      regionName: d.region.name,
      csbCount: d._count.csbs,
    }));
  }

  async createRegion(user: AuthenticatedUser, dto: CreateRegionDto) {
    const existing = await this.prisma.region.findUnique({ where: { code: dto.code } });
    if (existing) {
      throw new ConflictException(`Le code ${dto.code} est déjà utilisé`);
    }

    const region = await this.prisma.region.create({
      data: { id: uuidv7(), code: dto.code, name: dto.name.trim() },
    });

    await this.audit(user, AuditAction.CREATE, 'Region', region.id);
    return region;
  }

  async createDistrict(user: AuthenticatedUser, dto: CreateDistrictDto) {
    const region = await this.prisma.region.findUnique({ where: { id: dto.regionId } });
    if (!region) throw new BadRequestException('Région inconnue');

    const existing = await this.prisma.district.findUnique({ where: { code: dto.code } });
    if (existing) {
      throw new ConflictException(`Le code ${dto.code} est déjà utilisé`);
    }

    const district = await this.prisma.district.create({
      data: {
        id: uuidv7(),
        code: dto.code,
        name: dto.name.trim(),
        regionId: dto.regionId,
      },
    });

    await this.audit(user, AuditAction.CREATE, 'District', district.id);
    return district;
  }

  /**
   * Seul le nom est modifiable. Le code est figé : il sert de clé de
   * rapprochement avec DHIS2 et avec les publications nationales, et le
   * changer romprait silencieusement ces correspondances.
   */
  async renameRegion(user: AuthenticatedUser, id: string, dto: UpdateGeographyDto) {
    const exists = await this.prisma.region.findUnique({ where: { id } });
    if (!exists) throw new NotFoundException('Région introuvable');

    const updated = await this.prisma.region.update({
      where: { id },
      data: { name: dto.name?.trim() },
    });

    await this.audit(user, AuditAction.UPDATE, 'Region', id, ['name']);
    return updated;
  }

  async renameDistrict(user: AuthenticatedUser, id: string, dto: UpdateGeographyDto) {
    const exists = await this.prisma.district.findUnique({ where: { id } });
    if (!exists) throw new NotFoundException('District introuvable');

    const updated = await this.prisma.district.update({
      where: { id },
      data: { name: dto.name?.trim() },
    });

    await this.audit(user, AuditAction.UPDATE, 'District', id, ['name']);
    return updated;
  }

  private async audit(
    user: AuthenticatedUser,
    action: AuditAction,
    entityType: string,
    entityId: string,
    changedFields: string[] = [],
  ): Promise<void> {
    await this.prisma.auditLog.create({
      data: {
        id: uuidv7(),
        userId: user.id,
        csbId: user.csbId,
        action,
        entityType,
        entityId,
        changedFields,
        deviceId: user.deviceId,
      },
    });
  }
}
