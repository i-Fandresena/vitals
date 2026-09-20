# Déploiement

Comment mettre Vitals en service : l'API et l'espace d'administration sur un
VPS, l'APK construit localement puis distribué aux centres.

```
   Téléphone du CSB                    VPS
  ┌────────────────┐        ┌──────────────────────────────┐
  │  APK Vitals    │  HTTPS │  Caddy  (TLS automatique)    │
  │  base locale   │───────▶│    ├─ api-vitals…  → API     │
  │  = source de   │        │    └─ vitals…      → admin   │
  │    vérité      │        │  PostgreSQL (réseau interne) │
  └────────────────┘        └──────────────────────────────┘
```

L'APK ne se déploie pas : il se construit et se distribue. Le téléphone reste
utilisable si le VPS est injoignable — la base locale est la source de vérité
(CDC §6).

## 1 — DNS

Deux enregistrements `A` vers l'IP du VPS :

| Nom | Type | Valeur |
|---|---|---|
| `api-vitals.aura-plus.site` | A | IP du VPS |
| `vitals.aura-plus.site` | A | IP du VPS |

Attendre la propagation avant l'étape 3 : Caddy demande les certificats au
premier démarrage et Let's Encrypt doit pouvoir résoudre les deux noms.

```bash
dig +short api-vitals.aura-plus.site
```

## 2 — Préparer le VPS

Debian 12 ou Ubuntu 24.04, 2 Go de RAM au minimum.

```bash
# Docker
curl -fsSL https://get.docker.com | sh

# Pare-feu : seuls 22, 80 et 443 sont ouverts.
ufw allow 22/tcp && ufw allow 80/tcp && ufw allow 443/tcp && ufw enable
```

**PostgreSQL ne doit jamais être exposé.** Le `docker-compose.yml` ne publie
aucun port pour la base : elle n'est joignable que depuis le réseau interne de
Docker. Des données de santé accessibles depuis l'internet public, même
derrière un mot de passe, sont un risque qu'aucun mot de passe ne compense.

## 3 — Déployer

```bash
git clone https://github.com/i-Fandresena/vitals.git
cd vitals/deploy

cp .env.example .env
```

Renseigner `.env` :

```bash
# Mot de passe de la base
openssl rand -base64 36

# Les deux secrets JWT, DISTINCTS l'un de l'autre
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

Puis :

```bash
docker compose up -d --build
docker compose exec api npx prisma migrate deploy
```

`migrate deploy` applique les migrations sans jamais proposer de réinitialiser
la base, contrairement à `migrate dev`. C'est la seule commande de migration à
utiliser en production.

### Vérifier

```bash
curl https://api-vitals.aura-plus.site/api/v1/health
```

Attendu : `{"status":"ok","database":"up",…}` — en **https**, avec un
certificat valide obtenu automatiquement.

### Créer le premier compte

L'amorçage se fait en ligne de commande : sans compte, personne ne peut entrer
dans l'espace d'administration pour en créer un.

```bash
docker compose exec api node scripts/creer-admin.js admin "Nom Prenom"
```

Le mot de passe est généré et **affiché une seule fois**. Le noter, puis le
changer à la première connexion.

Le script refuse de s'exécuter s'il existe déjà un compte d'administration
actif : les suivants se créent depuis l'espace d'administration, où chaque
création est journalisée avec son auteur (CDC §8).

Ensuite, tout se passe sur `https://vitals.aura-plus.site` : créer les centres,
puis les comptes des soignants.

## 4 — Construire l'APK

### Créer le keystore — une seule fois

```bash
keytool -genkey -v -keystore ~/vitals-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias vitals
```

```bash
cp mobile/android/key.properties.example mobile/android/key.properties
# renseigner storeFile, storePassword, keyAlias, keyPassword
```

⚠️ **Ce keystore est irremplaçable.** Android identifie une application par sa
signature : perdre la clé interdit définitivement de mettre à jour les
installations existantes. Il faudrait republier sous un autre identifiant, puis
désinstaller et réinstaller dans chaque centre, en perdant les données locales
non synchronisées.

Le sauvegarder ailleurs que sur le poste de développement, avec son mot de
passe, avant le premier déploiement. Ni le keystore ni `key.properties` ne sont
versionnés — le dépôt les ignore.

### Construire

```bash
cd mobile
flutter build apk --release --split-per-abi \
  --dart-define=API_BASE_URL=https://api-vitals.aura-plus.site/api/v1
```

Sans `--dart-define`, l'application viserait `10.0.2.2`, l'adresse de
l'émulateur : elle ne joindrait aucun serveur sur un vrai téléphone.

Les fichiers sont dans `mobile/build/app/outputs/flutter-apk/`. Pour un CSB,
c'est `app-armeabi-v7a-release.apk` (≈ 24 Mo) dans la plupart des cas.

### Vérifier avant distribution

`apksigner`, fourni avec le SDK Android, lit les signatures APK v2 et v3 :

```bash
# Windows : $ANDROID_HOME/build-tools/<version>/apksigner.bat
apksigner verify --print-certs app-armeabi-v7a-release.apk
```

Attendu : un `certificate DN` portant le nom saisi à la création du keystore.

⚠️ Si la sortie indique `CN=Android Debug`, le keystore n'a pas été pris en
compte et **l'APK n'est pas distribuable**. Vérifier le chemin `storeFile`
dans `android/key.properties` : il doit être absolu.

`keytool -printcert -jarfile` ne convient pas ici — il ne lit que l'ancienne
signature JAR et répond « fichier non signé » sur un APK moderne.

## 5 — Sauvegardes

Sans sauvegarde, une panne du VPS détruit les données de tous les centres. Les
téléphones gardent leur copie locale, mais rien ne garantit qu'elle est
complète.

```bash
# Sauvegarde quotidienne à 2 h, conservée 30 jours
cat > /etc/cron.daily/vitals-backup <<'SCRIPT'
#!/bin/sh
cd /root/vitals/deploy || exit 1
FICHIER="/root/vitals/deploy/backups/vitals-$(date +%F).sql.gz"
docker compose exec -T db pg_dump -U vitals vitals | gzip > "$FICHIER"
find /root/vitals/deploy/backups -name 'vitals-*.sql.gz' -mtime +30 -delete
SCRIPT
chmod +x /etc/cron.daily/vitals-backup
```

⚠️ Ces sauvegardes restent **sur le même serveur** : elles protègent d'une
erreur de manipulation, pas d'une perte du VPS. Les copier hors du serveur, et
**vérifier qu'une restauration fonctionne** — une sauvegarde jamais restaurée
n'est pas une sauvegarde.

Le fichier contient des données de santé en clair : il se chiffre avant tout
transfert et ne se dépose pas sur un stockage grand public.

## 6 — Mise à jour

```bash
cd /root/vitals && git pull
cd deploy && docker compose up -d --build
docker compose exec api npx prisma migrate deploy
```

L'APK se met à jour séparément : les téléphones ne se mettent pas à jour tout
seuls, il faut redistribuer le fichier. Incrémenter `version` dans
`mobile/pubspec.yaml` à chaque diffusion, sinon Android refuse l'installation
par-dessus une version de même numéro.

## Ce qui reste à faire avant une mise en service réelle

| Point | Ticket |
|---|---|
| **Synchronisation** — les données restent sur les téléphones | 3.1 |
| **Chiffrement de la base locale** — un téléphone perdu expose les dossiers | 3.3 |
| Journal d'audit consultable | 3.4 |
| Cadre réglementaire et localisation des données | 0.3 |

⚠️ **Point juridique, pas technique** : héberger des données de santé
malgaches sur un VPS situé hors du pays peut être interdit. À trancher avant
de choisir l'hébergeur, pas après (ticket 0.3).
