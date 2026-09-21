import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { PrismaService } from '../prisma/prisma.service';

/** Les indicateurs qu'on sait remonter. */
export const INDICATEURS_DHIS2 = [
  'consultations',
  'cpn',
  'vaccinations',
  'planificationFamiliale',
  'nouveauxDossiers',
] as const;

export type IndicateurDhis2 = (typeof INDICATEURS_DHIS2)[number];

export interface ValeurDhis2 {
  dataElement: string;
  period: string;
  orgUnit: string;
  value: string;
  categoryOptionCombo?: string;
}

export interface ResultatExport {
  periode: string;
  /** Vrai quand DHIS2 a validé sans rien écrire. */
  simulation: boolean;
  valeursEnvoyees: number;
  centresRetenus: number;
  /** Centres sans unité d'organisation, donc hors export. */
  centresNonRapproches: string[];
  /** Indicateurs sans élément de données, donc non remontés. */
  indicateursNonRapproches: string[];
  /** Compte rendu d'import renvoyé par DHIS2. */
  resume?: {
    statut: string;
    importes: number;
    misAJour: number;
    ignores: number;
    rejetes: number;
    messages: string[];
  };
}

/**
 * Remontée des indicateurs vers DHIS2 (CDC §5).
 *
 * **Seuls des dénombrements partent d'ici.** DHIS2 est un entrepôt de données
 * agrégées : il n'a ni le besoin ni le droit de recevoir un dossier
 * individuel, et ce service ne sait pas en lire un.
 *
 * Le rapprochement — quel centre est quelle unité d'organisation, quel
 * indicateur est quel élément de données — vit en base. Les identifiants DHIS2
 * sont propres à chaque instance nationale ; les inscrire dans le code
 * obligerait à redéployer à chaque ajustement du ministère.
 *
 * L'export est **idempotent** : DHIS2 remplace la valeur d'une période pour
 * une unité donnée. Relancer un mois déjà envoyé le met à jour, il ne
 * s'additionne pas.
 */
@Injectable()
export class Dhis2Service {
  private readonly logger = new Logger(Dhis2Service.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  /** Configuration de la connexion, ou null si elle n'est pas renseignée. */
  private connexion(): { url: string; entete: string } | null {
    const url = this.config.get<string>('DHIS2_URL')?.replace(/\/+$/, '');
    const utilisateur = this.config.get<string>('DHIS2_USERNAME');
    const motDePasse = this.config.get<string>('DHIS2_PASSWORD');

    if (!url || !utilisateur || !motDePasse) return null;

    const jeton = Buffer.from(`${utilisateur}:${motDePasse}`).toString('base64');
    return { url, entete: `Basic ${jeton}` };
  }

  /** État de la configuration, pour l'écran d'administration. */
  async etat() {
    const connexion = this.connexion();
    const [correspondances, centres, centresRapproches] = await Promise.all([
      this.prisma.dhis2ElementMapping.findMany({ orderBy: { indicator: 'asc' } }),
      this.prisma.csb.count(),
      this.prisma.csb.count({ where: { dhis2OrgUnit: { not: null } } }),
    ]);

    return {
      // L'adresse seulement : l'identifiant et le mot de passe n'ont aucune
      // raison de traverser l'API, même vers un administrateur.
      serveur: connexion?.url ?? null,
      configure: connexion !== null,
      correspondances,
      centres,
      centresRapproches,
    };
  }

  /**
   * Remplace les correspondances indicateur → élément de données.
   *
   * Un `upsert` par ligne plutôt qu'un vidage suivi d'une réécriture : une
   * requête interrompue au milieu laisserait sinon la table vide, et l'export
   * suivant ne remonterait plus rien sans que personne ne l'ait demandé.
   */
  async enregistrerCorrespondances(
    correspondances: Array<{
      indicator: string;
      dataElement: string;
      categoryOptionCombo?: string;
      label?: string;
    }>,
  ) {
    await this.prisma.$transaction(
      correspondances.map((c) =>
        this.prisma.dhis2ElementMapping.upsert({
          where: { indicator: c.indicator },
          create: {
            indicator: c.indicator,
            dataElement: c.dataElement,
            categoryOptionCombo: c.categoryOptionCombo ?? null,
            label: c.label ?? null,
          },
          update: {
            dataElement: c.dataElement,
            categoryOptionCombo: c.categoryOptionCombo ?? null,
            label: c.label ?? null,
          },
        }),
      ),
    );

    return this.etat();
  }

  /**
   * Envoie les dénombrements d'un mois.
   *
   * [periode] au format `AAAA-MM`. DHIS2 attend `AAAAMM` ; la conversion est
   * faite ici pour que l'appelant manipule une date lisible.
   */
  async exporterMois(
    periode: string,
    options: { simulation?: boolean } = {},
  ): Promise<ResultatExport> {
    const connexion = this.connexion();
    if (!connexion) {
      throw new ServiceUnavailableException(
        "La connexion à DHIS2 n'est pas configurée sur ce serveur.",
      );
    }

    const { debut, fin, periodeDhis2 } = this.bornesDuMois(periode);

    const correspondances = await this.prisma.dhis2ElementMapping.findMany();
    if (correspondances.length === 0) {
      throw new BadRequestException(
        "Aucun indicateur n'est rapproché d'un élément de données DHIS2.",
      );
    }
    const parIndicateur = new Map(correspondances.map((c) => [c.indicator, c]));

    const centres = await this.prisma.csb.findMany({
      select: { id: true, name: true, dhis2OrgUnit: true },
      orderBy: { name: 'asc' },
    });

    const retenus = centres.filter((c) => c.dhis2OrgUnit);
    const nonRapproches = centres.filter((c) => !c.dhis2OrgUnit).map((c) => c.name);

    const valeurs: ValeurDhis2[] = [];
    for (const centre of retenus) {
      const totaux = await this.totauxDuCentre(centre.id, debut, fin);

      for (const indicateur of INDICATEURS_DHIS2) {
        const correspondance = parIndicateur.get(indicateur);
        if (!correspondance) continue;

        valeurs.push({
          dataElement: correspondance.dataElement,
          period: periodeDhis2,
          orgUnit: centre.dhis2OrgUnit!,
          value: String(totaux[indicateur]),
          ...(correspondance.categoryOptionCombo
            ? { categoryOptionCombo: correspondance.categoryOptionCombo }
            : {}),
        });
      }
    }

    const base: ResultatExport = {
      periode,
      simulation: options.simulation ?? false,
      valeursEnvoyees: valeurs.length,
      centresRetenus: retenus.length,
      centresNonRapproches: nonRapproches,
      indicateursNonRapproches: INDICATEURS_DHIS2.filter(
        (i) => !parIndicateur.has(i),
      ),
    };

    if (valeurs.length === 0) return base;

    const resume = await this.envoyer(connexion, valeurs, options.simulation ?? false);
    return { ...base, resume };
  }

  /**
   * Dénombrements d'un centre sur la période.
   *
   * Comptés sur `occurred_on`, la date de l'acte, et non sur la date de
   * saisie : un acte fait en brousse et synchronisé trois jours plus tard doit
   * compter dans le mois où il a eu lieu, sinon la remontée nationale se
   * déforme au rythme des connexions.
   */
  private async totauxDuCentre(
    csbId: string,
    debut: string,
    fin: string,
  ): Promise<Record<IndicateurDhis2, number>> {
    const [row] = await this.prisma.$queryRaw<
      Array<Record<string, bigint>>
    >`
      SELECT
        (SELECT count(*) FROM consultations c
           JOIN beneficiaries b ON b.id = c.beneficiary_id
          WHERE c.cancelled_at IS NULL AND b.csb_id = ${csbId}::uuid
            AND c.occurred_on BETWEEN ${debut}::date AND ${fin}::date) AS consultations,
        (SELECT count(*) FROM prenatal_visits v
           JOIN pregnancies p ON p.id = v.pregnancy_id
           JOIN beneficiaries b ON b.id = p.beneficiary_id
          WHERE v.cancelled_at IS NULL AND b.csb_id = ${csbId}::uuid
            AND v.occurred_on BETWEEN ${debut}::date AND ${fin}::date) AS cpn,
        (SELECT count(*) FROM vaccinations vc
           JOIN beneficiaries b ON b.id = vc.beneficiary_id
          WHERE vc.cancelled_at IS NULL AND b.csb_id = ${csbId}::uuid
            AND vc.occurred_on BETWEEN ${debut}::date AND ${fin}::date) AS vaccinations,
        (SELECT count(*) FROM family_planning_activities f
           JOIN beneficiaries b ON b.id = f.beneficiary_id
          WHERE f.cancelled_at IS NULL AND b.csb_id = ${csbId}::uuid
            AND f.occurred_on BETWEEN ${debut}::date AND ${fin}::date) AS pf,
        (SELECT count(*) FROM beneficiaries b
          WHERE b.csb_id = ${csbId}::uuid
            AND b.created_at::date BETWEEN ${debut}::date AND ${fin}::date) AS nouveaux
    `;

    return {
      consultations: Number(row?.consultations ?? 0),
      cpn: Number(row?.cpn ?? 0),
      vaccinations: Number(row?.vaccinations ?? 0),
      planificationFamiliale: Number(row?.pf ?? 0),
      nouveauxDossiers: Number(row?.nouveaux ?? 0),
    };
  }

  private async envoyer(
    connexion: { url: string; entete: string },
    dataValues: ValeurDhis2[],
    simulation: boolean,
  ): Promise<ResultatExport['resume']> {
    const url =
      `${connexion.url}/api/dataValueSets` +
      `?importStrategy=CREATE_AND_UPDATE&dryRun=${simulation}`;

    let reponse: Response;
    try {
      reponse = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: connexion.entete,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({ dataValues }),
        // Une liaison nationale peut être lente ; au-delà, c'est une panne.
        signal: AbortSignal.timeout(120_000),
      });
    } catch {
      // Le détail réseau ne remonte pas : il contiendrait l'adresse interne du
      // serveur, et l'administrateur n'en ferait rien.
      this.logger.warn('DHIS2 injoignable');
      throw new ServiceUnavailableException('Le serveur DHIS2 est injoignable.');
    }

    const corps: unknown = await reponse.json().catch(() => null);

    if (!reponse.ok) {
      this.logger.warn(`DHIS2 a refusé l'import (${reponse.status})`);
      throw new ServiceUnavailableException(
        `DHIS2 a refusé l'import (code ${reponse.status}). ` +
          this.messages(corps).join(' '),
      );
    }

    return this.resumer(corps);
  }

  /** Extrait le compte rendu, quelle que soit la forme de la réponse. */
  private resumer(corps: unknown): ResultatExport['resume'] {
    const reponse = this.objet(this.objet(corps)?.response) ?? this.objet(corps);
    const compte = this.objet(reponse?.importCount) ?? reponse;

    return {
      statut: typeof reponse?.status === 'string' ? reponse.status : 'INCONNU',
      importes: this.entier(compte?.imported),
      misAJour: this.entier(compte?.updated),
      ignores: this.entier(compte?.ignored),
      rejetes: this.entier(compte?.deleted) + this.entier(reponse?.rejected),
      messages: this.messages(corps),
    };
  }

  private messages(corps: unknown): string[] {
    const racine = this.objet(corps);
    const messages: string[] = [];

    if (typeof racine?.message === 'string') messages.push(racine.message);

    const reponse = this.objet(racine?.response);
    const conflits = Array.isArray(reponse?.conflicts) ? reponse.conflicts : [];
    for (const conflit of conflits.slice(0, 10)) {
      const c = this.objet(conflit);
      if (typeof c?.value === 'string') messages.push(c.value);
    }

    return messages;
  }

  private objet(v: unknown): Record<string, unknown> | null {
    return typeof v === 'object' && v !== null ? (v as Record<string, unknown>) : null;
  }

  private entier(v: unknown): number {
    return typeof v === 'number' && Number.isFinite(v) ? v : 0;
  }

  /** `2026-09` → bornes du mois et période au format DHIS2. */
  bornesDuMois(periode: string): {
    debut: string;
    fin: string;
    periodeDhis2: string;
  } {
    if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(periode)) {
      throw new BadRequestException('Période attendue au format AAAA-MM.');
    }

    const [annee, mois] = periode.split('-').map(Number);
    // Jour 0 du mois suivant : le dernier du mois demandé, sans table des
    // durées ni cas particulier pour février.
    const dernier = new Date(Date.UTC(annee, mois, 0)).getUTCDate();

    return {
      debut: `${periode}-01`,
      fin: `${periode}-${String(dernier).padStart(2, '0')}`,
      periodeDhis2: `${annee}${String(mois).padStart(2, '0')}`,
    };
  }
}
