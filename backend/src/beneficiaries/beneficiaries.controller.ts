import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { Permission } from '../auth/permissions';
import { AuthenticatedUser } from '../auth/types/jwt-payload';
import { BeneficiariesService } from './beneficiaries.service';
import { CreateBeneficiaryDto } from './dto/create-beneficiary.dto';

/**
 * Dossiers bénéficiaires.
 *
 * Chaque route déclare la permission qu'elle exige plutôt que la liste des
 * profils autorisés : ajouter un profil ne demande alors que de modifier
 * `auth/permissions.ts`.
 */
@Controller('beneficiaries')
export class BeneficiariesController {
  constructor(private readonly beneficiaries: BeneficiariesService) {}

  /** POST /api/v1/beneficiaries */
  @Post()
  @RequirePermissions(Permission.BeneficiaryCreate)
  create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateBeneficiaryDto) {
    return this.beneficiaries.create(user, dto);
  }

  /** GET /api/v1/beneficiaries?q=… */
  @Get()
  @RequirePermissions(Permission.BeneficiaryViewIdentity)
  search(@CurrentUser() user: AuthenticatedUser, @Query('q') query?: string) {
    return this.beneficiaries.search(user, query);
  }

  /** GET /api/v1/beneficiaries/:id */
  @Get(':id')
  @RequirePermissions(Permission.BeneficiaryViewIdentity)
  findOne(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', new ParseUUIDPipe()) id: string,
  ) {
    return this.beneficiaries.findOne(user, id);
  }
}
