## Cahier des charges fonctionnel

## Projet de digitalisation des Centres de Santé de Base

Porteur du projet : Maternal AI

Version : Pré-MVP

Type de projet : Application métier de santé / système de collecte et de gestion des données

sanitaires

## 1. Contexte

Les CSB utilisent encore largement des registres et des supports papier pour enregistrer les consultations, les vaccinations, la santé maternelle et infantile, la planification familiale et d'autres activités de santé.

Ces données sont importantes pour le suivi des patients mais aussi pour comprendre les besoins des populations et orienter les décisions sanitaires. Lorsqu'elles restent dispersées, leur consolidation et leur exploitation deviennent difficiles.

Maternal AI souhaite développer un outil simple permettant aux personnels des CSB de saisir et retrouver les informations essentielles, tout en construisant progressivement une base de données structurée pouvant être agrégée et analysée à différents niveaux du système de santé.

## 2. Objectif du projet

L'objectif est de digitaliser progressivement les activités essentielles des CSB avec un outil réellement utilisable sur le terrain.

La solution doit permettre de gérer les dossiers individuels, suivre les principales activités de santé et produire des données agrégées utiles au responsable du CSB, aux niveaux administratifs concernés, aux programmes de santé et, dans un cadre autorisé, à la recherche.

La priorité du MVP est la simplicité d'utilisation et la qualité des données, et non le nombre de fonctionnalités.

## 3. Utilisateurs

L'outil sera principalement utilisé par les sages-femmes, infirmiers, responsables de CSB et agents communautaires.

Les utilisateurs n'auront pas nécessairement une expérience avancée en informatique. L'interface doit donc être conçue pour une utilisation rapide, avec des formulaires simples, des informations clairement visibles et un minimum d'étapes.

Les droits d'accès devront dépendre du profil de l'utilisateur.

## 4. Fonctionnalités principales du MVP


## Gestion des dossiers

Création d'un dossier individuel pour chaque bénéficiaire, avec un identifiant unique et un QR code.

Le professionnel autorisé peut retrouver un dossier, consulter son historique et ajouter une nouvelle information.

Pour une femme enceinte, le dossier pourra notamment contenir les informations liées aux consultations prénatales, à l'évolution de la grossesse, aux examens, aux facteurs de risque, aux références et au suivi postnatal.

## Consultations

Le professionnel peut enregistrer une consultation directement depuis le dossier de la personne.

Les informations doivent être structurées afin de pouvoir être utilisées ensuite pour les statistiques et les tableaux de bord.

## Vaccination

Enregistrement des vaccinations réalisées et suivi des personnes ou enfants ayant bénéficié des services de vaccination.

Le système doit permettre de produire des indicateurs simples sur les vaccinations réalisées pendant une période donnée.

## Planification familiale

Enregistrement des activités de planification familiale et des méthodes utilisées ou distribuées.

Une évolution future pourra intégrer le suivi des stocks et des besoins en contraceptifs et autres intrants.

## Tableau de bord du CSB

Le responsable doit pouvoir visualiser les principaux indicateurs de son centre.

Le tableau de bord doit notamment permettre de suivre les consultations prénatales, les vaccinations, les activités de planification familiale et l'évolution de l'activité du centre.

Les données doivent pouvoir être consultées par période, notamment hebdomadaire, mensuelle et annuelle.

## Données communautaires

Le système pourra progressivement intégrer certaines informations permettant de mieux comprendre le contexte communautaire et les parcours de soins : recours aux matrones,


difficultés d'accès aux soins, pratiques communautaires, orientation vers les structures de santé ou autres facteurs pertinents.

Ces informations doivent être collectées uniquement lorsqu'elles ont une utilité clairement définie et dans le respect des règles applicables aux données de santé.

## 5. Consolidation et analyse

Les données des différents CSB doivent pouvoir être agrégées.

Un niveau supérieur ne doit pas nécessairement accéder aux dossiers individuels. Il doit pouvoir consulter des indicateurs agrégés selon ses droits.

À terme, le système pourra permettre une lecture des données par CSB, zone, district, région et niveau national.

L'objectif est de permettre l'identification de tendances, de besoins et de situations nécessitant une attention particulière.

## 6. Connectivité

La solution doit être pensée pour les réalités des CSB.

Elle doit fonctionner avec une connexion internet faible et prévoir un fonctionnement hors ligne ou une saisie temporaire hors connexion lorsque cela est techniquement possible.

Les données devront être synchronisées lorsque la connexion est disponible.

## 7. UX / interface

L'interface doit être très simple, sobre et fonctionnelle.

Nous ne recherchons pas une interface complexe ou très chargée visuellement. Le professionnel doit pouvoir comprendre immédiatement où rechercher une personne, créer un dossier, enregistrer une consultation et consulter les informations essentielles.

L'application doit être pensée d'abord selon les tâches réelles du personnel de santé, et non selon une logique purement informatique.

Une phase de test avec de vrais utilisateurs des CSB devra être prévue avant la validation du MVP.

## 8. Sécurité et gestion des accès

Les données de santé sont sensibles. La solution devra prévoir une authentification sécurisée et des droits d'accès adaptés aux différents profils.

Les données individuelles ne doivent être accessibles qu'aux personnes autorisées.


Le système devra également conserver un historique des opérations importantes afin de savoir qui a créé ou modifié une information.

Les exigences réglementaires applicables à la protection des données personnelles et aux données de santé devront être étudiées avant le déploiement.

## 9. Interopérabilité et évolutivité

L'architecture devra permettre l'évolution future de la solution et son interconnexion éventuelle avec d'autres systèmes de santé.

Les données devront être structurées de manière cohérente afin de permettre leur export, leur agrégation et leur analyse.

L'objectif à long terme est de construire une infrastructure pouvant alimenter des outils de reporting, de recherche, d'analyse de données et éventuellement d'intelligence artificielle.

## 10. Ce qui n'est pas prioritaire dans le MVP

Le MVP ne doit pas chercher à intégrer immédiatement toutes les fonctionnalités possibles.

Les dispositifs médicaux connectés, les modèles d'intelligence artificielle, les analyses prédictives avancées, la gestion complète de la chaîne logistique et les intégrations complexes pourront être développés progressivement.

La priorité est d'abord d'obtenir un système simple, stable, utilisable dans un CSB et capable de produire des données fiables.

## 11. Résultat attendu

À la fin du MVP, un CSB pilote doit pouvoir utiliser la solution pour gérer les dossiers, enregistrer les principales activités de santé et consulter ses indicateurs sans dépendre des registres papier pour les informations couvertes par le système.

Maternal AI doit également pouvoir récupérer des données structurées et agrégées permettant de suivre l'activité et de préparer les futures fonctionnalités d'analyse et d'interopérabilité.

## 12. Critères de validation

Le MVP sera considéré comme fonctionnel lorsqu'un personnel de santé peut, avec une formation minimale, créer ou retrouver un dossier, enregistrer une consultation, consulter l'historique d'une personne et retrouver les principaux indicateurs de son CSB.

La validation devra se faire sur le terrain avec des utilisateurs réels avant une extension à plusieurs centres.
