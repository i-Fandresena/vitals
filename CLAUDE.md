# Vitals — Digitalisation des CSB (Maternal AI)

Application de gestion de dossiers patients pour les Centres de Santé de Base à
Madagascar. Dépôt : `i-Fandresena/vitals`.

## Documents de référence — à lire avant de coder

| Document | Contenu |
|---|---|
| [docs/Cahier-des-charges-fonctionnel.md](docs/Cahier-des-charges-fonctionnel.md) | Périmètre fonctionnel, source de vérité |
| [docs/Maternal-AI-CSB-Analyse-et-Backlog.md](docs/Maternal-AI-CSB-Analyse-et-Backlog.md) | Backlog de tickets, phases 0 à 4 |
| [docs/00-decisions-techniques.md](docs/00-decisions-techniques.md) | Décisions figées : stack, identifiants, QR, sync |
| [docs/01-matrice-droits.md](docs/01-matrice-droits.md) | Qui a le droit de faire quoi |
| [docs/02-modele-donnees.md](docs/02-modele-donnees.md) | Modèle de données et principes de synchronisation |
| [docs/03-verification-phase-1.md](docs/03-verification-phase-1.md) | Procédure de vérification manuelle |

## Stack

- **Mobile** : Flutter 3.47.5 / Dart 3.13.4, cible Android (APK), `minSdk 24`
- **Base locale** : Drift (SQLite) + SQLCipher — source de vérité locale
- **Backend** : NestJS + PostgreSQL + Prisma
- **Auth** : JWT (access 15 min + refresh 30 j), `flutter_secure_storage`

Structure : `mobile/` (Flutter), `backend/` (NestJS), `docs/` (spécifications).

## Façon de travailler (imposée par le backlog §2)

- Un ticket à la fois, pas de ticket entamé sans qu'il soit donné explicitement.
- Avant de coder : reformuler en 3-4 lignes, signaler les hypothèses prises.
- À la fin d'un ticket : fichiers créés/modifiés, comment tester manuellement,
  limites connues et dettes techniques introduites.
- Ne pas sur-architecturer en prévision du hors-périmètre (CDC §10). Si une
  décision d'aujourd'hui rend une évolution future beaucoup plus coûteuse, le
  signaler au lieu de développer la fonctionnalité.

## Données de santé sensibles

- Ne jamais logger de donnée patient en clair.
- Ne jamais committer de fixture réaliste : les jeux de test sont générés
  (ticket 4.2), jamais tirés de vraies données.
- Aucune donnée personnelle dans les QR codes — ils n'encodent que l'UUID.
- Toute écriture est journalisée avec son auteur (CDC §8).

## Règles d'interface

Le CDC §7 demande une interface « très simple, sobre et fonctionnelle », pensée
selon les tâches réelles du personnel de santé. **La sobriété prime sur l'effet
visuel.** Une animation, un dégradé ou une illustration qui ajoute une étape, une
attente ou une ambiguïté est un défaut, pas une amélioration.

Contraintes concrètes : appareils anciens et lents, connexion faible ou absente,
usage debout et à une main, parfois en plein soleil. Donc contrastes élevés,
cibles tactiles larges, texte lisible sans zoom, pas d'asset lourd, interface en
français.

## Skills

Les skills de design installés sur ce compte sont presque tous orientés web
(React/Tailwind/shadcn) et **ne s'appliquent pas à Flutter**. À ne pas invoquer
pour `mobile/` : `shadcn`, `ui-styling`, `animate`, `animate-expo`, `impeccable`,
`prototype`, `write-swift`.

Restent utiles :

| Besoin | Skill |
|---|---|
| Principes UX, palettes, typographie, hiérarchie d'information, choix de graphiques pour le tableau de bord | `ui-ux-pro-max` |
| Principes de mouvement et de retour d'action, à transposer en Flutter | `emil-design-eng`, `apple-design` |
| Design tokens (couleurs, espacements) à traduire en `ThemeData` | `design-system` |
| Graphiques du tableau de bord (ticket 2.8) | `dataviz` |
| Vidéos de démonstration et de formation des agents (ticket 4.2) | `remotion-best-practices` |

Si une réflexion d'interface web devient utile plus tard (portail d'agrégation
multi-CSB du CDC §5, hors MVP), les skills web redeviendront pertinents.
