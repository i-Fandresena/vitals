import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  ValidateNested,
} from 'class-validator';

import { INDICATEURS_DHIS2 } from '../dhis2.service';

export class ExportDhis2Dto {
  /** Mois à remonter, au format `AAAA-MM`. */
  @Matches(/^\d{4}-(0[1-9]|1[0-2])$/, {
    message: 'Période attendue au format AAAA-MM.',
  })
  periode!: string;

  /** Demande à DHIS2 de valider sans rien écrire. */
  @IsOptional()
  @IsBoolean()
  simulation?: boolean;
}

export class CorrespondanceDhis2Dto {
  @IsIn(INDICATEURS_DHIS2)
  indicator!: string;

  /**
   * Identifiant DHIS2, onze caractères commençant par une lettre.
   *
   * Validé ici plutôt qu'au premier export : une coquille saisie dans un
   * formulaire ne doit pas se découvrir au moment de publier des chiffres
   * nationaux.
   */
  @Matches(/^[A-Za-z][A-Za-z0-9]{10}$/, {
    message: "Identifiant DHIS2 attendu : 11 caractères, commençant par une lettre.",
  })
  dataElement!: string;

  @IsOptional()
  @Matches(/^[A-Za-z][A-Za-z0-9]{10}$/, {
    message: "Identifiant DHIS2 attendu : 11 caractères, commençant par une lettre.",
  })
  categoryOptionCombo?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  label?: string;
}

export class MappingsDhis2Dto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CorrespondanceDhis2Dto)
  @ArrayMaxSize(50)
  correspondances!: CorrespondanceDhis2Dto[];
}
