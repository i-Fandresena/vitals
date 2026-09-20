import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';

import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { Permission } from '../auth/permissions';
import { AuthenticatedUser } from '../auth/types/jwt-payload';
import { PushDto } from './dto/sync.dto';
import { SyncService } from './sync.service';

/**
 * Synchronisation des appareils.
 *
 * Les deux routes exigent l'accès aux dossiers : un profil qui n'en consulte
 * aucun n'a rien à synchroniser.
 */
@Controller('sync')
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  /** POST /api/v1/sync/push */
  @Post('push')
  @RequirePermissions(Permission.BeneficiaryViewIdentity)
  // Limite large : un appareil resté longtemps hors ligne enchaîne plusieurs
  // lots d'affilée, et le brider ferait traîner son rattrapage.
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  push(@CurrentUser() user: AuthenticatedUser, @Body() dto: PushDto) {
    return this.sync.push(user, dto.mutations);
  }

  /** GET /api/v1/sync/pull?since=<iso> */
  @Get('pull')
  @RequirePermissions(Permission.BeneficiaryViewIdentity)
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  pull(
    @CurrentUser() user: AuthenticatedUser,
    @Query('since') since?: string,
    @Query('limit') limit?: string,
  ) {
    return this.sync.pull(user, since, limit ? Number(limit) : undefined);
  }
}
