import { ForbiddenException, Injectable, Logger } from '@nestjs/common';
import { AuditAction, Prisma, Sex } from '@prisma/client';
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

    if (mutation.entityType !== 'beneficiaries') {
      // Les événements de soin n'ont pas encore de producteur : leur saisie
      // arrive aux tickets 2.4 à 2.7. Plutôt que d'écrire un chemin jamais
      // exercé, on le refuse explicitement — l'appareil saura que ce n'est pas
      // une panne réseau et cessera de réessayer.
      return {
        ...base,
        statut: 'rejete',
        motif: `La synchronisation de « ${mutation.entityType} » arrive avec sa saisie (tickets 2.4 à 2.7).`,
      };
    }

    return this.appliquerBeneficiaire(user, csbId, mutation);
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
