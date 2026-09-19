import { Logger, ValidationPipe, VersioningType } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';

import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, {
    // Pas de log `debug` ni `verbose` en production : ils peuvent contenir des
    // charges utiles de requêtes, donc des données de santé.
    logger:
      process.env.NODE_ENV === 'production'
        ? ['error', 'warn', 'log']
        : ['error', 'warn', 'log', 'debug'],
  });

  const config = app.get(ConfigService);

  app.use(helmet());
  app.setGlobalPrefix('api');
  app.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      // Rejette toute propriété non déclarée dans le DTO plutôt que de
      // l'ignorer silencieusement.
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: false },
    }),
  );

  const origins = config
    .get<string>('CORS_ORIGINS', '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  if (origins.length > 0) {
    app.enableCors({ origin: origins, credentials: true });
  }

  const port = config.get<number>('PORT', 3000);
  await app.listen(port);

  new Logger('Bootstrap').log(`API Vitals démarrée sur http://localhost:${port}/api/v1`);
}

void bootstrap();
