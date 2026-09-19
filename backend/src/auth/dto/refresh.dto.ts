import { IsNotEmpty, IsString, MaxLength, MinLength } from 'class-validator';

export class RefreshDto {
  @IsString()
  @IsNotEmpty({ message: 'Le jeton de rafraîchissement est obligatoire' })
  @MaxLength(1024)
  refreshToken!: string;

  @IsString()
  @IsNotEmpty({ message: "L'identifiant d'appareil est obligatoire" })
  @MinLength(8)
  @MaxLength(128)
  deviceId!: string;
}
