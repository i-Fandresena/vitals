# Vérification manuelle

Comment constater par soi-même que ce qui est livré fonctionne. Compter
environ 30 minutes pour l'ensemble. Aucune donnée réelle de patient ne doit être utilisée : le
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

## 5 — Dossiers bénéficiaires (ticket 2.1)

### 5.1 Créer un dossier hors ligne

Mettre le téléphone **en mode avion**, puis : accueil → « Nouveau dossier ».

Saisir un nom, un prénom, un sexe, une date de naissance.

✅ Le dossier s'ouvre immédiatement, avec un identifiant `CSB-<code>-<AA>-00001`
et un QR code. Aucune erreur réseau : la création ne dépend pas du serveur.

### 5.2 L'identifiant progresse

Créer un deuxième dossier, toujours hors ligne.

✅ Il reçoit `…-00002`. Deux dossiers ne partagent jamais le même numéro.

### 5.3 Âge estimé

Créer un dossier en choisissant « Âge estimé » et en saisissant `45`.

✅ La fiche affiche `~45 ans`. Le tilde signale une approximation, pour qu'elle
ne soit jamais lue comme une date fiable.

### 5.4 L'âge d'un nourrisson se lit en mois

Créer un dossier avec une date de naissance d'il y a environ six mois.

✅ La fiche affiche « 6 mois », pas « 0 ans ». C'est ce qui rend le calendrier
vaccinal exploitable.

### 5.5 Recherche par nom

Accueil → « Rechercher une personne », taper les premières lettres d'un nom.

✅ La liste se met à jour pendant la frappe. Un fragment au milieu du nom
fonctionne aussi — les noms sont longs et souvent recopiés de mémoire.

### 5.6 Recherche par identifiant

Taper l'identifiant complet, en minuscules et avec des espaces au lieu des
tirets : `csb 0142 26 00001`.

✅ Le dossier correspondant est trouvé.

### 5.7 Scan du QR code

Ouvrir un dossier sur un premier appareil (ou l'imprimer), puis accueil →
« Scanner une carte » et viser le code.

✅ Le dossier s'ouvre directement.

### 5.8 **Un QR code étranger est refusé proprement**

Scanner n'importe quel autre QR code — un produit, une affiche, un lien.

✅ Un message explique que le code ne correspond à aucun dossier. L'application
n'ouvre rien et ne plante pas.

### 5.9 Le QR code ne contient aucune donnée personnelle

Lire le QR code d'un dossier avec **n'importe quelle autre application** de
scan, sur le téléphone.

✅ Le contenu lu est exactement `vitals:b/<uuid>` : pas de nom, pas de date de
naissance, pas d'information de santé. C'est ce qui permet de coller le code
sur un carnet remis à la personne sans risque en cas de perte.

### 5.10 La recherche est cloisonnée au centre

Si deux comptes de CSB différents sont disponibles : créer un dossier avec le
premier, se déconnecter, se connecter avec le second, chercher ce dossier.

✅ Il n'apparaît pas, et son QR code ne l'ouvre pas non plus.

## 6 — Droits par profil (ticket 2.2)

Le seed crée un compte par profil, tous avec le mot de passe
`Vitals-dev-2026` : `agent`, `infirmier`, `sagefemme`, `responsable`, `admin`.

### 6.1 L'agent communautaire ne voit pas le contenu médical

Se connecter avec `agent`, ouvrir un dossier existant.

✅ L'identité s'affiche — nom, âge, identifiant, fokontany — mais **ni
téléphone, ni contenu de soin**. Un encart explique pourquoi.

C'est la ligne que ce profil ne franchit pas : il oriente vers le CSB, il ne
soigne pas. C'est aussi le profil le plus exposé, sur un appareil partagé hors
du centre.

### 6.2 L'administration nationale n'accède à aucun dossier

Se connecter avec `admin`.

✅ Aucun accès aux dossiers : un écran explique que ce profil ne consulte que
des indicateurs agrégés (CDC §5). Ni recherche, ni création, ni scan.

### 6.3 **Le refus vient du serveur, pas seulement de l'interface**

C'est la vérification décisive du ticket. Masquer un bouton ne protège rien.

Récupérer un jeton d'agent communautaire :

```bash
curl -X POST http://localhost:3000/api/v1/auth/login -H "Content-Type: application/json" -d '{"username":"agent","password":"Vitals-dev-2026","deviceId":"test-0001"}'
```

Copier la valeur de `accessToken`, puis appeler l'API directement — sans passer
par l'application, donc sans qu'aucun bouton ne soit masqué :

```bash
curl -i http://localhost:3000/api/v1/beneficiaries -H "Authorization: Bearer <accessToken>"
```

✅ `200` — l'agent communautaire peut lister l'identité des dossiers.

Avec le compte `admin`, la même requête :

✅ `403 Action non autorisée pour votre profil`.

### 6.4 Le message ne révèle pas quel profil aurait le droit

✅ La réponse `403` dit seulement « Action non autorisée pour votre profil ».
Indiquer la permission manquante renseignerait un attaquant sur la structure
des droits.

### 6.5 Les deux modèles de droits concordent

```bash
cd backend && npx jest        # 30 tests
cd mobile  && flutter test    # 54 tests
```

✅ Les deux suites vérifient la même matrice. Une divergence entre
l'application et le serveur produirait soit un bouton qui échoue devant le
patient, soit une action refusée sans explication.

## 7 — Icône de l'application

Installer l'APK sur un téléphone.

✅ L'icône est le symbole Vitals — dossier, croix et tracé cardiaque — sur fond
blanc, avec le nom « Vitals » dessous.

Le mot « Vitals » du logo d'origine n'est volontairement pas repris dans
l'icône : à 48 dp il serait illisible, et Android affiche déjà le nom de
l'application juste en dessous.

✅ Le symbole n'est rogné sur aucun lanceur — Android applique son propre
masque (cercle, carré arrondi, goutte) et ne garantit que les 66 % centraux.

## 8 — Synchronisation (ticket 3.1)

C'est la vérification la plus importante du projet : elle décide si les
données saisies en brousse arrivent au serveur sans perte ni doublon.

### 8.1 Un appareil neuf reçoit ce qu'il ne connaît pas

Installer l'APK, se connecter avec un compte du centre.

✅ La recherche montre les dossiers du centre, y compris ceux créés par
d'autres. Un bandeau annonce brièvement la synchronisation, puis disparaît.

### 8.2 **Créer hors ligne, retrouver en ligne**

C'est le livrable du ticket.

1. Mettre le téléphone **en mode avion**.
2. Créer un dossier — nom reconnaissable, par exemple « ESSAI Terrain ».
3. ✅ Le dossier s'ouvre immédiatement, avec son identifiant et son QR code.
4. ✅ Un bandeau bleu annonce « Hors ligne — 1 enregistrement en attente.
   Rien n'est perdu. » Il n'est **pas rouge** : travailler sans réseau est le
   régime normal, pas une panne.
5. Fermer et rouvrir l'application, toujours en mode avion.
   ✅ Le dossier est toujours là. Le bandeau aussi.
6. Rétablir le réseau.
   ✅ Le bandeau passe en « Synchronisation… » tout seul, puis disparaît.
7. Ouvrir https://vitals.aura-plus.site → Indicateurs.
   ✅ Le compteur « Nouveaux dossiers » a augmenté de 1.

### 8.3 Aucun doublon après une coupure

Refaire l'étape 8.2, mais couper le réseau **pendant** la synchronisation,
puis le rétablir.

✅ Le dossier apparaît **une seule fois** côté serveur. L'identifiant est
attribué par le téléphone, donc un renvoi écrit au même endroit au lieu de
créer une deuxième ligne.

### 8.4 Deux téléphones, le même centre

Créer un dossier sur un premier téléphone, synchroniser, puis synchroniser le
second.

✅ Le dossier apparaît sur le second téléphone.

### 8.5 Le cloisonnement tient aussi en synchronisation

Avec un compte d'un autre centre, synchroniser.

✅ Aucun dossier du premier centre n'arrive. Le serveur borne le
téléchargement au centre de l'utilisateur, ce n'est pas un filtre d'affichage.

### 8.6 La déconnexion remet le compteur à zéro

Se déconnecter, se reconnecter avec un **autre** compte du même centre.

✅ La synchronisation retélécharge tout depuis le début. Sans cela, le second
soignant hériterait du curseur du premier et manquerait tout ce qui a changé
avant son arrivée.

## 9 — Saisie des soins (tickets 2.3 à 2.6)

Ouvrir un dossier depuis la recherche, puis utiliser les actions de la fiche.

### 9.1 Une consultation se saisit hors ligne

Couper le réseau. Ouvrir un dossier, « Consultation », renseigner un motif et
une température, enregistrer.

✅ La consultation apparaît immédiatement dans l'historique de la fiche.
✅ Le compteur « en attente » de l'accueil augmente de 1.

### 9.2 Le carnet de vaccination montre le retard avant de saisir

Ouvrir « Vaccination » sur un enfant déjà vacciné.

✅ Les antigènes déjà administrés sont listés en haut, avec leurs doses.
✅ Choisir un antigène propose **la dose suivante**, pas la dose 1.
✅ Choisir une dose supérieure affiche un avertissement sur les doses
manquantes, sans empêcher la saisie — un rattrapage est légitime.

### 9.3 **Une même vaccination ne s'enregistre pas deux fois**

Enregistrer BCG dose 1 aujourd'hui. Recommencer à l'identique.

✅ Un message explique que cette dose est déjà enregistrée ce jour-là. Ce
n'est pas une erreur technique : c'est le doublon le plus probable en pratique,
deux soignants sur le même enfant.

### 9.4 Une CPN s'attache à la grossesse en cours

Ouvrir « Suivi de grossesse » sur une femme sans grossesse ouverte.

✅ Le formulaire propose d'abord d'ouvrir la grossesse (dernières règles,
gestité, parité), puis enchaîne sur la première CPN.
✅ Sur une femme déjà suivie, il enchaîne directement sur la CPN suivante,
numérotée.

### 9.5 L'historique mélange les familles dans l'ordre du temps

✅ Consultations, vaccinations, CPN et PF apparaissent dans une seule frise,
la plus récente en haut, chacune avec son libellé — pas quatre listes
séparées, qui obligeraient à comparer des dates de tête.

## 10 — Synchronisation des soins

### 10.1 Les actes saisis hors ligne partent au réseau retrouvé

Après le §9, rétablir le réseau et synchroniser depuis l'accueil.

✅ Le compteur « en attente » retombe à zéro.
✅ Aucun enregistrement « refusé ».
✅ Les actes apparaissent dans les indicateurs de l'espace admin, comptés à la
**date de l'acte** et non à celle de la synchronisation.

### 10.2 Un renvoi ne crée pas de doublon

Depuis un poste, avec un compte soignant :

```bash
# Rejouer deux fois la même mutation
curl -s -X POST https://api-vitals.aura-plus.site/api/v1/sync/push   -H "Authorization: Bearer $JETON" -H 'Content-Type: application/json'   -d '{"mutations":[{ … même charge utile … }]}'
```

✅ Premier envoi : `"statut":"accepte"`.
✅ Second envoi : `"statut":"ignore"`, motif « Déjà enregistré ». L'identifiant
venant de l'appareil, le renvoi retombe sur la même ligne.

### 10.3 Un code inconnu est refusé, pas ramené à une valeur par défaut

Envoyer une consultation dont le `type` n'existe pas.

✅ `"statut":"rejete"`. Écrire « AUTRE » à la place fausserait silencieusement
les indicateurs, ce qui est pire qu'un refus visible.

### 10.4 Un acte dont le dossier manque reste en file

✅ `"statut":"ignore"` avec le motif « Dossier pas encore reçu ». Ce n'est pas
un refus : l'appareil doit le garder et réessayer, sinon la saisie est perdue.

### 10.5 Une grossesse close se met bien à jour

Enregistrer l'issue d'une grossesse déjà synchronisée, puis synchroniser.

✅ L'issue est à jour côté serveur. Contrairement aux actes, une grossesse
n'est pas figée à sa création : elle est ouverte à la première CPN puis close
par l'accouchement.

## Ce qui ne peut pas encore être testé

Ces fonctions ne sont pas développées ; leur absence n'est pas un défaut.

| Fonction | Ticket |
|---|---|
| Planification familiale, saisie dans l'application | 2.7 |
| Tableau de bord du CSB dans l'application | 2.8 |
| Remontée DHIS2 | reporté |

## Que faire si un test échoue

Noter le numéro du test, ce qui était attendu, ce qui s'est produit, et le
message exact s'il y en a un. **Ne jamais joindre de capture contenant des
données réelles de patient**, même depuis un appareil dont la base est
chiffrée : une capture d'écran, elle, ne l'est pas.
