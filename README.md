# Vitals

Digitalisation des Centres de Santé de Base — **Maternal AI**, Madagascar.

Les CSB enregistrent encore consultations, vaccinations, suivi de grossesse et
planification familiale sur des registres papier. Vitals permet au personnel de
santé de tenir ces dossiers sur un téléphone Android, **y compris sans réseau**,
et de retrouver les indicateurs de son centre sans dépendre du papier.

> **Statut : Pré-MVP, en cours de développement.** Aucun déploiement en centre
> réel à ce stade.

## Périmètre du MVP

1. Dossiers individuels — création, recherche, historique, identifiant unique + QR code
2. Consultations générales
3. Suivi de grossesse — CPN, examens, facteurs de risque, références, postnatal
4. Vaccination et indicateurs par période
5. Planification familiale
6. Tableau de bord du CSB, filtrable par semaine / mois / année
7. Authentification et droits d'accès par profil
8. Fonctionnement hors ligne avec synchronisation différée

Hors périmètre, volontairement : dispositifs connectés, IA et analyse prédictive,
gestion de stocks, intégrations externes, agrégation au-delà du CSB.

## Structure

```
vitals/
├── mobile/     Application Flutter (Android, APK)
├── backend/    API NestJS + PostgreSQL
└── docs/       Cahier des charges, backlog, décisions techniques
```

## Documentation

| Document | Contenu |
|---|---|
| [Cahier des charges fonctionnel](docs/Cahier-des-charges-fonctionnel.md) | Périmètre et exigences, source de vérité |
| [Analyse et backlog](docs/Maternal-AI-CSB-Analyse-et-Backlog.md) | Tickets, phases 0 à 4 |
| [Décisions techniques](docs/00-decisions-techniques.md) | Stack, identifiants, QR code, stratégie de synchronisation |
| [Matrice des droits](docs/01-matrice-droits.md) | Permissions par profil utilisateur |
| [Modèle de données](docs/02-modele-donnees.md) | Tables, principes, pourquoi les événements de soin sont immuables |
| [Vérification de la Phase 1](docs/03-verification-phase-1.md) | Comment constater soi-même que le socle fonctionne |

## Prérequis

- **Flutter** 3.47.5 ou plus récent (`flutter --version`)
- **JDK 21** et le SDK Android, pour builder l'APK
- **Node.js** 20+ et **PostgreSQL** 16+, pour le backend

## Démarrage

### Application mobile

```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # code généré (Drift)
flutter run                                                # sur un appareil connecté
```

Builder l'APK :

```bash
flutter build apk --debug      # test
flutter build apk --release    # distribution
```

L'APK est produit dans `mobile/build/app/outputs/flutter-apk/`.

### Backend

```bash
cd backend
npm install
cp .env.example .env           # renseigner DATABASE_URL et JWT_SECRET
npx prisma migrate dev
npm run start:dev              # http://localhost:3000
```

## Données de santé

Ce projet traite des données de santé sensibles. Trois règles non négociables :

- **Aucune donnée réelle dans le dépôt** — pas de fixture, pas de capture, pas de
  base de test issue d'un centre. Les jeux de démonstration sont générés.
- **Aucun secret commité** — `.env`, clés de signature et keystores sont ignorés.
- **Aucune donnée patient dans les logs**, y compris en développement.

Le cadre réglementaire applicable à Madagascar reste à faire valider par un
juriste avant tout déploiement (ticket 0.3).

## Licence

Propriété de Maternal AI. Tous droits réservés.
