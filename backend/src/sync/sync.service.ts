import { ForbiddenException, Injectable, Logger } from '@nestjs/common';
import {
  AuditAction,
  ConsultationType,
  FamilyPlanningActType,
  FamilyPlanningMethod,
  PregnancyOutcome,
  Prisma,
  Sex,
  VaccineCode,
} from '@prisma/client';
import { uuidv7 } from 'uuidv7';

import { AuthenticatedUser } from '../auth/types/jwt-payload';
import { PrismaService } from '../prisma/prisma.service';
import { MutationDto } from './dto/sync.dto';

export interface ResultatMutation {
  entityId: string;
  entityType: string;
  /**
   * `accepte` : écrit, ou déjà présent à l'identique.
   * `ignore` : le serveur détient une version plus récente (décision D6).
   * `rejete` : la donnée est invalide ou hors périmètre. **Ne pas réessayer.**
   */
  statut: 'accepte' | 'ignore' | 'rejete';
  motif?: string;
}

/**
 * Synchronisation entre la base locale d'un appareil et le serveur.
 *
 * Deux sens, deux logiques :
 *
 * **Push** — l'appareil envoie ce qu'il a créé hors ligne. Chaque mutation
 * porte l'identifiant attribué par l'appareil, ce qui rend l'envoi idempotent :
 * une réponse perdue sur une connexion instable se solde par un renvoi, et le
 * renvoi ne crée pas de doublon. C'est la propriété qui rend la
 * synchronisation sûre sur les réseaux des CSB.
 *
 * **Pull** — l'appareil réclame ce qui a changé depuis sa dernière visite.
 * Incrémental par `serverUpdatedAt`, borné au centre de l'utilisateur.
 *
 * Un appareil qui échoue à envoyer ne perd rien : sa base locale reste la
 * source de vérité et la file est rejouée au prochain passage (CDC §6).
 */
@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ---------------------------------------------------------------------
  // Push
  // ---------------------------------------------------------------------

  async push(user: AuthenticatedUser, mutations: MutationDto[]) {
    const csbId = this.requireCsb(user);
    const resultats: ResultatMutation[] = [];

    // Traitées une par une et non en bloc : une mutation invalide au milieu du
    // lot ne doit pas faire échouer les autres, sinon un seul enregistrement
    // corrompu bloquerait définitivement la file d'un appareil.
    for (const mutation of mutations) {
      try {
        resultats.push(await this.appliquer(user, csbId, mutation));
      } catch (erreur) {
        // Le message d'erreur peut contenir des valeurs de champs : il ne part
        // pas dans les journaux, seulement le type d'entité.
        this.logger.warn(
          `Mutation refusée (${mutation.entityType}) pour l'appareil ${user.deviceId}`,
        );
        resultats.push({
          entityId: mutation.entityId,
          entityType: mutation.entityType,
          statut: 'rejete',
          motif: erreur instanceof Error ? erreur.message : 'Donnée invalide',
        });
      }
    }

    return {
      serverTime: new Date().toISOString(),
      resultats,
      acceptees: resultats.filter((r) => r.statut === 'accepte').length,
      rejetees: resultats.filter((r) => r.statut === 'rejete').length,
    };
  }

  private async appliquer(
    user: AuthenticatedUser,
    csbId: string,
    mutation: MutationDto,
  ): Promise<ResultatMutation> {
    const base = { entityId: mutation.entityId, entityType: mutation.entityType };

    switch (mutation.entityType) {
      case 'beneficiaries':
        return this.appliquerBeneficiaire(user, csbId, mutation);
      case 'pregnancies':
        return this.appliquerGrossesse(user, csbId, mutation);
      case 'consultations':
      case 'vaccinations':
      case 'family_planning_activities':
      case 'prenatal_visits':
        return this.appliquerEvenementDeSoin(user, csbId, mutation);
      default: {
        // Inatteignable : le DTO borne déjà `entityType`. La garde est là pour
        // que l'ajout d'une entité sans chemin de réception casse à la
        // compilation, et non en production.
        const jamais: never = mutation.entityType;
        return { ...base, statut: 'rejete', motif: `Type inconnu : ${String(jamais)}` };
      }
    }
  }

  private async appliquerBeneficiaire(
    user: AuthenticatedUser,
    csbId: string,
    mutation: MutationDto,
  ): Promise<ResultatMutation> {
    const p = mutation.payload;
    const base = { entityId: mutation.entityId, entityType: mutation.entityType };

    const champs = {
      id: this.texte(p.id, 'id'),
      localId: this.texte(p.localId, 'localId'),
      firstName: this.texte(p.firstName, 'firstName'),
      lastName: this.texte(p.lastName, 'lastName'),
      sex: this.sexe(p.sex),
      birthDate: this.dateCalendaire(p.birthDate),
      birthDateIsEstimated: p.birthDateIsEstimated === true,
      phone: this.texteFacultatif(p.phone),
      fokontany: this.texteFacultatif(p.fokontany),
      address: this.texteFacultatif(p.address),
      version: typeof p.version === 'number' ? p.version : 1,
      deviceUpdatedAt: new Date(mutation.deviceCreatedAt),
    };

    if (champs.id !== mutation.entityId) {
      return { ...base, statut: 'rejete', motif: 'Identifiant incohérent' };
    }

    const existant = await this.prisma.beneficiary.findUnique({
      where: { id: champs.id },
    });

    if (!existant) {
      await this.prisma.beneficiary.create({
        data: { ...champs, csbId, createdByUserId: user.id },
      });
      await this.audit(user, AuditAction.CREATE, champs.id, []);
      return { ...base, statut: 'accepte' };
    }

    // Un dossier appartenant à un autre centre n'est pas « déjà reçu » : c'est
    // une tentative d'écriture hors périmètre.
    if (existant.csbId !== csbId) {
      throw new ForbiddenException('Dossier hors de votre centre');
    }

    // Dernier écrit gagne, arbitré par l'horodatage de l'appareil (décision
    // D6). Une mutation plus ancienne que ce que détient le serveur est
    // ignorée, pas rejetée : l'appareil doit la retirer de sa file sans la
    // considérer comme une erreur.
    if (existant.deviceUpdatedAt >= champs.deviceUpdatedAt) {
      return {
        ...base,
        statut: 'ignore',
        motif: 'Le serveur détient une version plus récente',
      };
    }

    const modifies = this.champsModifies(existant, champs);

    await this.prisma.beneficiary.update({
      where: { id: champs.id },
      data: { ...champs, version: existant.version + 1 },
    });

    // Un écrasement est consigné pour rattrapage manuel : c'est la
    // contrepartie du « dernier écrit gagne ».
    await this.audit(
      user,
      modifies.length > 0 ? AuditAction.SYNC_CONFLICT : AuditAction.UPDATE,
      champs.id,
      modifies,
    );

    return { ...base, statut: 'accepte' };
  }

  /**
   * Enregistre un événement de soin.
   *
   * Ces entités sont **immuables** : une consultation, une vaccination ou une
   * CPN décrit un fait passé, que rien ne vient corriger ensuite. La réception
   * est donc un simple « créer si absent » — aucun conflit n'est possible,
   * puisque deux appareils ne produisent jamais le même identifiant.
   *
   * La grossesse fait exception et passe par {@link appliquerGrossesse} : son
   * issue change quand la femme accouche.
   */
  private async appliquerEvenementDeSoin(
    user: AuthenticatedUser,
    csbId: string,
    mutation: MutationDto,
  ): Promise<ResultatMutation> {
    const p = mutation.payload;
    const base = { entityId: mutation.entityId, entityType: mutation.entityType };

    if (this.texte(p.id, 'id') !== mutation.entityId) {
      return { ...base, statut: 'rejete', motif: 'Identifiant incohérent' };
    }

    // Le rattachement au centre est vérifié via le dossier : un appareil ne
    // doit pas pouvoir écrire un acte sur un dossier d'un autre CSB, même en
    // forgeant la requête.
    const beneficiaryId = await this.dossierDeLEvenement(mutation, p);
    const dossier = beneficiaryId
      ? await this.prisma.beneficiary.findUnique({
          where: { id: beneficiaryId },
          select: { csbId: true },
        })
      : null;

    if (!dossier) {
      // Le dossier n'est pas encore arrivé. Ce n'est pas une erreur : si son
      // envoi a échoué, l'acte le précède dans la file. On laisse l'appareil
      // réessayer au prochain passage.
      return {
        ...base,
        statut: 'ignore',
        motif: 'Dossier pas encore reçu, sera renvoyé',
      };
    }

    if (dossier.csbId !== csbId) {
      throw new ForbiddenException('Dossier hors de votre centre');
    }

    const cree = await this.creerEvenement(mutation, p, user);
    if (!cree) {
      // Déjà reçu : l'identifiant vient de l'appareil, donc un renvoi tombe
      // sur la même ligne. C'est exactement ce qu'on veut.
      return { ...base, statut: 'ignore', motif: 'Déjà enregistré' };
    }

    await this.auditEvenement(user, mutation.entityType, mutation.entityId);
    return { ...base, statut: 'accepte' };
  }

  /**
   * Enregistre ou met à jour une grossesse.
   *
   * Contrairement aux actes, une grossesse **vit** : elle est ouverte à la
   * première CPN, puis close par un accouchement. Elle suit donc le même
   * arbitrage que le dossier — dernier écrit gagne, sur l'horodatage de
   * l'appareil (décision D6).
   */
  private async appliquerGrossesse(
    user: AuthenticatedUser,
    csbId: string,
    mutation: MutationDto,
  ): Promise<ResultatMutation> {
    const p = mutation.payload;
    const base = { entityId: mutation.entityId, entityType: mutation.entityType };
    const id = this.texte(p.id, 'id');

    if (id !== mutation.entityId) {
      return { ...base, statut: 'rejete', motif: 'Identifiant incohérent' };
    }

    const beneficiaryId = this.texte(p.beneficiaryId, 'beneficiaryId');
    const dossier = await this.prisma.beneficiary.findUnique({
      where: { id: beneficiaryId },
      select: { csbId: true },
    });

    if (!dossier) {
      return {
        ...base,
        statut: 'ignore',
        motif: 'Dossier pas encore reçu, sera renvoyé',
      };
    }
    if (dossier.csbId !== csbId) {
      throw new ForbiddenException('Dossier hors de votre centre');
    }

    // Chaque mutation est datée au moment où l'appareil l'a mise en file :
    // c'est cet horodatage qui arbitre, comme pour le dossier.
    const surLAppareil = new Date(mutation.deviceCreatedAt);
    const champs = {
      lastPeriodDate: this.dateFacultative(p.lastPeriodDate),
      expectedDeliveryOn: this.dateFacultative(p.expectedDeliveryOn),
      gravida: this.entier(p.gravida),
      para: this.entier(p.para),
      outcome: this.enumFacultatif(p.outcome, PregnancyOutcome) ?? PregnancyOutcome.EN_COURS,
      outcomeDate: this.dateFacultative(p.outcomeDate),
      deviceUpdatedAt: surLAppareil,
    };

    const existante = await this.prisma.pregnancy.findUnique({
      where: { id },
      select: { deviceUpdatedAt: true, version: true },
    });

    if (!existante) {
      await this.prisma.pregnancy.create({
        data: {
          id,
          beneficiaryId,
          ...champs,
          version: this.entier(p.version) ?? 1,
          createdByUserId: this.texteFacultatif(p.createdByUserId) ?? user.id,
          createdAt: this.instant(p.createdAt),
        },
      });
      await this.auditEvenement(user, mutation.entityType, id, AuditAction.CREATE);
      return { ...base, statut: 'accepte' };
    }

    if (existante.deviceUpdatedAt >= surLAppareil) {
      return {
        ...base,
        statut: 'ignore',
        motif: 'Le serveur détient une version plus récente',
      };
    }

    await this.prisma.pregnancy.update({
      where: { id },
      data: { ...champs, version: existante.version + 1 },
    });
    await this.auditEvenement(user, mutation.entityType, id, AuditAction.UPDATE);
    return { ...base, statut: 'accepte' };
  }

  /** Dossier auquel se rattache un événement, directement ou via sa grossesse. */
  private async dossierDeLEvenement(
    mutation: MutationDto,
    p: Record<string, unknown>,
  ): Promise<string> {
    if (mutation.entityType === 'prenatal_visits') {
      const grossesse = await this.prisma.pregnancy.findUnique({
        where: { id: this.texte(p.pregnancyId, 'pregnancyId') },
        select: { beneficiaryId: true },
      });
      // Chaîne vide plutôt qu'une exception : l'appelant la traite comme
      // « pas encore reçu » et fera réessayer.
      return grossesse?.beneficiaryId ?? '';
    }
    return this.texte(p.beneficiaryId, 'beneficiaryId');
  }

  /** Renvoie false si l'enregistrement existait déjà. */
  private async creerEvenement(
    mutation: MutationDto,
    p: Record<string, unknown>,
    user: AuthenticatedUser,
  ): Promise<boolean> {
    const id = this.texte(p.id, 'id');
    const auteur = this.texteFacultatif(p.recordedByUserId) ?? user.id;
    const creeLe = this.instant(p.createdAt);
    const surLAppareil = new Date(mutation.deviceCreatedAt);

    switch (mutation.entityType) {
      case 'consultations': {
        if (await this.prisma.consultation.findUnique({ where: { id } })) return false;
        await this.prisma.consultation.create({
          data: {
            id,
            beneficiaryId: this.texte(p.beneficiaryId, 'beneficiaryId'),
            type: this.enumValue(p.type, ConsultationType, 'type'),
            occurredOn: this.dateCalendaire(p.occurredOn),
            motiveCode: this.texte(p.motiveCode, 'motiveCode'),
            diagnosisCode: this.texteFacultatif(p.diagnosisCode),
            weightKg: this.nombre(p.weightKg),
            temperatureC: this.nombre(p.temperatureC),
            bloodPressureSys: this.entier(p.bloodPressureSys),
            bloodPressureDia: this.entier(p.bloodPressureDia),
            treatmentGiven: p.treatmentGiven === true,
            referred: p.referred === true,
            referredTo: this.texteFacultatif(p.referredTo),
            notes: this.texteFacultatif(p.notes),
            recordedByUserId: auteur,
            deviceCreatedAt: surLAppareil,
            createdAt: creeLe,
          },
        });
        return true;
      }

      case 'vaccinations': {
        if (await this.prisma.vaccination.findUnique({ where: { id } })) return false;
        await this.prisma.vaccination.create({
          data: {
            id,
            beneficiaryId: this.texte(p.beneficiaryId, 'beneficiaryId'),
            vaccine: this.enumValue(p.vaccine, VaccineCode, 'vaccine'),
            doseNumber: this.entier(p.doseNumber) ?? 1,
            occurredOn: this.dateCalendaire(p.occurredOn),
            lotNumber: this.texteFacultatif(p.lotNumber),
            recordedByUserId: auteur,
            deviceCreatedAt: surLAppareil,
            createdAt: creeLe,
          },
        });
        return true;
      }

      case 'family_planning_activities': {
        if (await this.prisma.familyPlanningActivity.findUnique({ where: { id } })) {
          return false;
        }
        await this.prisma.familyPlanningActivity.create({
          data: {
            id,
            beneficiaryId: this.texte(p.beneficiaryId, 'beneficiaryId'),
            method: this.enumValue(p.method, FamilyPlanningMethod, 'method'),
            actType: this.enumValue(p.actType, FamilyPlanningActType, 'actType'),
            occurredOn: this.dateCalendaire(p.occurredOn),
            quantity: this.entier(p.quantity),
            recordedByUserId: auteur,
            deviceCreatedAt: surLAppareil,
            createdAt: creeLe,
          },
        });
        return true;
      }

      case 'prenatal_visits': {
        if (await this.prisma.prenatalVisit.findUnique({ where: { id } })) return false;
        await this.prisma.prenatalVisit.create({
          data: {
            id,
            pregnancyId: this.texte(p.pregnancyId, 'pregnancyId'),
            visitNumber: this.entier(p.visitNumber) ?? 1,
            occurredOn: this.dateCalendaire(p.occurredOn),
            gestationalAgeWeeks: this.entier(p.gestationalAgeWeeks),
            weightKg: this.nombre(p.weightKg),
            bloodPressureSys: this.entier(p.bloodPressureSys),
            bloodPressureDia: this.entier(p.bloodPressureDia),
            fundalHeightCm: this.nombre(p.fundalHeightCm),
            fetalHeartRate: this.entier(p.fetalHeartRate),
            tetanusVaccineGiven: p.tetanusVaccineGiven === true,
            ironFolateGiven: p.ironFolateGiven === true,
            malariaPreventionGiven: p.malariaPreventionGiven === true,
            insecticideNetGiven: p.insecticideNetGiven === true,
            riskFactorCodes: Array.isArray(p.riskFactorCodes)
              ? p.riskFactorCodes.filter((c): c is string => typeof c === 'string')
              : [],
            referred: p.referred === true,
            referredTo: this.texteFacultatif(p.referredTo),
            notes: this.texteFacultatif(p.notes),
            recordedByUserId: auteur,
            deviceCreatedAt: surLAppareil,
            createdAt: creeLe,
          },
        });
        return true;
      }

      default:
        throw new Error('Type non pris en charge');
    }
  }

  private async auditEvenement(
    user: AuthenticatedUser,
    entityType: string,
    entityId: string,
    action: AuditAction = AuditAction.CREATE,
  ): Promise<void> {
    await this.prisma.auditLog.create({
      data: {
        id: uuidv7(),
        userId: user.id,
        csbId: user.csbId,
        action,
        entityType,
        entityId,
        changedFields: [],
        deviceId: user.deviceId,
      },
    });
  }

  // ---------------------------------------------------------------------
  // Pull
  // ---------------------------------------------------------------------

  /**
   * Renvoie ce qui a changé depuis [depuis], borné au centre de l'utilisateur.
   *
   * `serverTime` est renvoyé pour que l'appareil s'en serve comme curseur au
   * prochain appel, plutôt que de son horloge à lui : c'est l'horloge du
   * serveur qui ordonne les changements, et celle de l'appareil peut dériver.
   */
  async pull(user: AuthenticatedUser, depuis?: string, limite = 500) {
    const csbId = this.requireCsb(user);
    const serverTime = new Date().toISOString();
    const apres = depuis ? new Date(depuis) : new Date(0);
    const take = Math.min(limite, 1000);

    const filtreDossier: Prisma.BeneficiaryWhereInput = {
      csbId,
      serverUpdatedAt: { gt: apres },
    };

    // Les événements de soin n'ont pas de `serverUpdatedAt` : ils sont
    // immuables, donc leur date de création suffit à les ordonner.
    const parDossier = { beneficiary: { csbId } };
    const cree = { createdAt: { gt: apres } };

    const [beneficiaries, consultations, vaccinations, familyPlanning, pregnancies] =
      await Promise.all([
        this.prisma.beneficiary.findMany({
          where: filtreDossier,
          orderBy: { serverUpdatedAt: 'asc' },
          take,
        }),
        this.prisma.consultation.findMany({
          where: { ...parDossier, ...cree },
          orderBy: { createdAt: 'asc' },
          take,
        }),
        this.prisma.vaccination.findMany({
          where: { ...parDossier, ...cree },
          orderBy: { createdAt: 'asc' },
          take,
        }),
        this.prisma.familyPlanningActivity.findMany({
          where: { ...parDossier, ...cree },
          orderBy: { createdAt: 'asc' },
          take,
        }),
        this.prisma.pregnancy.findMany({
          where: { ...parDossier, serverUpdatedAt: { gt: apres } },
          orderBy: { serverUpdatedAt: 'asc' },
          take,
        }),
      ]);

    const prenatalVisits = await this.prisma.prenatalVisit.findMany({
      where: { pregnancy: { beneficiary: { csbId } }, ...cree },
      orderBy: { createdAt: 'asc' },
      take,
    });

    const lots = [
      beneficiaries,
      consultations,
      vaccinations,
      familyPlanning,
      pregnancies,
      prenatalVisits,
    ];

    return {
      serverTime,
      // Vrai si un lot est plein : l'appareil doit rappeler pour la suite.
      // Sans ce signal, il croirait avoir tout reçu et s'arrêterait au milieu.
      hasMore: lots.some((l) => l.length === take),
      beneficiaries: beneficiaries.map((b) => ({
        ...b,
        birthDate: b.birthDate.toISOString().slice(0, 10),
      })),
      consultations: consultations.map((c) => ({
        ...c,
        occurredOn: c.occurredOn.toISOString().slice(0, 10),
      })),
      vaccinations: vaccinations.map((v) => ({
        ...v,
        occurredOn: v.occurredOn.toISOString().slice(0, 10),
      })),
      familyPlanning: familyPlanning.map((f) => ({
        ...f,
        occurredOn: f.occurredOn.toISOString().slice(0, 10),
      })),
      pregnancies: pregnancies.map((g) => ({
        ...g,
        lastPeriodDate: g.lastPeriodDate?.toISOString().slice(0, 10) ?? null,
        expectedDeliveryOn: g.expectedDeliveryOn?.toISOString().slice(0, 10) ?? null,
        outcomeDate: g.outcomeDate?.toISOString().slice(0, 10) ?? null,
      })),
      prenatalVisits: prenatalVisits.map((v) => ({
        ...v,
        occurredOn: v.occurredOn.toISOString().slice(0, 10),
      })),
    };
  }

  // ---------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------

  private texte(valeur: unknown, champ: string): string {
    if (typeof valeur !== 'string' || valeur.trim() === '') {
      throw new Error(`Champ « ${champ} » manquant`);
    }
    return valeur.trim();
  }

  private texteFacultatif(valeur: unknown): string | null {
    return typeof valeur === 'string' && valeur.trim() !== '' ? valeur.trim() : null;
  }

  private sexe(valeur: unknown): Sex {
    if (valeur !== 'F' && valeur !== 'M') throw new Error('Sexe invalide');
    return valeur;
  }

  private nombre(valeur: unknown): number | null {
    return typeof valeur === 'number' && Number.isFinite(valeur) ? valeur : null;
  }

  private entier(valeur: unknown): number | null {
    return typeof valeur === 'number' && Number.isInteger(valeur) ? valeur : null;
  }

  private instant(valeur: unknown): Date {
    const d = typeof valeur === 'string' ? new Date(valeur) : null;
    return d && !Number.isNaN(d.getTime()) ? d : new Date();
  }

  private dateFacultative(valeur: unknown): Date | null {
    return typeof valeur === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(valeur)
      ? new Date(valeur)
      : null;
  }

  /** Variante tolérante : une valeur absente ou vide rend null. */
  private enumFacultatif<T extends Record<string, string>>(
    valeur: unknown,
    enumeration: T,
  ): T[keyof T] | null {
    if (typeof valeur === 'string' && Object.values(enumeration).includes(valeur)) {
      return valeur as T[keyof T];
    }
    return null;
  }

  /**
   * Valide une valeur d'énumération venue de l'appareil.
   *
   * Une version plus ancienne de l'application peut envoyer un code retiré
   * depuis, une plus récente un code que le serveur ignore. Refuser
   * explicitement vaut mieux qu'écrire une valeur par défaut, qui fausserait
   * silencieusement les indicateurs.
   */
  private enumValue<T extends Record<string, string>>(
    valeur: unknown,
    enumeration: T,
    champ: string,
  ): T[keyof T] {
    if (typeof valeur === 'string' && Object.values(enumeration).includes(valeur)) {
      return valeur as T[keyof T];
    }
    throw new Error(`Valeur de « ${champ} » inconnue`);
  }

  private dateCalendaire(valeur: unknown): Date {
    if (typeof valeur !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(valeur)) {
      throw new Error('Date de naissance invalide');
    }
    return new Date(valeur);
  }

  /** Noms des champs qui diffèrent. Jamais leurs valeurs. */
  private champsModifies(
    avant: Record<string, unknown>,
    apres: Record<string, unknown>,
  ): string[] {
    const suivis = [
      'firstName',
      'lastName',
      'sex',
      'birthDate',
      'phone',
      'fokontany',
      'address',
    ];
    return suivis.filter((c) => this.comparable(avant[c]) !== this.comparable(apres[c]));
  }

  /**
   * Réduit une valeur à une chaîne comparable.
   *
   * `String()` seul produirait « [object Object] » sur une Date, et deux dates
   * différentes paraîtraient identiques : le conflit passerait inaperçu.
   */
  private comparable(valeur: unknown): string {
    if (valeur === null || valeur === undefined) return '';
    if (valeur instanceof Date) return valeur.toISOString();
    if (typeof valeur === 'string') return valeur;
    if (typeof valeur === 'number' || typeof valeur === 'boolean') {
      return String(valeur);
    }
    return JSON.stringify(valeur);
  }

  private requireCsb(user: AuthenticatedUser): string {
    if (!user.csbId) {
      throw new ForbiddenException("Votre profil n'accède pas aux dossiers individuels");
    }
    return user.csbId;
  }

  private async audit(
    user: AuthenticatedUser,
    action: AuditAction,
    entityId: string,
    changedFields: string[],
  ): Promise<void> {
    await this.prisma.auditLog.create({
      data: {
        id: uuidv7(),
        userId: user.id,
        csbId: user.csbId,
        action,
        entityType: 'Beneficiary',
        entityId,
        changedFields,
        deviceId: user.deviceId,
      },
    });
  }
}
