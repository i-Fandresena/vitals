import { Sex } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateBeneficiaryDto {
  /**
   * UUID v7 généré sur l'appareil.
   *
   * C'est l'appareil qui décide de l'identifiant, pas le serveur : un dossier
   * doit pouvoir être créé hors ligne. Le serveur le reçoit tel quel, ce qui
   * rend aussi l'envoi idempotent — rejouer la même création ne crée pas de
   * doublon.
   */
  @IsUUID()
  id!: string;

  /** Identifiant lisible `CSB-0142-26-00731`, attribué par l'appareil. */
  @IsString()
  @Matches(/^CSB-[A-Z0-9]+-\d{2}-\d{1,6}$/, {
    message: "Format d'identifiant invalide",
  })
  localId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  firstName!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  lastName!: string;

  @IsEnum(Sex)
  sex!: Sex;

  /** Date calendaire `AAAA-MM-JJ`, sans heure ni fuseau. */
  @IsDateString({ strict: true })
  birthDate!: string;

  @IsBoolean()
  birthDateIsEstimated!: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  phone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  fokontany?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  address?: string;

  /**
   * Horodatage de l'appareil au moment de la saisie.
   *
   * Conservé en plus de l'horodatage de réception : l'écart mesure la dérive
   * d'horloge, qui arbitre les conflits de synchronisation (décision D6).
   */
  @IsDateString()
  deviceUpdatedAt!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1_000_000)
  version?: number;
}
