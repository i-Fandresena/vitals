# API Vitals

Backend NestJS + PostgreSQL du projet [Vitals](../README.md). Il assure
l'authentification, la gestion des rôles et — à partir de la Phase 3 — la
réception des données synchronisées depuis les appareils.

## Démarrage

### 1. Base de données

```bash
createdb vitals          # ou : psql -U postgres -c "CREATE DATABASE vitals;"
```

### 2. Configuration

```bash
cp .env.example .env
```

Renseigner `DATABASE_URL`, puis générer deux secrets distincts :

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

### 3. Installation et migrations

```bash
npm install
npx prisma migrate dev      # crée le schéma
npm run seed                # comptes de développement
npm run start:dev           # http://localhost:3000/api/v1
```

Le seed crée un CSB fictif et cinq comptes, un par profil — `agent`,
`infirmier`, `sagefemme`, `responsable`, `admin` — avec le mot de passe commun
`Vitals-dev-2026`. **Développement uniquement** : le script refuse de tourner
avec `NODE_ENV=production`, et aucun dossier bénéficiaire n'est créé.

## Endpoints

Préfixe : `/api/v1`. Toutes les routes exigent un jeton d'accès sauf celles
marquées publiques.

| Méthode | Route | Public | Description |
|---|---|:--:|---|
| `GET` | `/health` | ✅ | État du service et de la base |
| `POST` | `/auth/login` | ✅ | Connexion, renvoie les jetons |
| `POST` | `/auth/refresh` | ✅ | Renouvelle les jetons (rotation) |
| `POST` | `/auth/logout` | ❌ | Déconnecte l'appareil courant |
| `GET` | `/auth/me` | ❌ | Profil de l'utilisateur connecté |

## Tester avec curl

### Service en ligne

```bash
curl http://localhost:3000/api/v1/health
```

```json
{ "status": "ok", "database": "up", "time": "2026-09-19T10:12:03.441Z" }
```

### Connexion

`deviceId` est obligatoire : il identifie le téléphone, permet de révoquer un
appareil perdu et trace l'origine des synchronisations.

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
        "username": "sagefemme",
        "password": "Vitals-dev-2026",
        "deviceId": "poste-de-test-0001",
        "deviceLabel": "Poste de développement"
      }'
```

```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "9fK2mQ...",
  "expiresIn": 900,
  "user": {
    "id": "0194f2c1-...",
    "username": "sagefemme",
    "fullName": "Sage-femme (démo)",
    "role": "SAGE_FEMME",
    "csbId": "0194f2c0-...",
    "csbName": "CSB II de démonstration"
  }
}
```

### Route authentifiée

```bash
curl http://localhost:3000/api/v1/auth/me \
  -H "Authorization: Bearer <accessToken>"
```

### Renouvellement

```bash
curl -X POST http://localhost:3000/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{ "refreshToken": "<refreshToken>", "deviceId": "poste-de-test-0001" }'
```

Le jeton fourni est **révoqué au passage** : chaque refresh en délivre un
nouveau. Rejouer l'ancien renvoie `401`.

### Vérifications attendues

| Cas | Résultat |
|---|---|
| Mauvais mot de passe | `401 Identifiant ou mot de passe incorrect` |
| Identifiant inexistant | `401`, **même message et même délai** |
| Compte désactivé | `401`, même message |
| Route protégée sans jeton | `401` |
| 6 connexions en moins d'une minute | `429 Too Many Requests` |
| Champ non déclaré dans le corps | `400` |

Le message unique sur les trois premiers cas est délibéré : un message
distinguant « compte inconnu » de « mot de passe faux » permettrait d'énumérer
les comptes du centre. La vérification de mot de passe est exécutée même
lorsque l'identifiant n'existe pas, pour que les deux cas prennent le même
temps.

## Sécurité

| Sujet | Choix |
|---|---|
| Mots de passe | argon2id |
| Jeton d'accès | JWT, 15 min |
| Jeton de refresh | valeur aléatoire opaque de 48 octets, **stockée hachée**, rotation à chaque usage, une ligne par appareil |
| Gardes | authentification et rôles appliqués **globalement** — une route sans annotation est fermée, jamais ouverte |
| Validation | `whitelist` + `forbidNonWhitelisted` : tout champ non déclaré est rejeté |
| Journalisation | requêtes Prisma non journalisées, IP hachée dans l'audit, aucune donnée patient dans les logs |
| En-têtes | `helmet` |
| Débit | 5 connexions/min/IP, 120 requêtes/min par défaut |

Le jeton d'accès est revalidé en base à chaque requête : désactiver un compte ou
changer un rôle prend effet immédiatement, sans attendre l'expiration.

## Commandes

```bash
npm run start:dev      # rechargement à chaud
npm run build          # compilation vers dist/
npm run lint
npx tsc --noEmit       # vérification de types seule
npx prisma studio      # exploration de la base
npx prisma migrate dev --name <nom>
```

## Structure

```
src/
├── main.ts                    amorçage, helmet, validation, versionnage d'URL
├── app.module.ts              gardes globales
├── health/                    sonde utilisée par l'app pour tester le réseau
├── prisma/                    accès base
└── auth/
    ├── auth.controller.ts     login, refresh, logout, me
    ├── auth.service.ts        vérification, émission et rotation des jetons
    ├── strategies/            validation du JWT
    ├── guards/                JwtAuthGuard, RolesGuard
    └── decorators/            @Public, @Roles, @CurrentUser
prisma/
├── schema.prisma              modèle serveur, miroir du modèle Drift
└── seed.ts                    comptes de développement
```

## Limites connues

- **Aucun endpoint métier** : dossiers, consultations et synchronisation
  arrivent en Phase 2 et 3.
- **Les jetons de refresh expirés ne sont pas purgés** — une tâche de nettoyage
  sera nécessaire avant le pilote.
- Les listes d'antigènes PEV, de méthodes de PF et de codes de motifs sont des
  propositions à faire valider (voir [docs/02-modele-donnees.md](../docs/02-modele-donnees.md)).
