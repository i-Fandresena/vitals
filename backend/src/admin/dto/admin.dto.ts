import { UserRole } from '@prisma/client';
import {
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateCsbDto {
  @IsString()
  @Matches(/^[A-Z0-9]{2,12}$/, {
    message: 'Le code du centre ne contient que des majuscules et des chiffres',
  })
  code!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  commune?: string;

  @IsUUID()
  districtId!: string;

  /** Vrai quand le centre n'a pas de sage-femme : les infirmiers saisissent
   *  alors les CPN (voir docs/01-matrice-droits.md). */
  @IsOptional()
  @IsBoolean()
  allowsNurseAntenatalCare?: boolean;
}

export class UpdateCsbDto {
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  commune?: string;

  @IsOptional()
  @IsBoolean()
  allowsNurseAntenatalCare?: boolean;

  /**
   * Unité d'organisation correspondante dans DHIS2.
   *
   * Chaîne vide acceptée pour défaire un rapprochement : un centre mal
   * rapproché doit pouvoir sortir de l'export sans passer par la base.
   */
  @IsOptional()
  @Matches(/^([A-Za-z][A-Za-z0-9]{10})?$/, {
    message: "Identifiant DHIS2 attendu : 11 caractères, commençant par une lettre.",
  })
  dhis2OrgUnit?: string;
}

export class CreateUserDto {
  /**
   * Identifiant de connexion.
   *
   * Une adresse e-mail est acceptée mais n'est pas imposée : beaucoup de
   * personnels de CSB n'en ont pas, et leur en exiger une bloquerait la
   * création de leur compte. Un matricule ou un nom d'usage convient.
   */
  @IsString()
  @Matches(/^[a-z0-9._@+-]{3,120}$/, {
    message:
      "L'identifiant ne contient que des minuscules, chiffres, point, tiret, " +
      'souligné, plus ou arobase, et fait au moins 3 caractères',
  })
  username!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  fullName!: string;

  @IsEnum(UserRole)
  role!: UserRole;

  /**
   * Centre de rattachement. Obligatoire sauf pour ADMIN_NATIONAL, qui
   * n'accède à aucun dossier individuel.
   */
  @IsOptional()
  @IsUUID()
  csbId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  phone?: string;

  /**
   * Mot de passe initial. 12 caractères au minimum : ces comptes ouvrent
   * l'accès à des données de santé, et un mot de passe court est la voie
   * d'entrée la plus probable.
   */
  @IsString()
  @MinLength(12, { message: 'Le mot de passe fait au moins 12 caractères' })
  @MaxLength(256)
  password!: string;
}

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  fullName?: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  phone?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class ResetPasswordDto {
  @IsString()
  @MinLength(12, { message: 'Le mot de passe fait au moins 12 caractères' })
  @MaxLength(256)
  password!: string;
}
