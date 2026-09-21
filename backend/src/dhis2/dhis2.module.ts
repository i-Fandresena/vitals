import { Module } from '@nestjs/common';

import { Dhis2Controller } from './dhis2.controller';
import { Dhis2Service } from './dhis2.service';

@Module({
  controllers: [Dhis2Controller],
  providers: [Dhis2Service],
})
export class Dhis2Module {}
