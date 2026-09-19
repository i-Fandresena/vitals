import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { AuditAction, User } from '@prisma/client';
import * as argon2 from 'argon2';
import { createHash, randomBytes } from 'node:crypto';
import { uuidv7 } from 'uuidv7';

import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { JwtPayload } from './types/jwt-payload';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface AuthResult extends AuthTokens {
  user: {
    id: string;
    username: string;
    fullName: string;
    role: string;
    csbId: string | null;
    csbName: string | null;
  };
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  /**
   * Hachage d'un mot de passe aléatoire, vérifié à la place du vrai quand
   * l'identifiant n'existe pas.
   *
   * Il doit s'agir d'un **vrai** hachage argon2 : sur une valeur factice,
   * `verify` échouerait immédiatement au lieu de faire le calcul, et la
   * différence de durée entre « compte inconnu » et « mot de passe faux »
   * permettrait d'énumérer les comptes du centre — exactement ce que cette
   * précaution vise à empêcher.
   *
   * Calculé une fois au démarrage et réutilisé : argon2 est volontairement lent.
   */
  private readonly decoyHash: Promise<string> = argon2.hash(
    randomBytes(32).toString('hex'),
    { type: argon2.argon2id },
  );

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async login(dto: LoginDto, ipHash?: string): Promise<AuthResult> {
    const user = await this.prisma.user.findUnique({
      where: { username: dto.username },
      include: { csb: { select: { name: true } } },
    });

    let passwordValid = false;
    if (user) {
      passwordValid = await this.verifyPassword(user.passwordHash, dto.password);
    } else {
      // Vérification volontairement inutile : elle ne sert qu'à consommer le
      // même temps de calcul que le cas nominal. Son résultat est ignoré.
      await this.verifyPassword(await this.decoyHash, dto.password);
    }

    if (!user || !passwordValid || !user.isActive) {
      await this.writeAudit({
        action: AuditAction.LOGIN_FAILED,
        userId: user?.id ?? null,
        csbId: user?.csbId ?? null,
        deviceId: dto.deviceId,
        ipHash,
      });
      // Message unique : ne jamais révéler laquelle des trois conditions a échoué.
      throw new UnauthorizedException('Identifiant ou mot de passe incorrect');
    }

    const tokens = await this.issueTokens(user, dto.deviceId, dto.deviceLabel);

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    await this.writeAudit({
      action: AuditAction.LOGIN,
      userId: user.id,
      csbId: user.csbId,
      deviceId: dto.deviceId,
      ipHash,
    });

    return {
      ...tokens,
      user: {
        id: user.id,
        username: user.username,
        fullName: user.fullName,
        role: user.role,
        csbId: user.csbId,
        csbName: user.csb?.name ?? null,
      },
    };
  }

  /**
   * Échange un jeton de rafraîchissement contre un nouveau couple de jetons.
   * L'ancien est révoqué au passage (rotation) : un jeton intercepté ne reste
   * utilisable que jusqu'à la prochaine synchronisation de l'appareil légitime.
   */
  async refresh(dto: RefreshDto): Promise<AuthTokens> {
    const tokenHash = this.hashToken(dto.refreshToken);

    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });

    if (
      !stored ||
      stored.revokedAt !== null ||
      stored.expiresAt < new Date() ||
      stored.deviceId !== dto.deviceId ||
      !stored.user.isActive
    ) {
      throw new UnauthorizedException('Session expirée, reconnexion nécessaire');
    }

    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });

    return this.issueTokens(stored.user, stored.deviceId, stored.deviceLabel ?? undefined);
  }

  /** Déconnexion d'un seul appareil : les autres restent connectés. */
  async logout(userId: string, deviceId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { userId, deviceId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async issueTokens(
    user: User,
    deviceId: string,
    deviceLabel?: string,
  ): Promise<AuthTokens> {
    const payload: JwtPayload = {
      sub: user.id,
      role: user.role,
      csbId: user.csbId,
      deviceId,
    };

    // Converties en secondes dès maintenant : une seule source pour la durée
    // du jeton et pour le `expiresIn` renvoyé à l'application.
    const accessTtlSeconds = Math.floor(
      this.parseTtlMs(this.config.get<string>('JWT_ACCESS_TTL', '15m')) / 1000,
    );
    const refreshTtlMs = this.parseTtlMs(this.config.get<string>('JWT_REFRESH_TTL', '30d'));

    const accessToken = await this.jwt.signAsync(payload, {
      secret: this.config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      expiresIn: accessTtlSeconds,
    });

    // Le refresh est une valeur aléatoire opaque, pas un JWT : il n'a rien à
    // transporter et il doit être révocable côté serveur.
    const refreshToken = randomBytes(48).toString('base64url');

    await this.prisma.refreshToken.create({
      data: {
        id: uuidv7(),
        userId: user.id,
        tokenHash: this.hashToken(refreshToken),
        deviceId,
        deviceLabel,
        expiresAt: new Date(Date.now() + refreshTtlMs),
      },
    });

    return { accessToken, refreshToken, expiresIn: accessTtlSeconds };
  }

  private async verifyPassword(hash: string, password: string): Promise<boolean> {
    try {
      return await argon2.verify(hash, password);
    } catch {
      // Hachage illisible ou corrompu : échec d'authentification, pas une
      // erreur serveur. Le mot de passe n'est jamais journalisé.
      return false;
    }
  }

  /**
   * Les jetons de rafraîchissement sont stockés hachés : une fuite de la base
   * ne permet pas de rejouer les sessions. SHA-256 suffit ici, la valeur est
   * déjà aléatoire sur 48 octets et n'a pas besoin d'être ralentie.
   */
  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private parseTtlMs(ttl: string): number {
    const match = /^(\d+)([smhd])$/.exec(ttl.trim());
    if (!match) {
      throw new Error(`Durée de validité invalide : "${ttl}" (attendu 15m, 24h, 30d…)`);
    }
    const value = Number(match[1]);
    const unit = match[2] as 's' | 'm' | 'h' | 'd';
    const multipliers = { s: 1_000, m: 60_000, h: 3_600_000, d: 86_400_000 };
    return value * multipliers[unit];
  }

  private async writeAudit(entry: {
    action: AuditAction;
    userId: string | null;
    csbId: string | null;
    deviceId: string;
    ipHash?: string;
  }): Promise<void> {
    try {
      await this.prisma.auditLog.create({
        data: {
          id: uuidv7(),
          action: entry.action,
          userId: entry.userId,
          csbId: entry.csbId,
          entityType: 'User',
          entityId: entry.userId,
          changedFields: [],
          deviceId: entry.deviceId,
          ipHash: entry.ipHash,
        },
      });
    } catch (error) {
      // L'audit ne doit jamais faire échouer une authentification légitime,
      // mais son échec doit être visible en exploitation.
      this.logger.error(
        `Échec d'écriture du journal d'audit (${entry.action})`,
        error instanceof Error ? error.stack : undefined,
      );
    }
  }
}
