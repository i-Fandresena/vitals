# Décisions techniques figées — Ticket 0.1

> **Statut : proposition à valider par l'équipe Maternal AI.**
> Le backlog (ticket 0.1) réserve ces décisions à l'équipe, pas à Claude Code.
> Ce document fixe une position par défaut pour ne pas bloquer la Phase 1 ; chaque
> point marqué ⚠️ doit être confirmé ou corrigé avant le déploiement pilote.

## D1 — Stack mobile

**Flutter 3.47.5 / Dart 3.13.4**, cible Android en priorité, livrable APK.

- `minSdkVersion 24` (Android 7.0, 2016) — valeur plancher de Flutter 3.47, qui
  ne supporte plus les versions antérieures.

  ⚠️ **Conséquence à vérifier sur le terrain** : les appareils sous Android 5 ou
  6 ne pourront pas installer l'application. Si des CSB pilotes en utilisent, il
  faut le savoir avant le déploiement, car la seule issue serait de rétrograder
  Flutter ou de changer d'appareil. À contrôler pendant les tests du ticket 4.3.
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

**Le gouvernement malgache a autorisé la phase pilote** (septembre 2026,
information transmise par l'équipe Maternal AI). Le déploiement sur un VPS
hébergé hors du pays est donc couvert pour cette phase.

⚠️ **Cette autorisation porte sur le pilote, pas sur la généralisation.** Ce
qui reste à cadrer avant une extension à plusieurs centres :

- la portée exacte et la durée de l'autorisation obtenue ;
- les règles de conservation, de consentement et d'export des données ;
- si la production devra être rapatriée sur un hébergement national ;
- le rôle de la CMIL et l'application de la loi n°2014-038 sur la protection
  des données à caractère personnel.

⚠️ **Cloudflare est en coupure du trafic.** Les deux sous-domaines passent par
son proxy, qui termine le TLS : Cloudflare déchiffre donc les échanges entre
les téléphones et le serveur, et voit les données de santé en clair. La
liaison Cloudflare → VPS est bien chiffrée, mais cela ajoute un tiers dans la
chaîne. À signaler au référent conformité, et à retirer si nécessaire — il
suffit de désactiver le proxy (nuage gris) dans Cloudflare, Traefik ayant déjà
ses propres certificats Let's Encrypt.

## D8 — Ce qui est délibérément absent

Conformément au CDC §10 et aux consignes du backlog, le code ne prépare pas :
dispositifs médicaux connectés, IA et analyse prédictive, gestion de stocks
d'intrants, intégrations externes, agrégation au-delà du CSB.

La seule concession à l'avenir est structurelle et sans coût aujourd'hui : les
entités portent un rattachement géographique (CSB → commune → district → région)
pour que l'agrégation multi-niveaux du CDC §5 reste possible sans migration
douloureuse.

## D12 — Renommage en MbolaTsara : ce qui change, ce qui ne change pas

Le produit s'appelle **MbolaTsara**. Tout ce que voit un utilisateur porte ce
nom : libellé de l'application sur Android, titres des écrans, messages,
espace d'administration.

Quatre identifiants techniques gardent volontairement l'ancien nom. Les
changer coûterait cher pour un gain nul, puisqu'aucun utilisateur ne les voit.

| Identifiant | Valeur | Pourquoi il ne bouge pas |
|---|---|---|
| `applicationId` Android | `ai.maternal.vitals` | Android le traite comme l'identité de l'application. Le changer produit une **seconde** application : la mise à jour ne s'installe plus par-dessus, et la base locale chiffrée du téléphone — donc les dossiers pas encore synchronisés — devient inatteignable. |
| Nom du fichier de base locale | `vitals.sqlite` | Même conséquence : un nouveau nom ouvre une base vide et abandonne l'ancienne sur l'appareil. |
| Préfixe des QR codes | `vitals:b/` | Il est imprimé sur les cartes déjà remises aux personnes suivies. Un nouveau préfixe rendrait ces cartes illisibles par l'application. |
| Chemin de déploiement, base PostgreSQL, dépôt | `/opt/vitals`, `vitals` | Renommer demande une migration de la base et une reconfiguration du serveur, sans rien apporter. |

Le nom du paquet Dart (`name: vitals` dans `pubspec.yaml`) reste également :
il n'apparaît que dans les `import` du code.

Si l'un de ces changements devient souhaitable, le bon moment est **avant** la
distribution des premières cartes et des premiers téléphones, pas après.
