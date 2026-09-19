import { Controller, Get } from '@nestjs/common';

import { Public } from '../auth/decorators/public.decorator';
import { PrismaService } from '../prisma/prisma.service';

@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * GET /api/v1/health
   *
   * Sert aussi de sonde de connectivité à l'application mobile : c'est ce que
   * l'appareil interroge pour décider s'il peut vider sa file de
   * synchronisation. Réponse volontairement minimale, et publique : elle ne
   * doit rien révéler de l'infrastructure.
   */
  @Public()
  @Get()
  async check() {
    let database = 'down';
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      database = 'up';
    } catch {
      database = 'down';
    }

    return { status: database === 'up' ? 'ok' : 'degraded', database, time: new Date().toISOString() };
  }
}
