import { Body, Controller, HttpCode, HttpStatus, Post, Req } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { createHash } from 'node:crypto';

import { AuthService } from './auth.service';
import { CurrentUser } from './decorators/current-user.decorator';
import { Public } from './decorators/public.decorator';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { AuthenticatedUser } from './types/jwt-payload';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  /** POST /api/v1/auth/login */
  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  // Limite les tentatives par force brute : 5 essais par minute et par IP.
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.authService.login(dto, this.hashIp(req.ip));
  }

  /** POST /api/v1/auth/refresh */
  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  refresh(@Body() dto: RefreshDto) {
    return this.authService.refresh(dto);
  }

  /** POST /api/v1/auth/logout — déconnecte uniquement l'appareil courant. */
  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout(@CurrentUser() user: AuthenticatedUser): Promise<void> {
    await this.authService.logout(user.id, user.deviceId);
  }

  /** GET-like : profil de l'utilisateur connecté, utile au démarrage de l'app. */
  @Post('me')
  @HttpCode(HttpStatus.OK)
  me(@CurrentUser() user: AuthenticatedUser) {
    return user;
  }

  /**
   * L'adresse IP est une donnée personnelle : elle est hachée avant d'entrer
   * dans le journal d'audit, où elle ne sert qu'à recouper des tentatives.
   */
  private hashIp(ip?: string): string | undefined {
    return ip ? createHash('sha256').update(ip).digest('hex').slice(0, 32) : undefined;
  }
}
