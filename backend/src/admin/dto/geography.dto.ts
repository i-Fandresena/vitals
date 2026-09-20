import { IsNotEmpty, IsOptional, IsString, IsUUID, Matches, MaxLength } from 'class-validator';

/**
 * Découpage géographique : régions et districts.
 *
 * Sans eux, aucun centre ne peut être créé, donc aucun compte de soignant.
 * C'est la toute première chose à renseigner sur une installation neuve.
 *
 * Les codes suivent la nomenclature de l'INSTAT et du ministère de la Santé
 * quand elle existe. Ils sont figés après création : ils servent de clé de
 * rapprochement avec DHIS2 et avec les publications statistiques nationales.
 */

export class CreateRegionDto {
  @IsString()
  @Matches(/^[A-Z0-9-]{2,16}$/, {
    message: 'Le code ne contient que des majuscules, chiffres et tirets',
  })
  code!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name!: string;
}

export class CreateDistrictDto {
  @IsString()
  @Matches(/^[A-Z0-9-]{2,16}$/, {
    message: 'Le code ne contient que des majuscules, chiffres et tirets',
  })
  code!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name!: string;

  @IsUUID()
  regionId!: string;
}

export class UpdateGeographyDto {
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name?: string;
}
