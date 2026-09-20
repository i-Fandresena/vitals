import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';

import { AuthenticatedUser } from '../auth/types/jwt-payload';
import { PrismaService } from '../prisma/prisma.service';

export type Granularite = 'semaine' | 'mois' | 'annee';
export type Niveau = 'csb' | 'district' | 'region' | 'national';

export interface PeriodeIndicateurs {
  debut: string;
  fin: string;
  granularite: Granularite;
}

export interface LigneIndicateur {
  cle: string;
  libelle: string;
  consultations: number;
  cpn: number;
  vaccinations: number;
  planificationFamiliale: number;
  nouveauxDossiers: number;
}

/**
 * Indicateurs agrégés (CDC §4 et §5).
 *
 * **Aucun dossier individuel n'est exposé ici.** Toutes les requêtes
 * renvoient des dénombrements ; un niveau supérieur voit des totaux, jamais
 * des personnes. C'est la règle du CDC §5 et elle est appliquée par
 * construction : ce service ne sait pas lire un nom.
 *
 * Les comptages portent sur `occurred_on`, la date de l'acte, et non sur la
 * date de saisie. Un acte fait en brousse et synchronisé trois jours plus tard
 * doit compter dans la semaine où il a eu lieu, sinon les indicateurs
 * hebdomadaires deviennent faux dès qu'il y a du retard de connexion.
 */
@Injectable()
export class IndicatorsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Totaux et répartition pour une période.
   *
   * [niveau] choisit l'axe de regroupement. Un responsable de CSB est ramené
   * de force à son propre centre, quel que soit le niveau demandé.
   */
  async resume(
    user: AuthenticatedUser,
    options: {
      debut?: string;
      fin?: string;
      granularite?: Granularite;
      niveau?: Niveau;
    },
  ) {
    const granularite = options.granularite ?? 'mois';
    const { debut, fin } = this.bornes(options.debut, options.fin, granularite);

    const restreintAuCsb = user.role !== UserRole.ADMIN_NATIONAL;
    const csbId = restreintAuCsb ? (user.csbId ?? '') : null;
    const niveau: Niveau = restreintAuCsb ? 'csb' : (options.niveau ?? 'csb');

    const [totaux, repartition, serie] = await Promise.all([
      this.totaux(debut, fin, csbId),
      this.repartition(debut, fin, csbId, niveau),
      this.serieTemporelle(debut, fin, csbId, granularite),
    ]);

    return {
      periode: { debut, fin, granularite } satisfies PeriodeIndicateurs,
      niveau,
      totaux,
      repartition,
      serie,
    };
  }

  /** Dénombrements sur toute la période. */
  private async totaux(debut: string, fin: string, csbId: string | null) {
    const filtreCsb = csbId ? Prisma.sql`AND b.csb_id = ${csbId}::uuid` : Prisma.empty;

    const [row] = await this.prisma.$queryRaw<
      Array<{
        consultations: bigint;
        cpn: bigint;
        vaccinations: bigint;
        pf: bigint;
        nouveaux: bigint;
        beneficiaires: bigint;
      }>
    >`
      SELECT
        (SELECT count(*) FROM consultations c
           JOIN beneficiaries b ON b.id = c.beneficiary_id
          WHERE c.cancelled_at IS NULL
            AND c.occurred_on BETWEEN ${debut}::date AND ${fin}::date
            ${filtreCsb}) AS consultations,
        (SELECT count(*) FROM prenatal_visits v
           JOIN pregnancies p ON p.id = v.pregnancy_id
           JOIN beneficiaries b ON b.id = p.beneficiary_id
          WHERE v.cancelled_at IS NULL
            AND v.occurred_on BETWEEN ${debut}::date AND ${fin}::date
            ${filtreCsb}) AS cpn,
        (SELECT count(*) FROM vaccinations vc
           JOIN beneficiaries b ON b.id = vc.beneficiary_id
          WHERE vc.cancelled_at IS NULL
            AND vc.occurred_on BETWEEN ${debut}::date AND ${fin}::date
            ${filtreCsb}) AS vaccinations,
        (SELECT count(*) FROM family_planning_activities f
           JOIN beneficiaries b ON b.id = f.beneficiary_id
          WHERE f.cancelled_at IS NULL
            AND f.occurred_on BETWEEN ${debut}::date AND ${fin}::date
            ${filtreCsb}) AS pf,
        (SELECT count(*) FROM beneficiaries b
          WHERE b.created_at::date BETWEEN ${debut}::date AND ${fin}::date
            ${filtreCsb}) AS nouveaux,
        (SELECT count(*) FROM beneficiaries b
          WHERE b.archived_at IS NULL ${filtreCsb}) AS beneficiaires
    `;

    return {
      consultations: Number(row?.consultations ?? 0),
      cpn: Number(row?.cpn ?? 0),
      vaccinations: Number(row?.vaccinations ?? 0),
      planificationFamiliale: Number(row?.pf ?? 0),
      nouveauxDossiers: Number(row?.nouveaux ?? 0),
      dossiersActifs: Number(row?.beneficiaires ?? 0),
    };
  }

  /** Répartition par centre, district ou région. */
  private async repartition(
    debut: string,
    fin: string,
    csbId: string | null,
    niveau: Niveau,
  ): Promise<LigneIndicateur[]> {
    if (niveau === 'national') return [];

    const filtreCsb = csbId ? Prisma.sql`AND b.csb_id = ${csbId}::uuid` : Prisma.empty;

    // Les trois axes partagent la même requête : seule la clé de regroupement
    // change. Écrire trois requêtes distinctes inviterait à les faire diverger.
    const cle =
      niveau === 'csb'
        ? Prisma.sql`csb.id::text`
        : niveau === 'district'
          ? Prisma.sql`d.id::text`
          : Prisma.sql`r.id::text`;

    const libelle =
      niveau === 'csb'
        ? Prisma.sql`csb.name`
        : niveau === 'district'
          ? Prisma.sql`d.name`
          : Prisma.sql`r.name`;

    const rows = await this.prisma.$queryRaw<
      Array<{
        cle: string;
        libelle: string;
        consultations: bigint;
        cpn: bigint;
        vaccinations: bigint;
        pf: bigint;
        nouveaux: bigint;
      }>
    >`
      SELECT
        ${cle} AS cle,
        ${libelle} AS libelle,
        count(*) FILTER (WHERE a.type = 'consultation') AS consultations,
        count(*) FILTER (WHERE a.type = 'cpn') AS cpn,
        count(*) FILTER (WHERE a.type = 'vaccination') AS vaccinations,
        count(*) FILTER (WHERE a.type = 'pf') AS pf,
        count(*) FILTER (WHERE a.type = 'dossier') AS nouveaux
      FROM csbs csb
      JOIN districts d ON d.id = csb.district_id
      JOIN regions r ON r.id = d.region_id
      LEFT JOIN beneficiaries b ON b.csb_id = csb.id
      LEFT JOIN LATERAL (
        SELECT 'consultation' AS type, c.occurred_on AS jour
          FROM consultations c
         WHERE c.beneficiary_id = b.id AND c.cancelled_at IS NULL
        UNION ALL
        SELECT 'cpn', v.occurred_on
          FROM prenatal_visits v
          JOIN pregnancies p ON p.id = v.pregnancy_id
         WHERE p.beneficiary_id = b.id AND v.cancelled_at IS NULL
        UNION ALL
        SELECT 'vaccination', vc.occurred_on
          FROM vaccinations vc
         WHERE vc.beneficiary_id = b.id AND vc.cancelled_at IS NULL
        UNION ALL
        SELECT 'pf', f.occurred_on
          FROM family_planning_activities f
         WHERE f.beneficiary_id = b.id AND f.cancelled_at IS NULL
        UNION ALL
        SELECT 'dossier', b.created_at::date
      ) a ON a.jour BETWEEN ${debut}::date AND ${fin}::date
      WHERE TRUE ${filtreCsb}
      GROUP BY 1, 2
      ORDER BY 2
    `;

    return rows.map((r) => ({
      cle: r.cle,
      libelle: r.libelle,
      consultations: Number(r.consultations),
      cpn: Number(r.cpn),
      vaccinations: Number(r.vaccinations),
      planificationFamiliale: Number(r.pf),
      nouveauxDossiers: Number(r.nouveaux),
    }));
  }

  /** Évolution dans le temps, au pas demandé. */
  private async serieTemporelle(
    debut: string,
    fin: string,
    csbId: string | null,
    granularite: Granularite,
  ) {
    const pas =
      granularite === 'semaine' ? 'week' : granularite === 'annee' ? 'year' : 'month';
    const filtreCsb = csbId ? Prisma.sql`AND b.csb_id = ${csbId}::uuid` : Prisma.empty;

    const rows = await this.prisma.$queryRaw<
      Array<{
        periode: Date;
        consultations: bigint;
        cpn: bigint;
        vaccinations: bigint;
        pf: bigint;
      }>
    >`
      SELECT
        date_trunc(${pas}, a.jour)::date AS periode,
        count(*) FILTER (WHERE a.type = 'consultation') AS consultations,
        count(*) FILTER (WHERE a.type = 'cpn') AS cpn,
        count(*) FILTER (WHERE a.type = 'vaccination') AS vaccinations,
        count(*) FILTER (WHERE a.type = 'pf') AS pf
      FROM beneficiaries b
      JOIN LATERAL (
        SELECT 'consultation' AS type, c.occurred_on AS jour
          FROM consultations c
         WHERE c.beneficiary_id = b.id AND c.cancelled_at IS NULL
        UNION ALL
        SELECT 'cpn', v.occurred_on
          FROM prenatal_visits v
          JOIN pregnancies p ON p.id = v.pregnancy_id
         WHERE p.beneficiary_id = b.id AND v.cancelled_at IS NULL
        UNION ALL
        SELECT 'vaccination', vc.occurred_on
          FROM vaccinations vc
         WHERE vc.beneficiary_id = b.id AND vc.cancelled_at IS NULL
        UNION ALL
        SELECT 'pf', f.occurred_on
          FROM family_planning_activities f
         WHERE f.beneficiary_id = b.id AND f.cancelled_at IS NULL
      ) a ON a.jour BETWEEN ${debut}::date AND ${fin}::date
      WHERE TRUE ${filtreCsb}
      GROUP BY 1
      ORDER BY 1
    `;

    return rows.map((r) => ({
      periode: r.periode.toISOString().slice(0, 10),
      consultations: Number(r.consultations),
      cpn: Number(r.cpn),
      vaccinations: Number(r.vaccinations),
      planificationFamiliale: Number(r.pf),
    }));
  }

  /**
   * Borne la période demandée.
   *
   * Par défaut : les douze derniers mois, ou les douze dernières semaines au
   * pas hebdomadaire. Une période ouverte sur toute l'histoire ne dit rien
   * d'utile et coûte cher à calculer.
   */
  private bornes(debut: string | undefined, fin: string | undefined, granularite: Granularite) {
    const iso = /^\d{4}-\d{2}-\d{2}$/;

    if (debut && !iso.test(debut)) throw new BadRequestException('Date de début invalide');
    if (fin && !iso.test(fin)) throw new BadRequestException('Date de fin invalide');

    const finale = fin ?? new Date().toISOString().slice(0, 10);
    let initiale = debut;

    if (!initiale) {
      const d = new Date(finale);
      if (granularite === 'semaine') d.setDate(d.getDate() - 7 * 12);
      else if (granularite === 'annee') d.setFullYear(d.getFullYear() - 5);
      else d.setMonth(d.getMonth() - 12);
      initiale = d.toISOString().slice(0, 10);
    }

    if (initiale > finale) {
      throw new BadRequestException('La date de début est postérieure à la date de fin');
    }

    return { debut: initiale, fin: finale };
  }
}
