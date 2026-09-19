# Maternal AI — Digitalisation des CSB
## Analyse du cahier des charges, prompt pour Claude Code et backlog de tickets

---

## 1. Analyse du cahier des charges

### 1.1 Ce que le document dit bien
- Le **périmètre du MVP est clair et volontairement restreint** : dossiers, consultations, vaccination, PF, dashboard CSB. Tout le reste (IA, dispositifs connectés, logistique) est explicitement repoussé (section 10). C'est une bonne base pour découper en tickets sans scope creep.
- La **priorité "simplicité d'usage" avant "nombre de fonctionnalités"** est répétée à plusieurs endroits (sections 2, 3, 7) — c'est un critère de conception à rappeler à Claude Code pour éviter qu'il sur-ingénierie l'UI.
- Le **mode hors ligne** est un vrai prérequis technique (section 6), pas une option : il structure fortement le choix d'architecture (stockage local, file de synchronisation, gestion des conflits).
- La **hiérarchie des droits d'accès** (CSB → zone → district → région → national, section 5) implique un modèle de rôles et d'agrégation dès la conception de la base de données, même si le MVP ne couvre que le niveau CSB.

### 1.2 Zones à clarifier avant de coder (à poser à l'équipe Maternal AI, pas à deviner)
Le cahier des charges est fonctionnel, pas technique : plusieurs décisions structurantes ne sont pas prises. Il vaut mieux les trancher maintenant plutôt que de laisser Claude Code les improviser :

1. **Stack technique cible** — le document ne dit pas Flutter, React Native, Kotlin natif, etc. Vous demandez "l'APK", donc Android est confirmé, mais le choix du framework doit être fixé avant le premier ticket (impact direct sur le offline-first et la synchro).
2. **Backend** — self-hosted ? Firebase/Supabase ? Un backend REST maison ? Le cahier des charges suppose un serveur central pour l'agrégation (section 5) mais ne le spécifie pas.
3. **Format d'échange / synchronisation** — quelle stratégie de résolution de conflits quand deux agents modifient le même dossier hors ligne ?
4. **Identifiant unique du bénéficiaire** — généré comment (UUID local, séquence serveur, format lisible par un agent de santé) ? Le QR code encode quoi exactement ?
5. **Référentiel réglementaire santé à Madagascar** — la section 8 mentionne des "exigences réglementaires" à étudier ; c'est un prérequis juridique, pas seulement technique, à traiter en parallèle du dev.
6. **Profils utilisateurs exacts et matrice de droits** — la section 3 cite sage-femme, infirmier, responsable CSB, agent communautaire, mais ne détaille pas qui a le droit de faire quoi (lecture seule ? création ? suppression ?).

→ Je les ai transformés en **tickets "Cadrage" à traiter avant le ticket 1 de code** (voir section 3), plutôt que de laisser Claude Code prendre ces décisions à votre place.

### 1.3 Architecture proposée (à valider, sert de base au prompt et aux tickets)
- **App mobile** : Flutter (un seul codebase Android/iOS, bon support offline-first via `drift`/`sqflite`, écosystème mature pour QR code et sync).
- **Stockage local** : base SQLite embarquée (via Drift) comme source de vérité locale, avec file de mutations à synchroniser.
- **Backend** : API REST (Node.js/NestJS ou Django) + base PostgreSQL, qui sert aussi de point d'agrégation multi-CSB.
- **Auth** : JWT avec rôles (agent CSB, responsable CSB, niveau district/région, admin national), stockage sécurisé du token sur l'appareil.
- **Sync** : synchronisation incrémentale par `updated_at`/`version`, horodatage local, résolution de conflit "dernier écrit gagne" en MVP avec journal d'audit (section 8) pour trace.

Si votre équipe a déjà tranché pour une autre stack (React Native, backend Firebase, etc.), il suffit d'adapter le prompt en section 2 — la structure des tickets reste valable.

---

## 2. Prompt à donner à Claude Code

Copiez-collez ce prompt tel quel comme premier message à Claude Code (ou adaptez les crochets `[...]` une fois les points de cadrage de la section 1.2 tranchés) :

```
Tu es Claude Code, chargé de développer le MVP mobile Android (APK) du projet
"Maternal AI — Digitalisation des CSB", une application de gestion de dossiers
patients pour les Centres de Santé de Base à Madagascar.

CONTEXTE MÉTIER
Les CSB utilisent encore des registres papier. L'app doit permettre aux
sages-femmes, infirmiers, responsables de CSB et agents communautaires de
créer et retrouver des dossiers patients, enregistrer des consultations,
vaccinations et activités de planification familiale, et consulter un
tableau de bord d'indicateurs — avec un fonctionnement fiable en connexion
faible ou hors ligne, et une synchronisation différée.

PRIORITÉ ABSOLUE : simplicité d'usage pour des utilisateurs non-experts en
informatique, avant le nombre de fonctionnalités. Formulaires courts,
information visible immédiatement, un minimum d'étapes pour chaque tâche
courante (retrouver un dossier, créer un dossier, enregistrer une
consultation).

STACK IMPOSÉE
- App mobile : Flutter (cible Android en priorité, build APK)
- Stockage local offline-first : Drift (SQLite) comme source de vérité locale
- Backend : API REST [NestJS+PostgreSQL / à confirmer] avec authentification
  JWT et gestion de rôles (agent CSB, responsable CSB, niveaux
  district/région, admin national)
- Synchronisation : file de mutations locale, sync incrémentale par
  horodatage/version dès que la connexion est disponible, journal d'audit
  de qui a créé/modifié quoi (exigence de traçabilité, cf. section 8 du
  cahier des charges)

PÉRIMÈTRE DU MVP (rien de plus, rien de moins pour l'instant) :
1. Gestion des dossiers individuels (création, recherche, historique, QR code)
2. Enregistrement de consultations liées à un dossier
3. Enregistrement des vaccinations + indicateurs simples par période
4. Enregistrement des activités de planification familiale
5. Tableau de bord CSB (consultations prénatales, vaccinations, PF,
   activité globale), filtrable par semaine/mois/année
6. Authentification sécurisée + droits d'accès par profil utilisateur
7. Fonctionnement hors ligne avec synchronisation différée

EXPLICITEMENT HORS PÉRIPHÈTRE DU MVP (ne pas développer, ne pas
sur-architecturer en prévision) : dispositifs médicaux connectés, IA/analyse
prédictive, gestion complète de la chaîne logistique des intrants,
intégrations externes complexes, agrégation multi-CSB au-delà du niveau CSB
lui-même. Le code doit rester simple et ne pas anticiper ces couches, sauf
si une décision d'architecture aujourd'hui les rend beaucoup plus coûteuses
à ajouter plus tard (dans ce cas, signale-le au lieu de développer la
fonctionnalité).

FAÇON DE TRAVAILLER
- Je vais te fournir un backlog de tickets, un par un, avec pour chacun un
  objectif, un périmètre précis et une liste de livrables attendus.
- Ne commence pas un ticket avant que je te l'aie donné explicitement.
- Pour chaque ticket, avant de coder : reformule en 3-4 lignes ce que tu vas
  faire et signale toute ambiguïté ou hypothèse que tu comptes prendre.
- À la fin de chaque ticket : liste les fichiers créés/modifiés, comment
  tester manuellement la fonctionnalité, et les éventuelles limites connues
  ou dettes techniques introduites.
- Les données traitées sont des données de santé sensibles : ne jamais les
  logger en clair, ne jamais les committer dans des fixtures de test
  réalistes, chiffrer le stockage local des champs sensibles si la
  bibliothèque Drift le permet simplement.

Confirme que tu as bien compris le contexte et la façon de travailler, puis
attends le premier ticket.
```

---

## 3. Backlog de tickets

Organisé en 4 phases. Chaque ticket est pensé pour être donné indépendamment à Claude Code avec un livrable vérifiable, dans l'esprit "un ticket = une chose testable".

### Phase 0 — Cadrage (à trancher avec l'équipe Maternal AI, pas par Claude Code)

**Ticket 0.1 — Décisions techniques structurantes**
- À faire : valider stack (Flutter confirmé ?), choix du backend, hébergement, format de l'identifiant unique et du QR code, stratégie de résolution de conflits de sync.
- Livrable : un document d'1 page de décisions figées, à coller en tête du prompt Claude Code avant de lancer la Phase 1.

**Ticket 0.2 — Matrice des droits par profil**
- À faire : lister, pour chaque profil (sage-femme, infirmier, responsable CSB, agent communautaire), les actions autorisées (créer dossier, consulter dossier, modifier, enregistrer consultation/vaccination/PF, voir dashboard, exporter).
- Livrable : tableau profil × action × autorisé/non, servira directement de spec au ticket 2.2.

**Ticket 0.3 — Cadre réglementaire données de santé**
- À faire : point avec un juriste ou référent conformité sur les règles applicables aux données de santé à Madagascar (conservation, consentement, export).
- Livrable : note de contraintes à respecter, à injecter dans les tickets de sécurité (Phase 3).

### Phase 1 — Socle technique

**Ticket 1.1 — Initialisation du projet Flutter**
- Objectif : squelette d'app buildable en APK, structure de dossiers claire (data/domain/presentation ou équivalent), CI locale minimale (lint + build).
- Livrable : projet Flutter qui compile en APK debug, README expliquant comment builder et lancer.

**Ticket 1.2 — Schéma de base de données locale (Drift/SQLite)**
- Objectif : modéliser les tables locales (bénéficiaires, consultations, vaccinations, PF, utilisateurs, file de sync) à partir des entités du cahier des charges.
- Livrable : schéma Drift versionné avec migrations, diagramme du modèle de données en commentaire ou fichier séparé.

**Ticket 1.3 — API backend : squelette + authentification**
- Objectif : endpoints REST de login/refresh token, gestion des rôles définis au ticket 0.2, modèle de données serveur miroir du modèle local.
- Livrable : backend qui démarre, endpoint `/auth/login` fonctionnel testé via un client HTTP (Postman/curl documenté dans le README).

**Ticket 1.4 — Écran de connexion + gestion de session mobile**
- Objectif : écran de login simple, stockage sécurisé du token, redirection selon le profil connecté.
- Livrable : APK où un utilisateur peut se connecter, rester connecté après fermeture de l'app, se déconnecter.

### Phase 2 — Fonctionnalités métier du MVP

**Ticket 2.1 — Création et recherche de dossier bénéficiaire**
- Objectif : formulaire de création de dossier (identité, infos de base), génération d'un identifiant unique + QR code associé, recherche par nom/identifiant/scan QR.
- Livrable : APK permettant de créer un dossier hors ligne, de le retrouver par recherche texte et par scan QR, dossier visible dans la base locale.

**Ticket 2.2 — Droits d'accès aux dossiers selon le profil**
- Objectif : appliquer la matrice du ticket 0.2 — restreindre les actions visibles/possibles selon le profil connecté.
- Livrable : démonstration (captures ou test manuel documenté) qu'un profil sans droit de création ne voit pas le bouton correspondant, et qu'un appel API sans droit est rejeté côté backend (pas seulement caché côté UI).

**Ticket 2.3 — Historique et fiche dossier**
- Objectif : vue dossier affichant l'historique chronologique (consultations, vaccinations, PF) de façon lisible pour un usage rapide sur le terrain.
- Livrable : écran fiche dossier avec historique trié par date, temps de chargement acceptable même avec un historique long (test avec ~100 entrées factices).

**Ticket 2.4 — Consultation générale**
- Objectif : formulaire d'enregistrement d'une consultation depuis un dossier, avec champs structurés (pas de texte libre pour les données réutilisables en stats).
- Livrable : APK permettant d'enregistrer une consultation offline, visible immédiatement dans l'historique du dossier (ticket 2.3).

**Ticket 2.5 — Suivi grossesse / santé maternelle**
- Objectif : extension du dossier pour une femme enceinte (consultations prénatales, évolution de grossesse, examens, facteurs de risque, références, suivi postnatal), telle que décrite section 4.
- Livrable : sous-formulaire dédié accessible depuis un dossier marqué "grossesse", données visibles dans l'historique et exploitables pour le dashboard prénatal.

**Ticket 2.6 — Vaccination**
- Objectif : enregistrement d'une vaccination (type, date, bénéficiaire), calcul simple d'indicateurs (nombre de vaccinations par type/période).
- Livrable : APK permettant d'enregistrer une vaccination offline et de voir un compteur d'indicateurs vaccination sur une période donnée.

**Ticket 2.7 — Planification familiale**
- Objectif : enregistrement d'une activité de PF (méthode utilisée/distribuée, date, bénéficiaire).
- Livrable : APK permettant d'enregistrer une activité PF offline, visible dans l'historique et comptabilisée pour le dashboard.

**Ticket 2.8 — Tableau de bord CSB**
- Objectif : écran de synthèse pour le responsable CSB — consultations prénatales, vaccinations, PF, activité globale — filtrable par semaine/mois/année.
- Livrable : APK affichant le dashboard avec des chiffres corrects sur un jeu de données de test, filtre de période fonctionnel.

### Phase 3 — Offline, sécurité, robustesse

**Ticket 3.1 — File de synchronisation et logique offline-first**
- Objectif : toute écriture (dossier, consultation, vaccination, PF) passe par la base locale d'abord, avec une file de mutations à envoyer au backend dès que la connexion revient.
- Livrable : démonstration en mode avion — créer un dossier + une consultation offline, repasser en ligne, vérifier que les données apparaissent côté backend sans perte ni doublon.

**Ticket 3.2 — Gestion des conflits de synchronisation**
- Objectif : implémenter la stratégie choisie au ticket 0.1 (ex. dernier écrit gagne + horodatage) et journaliser les conflits résolus.
- Livrable : test reproductible avec deux modifications concurrentes du même dossier sur deux appareils, résultat final prévisible et tracé dans le journal d'audit.

**Ticket 3.3 — Chiffrement et sécurité du stockage local**
- Objectif : chiffrer les champs sensibles en base locale, sécuriser le stockage du token, ne jamais logger de données patient en clair.
- Livrable : revue de code documentée confirmant l'absence de logs sensibles et le chiffrement effectif (test : extraire le fichier SQLite brut et vérifier qu'un champ sensible n'est pas lisible en clair).

**Ticket 3.4 — Journal d'audit des opérations**
- Objectif : tracer qui a créé/modifié quelle information et quand (exigence section 8).
- Livrable : table d'audit consultable (au moins côté backend), démonstration qu'une modification de dossier génère bien une entrée d'audit.

### Phase 4 — Finition et validation terrain

**Ticket 4.1 — Revue UX / réduction des étapes**
- Objectif : passer en revue les parcours "retrouver un dossier", "créer un dossier", "enregistrer une consultation" pour minimiser le nombre d'étapes et de champs obligatoires, conformément à la priorité "simplicité" du cahier des charges.
- Livrable : rapport avant/après (nombre de taps, nombre de champs) sur les 3 parcours clés, ajustements appliqués dans le code.

**Ticket 4.2 — Jeu de données de démonstration et guide de test terrain**
- Objectif : préparer un jeu de données factices réaliste et un guide pas-à-pas pour la phase de test avec de vrais utilisateurs CSB (section 7).
- Livrable : script de seed de données de démo, document d'1-2 pages pour un testeur non technique expliquant quoi tester et comment remonter un problème.

**Ticket 4.3 — Build APK de release et checklist de validation**
- Objectif : build APK signé prêt pour un CSB pilote, checklist reprenant les critères de validation de la section 12 du cahier des charges.
- Livrable : APK release + checklist cochée (création/recherche de dossier, consultation, historique, indicateurs CSB) sur un appareil de test réel.

---

*Document généré à partir du cahier des charges fonctionnel "Digitalisation des CSB" (Maternal AI, version Pré-MVP). Les tickets de la Phase 0 doivent être tranchés avant de lancer la Phase 1 avec Claude Code.*
