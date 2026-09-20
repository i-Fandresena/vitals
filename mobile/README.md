# Application mobile Vitals

Application Flutter du projet [Vitals](../README.md), destinée aux personnels
des Centres de Santé de Base. Cible Android, livrable APK.

## Démarrage

```bash
flutter pub get
dart run build_runner build      # code généré par Drift — indispensable
flutter run
```

Le code généré (`*.g.dart`) n'est pas versionné : un dépôt fraîchement cloné ne
compile pas tant que `build_runner` n'a pas tourné.

### Se connecter à l'API

Par défaut l'application vise `http://10.0.2.2:3000/api/v1`, c'est-à-dire la
machine hôte vue depuis l'émulateur Android. Pour un appareil réel :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api/v1
```

Comptes de développement : voir [backend/README.md](../backend/README.md).

### Builder l'APK

```bash
flutter build apk --debug

flutter build apk --release --split-per-abi \
  --dart-define=API_BASE_URL=https://api.exemple.org/api/v1
```

Les fichiers atterrissent dans `build/app/outputs/flutter-apk/`.

**Toujours utiliser `--split-per-abi` pour distribuer.** Un APK universel
embarque les bibliothèques natives des trois architectures ; découpé, chaque
appareil ne télécharge que la sienne. Tailles mesurées sur la Phase 1 :

| Variante | Taille | Pour |
|---|---|---|
| `app-armeabi-v7a-release.apk` | 17,0 Mo | appareils 32 bits, les plus courants en CSB |
| `app-arm64-v8a-release.apk` | 19,4 Mo | appareils 64 bits récents |
| `app-x86_64-release.apk` | 20,8 Mo | émulateurs — inutile sur le terrain |
| `app-debug.apk` | 163 Mo | développement seulement, ne jamais distribuer |

L'écart entre 17 Mo et 163 Mo n'est pas un détail : l'APK se transfère souvent
par clé USB ou par partage direct entre téléphones, sur des connexions où
163 Mo sont hors de portée.

## Organisation

```
lib/
├── main.dart              amorçage
├── app.dart               thème, langue, aiguillage connexion/accueil
├── core/
│   ├── config/            paramètres passés au build
│   ├── errors/            exceptions présentables à l'utilisateur
│   ├── routing/           routes et aiguillage selon la session
│   ├── theme/             couleurs, dimensions, thème
│   └── utils/             dates ISO, identifiants et QR code
├── domain/
│   ├── entities/          objets métier
│   └── enums/             rôles et nomenclatures cliniques
├── data/
│   ├── local/             base Drift — source de vérité
│   ├── remote/            client HTTP
│   ├── repositories/      orchestration local ↔ distant
│   └── secure/            jetons dans le coffre du système
└── presentation/
    ├── auth/              connexion
    ├── beneficiaries/     recherche, création, fiche, scan
    ├── home/              accueil
    └── providers.dart     injection de dépendances (Riverpod)
```

## Partis pris

**La base locale est la source de vérité, pas le serveur.** Toute écriture y va
d'abord ; le serveur est une destination, pas une dépendance. L'application
s'ouvre et fonctionne sans réseau, y compris avec un jeton expiré : seule la
synchronisation attend (CDC §6).

**Les dates d'acte sont du texte ISO, pas des horodatages.** Voir
[`core/utils/iso_date.dart`](lib/core/utils/iso_date.dart) — un horodatage
« minuit local » converti en UTC recule d'un jour à Madagascar et fausserait
silencieusement les indicateurs mensuels.

**Les événements de soin sont immuables.** Une consultation ou une vaccination
se crée, ne se modifie jamais. Une correction annule et recrée. Conséquence
utile : ces données ne peuvent pas entrer en conflit lors de la synchronisation.

**Le QR code n'encode que l'UUID du dossier.** Voir
[`core/utils/local_id.dart`](lib/core/utils/local_id.dart) — ni nom, ni date de
naissance, ni donnée de santé. Une carte collée sur un carnet et perdue ne
révèle rien ; elle n'est exploitable que depuis l'application, par quelqu'un
d'authentifié.

**L'interface vise la lisibilité en plein soleil, pas l'élégance.** Contrastes
au-delà des minimums d'accessibilité, cibles tactiles de 56 à 60 dp, corps de
texte à 16, aucune surface translucide. Le CDC §7 demande une interface « très
simple, sobre et fonctionnelle » ; les conditions d'usage l'imposent autant que
le cahier des charges.

## Commandes

```bash
flutter analyze                          # lint, doit rester à zéro problème
flutter test
dart run build_runner build              # après toute modification des tables
dart run build_runner watch              # pendant le développement
flutter build apk --debug
```

## État

**Phase 1 livrée** — socle technique : base locale, authentification, session.
**Ticket 2.1 livré** — création et recherche de dossiers, identifiant lisible,
QR code et scan.

Limites connues à ce stade :

- **Pas de chiffrement de la base locale** (ticket 3.3). Aucune donnée réelle de
  patient ne doit être saisie avant sa livraison.
- **Pas de synchronisation** (ticket 3.1) : la file se remplit à chaque création,
  mais rien ne la vide encore. Les dossiers restent sur l'appareil.
- **Aucun droit différencié** (ticket 2.2) : tout profil connecté peut créer et
  consulter les dossiers de son centre.
- **La fiche dossier ne montre pas d'historique de soin** (ticket 2.3) — il n'y
  a encore rien à y montrer.
- Un dossier ne peut pas être modifié ni archivé depuis l'application.
- Thème sombre défini mais désactivé, en attente des retours terrain.
