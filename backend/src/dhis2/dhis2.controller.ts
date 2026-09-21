import { Body, Controller, Get, Post, Put } from '@nestjs/common';

import { RequirePermissions } from '../auth/decorators/permissions.decorator';
import { Permission } from '../auth/permissions';
import { Dhis2Service } from './dhis2.service';
import { ExportDhis2Dto, MappingsDhis2Dto } from './dto/dhis2.dto';

/**
 * Remontée des indicateurs vers DHIS2.
 *
 * Gardé par [Permission.ManageCsbs], que seule l'administration nationale
 * détient, et non par [Permission.DataExport] qui serait pourtant mieux
 * nommée : celle-ci appartient au responsable de centre, pour ses propres
 * données, alors qu'un export DHIS2 pousse les chiffres de **tous** les
 * centres. Un responsable ne doit pas pouvoir déclencher une remontée
 * nationale.
 */
@Controller('admin/dhis2')
export class Dhis2Controller {
  constructor(private readonly dhis2: Dhis2Service) {}

  /** Ce qui est configuré, et ce qui manque encore. */
  @Get()
  @RequirePermissions(Permission.ManageCsbs)
  etat() {
    return this.dhis2.etat();
  }

  /** Enregistre les correspondances indicateur → élément de données. */
  @Put('correspondances')
  @RequirePermissions(Permission.ManageCsbs)
  enregistrerCorrespondances(@Body() dto: MappingsDhis2Dto) {
    return this.dhis2.enregistrerCorrespondances(dto.correspondances);
  }

  /**
   * Envoie les dénombrements d'un mois.
   *
   * `simulation` demande à DHIS2 de tout valider sans rien écrire. C'est le
   * seul moyen de vérifier un rapprochement avant de publier des chiffres
   * nationaux, et il vaut mieux s'en servir.
   */
  @Post('export')
  @RequirePermissions(Permission.ManageCsbs)
  exporter(@Body() dto: ExportDhis2Dto) {
    return this.dhis2.exporterMois(dto.periode, { simulation: dto.simulation });
  }
}
