import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { Permission } from '../auth/permissions';
import { AuthenticatedUser } from '../auth/types/jwt-payload';
import { AdminService } from './admin.service';
import {
  CreateCsbDto,
  CreateUserDto,
  ResetPasswordDto,
  UpdateCsbDto,
  UpdateUserDto,
} from './dto/admin.dto';

/**
 * Administration : centres de santé et comptes.
 *
 * Utilisé par l'espace d'administration sur navigateur, pas par l'application
 * mobile. C'est ce qui rend le déploiement possible : sans ces routes, aucun
 * compte ne peut être créé hors du script de développement.
 */
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  // --- Découpage géographique, pour les formulaires ---

  @Get('regions')
  @RequirePermissions(Permission.ManageCsbUsers)
  listRegions() {
    return this.admin.listRegions();
  }

  @Get('districts')
  @RequirePermissions(Permission.ManageCsbUsers)
  listDistricts(@Query('regionId') regionId?: string) {
    return this.admin.listDistricts(regionId);
  }

  // --- Centres ---

  @Get('csbs')
  @RequirePermissions(Permission.ManageCsbUsers)
  listCsbs(@CurrentUser() user: AuthenticatedUser) {
    return this.admin.listCsbs(user);
  }

  @Post('csbs')
  @RequirePermissions(Permission.ManageCsbs)
  createCsb(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateCsbDto) {
    return this.admin.createCsb(user, dto);
  }

  @Patch('csbs/:id')
  @RequirePermissions(Permission.ManageCsbs)
  updateCsb(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateCsbDto,
  ) {
    return this.admin.updateCsb(user, id, dto);
  }

  // --- Comptes ---

  @Get('users')
  @RequirePermissions(Permission.ManageCsbUsers)
  listUsers(@CurrentUser() user: AuthenticatedUser, @Query('csbId') csbId?: string) {
    return this.admin.listUsers(user, csbId);
  }

  @Post('users')
  @RequirePermissions(Permission.ManageCsbUsers)
  createUser(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateUserDto) {
    return this.admin.createUser(user, dto);
  }

  @Patch('users/:id')
  @RequirePermissions(Permission.ManageCsbUsers)
  updateUser(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: UpdateUserDto,
  ) {
    return this.admin.updateUser(user, id, dto);
  }

  @Post('users/:id/reset-password')
  @RequirePermissions(Permission.ManageCsbUsers)
  resetPassword(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', new ParseUUIDPipe()) id: string,
    @Body() dto: ResetPasswordDto,
  ) {
    return this.admin.resetPassword(user, id, dto);
  }
}
