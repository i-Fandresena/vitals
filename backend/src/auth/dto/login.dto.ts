import { IsNotEmpty, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class LoginDto {
  @IsString()
  @IsNotEmpty({ message: "L'identifiant est obligatoire" })
  @MaxLength(64)
  username!: string;

  @IsString()
  @IsNotEmpty({ message: 'Le mot de passe est obligatoire' })
  @MaxLength(256)
  password!: string;

  /// Identifiant stable de l'appareil. Il permet de révoquer un téléphone
  /// perdu sans déconnecter les autres appareils du même utilisateur, et de
  /// tracer l'origine des synchronisations.
  @IsString()
  @IsNotEmpty({ message: "L'identifiant d'appareil est obligatoire" })
  @MinLength(8)
  @MaxLength(128)
  deviceId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  deviceLabel?: string;
}
