import { Module } from '@nestjs/common';

import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { AuditService } from './audit.service';
import { GeographyController } from './geography.controller';
import { GeographyService } from './geography.service';
import { IndicatorsService } from './indicators.service';

@Module({
  controllers: [AdminController, GeographyController],
  providers: [AdminService, GeographyService, IndicatorsService, AuditService],
})
export class AdminModule {}
