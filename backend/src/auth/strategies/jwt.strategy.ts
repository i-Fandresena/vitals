import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

import { PrismaService } from '../../prisma/prisma.service';
import { AuthenticatedUser, JwtPayload } from '../types/jwt-payload';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.getOrThrow<string>('JWT_ACCESS_SECRET'),
    });
  }

  async validate(payload: JwtPayload): Promise<AuthenticatedUser> {
    // Le jeton est signé et non expiré, mais le compte a pu être désactivé
    // depuis son émission : un accès révoqué doit cesser immédiatement, sans
    // attendre l'expiration du jeton.
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: { id: true, role: true, csbId: true, isActive: true },
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('Compte désactivé');
    }

    // On repart des valeurs en base, pas de celles du jeton : un changement de
    // rôle ou d'affectation prend effet sans réémission.
    return {
      id: user.id,
      role: user.role,
      csbId: user.csbId,
      deviceId: payload.deviceId,
    };
  }
}
