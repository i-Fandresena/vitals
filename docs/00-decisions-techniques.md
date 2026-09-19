# Décisions techniques figées — Ticket 0.1

> **Statut : proposition à valider par l'équipe Maternal AI.**
> Le backlog (ticket 0.1) réserve ces décisions à l'équipe, pas à Claude Code.
> Ce document fixe une position par défaut pour ne pas bloquer la Phase 1 ; chaque
> point marqué ⚠️ doit être confirmé ou corrigé avant le déploiement pilote.

## D1 — Stack mobile

**Flutter 3.47.5 / Dart 3.13.4**, cible Android en priorité, livrable APK.

- `minSdkVersion 21` (Android 5.0) : les appareils des CSB sont souvent anciens,
  descendre plus bas n'est plus supporté par les dépendances de chiffrement.
- `targetSdkVersion` : dernier stable supporté par Flutter.
- Architecture applicative en trois couches : `data/` (Drift, API, sync),
  `domain/` (entités et règles métier, sans dépendance framework),
  `presentation/` (écrans et widgets).

## D2 — Stockage local

**Drift (SQLite) comme source de vérité locale**, conformément au backlog §1.3.

- L'application écrit toujours en local d'abord, puis synchronise (CDC §6).
- Chiffrement au repos via **SQLCipher** (`sqlcipher_flutter_libs`), clé stockée
  dans le keystore Android via `flutter_secure_storage` (voir ticket 3.3).

## D3 — Backend

**NestJS + PostgreSQL + Prisma.**

- Le backlog laissait le choix ouvert (« NestJS+PostgreSQL / à confirmer »).
  PostgreSQL 16 est déjà installé sur le poste de développement.
- Prisma plutôt que TypeORM : migrations versionnées et typage strict, utile pour
  garder le modèle serveur aligné sur le modèle local (CDC §9, interopérabilité).
- Le serveur est le point d'agrégation multi-CSB (CDC §5), même si le MVP
  n'expose que le niveau CSB.

⚠️ **Hébergement non tranché.** Le choix (VPS souverain, cloud régional, serveur
du ministère) dépend du cadre réglementaire du ticket 0.3 et doit être fait avant
le pilote : héberger des données de santé hors du pays peut être interdit.

## D4 — Authentification et rôles

- **JWT** : access token court (15 min) + refresh token (30 jours), stockés via
  `flutter_secure_storage`.
- Refresh long assumé : un agent en brousse peut rester des semaines sans
  connexion et doit continuer à travailler hors ligne. L'app reste utilisable
  hors ligne même token expiré ; seule la synchronisation exige un token valide.
- Rôles : `agent_communautaire`, `infirmier`, `sage_femme`, `responsable_csb`,
  `admin_national`. Les niveaux district/région sont présents dans le modèle mais
  hors périmètre MVP (CDC §10).
- Voir [01-matrice-droits.md](01-matrice-droits.md) pour le détail des permissions.

## D5 — Identifiant unique du bénéficiaire et QR code

Deux identifiants distincts, c'est volontaire :

| | Usage | Format |
|---|---|---|
| **Identifiant technique** | clé primaire, synchronisation, QR code | UUID v7 |
| **Identifiant lisible** | communication orale, registre papier de secours | `CSB-<code>-<AA>-<séquence>` ex. `CSB-0142-26-00731` |

- **UUID v7** (ordonné dans le temps) : généré localement, donc aucune collision
  entre CSB même hors ligne, et pas d'aller-retour serveur à la création.
- L'identifiant lisible est généré localement à partir du code du CSB, il reste
  donc unique sans coordination réseau. Il sert à dire un dossier à voix haute et
  à faire le lien avec les registres papier pendant la transition.

**Le QR code n'encode que l'UUID**, sous la forme `vitals:b/<uuid>`.

⚠️ Décision de confidentialité importante : **aucune donnée personnelle dans le
QR code** (ni nom, ni date de naissance, ni information de santé). Une carte
perdue ou photographiée ne révèle donc rien ; elle n'est exploitable que par
quelqu'un déjà authentifié dans l'application.

## D6 — Stratégie de synchronisation et de conflits

Synchronisation incrémentale par `updated_at` + compteur `version`, file de
mutations locale rejouée dès que la connexion revient.

La résolution de conflit dépend du type de donnée, et cette distinction simplifie
beaucoup le problème :

- **Événements de soin** (consultations, vaccinations, PF, CPN) : **immuables,
  append-only**. Deux agents ne peuvent pas entrer en conflit sur un événement,
  puisque chacun crée le sien. La déduplication se fait sur l'UUID de l'événement,
  généré à la saisie. Une correction crée un événement d'annulation, elle ne
  modifie pas l'original — cohérent avec l'exigence de traçabilité du CDC §8.
- **Identité du bénéficiaire** (nom, date de naissance, village…) : seule donnée
  réellement modifiable, donc seule source de conflit. MVP : **dernier écrit
  gagne**, arbitré par `updated_at`, avec le conflit et la valeur écrasée
  consignés dans le journal d'audit (ticket 3.4) pour rattrapage manuel.

⚠️ Les horloges des appareils peuvent dériver hors ligne. Le serveur enregistre
donc à la fois l'horodatage de l'appareil et son propre horodatage de réception,
et l'arbitrage se fait sur l'horodatage appareil corrigé de la dérive mesurée à
la connexion.

## D7 — Cadre réglementaire

⚠️ **Non tranché — ticket 0.3, prérequis juridique au déploiement, pas au
développement.**

À faire valider par un juriste ou un référent conformité, sans présumer du
résultat : la loi malgache n°2014-038 sur la protection des données à caractère
personnel et le rôle de la CMIL sont les points de départ à vérifier, ainsi que
les règles de conservation, de consentement, d'export et de localisation des
données de santé. Les conclusions alimenteront les tickets de la Phase 3.

## D8 — Ce qui est délibérément absent

Conformément au CDC §10 et aux consignes du backlog, le code ne prépare pas :
dispositifs médicaux connectés, IA et analyse prédictive, gestion de stocks
d'intrants, intégrations externes, agrégation au-delà du CSB.

La seule concession à l'avenir est structurelle et sans coût aujourd'hui : les
entités portent un rattachement géographique (CSB → commune → district → région)
pour que l'agrégation multi-niveaux du CDC §5 reste possible sans migration
douloureuse.
