# Matrice des droits par profil — Ticket 0.2

> **Statut : proposition à valider par l'équipe Maternal AI.**
> Le CDC §3 cite les profils mais ne détaille pas qui fait quoi. Cette matrice
> sert de spécification directe aux tickets 1.3 (rôles backend) et 2.2 (droits
> d'accès aux dossiers). Toute correction ici doit être répercutée dans les deux.

## Profils

| Code | Profil | Rôle sur le terrain |
|---|---|---|
| `agent_communautaire` | Agent communautaire | Travaille hors du centre, identifie et oriente les personnes vers le CSB |
| `infirmier` | Infirmier | Consultations générales, vaccination, planification familiale |
| `sage_femme` | Sage-femme | Idem infirmier, plus le suivi de grossesse et le postnatal |
| `responsable_csb` | Responsable du CSB | Supervise le centre, lit les indicateurs, gère les comptes de son centre |
| `admin_national` | Administration Maternal AI | Gère les CSB et les comptes, ne consulte pas les dossiers individuels |

## Matrice

| Action | Agent com. | Infirmier | Sage-femme | Resp. CSB | Admin nat. |
|---|:--:|:--:|:--:|:--:|:--:|
| Créer un dossier bénéficiaire | ✅ | ✅ | ✅ | ✅ | ❌ |
| Rechercher / ouvrir un dossier | 🔸 | ✅ | ✅ | ✅ | ❌ |
| Voir l'historique de soin complet | ❌ | ✅ | ✅ | ✅ | ❌ |
| Modifier l'identité d'un dossier | ❌ | ✅ | ✅ | ✅ | ❌ |
| Archiver un dossier | ❌ | ❌ | ❌ | ✅ | ❌ |
| Supprimer un dossier | ❌ | ❌ | ❌ | ❌ | ❌ |
| Enregistrer une consultation générale | ❌ | ✅ | ✅ | ✅ | ❌ |
| Enregistrer une CPN / suivi grossesse | ❌ | 🔸 | ✅ | ✅ | ❌ |
| Enregistrer un suivi postnatal | ❌ | 🔸 | ✅ | ✅ | ❌ |
| Enregistrer une vaccination | ❌ | ✅ | ✅ | ✅ | ❌ |
| Enregistrer une activité de PF | ❌ | ✅ | ✅ | ✅ | ❌ |
| Saisir une donnée communautaire | ✅ | ✅ | ✅ | ✅ | ❌ |
| Consulter le tableau de bord du CSB | ❌ | 🔸 | 🔸 | ✅ | ❌ |
| Consulter les indicateurs consolidés | ❌ | ❌ | ❌ | ✅ | ✅ |
| Exporter les données du CSB | ❌ | ❌ | ❌ | ✅ | ❌ |
| Gérer les comptes de son CSB | ❌ | ❌ | ❌ | ✅ | ✅ |
| Gérer les CSB et les rattachements | ❌ | ❌ | ❌ | ❌ | ✅ |
| Consulter le journal d'audit | ❌ | ❌ | ❌ | 🔸 | ✅ |

**Légende** — ✅ autorisé · ❌ refusé · 🔸 autorisé avec restriction, détaillée ci-dessous.

## Restrictions détaillées

**Agent communautaire — recherche de dossier 🔸**
Ne voit que l'identité (nom, âge, village, identifiant) et uniquement pour les
dossiers de sa zone de rattachement. Aucun accès au contenu clinique : ce profil
oriente vers le CSB, il ne soigne pas. C'est aussi le profil le plus exposé
(appareil partagé, usage hors du centre), donc celui qui doit porter le moins de
données sensibles.

**Infirmier — CPN, postnatal 🔸**
Autorisé en lecture, et en saisie seulement si le CSB n'a pas de sage-femme
affectée. Beaucoup de CSB de base n'en ont pas ; interdire la saisie bloquerait
le suivi de grossesse là où il est le plus nécessaire. Le réglage est un
paramètre du CSB, pas une permission individuelle.

**Infirmier, sage-femme — tableau de bord 🔸**
Accès aux indicateurs de leur propre activité, pas à ceux du centre entier. Le
tableau de bord complet reste au responsable (CDC §4).

**Responsable CSB — journal d'audit 🔸**
Accès aux opérations faites dans son seul CSB.

## Principes transverses

1. **Aucune suppression de dossier, pour personne.** Les données de santé
   s'archivent, elles ne se suppriment pas : la traçabilité exigée au CDC §8
   serait sinon contournable. L'archivage retire le dossier des recherches
   courantes sans effacer l'historique.

2. **Un utilisateur n'accède qu'aux dossiers de son CSB de rattachement.** La
   matrice s'applique *à l'intérieur* de ce périmètre. Un infirmier du CSB A ne
   voit aucun dossier du CSB B, quel que soit son rôle.

3. **Les niveaux supérieurs ne voient jamais les dossiers individuels**, seulement
   des indicateurs agrégés (CDC §5). C'est la raison pour laquelle
   `admin_national` est refusé sur toute la colonne « dossier ».

   Ces deux moitiés sont des permissions distinctes : consulter des totaux par
   district et ouvrir un dossier n'ont aucun rapport, et les confondre
   reviendrait à ouvrir l'un en accordant l'autre. Les avoir mélangées au
   départ a produit un refus injustifié du tableau de bord, découvert en
   production.

4. **Les droits sont appliqués côté serveur, pas seulement dans l'interface.**
   Masquer un bouton n'est pas une permission. Chaque endpoint vérifie le rôle et
   le rattachement CSB, indépendamment de ce que l'application affiche
   (exigence explicite du ticket 2.2).

5. **Toute action d'écriture est journalisée** avec son auteur, quel que soit le
   profil (ticket 3.4).
