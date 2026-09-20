# Image de production de l'API Vitals.
#
# Debian « slim » plutôt qu'Alpine : argon2 est un module natif, et la libc
# musl d'Alpine impose une recompilation fragile là où Debian utilise les
# binaires précompilés.

# ---------- Étape 1 : dépendances et compilation ----------
FROM node:22-slim AS builder

WORKDIR /app

# Outils nécessaires si un module natif doit être recompilé.
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ openssl \
    && rm -rf /var/lib/apt/lists/*

# Les dépendances sont installées avant de copier le code : tant que
# package-lock.json ne change pas, cette couche reste en cache et les
# déploiements suivants ne réinstallent rien.
COPY package.json package-lock.json ./
RUN npm ci

COPY prisma ./prisma
RUN npx prisma generate

COPY tsconfig.json nest-cli.json ./
COPY src ./src
RUN npm run build

# Retire les dépendances de développement de l'arborescence à copier.
RUN npm prune --omit=dev

# ---------- Étape 2 : image d'exécution ----------
FROM node:22-slim AS runner

WORKDIR /app

# openssl est requis par le client Prisma ; ca-certificates pour les appels
# sortants en TLS.
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production
ENV PORT=3000

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/package.json ./package.json

# Script d'amorçage du premier compte d'administration. En JavaScript simple :
# ts-node est retiré avec les dépendances de développement.
COPY scripts ./scripts

# L'application ne tourne pas en root : une faille d'exécution de code ne doit
# pas donner la main sur le conteneur entier.
USER node

EXPOSE 3000

# Sonde de vitalité. Elle interroge la route publique /health, qui teste aussi
# la connexion à PostgreSQL : un conteneur qui répond mais ne joint plus la
# base doit être signalé comme dégradé, pas comme sain.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:3000/api/v1/health').then(r=>r.json()).then(j=>process.exit(j.database==='up'?0:1)).catch(()=>process.exit(1))"

CMD ["node", "dist/main"]
