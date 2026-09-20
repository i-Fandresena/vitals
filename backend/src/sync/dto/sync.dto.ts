import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';

/** Types d'entités que la file de synchronisation sait transporter. */
export const ENTITES_SYNCHRONISABLES = [
  'beneficiaries',
  'consultations',
  'vaccinations',
  'family_planning_activities',
  'pregnancies',
  'prenatal_visits',
] as const;

export type EntiteSynchronisable = (typeof ENTITES_SYNCHRONISABLES)[number];

export class MutationDto {
  @IsIn(ENTITES_SYNCHRONISABLES)
  entityType!: EntiteSynchronisable;

  @IsString()
  entityId!: string;

  @IsIn(['CREATE', 'UPDATE', 'CANCEL', 'ARCHIVE'])
  operation!: 'CREATE' | 'UPDATE' | 'CANCEL' | 'ARCHIVE';

  /**
   * Contenu de l'enregistrement, tel que l'appareil l'a écrit.
   *
   * Validé par le service selon `entityType` : un DTO typé par entité
   * obligerait à une union discriminée que `class-validator` gère mal, et le
   * service doit de toute façon vérifier les champs avant d'écrire.
   */
  @IsObject()
  payload!: Record<string, unknown>;

  /**
   * Horodatage de l'appareil au moment de la saisie.
   *
   * Conservé en plus de l'horodatage de réception : l'écart mesure la dérive
   * d'horloge, qui arbitre les conflits (décision D6).
   */
  @IsDateString()
  deviceCreatedAt!: string;
}

export class PushDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => MutationDto)
  // Un lot borné : un appareil resté trois semaines hors ligne ne doit pas
  // envoyer dix mille mutations en une requête sur une connexion 2G. Il
  // enverra plusieurs lots.
  @ArrayMaxSize(200)
  mutations!: MutationDto[];

  @IsOptional()
  @IsString()
  deviceLabel?: string;
}
