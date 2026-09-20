import { PregnancyOutcome } from '@prisma/client';

import { AuthenticatedUser } from '../auth/types/jwt-payload';
import { PrismaService } from '../prisma/prisma.service';
import { MutationDto } from './dto/sync.dto';
import { SyncService } from './sync.service';

/**
 * Réception des événements de soin.
 *
 * Ces tests portent sur le chemin que prend une consultation saisie hors
 * ligne : c'est lui qui décide si la saisie d'un soignant finit enregistrée ou
 * marquée « refusé » sur son appareil. Les trois issues comptent autant l'une
 * que l'autre — un `rejete` à tort fait perdre la donnée, un `ignore` à tort
 * la fait boucler indéfiniment dans la file.
 */
interface DonneesGrossesse {
  outcome: PregnancyOutcome;
  version: number;
}

describe('SyncService — réception des soins', () => {
  const CSB = 'csb-1';
  const DOSSIER = '0190a000-0000-7000-8000-000000000001';

  const user: AuthenticatedUser = {
    id: 'user-1',
    csbId: CSB,
    role: 'INFIRMIER',
    deviceId: 'device-1',
  };

  let prisma: {
    beneficiary: { findUnique: jest.Mock };
    consultation: { findUnique: jest.Mock; create: jest.Mock };
    pregnancy: {
      findUnique: jest.Mock;
      create: jest.Mock;
      // Typée : le test inspecte les champs écrits, pas seulement l'appel.
      update: jest.Mock<Promise<unknown>, [{ data: DonneesGrossesse }]>;
    };
    prenatalVisit: { findUnique: jest.Mock; create: jest.Mock };
    auditLog: { create: jest.Mock };
  };
  let service: SyncService;

  beforeEach(() => {
    prisma = {
      beneficiary: { findUnique: jest.fn().mockResolvedValue({ csbId: CSB }) },
      consultation: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({}),
      },
      pregnancy: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({}),
        update: jest.fn<Promise<unknown>, [{ data: DonneesGrossesse }]>(
          () => Promise.resolve({}),
        ),
      },
      prenatalVisit: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({}),
      },
      auditLog: { create: jest.fn().mockResolvedValue({}) },
    };
    service = new SyncService(prisma as unknown as PrismaService);
  });

  const consultation = (
    id = '0190a000-0000-7000-8000-000000000002',
    payload: Record<string, unknown> = {},
  ): MutationDto => ({
      entityType: 'consultations',
      entityId: id,
      operation: 'CREATE',
      deviceCreatedAt: '2026-03-01T08:00:00.000Z',
      payload: {
        id,
        beneficiaryId: DOSSIER,
        type: 'CURATIVE',
        occurredOn: '2026-03-01',
        motiveCode: 'FIEVRE',
        treatmentGiven: true,
        referred: false,
        recordedByUserId: 'user-1',
        createdAt: '2026-03-01T08:00:00.000Z',
        ...payload,
      },
    });

  it('enregistre une consultation saisie hors ligne', async () => {
    const { resultats, acceptees } = await service.push(user, [consultation()]);

    expect(acceptees).toBe(1);
    expect(resultats[0].statut).toBe('accepte');
    expect(prisma.consultation.create).toHaveBeenCalledTimes(1);
    expect(prisma.auditLog.create).toHaveBeenCalledTimes(1);
  });

  it('ignore un renvoi sans créer de doublon', async () => {
    // Le cas réel : la réponse s'est perdue sur une connexion 2G et
    // l'appareil rejoue sa file. L'identifiant venant de l'appareil, le
    // renvoi retombe sur la même ligne.
    prisma.consultation.findUnique.mockResolvedValue({ id: 'déjà là' });

    const { resultats } = await service.push(user, [consultation()]);

    expect(resultats[0].statut).toBe('ignore');
    expect(prisma.consultation.create).not.toHaveBeenCalled();
  });

  it('fait réessayer quand le dossier n’est pas encore arrivé', async () => {
    // « ignore » serait ici une perte de donnée : l'acte doit rester en file.
    prisma.beneficiary.findUnique.mockResolvedValue(null);

    const { resultats, rejetees } = await service.push(user, [consultation()]);

    expect(resultats[0].statut).toBe('ignore');
    expect(rejetees).toBe(0);
    expect(prisma.consultation.create).not.toHaveBeenCalled();
  });

  it('refuse un acte sur un dossier d’un autre centre', async () => {
    prisma.beneficiary.findUnique.mockResolvedValue({ csbId: 'csb-2' });

    const { resultats } = await service.push(user, [consultation()]);

    expect(resultats[0].statut).toBe('rejete');
    expect(prisma.consultation.create).not.toHaveBeenCalled();
  });

  it('refuse un code inconnu au lieu de retomber sur une valeur par défaut', async () => {
    // Écrire « AUTRE » à la place fausserait silencieusement les indicateurs.
    const { resultats } = await service.push(user, [
      consultation('0190a000-0000-7000-8000-000000000003', { type: 'INVENTE' }),
    ]);

    expect(resultats[0].statut).toBe('rejete');
    expect(prisma.consultation.create).not.toHaveBeenCalled();
  });

  it('refuse une charge utile dont l’identifiant ne correspond pas', async () => {
    const mutation = consultation();
    mutation.payload = { ...mutation.payload, id: 'un-autre-id' };

    const { resultats } = await service.push(user, [mutation]);

    expect(resultats[0].statut).toBe('rejete');
  });

  it('n’interrompt pas le lot sur une mutation invalide', async () => {
    const { resultats, acceptees } = await service.push(user, [
      consultation('0190a000-0000-7000-8000-000000000004', { type: 'INVENTE' }),
      consultation('0190a000-0000-7000-8000-000000000005'),
    ]);

    expect(resultats[0].statut).toBe('rejete');
    expect(resultats[1].statut).toBe('accepte');
    expect(acceptees).toBe(1);
  });

  describe('grossesse', () => {
    const GROSSESSE = '0190a000-0000-7000-8000-00000000000a';

    const grossesse = (
      quand: string,
      payload: Record<string, unknown> = {},
    ): MutationDto =>
      ({
        entityType: 'pregnancies',
        entityId: GROSSESSE,
        operation: 'UPDATE',
        deviceCreatedAt: quand,
        payload: {
          id: GROSSESSE,
          beneficiaryId: DOSSIER,
          lastPeriodDate: '2025-08-01',
          expectedDeliveryOn: '2026-05-08',
          gravida: 2,
          para: 1,
          outcome: 'EN_COURS',
          version: 1,
          createdByUserId: 'user-1',
          createdAt: '2025-09-01T08:00:00.000Z',
          ...payload,
        },
      });

    it('met à jour l’issue quand la femme accouche', async () => {
      // Une grossesse n'est pas un acte : elle est ouverte puis close. Un
      // « créer si absent » la figerait à EN_COURS pour toujours.
      prisma.pregnancy.findUnique.mockResolvedValue({
        deviceUpdatedAt: new Date('2025-09-01T08:00:00.000Z'),
        version: 1,
      });

      const { resultats } = await service.push(user, [
        grossesse('2026-05-06T10:00:00.000Z', {
          outcome: 'ACCOUCHEMENT_VIVANT',
          outcomeDate: '2026-05-06',
        }),
      ]);

      expect(resultats[0].statut).toBe('accepte');
      const ecrit = prisma.pregnancy.update.mock.calls[0][0].data;
      expect(ecrit.outcome).toBe(PregnancyOutcome.ACCOUCHEMENT_VIVANT);
      expect(ecrit.version).toBe(2);
    });

    it('ignore une mise à jour plus ancienne que celle du serveur', async () => {
      prisma.pregnancy.findUnique.mockResolvedValue({
        deviceUpdatedAt: new Date('2026-05-06T10:00:00.000Z'),
        version: 2,
      });

      const { resultats } = await service.push(user, [
        grossesse('2026-05-01T10:00:00.000Z'),
      ]);

      expect(resultats[0].statut).toBe('ignore');
      expect(prisma.pregnancy.update).not.toHaveBeenCalled();
    });
  });

  it('rattache une CPN au centre via sa grossesse', async () => {
    // La CPN ne porte pas de beneficiaryId : sans cette remontée, un appareil
    // pourrait écrire sur le dossier d'un autre centre.
    prisma.pregnancy.findUnique.mockResolvedValue({ beneficiaryId: DOSSIER });
    prisma.beneficiary.findUnique.mockResolvedValue({ csbId: 'csb-2' });

    const id = '0190a000-0000-7000-8000-00000000000b';
    const { resultats } = await service.push(user, [
      {
        entityType: 'prenatal_visits',
        entityId: id,
        operation: 'CREATE',
        deviceCreatedAt: '2026-03-01T08:00:00.000Z',
        payload: {
          id,
          pregnancyId: '0190a000-0000-7000-8000-00000000000a',
          visitNumber: 1,
          occurredOn: '2026-03-01',
          riskFactorCodes: [],
          recordedByUserId: 'user-1',
          createdAt: '2026-03-01T08:00:00.000Z',
        },
      },
    ]);

    expect(resultats[0].statut).toBe('rejete');
    expect(prisma.prenatalVisit.create).not.toHaveBeenCalled();
  });
});
