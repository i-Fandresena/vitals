-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('AGENT_COMMUNAUTAIRE', 'INFIRMIER', 'SAGE_FEMME', 'RESPONSABLE_CSB', 'ADMIN_NATIONAL');

-- CreateEnum
CREATE TYPE "Sex" AS ENUM ('F', 'M');

-- CreateEnum
CREATE TYPE "ConsultationType" AS ENUM ('CURATIVE', 'ENFANT', 'POSTNATALE', 'AUTRE');

-- CreateEnum
CREATE TYPE "VaccineCode" AS ENUM ('BCG', 'VPO', 'VPI', 'PENTA', 'PNEUMO', 'ROTA', 'VAR', 'RR', 'VAT', 'AUTRE');

-- CreateEnum
CREATE TYPE "FamilyPlanningMethod" AS ENUM ('PILULE', 'INJECTABLE', 'IMPLANT', 'DIU', 'PRESERVATIF_MASCULIN', 'PRESERVATIF_FEMININ', 'COLLIER_DU_CYCLE', 'MAMA', 'LIGATURE_TUBAIRE', 'VASECTOMIE', 'CONTRACEPTION_URGENCE', 'AUTRE');

-- CreateEnum
CREATE TYPE "FamilyPlanningActType" AS ENUM ('NOUVELLE_ADHERENTE', 'RENOUVELLEMENT', 'CHANGEMENT_METHODE', 'ARRET');

-- CreateEnum
CREATE TYPE "PregnancyOutcome" AS ENUM ('EN_COURS', 'ACCOUCHEMENT_VIVANT', 'MORT_NE', 'AVORTEMENT', 'PERDUE_DE_VUE');

-- CreateEnum
CREATE TYPE "AuditAction" AS ENUM ('CREATE', 'UPDATE', 'ARCHIVE', 'CANCEL', 'LOGIN', 'LOGIN_FAILED', 'SYNC_CONFLICT', 'EXPORT');

-- CreateTable
CREATE TABLE "regions" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "regions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "districts" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "region_id" UUID NOT NULL,

    CONSTRAINT "districts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "csbs" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "commune" TEXT,
    "district_id" UUID NOT NULL,
    "allows_nurse_antenatal_care" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "csbs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "username" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "full_name" TEXT NOT NULL,
    "role" "UserRole" NOT NULL,
    "phone" TEXT,
    "csb_id" UUID,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "last_login_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "device_id" TEXT NOT NULL,
    "device_label" TEXT,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "revoked_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "beneficiaries" (
    "id" UUID NOT NULL,
    "local_id" TEXT NOT NULL,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "sex" "Sex" NOT NULL,
    "birth_date" DATE NOT NULL,
    "birth_date_is_estimated" BOOLEAN NOT NULL DEFAULT false,
    "phone" TEXT,
    "fokontany" TEXT,
    "address" TEXT,
    "csb_id" UUID NOT NULL,
    "archived_at" TIMESTAMP(3),
    "version" INTEGER NOT NULL DEFAULT 1,
    "device_updated_at" TIMESTAMP(3) NOT NULL,
    "server_updated_at" TIMESTAMP(3) NOT NULL,
    "created_by_user_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "beneficiaries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "consultations" (
    "id" UUID NOT NULL,
    "beneficiary_id" UUID NOT NULL,
    "type" "ConsultationType" NOT NULL,
    "occurred_on" DATE NOT NULL,
    "motive_code" TEXT NOT NULL,
    "diagnosis_code" TEXT,
    "weight_kg" DOUBLE PRECISION,
    "temperature_c" DOUBLE PRECISION,
    "blood_pressure_sys" INTEGER,
    "blood_pressure_dia" INTEGER,
    "treatment_given" BOOLEAN NOT NULL DEFAULT false,
    "referred" BOOLEAN NOT NULL DEFAULT false,
    "referred_to" TEXT,
    "notes" TEXT,
    "cancelled_at" TIMESTAMP(3),
    "cancel_reason" TEXT,
    "recorded_by_user_id" UUID NOT NULL,
    "device_created_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "consultations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vaccinations" (
    "id" UUID NOT NULL,
    "beneficiary_id" UUID NOT NULL,
    "vaccine" "VaccineCode" NOT NULL,
    "dose_number" INTEGER NOT NULL,
    "occurred_on" DATE NOT NULL,
    "lot_number" TEXT,
    "cancelled_at" TIMESTAMP(3),
    "cancel_reason" TEXT,
    "recorded_by_user_id" UUID NOT NULL,
    "device_created_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vaccinations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "family_planning_activities" (
    "id" UUID NOT NULL,
    "beneficiary_id" UUID NOT NULL,
    "method" "FamilyPlanningMethod" NOT NULL,
    "act_type" "FamilyPlanningActType" NOT NULL,
    "occurred_on" DATE NOT NULL,
    "quantity" INTEGER,
    "cancelled_at" TIMESTAMP(3),
    "cancel_reason" TEXT,
    "recorded_by_user_id" UUID NOT NULL,
    "device_created_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "family_planning_activities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pregnancies" (
    "id" UUID NOT NULL,
    "beneficiary_id" UUID NOT NULL,
    "last_period_date" DATE,
    "expected_delivery_on" DATE,
    "gravida" INTEGER,
    "para" INTEGER,
    "outcome" "PregnancyOutcome" NOT NULL DEFAULT 'EN_COURS',
    "outcome_date" DATE,
    "version" INTEGER NOT NULL DEFAULT 1,
    "device_updated_at" TIMESTAMP(3) NOT NULL,
    "server_updated_at" TIMESTAMP(3) NOT NULL,
    "created_by_user_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pregnancies_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "prenatal_visits" (
    "id" UUID NOT NULL,
    "pregnancy_id" UUID NOT NULL,
    "visit_number" INTEGER NOT NULL,
    "occurred_on" DATE NOT NULL,
    "gestational_age_weeks" INTEGER,
    "weight_kg" DOUBLE PRECISION,
    "blood_pressure_sys" INTEGER,
    "blood_pressure_dia" INTEGER,
    "fundal_height_cm" DOUBLE PRECISION,
    "fetal_heart_rate" INTEGER,
    "tetanus_vaccine_given" BOOLEAN NOT NULL DEFAULT false,
    "iron_folate_given" BOOLEAN NOT NULL DEFAULT false,
    "malaria_prevention_given" BOOLEAN NOT NULL DEFAULT false,
    "insecticide_net_given" BOOLEAN NOT NULL DEFAULT false,
    "risk_factor_codes" TEXT[],
    "referred" BOOLEAN NOT NULL DEFAULT false,
    "referred_to" TEXT,
    "notes" TEXT,
    "cancelled_at" TIMESTAMP(3),
    "cancel_reason" TEXT,
    "recorded_by_user_id" UUID NOT NULL,
    "device_created_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "prenatal_visits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "user_id" UUID,
    "csb_id" UUID,
    "action" "AuditAction" NOT NULL,
    "entity_type" TEXT NOT NULL,
    "entity_id" TEXT,
    "changed_fields" TEXT[],
    "device_id" TEXT,
    "ip_hash" TEXT,
    "device_timestamp" TIMESTAMP(3),
    "server_timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "regions_code_key" ON "regions"("code");

-- CreateIndex
CREATE UNIQUE INDEX "districts_code_key" ON "districts"("code");

-- CreateIndex
CREATE INDEX "districts_region_id_idx" ON "districts"("region_id");

-- CreateIndex
CREATE UNIQUE INDEX "csbs_code_key" ON "csbs"("code");

-- CreateIndex
CREATE INDEX "csbs_district_id_idx" ON "csbs"("district_id");

-- CreateIndex
CREATE UNIQUE INDEX "users_username_key" ON "users"("username");

-- CreateIndex
CREATE INDEX "users_csb_id_idx" ON "users"("csb_id");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_token_hash_key" ON "refresh_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "refresh_tokens_user_id_idx" ON "refresh_tokens"("user_id");

-- CreateIndex
CREATE INDEX "refresh_tokens_device_id_idx" ON "refresh_tokens"("device_id");

-- CreateIndex
CREATE UNIQUE INDEX "beneficiaries_local_id_key" ON "beneficiaries"("local_id");

-- CreateIndex
CREATE INDEX "beneficiaries_csb_id_idx" ON "beneficiaries"("csb_id");

-- CreateIndex
CREATE INDEX "beneficiaries_last_name_first_name_idx" ON "beneficiaries"("last_name", "first_name");

-- CreateIndex
CREATE INDEX "beneficiaries_server_updated_at_idx" ON "beneficiaries"("server_updated_at");

-- CreateIndex
CREATE INDEX "consultations_beneficiary_id_idx" ON "consultations"("beneficiary_id");

-- CreateIndex
CREATE INDEX "consultations_occurred_on_idx" ON "consultations"("occurred_on");

-- CreateIndex
CREATE INDEX "vaccinations_occurred_on_idx" ON "vaccinations"("occurred_on");

-- CreateIndex
CREATE UNIQUE INDEX "vaccinations_beneficiary_id_vaccine_dose_number_occurred_on_key" ON "vaccinations"("beneficiary_id", "vaccine", "dose_number", "occurred_on");

-- CreateIndex
CREATE INDEX "family_planning_activities_beneficiary_id_idx" ON "family_planning_activities"("beneficiary_id");

-- CreateIndex
CREATE INDEX "family_planning_activities_occurred_on_idx" ON "family_planning_activities"("occurred_on");

-- CreateIndex
CREATE INDEX "pregnancies_beneficiary_id_idx" ON "pregnancies"("beneficiary_id");

-- CreateIndex
CREATE INDEX "prenatal_visits_pregnancy_id_idx" ON "prenatal_visits"("pregnancy_id");

-- CreateIndex
CREATE INDEX "prenatal_visits_occurred_on_idx" ON "prenatal_visits"("occurred_on");

-- CreateIndex
CREATE INDEX "audit_logs_user_id_idx" ON "audit_logs"("user_id");

-- CreateIndex
CREATE INDEX "audit_logs_csb_id_idx" ON "audit_logs"("csb_id");

-- CreateIndex
CREATE INDEX "audit_logs_entity_type_entity_id_idx" ON "audit_logs"("entity_type", "entity_id");

-- CreateIndex
CREATE INDEX "audit_logs_server_timestamp_idx" ON "audit_logs"("server_timestamp");

-- AddForeignKey
ALTER TABLE "districts" ADD CONSTRAINT "districts_region_id_fkey" FOREIGN KEY ("region_id") REFERENCES "regions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "csbs" ADD CONSTRAINT "csbs_district_id_fkey" FOREIGN KEY ("district_id") REFERENCES "districts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_csb_id_fkey" FOREIGN KEY ("csb_id") REFERENCES "csbs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "beneficiaries" ADD CONSTRAINT "beneficiaries_csb_id_fkey" FOREIGN KEY ("csb_id") REFERENCES "csbs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "consultations" ADD CONSTRAINT "consultations_beneficiary_id_fkey" FOREIGN KEY ("beneficiary_id") REFERENCES "beneficiaries"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vaccinations" ADD CONSTRAINT "vaccinations_beneficiary_id_fkey" FOREIGN KEY ("beneficiary_id") REFERENCES "beneficiaries"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_planning_activities" ADD CONSTRAINT "family_planning_activities_beneficiary_id_fkey" FOREIGN KEY ("beneficiary_id") REFERENCES "beneficiaries"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pregnancies" ADD CONSTRAINT "pregnancies_beneficiary_id_fkey" FOREIGN KEY ("beneficiary_id") REFERENCES "beneficiaries"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prenatal_visits" ADD CONSTRAINT "prenatal_visits_pregnancy_id_fkey" FOREIGN KEY ("pregnancy_id") REFERENCES "pregnancies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_csb_id_fkey" FOREIGN KEY ("csb_id") REFERENCES "csbs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

