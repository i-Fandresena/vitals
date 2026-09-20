import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { Permission } from '../auth/permissions';
import { AuthenticatedUser } from '../auth/types/jwt-payload';
import { AuditService } from './audit.service';
import { CreateDistrictDto, CreateRegionDto, UpdateGeographyDto } from './dto/geography.dto';
import { GeographyService } from './geography.service';
import { Granularite, IndicatorsService, Niveau } from './indicators.service';

/**
 * Découpage géographique, indicateurs et journal d'audit.
 *
 * Aucune de ces routes n'expose un dossier individuel : elles renvoient des
 * référentiels, des dénombrements ou des traces d'opérations (CDC §5).
 */
@Controller('admin')
export class GeographyController {
  constructor(
    private readonly geography: GeographyService,
    private readonly indicators: IndicatorsService,
    private readonly audit: AuditService,
  ) {}

  // --- Régions ---

  @Get('regions')
  @RequirePermissions(Permission.ManageCsbUsers)
  listRegions() {
    return this.geography.listRegions();
  }

  @Post('regions')
  @RequirePermissions(Permission.ManageCsbs)
  createRegion(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateRegionDto) {
    return this.geography.createRegion(user, dto);
  }

  @Patch('regions/:id')
  @RequirePermissions(Permission.ManageCsbs)
  renameRegion(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateGeographyDto,
  ) {
    return this.geography.renameRegion(user, id, dto);
  }

  // --- Districts ---

  @Get('districts')
  @RequirePermissions(Permission.ManageCsbUsers)
  listDistricts(@Query('regionId') regionId?: string) {
    return this.geography.listDistricts(regionId);
  }

  @Post('districts')
  @RequirePermissions(Permission.ManageCsbs)
  createDistrict(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateDistrictDto) {
    return this.geography.createDistrict(user, dto);
  }

  @Patch('districts/:id')
  @RequirePermissions(Permission.ManageCsbs)
  renameDistrict(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateGeographyDto,
  ) {
    return this.geography.renameDistrict(user, id, dto);
  }

  // --- Indicateurs agrégés ---

  @Get('indicateurs')
  @RequirePermissions(Permission.DashboardCsb)
  indicateurs(
    @CurrentUser() user: AuthenticatedUser,
    @Query('debut') debut?: string,
    @Query('fin') fin?: string,
    @Query('granularite') granularite?: Granularite,
    @Query('niveau') niveau?: Niveau,
  ) {
    return this.indicators.resume(user, { debut, fin, granularite, niveau });
  }

  // --- Journal d'audit ---

  @Get('audit')
  @RequirePermissions(Permission.ViewAuditLog)
  journal(
    @CurrentUser() user: AuthenticatedUser,
    @Query('limit') limit?: string,
    @Query('avant') avant?: string,
    @Query('action') action?: string,
  ) {
    return this.audit.list(user, {
      limit: limit ? Number(limit) : undefined,
      avant,
      action,
    });
  }

  @Get('audit/connexions-echouees')
  @RequirePermissions(Permission.ViewAuditLog)
  async connexionsEchouees(@CurrentUser() user: AuthenticatedUser) {
    return { total24h: await this.audit.connexionsEchouees(user) };
  }
}
