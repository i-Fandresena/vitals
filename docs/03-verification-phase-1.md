# Vérification manuelle de la Phase 1

Comment constater par soi-même que le socle technique fonctionne. Compter
environ 20 minutes. Aucune donnée réelle de patient ne doit être utilisée : le
chiffrement de la base locale n'est pas encore en place (ticket 3.3).

## Prérequis

- PostgreSQL démarré, une base `vitals` créée
- Node.js 20+, Flutter 3.47.5+
- Un émulateur Android ou un téléphone en mode développeur

## 1 — Backend

```bash
cd backend
cp .env.example .env          # renseigner DATABASE_URL et les deux secrets
npm install
npx prisma migrate dev --name init
npm run seed
npm run start:dev
```

**Attendu** : `API Vitals démarrée sur http://localhost:3000/api/v1`, et le seed
annonce cinq comptes créés.

### 1.1 Le service répond

```bash
curl http://localhost:3000/api/v1/health
```

✅ `{"status":"ok","database":"up","time":"..."}`

### 1.2 Une connexion valide délivre des jetons

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"sagefemme","password":"Vitals-dev-2026","deviceId":"test-0001"}'
```

✅ `accessToken`, `refreshToken`, `expiresIn: 900`, et un bloc `user` avec
`role: "SAGE_FEMME"` et le nom du CSB.

### 1.3 Un mauvais mot de passe et un compte inexistant se comportent pareil

```bash
curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"sagefemme","password":"faux","deviceId":"test-0001"}'

curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"personne","password":"faux","deviceId":"test-0001"}'
```

✅ Les deux renvoient `401`, **et des durées du même ordre**. C'est le point à
vérifier : si le compte inexistant répondait nettement plus vite, on pourrait
énumérer les comptes du centre en chronométrant les réponses.

### 1.4 Une route protégée refuse un appel sans jeton

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/api/v1/auth/me
```

✅ `401`.

### 1.5 Le jeton de rafraîchissement ne sert qu'une fois

Appeler `/auth/refresh` deux fois avec le **même** `refreshToken` :

✅ Le premier appel renvoie de nouveaux jetons, le second `401`. La rotation
limite la durée de vie d'un jeton intercepté.

### 1.6 La force brute est freinée

Six connexions en moins d'une minute depuis la même adresse :

✅ La sixième renvoie `429`.

## 2 — Application mobile

```bash
cd mobile
flutter pub get
dart run build_runner build
flutter run                    # émulateur : l'API est vue comme 10.0.2.2
```

Sur un téléphone réel, passer l'adresse du poste :
`flutter run --dart-define=API_BASE_URL=http://192.168.X.X:3000/api/v1`

### 2.1 Connexion

Saisir `sagefemme` / `Vitals-dev-2026`.

✅ L'accueil affiche le nom, le rôle « Sage-femme » et le nom du CSB.

### 2.2 Un mauvais mot de passe s'explique sans disparaître

✅ Un bandeau rouge reste affiché pendant la correction de la saisie — il ne
s'efface pas au bout de quelques secondes comme le ferait une notification.

### 2.3 La session survit à la fermeture

Fermer complètement l'application, la rouvrir.

✅ L'accueil s'affiche directement, sans repasser par la connexion.

### 2.4 **La session survit à l'absence de réseau**

C'est la vérification la plus importante de la Phase 1, parce qu'elle
correspond au régime normal d'usage sur le terrain (CDC §6).

1. Se connecter une fois, application ouverte.
2. Arrêter le backend (`Ctrl+C`), **et** mettre le téléphone en mode avion.
3. Fermer l'application, la rouvrir.

✅ L'accueil s'affiche avec le nom et le rôle, **sans aucun appel réseau**. Si
l'écran de connexion apparaît, c'est un défaut : l'application serait
inutilisable là où elle est le plus nécessaire.

### 2.5 Déconnexion

✅ Une confirmation est demandée, puis l'écran de connexion revient. Rouvrir
l'application ne rétablit pas la session.

## 3 — Build de l'APK

```bash
cd mobile
flutter build apk --release --split-per-abi
```

✅ Trois fichiers apparaissent dans `build/app/outputs/flutter-apk/`, d'environ
17 Mo (`armeabi-v7a`), 19 Mo (`arm64-v8a`) et 21 Mo (`x86_64`).

Pour un CSB, c'est la variante `armeabi-v7a` qui sert dans la plupart des cas.
Ne jamais distribuer `app-debug.apk` : il pèse 163 Mo.

⚠️ Ces APK sont signés avec la **clé de débogage** : ils servent aux tests, pas
à une distribution. La signature réelle est l'objet du ticket 4.3.

⚠️ `minSdk` vaut 24 : un appareil sous Android 5 ou 6 refusera l'installation.
À contrôler sur les téléphones réellement utilisés dans les CSB pilotes.

## 4 — Qualité du code

```bash
cd backend && npx tsc --noEmit && npm run lint
cd mobile && flutter analyze && flutter test
```

✅ Aucun problème signalé dans les quatre cas.

## Ce qui ne peut pas encore être testé

Ces fonctions ne sont pas développées ; leur absence n'est pas un défaut.

| Fonction | Ticket |
|---|---|
| Créer et rechercher un dossier, QR code | 2.1 |
| Consultations, vaccination, PF, CPN | 2.4 à 2.7 |
| Tableau de bord du CSB | 2.8 |
| Synchronisation hors ligne | 3.1 |
| Chiffrement de la base locale | 3.3 |

## Que faire si un test échoue

Noter le numéro du test, ce qui était attendu, ce qui s'est produit, et le
message exact s'il y en a un. **Ne jamais joindre de capture contenant des
données réelles de patient** — il ne devrait pas y en avoir à ce stade, la
base n'étant pas encore chiffrée.
