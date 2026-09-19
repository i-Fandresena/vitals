# Modèle de données — Ticket 1.2

Le modèle existe en deux exemplaires qui doivent rester alignés :

| Où | Fichier | Rôle |
|---|---|---|
| Appareil | `mobile/lib/data/local/tables/` (Drift) | **Source de vérité locale** — toute écriture y passe d'abord |
| Serveur | `backend/prisma/schema.prisma` | Point d'agrégation et de sauvegarde |

Une modification d'un côté sans l'autre casse la synchronisation. Les deux
fichiers se citent mutuellement en en-tête.

## Vue d'ensemble

```
Region
  └── District
        └── Csb ──────────────┬── User
                              │     (role, csbId)
                              │
                              └── Beneficiary  ◄── seule entité modifiable
                                    │
                                    ├── Consultation            ┐
                                    ├── Vaccination             │ événements de soin
                                    ├── FamilyPlanningActivity  │ immuables, append-only
                                    └── Pregnancy               │
                                          └── PrenatalVisit     ┘

AuditLog  ──► User, Csb        journal des opérations (CDC §8)
SyncQueue ──► local uniquement  file de mutations à envoyer
```

## Le principe qui structure tout le reste

Les entités se répartissent en **deux familles**, et cette séparation est ce qui
rend la synchronisation hors ligne tenable :

**1. Les événements de soin sont immuables.** Une consultation, une vaccination,
une activité de PF ou une CPN décrit un fait passé : elle est créée, jamais
modifiée. Deux agents hors ligne ne peuvent donc pas entrer en conflit dessus,
puisque chacun crée son propre enregistrement avec son propre UUID. La
synchronisation se réduit à un envoi, et la déduplication à une clé primaire.

Corriger une erreur ne consiste pas à modifier l'événement mais à l'annuler
(`cancelledAt`, `cancelReason`) et à en saisir un nouveau. L'historique reste
donc complet, ce qu'exige la traçabilité du CDC §8.

**2. L'identité du bénéficiaire est modifiable**, donc conflictuelle. C'est la
seule entité qui l'est vraiment : un nom mal orthographié se corrige, un
déménagement se répercute. Elle porte pour cela `version`, `deviceUpdatedAt` et
`serverUpdatedAt`, et suit la règle « dernier écrit gagne » avec consignation du
conflit (voir [00-decisions-techniques.md](00-decisions-techniques.md), D6).

Conséquence pratique : **le cas difficile de la synchronisation ne concerne
qu'une table.** Tout le reste est un journal qu'on rejoue.

## Identifiants

Chaque enregistrement porte un **UUID v7** généré sur l'appareil. Deux
propriétés en découlent, toutes deux nécessaires au fonctionnement hors ligne :

- aucune coordination réseau n'est requise pour créer une donnée ;
- l'UUID v7 étant ordonné dans le temps, les index restent efficaces et les
  enregistrements s'ordonnent naturellement par date de création.

Le bénéficiaire porte en plus un **identifiant lisible** `CSB-0142-26-00731`
(code du centre, année, séquence locale). Il n'a aucun rôle technique : il sert
à dire un dossier à voix haute et à faire le lien avec le registre papier
pendant la transition. Le QR code, lui, n'encode que l'UUID — jamais de nom ni
de donnée de santé.

## Table par table

### Découpage géographique — `regions`, `districts`, `csbs`

Le MVP n'agrège qu'au niveau CSB, mais le rattachement est posé dès maintenant :
c'est ce qui permettra l'agrégation par district et région du CDC §5 sans
reprise de données. Coût aujourd'hui : deux tables de référence, quelques
dizaines de lignes.

`csbs.allows_nurse_antenatal_care` traduit une réalité de terrain : beaucoup de
CSB n'ont pas de sage-femme. Le drapeau autorise alors les infirmiers du centre
à saisir les CPN, plutôt que de bloquer le suivi de grossesse là où il manque
le plus de personnel.

### `users`

Connexion par **nom d'utilisateur, pas par e-mail** : le personnel des CSB n'en
a pas systématiquement. Mot de passe haché en argon2id.

`csb_id` est le périmètre d'accès : un utilisateur ne voit que les dossiers de
son centre. Nul uniquement pour `ADMIN_NATIONAL`, qui n'accède à aucun dossier
individuel.

### `refresh_tokens`

Une ligne par appareil, jeton stocké haché. Permet de révoquer un téléphone
perdu — cas courant sur le terrain — sans déconnecter les autres appareils.

### `beneficiaries`

`birth_date_is_estimated` mérite une explication : beaucoup de bénéficiaires ne
connaissent pas leur date de naissance exacte, et l'âge est alors estimé à la
saisie. Sans ce drapeau, une approximation entrerait dans les statistiques au
même titre qu'une date fiable. Avec lui, l'analyse peut choisir.

`archived_at` remplace la suppression : les données de santé s'archivent, sinon
la traçabilité du CDC §8 serait contournable.

### `consultations`, `vaccinations`, `family_planning_activities`

Champs **codés plutôt que libres** pour tout ce qui doit remonter en
statistiques (ticket 2.4). Le texte libre existe (`notes`) mais n'est jamais
agrégé.

`occurred_on` (date de l'acte) est distinct de `created_at` (date de saisie) :
un acte fait hors ligne peut être saisi le lendemain, et les indicateurs doivent
compter la date de l'acte.

`vaccinations` porte une contrainte d'unicité sur
`(bénéficiaire, antigène, dose, date)`. Elle protège du doublon le plus probable
en pratique : une double saisie, ou un rejeu de la file de synchronisation.

### `pregnancies`, `prenatal_visits`

Modélisés dès la Phase 1 alors que la saisie arrive au ticket 2.5 : le suivi de
grossesse est décrit au CDC §4 comme contenu du dossier, et l'ajouter plus tard
aurait imposé une migration sur une base déjà déployée en centre pilote.

Les interventions systématiques du suivi prénatal (VAT, fer-acide folique,
prévention du paludisme, moustiquaire) sont des booléens dédiés et non une liste
d'actes : ce sont exactement les indicateurs que le CSB doit remonter.

### `audit_logs`

`changed_fields` ne contient **que les noms des champs modifiés, jamais leurs
valeurs** : un journal d'audit qui recopierait les données de santé deviendrait
lui-même une base de données de santé, avec les mêmes obligations et une
surface d'exposition supplémentaire.

Les deux horodatages (`device_timestamp`, `server_timestamp`) permettent de
mesurer la dérive d'horloge des appareils, qui sert à arbitrer les conflits.

### `sync_queue` — local uniquement

N'existe pas côté serveur. Contient les mutations en attente d'envoi, leur
nombre de tentatives et la dernière erreur rencontrée. Détaillée au ticket 3.1.

## Ce qui n'est pas modélisé, volontairement

Stocks d'intrants, dispositifs connectés, référentiels de nomenclature
externes, agrégats pré-calculés multi-CSB. Conformément au CDC §10, ces couches
ne sont pas préparées : les ajouter plus tard ne demandera pas de reprise du
modèle existant.

⚠️ **Points à faire valider avant le pilote** : les listes d'antigènes du PEV,
de méthodes de planification familiale et de codes de motifs de consultation
sont des propositions. Elles doivent être alignées sur les nomenclatures du
ministère de la Santé avant toute collecte réelle.
