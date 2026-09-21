-- Rapprochement avec DHIS2.
--
-- Deux correspondances sont nécessaires pour qu'un chiffre parte au bon
-- endroit : de quel centre il vient, et de quel indicateur il s'agit. Les
-- deux vivent en base et non dans le code, parce que les identifiants DHIS2
-- sont propres à chaque instance nationale — un changement de serveur ne doit
-- pas demander un nouveau déploiement.

-- Le centre, rapproché d'une unité d'organisation DHIS2.
--
-- Nullable : un centre non rapproché est simplement absent de l'export. C'est
-- préférable à une valeur devinée, qui écrirait les chiffres d'un centre sur
-- un autre sans que personne ne s'en aperçoive.
ALTER TABLE "csbs" ADD COLUMN "dhis2_org_unit" TEXT;

-- L'indicateur, rapproché d'un élément de données DHIS2.
CREATE TABLE "dhis2_element_mappings" (
    "indicator" TEXT NOT NULL,
    "data_element" TEXT NOT NULL,
    "category_option_combo" TEXT,
    "label" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "dhis2_element_mappings_pkey" PRIMARY KEY ("indicator")
);
