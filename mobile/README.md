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
flutter build apk --release --dart-define=API_BASE_URL=https://api.exemple.org/api/v1
```

Le fichier atterrit dans `build/app/outputs/flutter-apk/`.

## Organisation

```
lib/
├── main.dart              amorçage
├── app.dart               thème, langue, aiguillage connexion/accueil
├── core/
│   ├── config/            paramètres passés au build
│   ├── errors/            exceptions présentables à l'utilisateur
│   ├── theme/             couleurs, dimensions, thème
│   └── utils/             dates ISO
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

**Phase 1 livrée** — socle technique : base locale, API d'authentification,
connexion et session persistante.

Limites connues à ce stade :

- **Pas de chiffrement de la base locale** (ticket 3.3). Aucune donnée réelle de
  patient ne doit être saisie avant sa livraison.
- **Pas de synchronisation** (ticket 3.1) : la file existe en base, rien ne la
  vide encore.
- **Aucun écran métier** : dossiers, consultations, vaccination, PF et tableau
  de bord arrivent en Phase 2.
- Pas de routeur : deux écrans suffisent pour l'instant, il sera introduit au
  ticket 2.1.
- Thème sombre défini mais désactivé, en attente des retours terrain.
