import { ConfigService } from '@nestjs/config';

import { PrismaService } from '../prisma/prisma.service';
import { Dhis2Service } from './dhis2.service';

/**
 * Remontée vers DHIS2.
 *
 * Ce qui est vérifié ici tient en une phrase : **un chiffre ne doit jamais
 * partir sur le mauvais centre**. Une remontée nationale fausse est plus
 * nuisible qu'une remontée absente, parce que personne ne la voit passer.
 */
describe('Dhis2Service', () => {
  const CONFIG = {
    DHIS2_URL: 'https://play.im.dhis2.org/stable-2-43-1',
    DHIS2_USERNAME: 'admin',
    DHIS2_PASSWORD: 'district',
  } as Record<string, string>;

  let prisma: {
    dhis2ElementMapping: { findMany: jest.Mock };
    csb: { findMany: jest.Mock; count: jest.Mock };
    $queryRaw: jest.Mock;
  };
  let service: Dhis2Service;
  let envoye: { url: string; corps: { dataValues: unknown[] } } | null;

  beforeEach(() => {
    envoye = null;

    prisma = {
      dhis2ElementMapping: {
        findMany: jest.fn().mockResolvedValue([
          { indicator: 'consultations', dataElement: 'fbfJHSPpUQD', categoryOptionCombo: 'pq2XI5kz2BY' },
          { indicator: 'cpn', dataElement: 'aaaaaaaaaaa', categoryOptionCombo: null },
        ]),
      },
      csb: {
        findMany: jest.fn().mockResolvedValue([
          { id: 'csb-1', name: 'CSB II Alpha', dhis2OrgUnit: 'Rp268JB6Ne4' },
          { id: 'csb-2', name: 'CSB I Beta', dhis2OrgUnit: null },
        ]),
        count: jest.fn().mockResolvedValue(2),
      },
      $queryRaw: jest.fn().mockResolvedValue([
        { consultations: 12n, cpn: 5n, vaccinations: 9n, pf: 3n, nouveaux: 2n },
      ]),
    };

    const compteRendu = {
      status: 'OK',
      response: {
        status: 'SUCCESS',
        importCount: { imported: 2, updated: 0, ignored: 0, deleted: 0 },
      },
    };

    global.fetch = jest.fn((url: string, init: { body: string }) => {
      envoye = { url, corps: JSON.parse(init.body) as { dataValues: unknown[] } };
      return Promise.resolve({
        ok: true,
        status: 200,
        json: () => Promise.resolve(compteRendu),
      });
    }) as unknown as typeof fetch;

    service = new Dhis2Service(
      prisma as unknown as PrismaService,
      { get: (c: string) => CONFIG[c] } as unknown as ConfigService,
    );
  });

  describe('bornes du mois', () => {
    it('traduit la période au format attendu par DHIS2', () => {
      expect(service.bornesDuMois('2026-09')).toEqual({
        debut: '2026-09-01',
        fin: '2026-09-30',
        periodeDhis2: '202609',
      });
    });

    it('trouve le dernier jour de février, année bissextile comprise', () => {
      expect(service.bornesDuMois('2026-02').fin).toBe('2026-02-28');
      expect(service.bornesDuMois('2028-02').fin).toBe('2028-02-29');
    });

    it('refuse une période mal formée', () => {
      expect(() => service.bornesDuMois('2026-13')).toThrow();
      expect(() => service.bornesDuMois('septembre')).toThrow();
    });
  });

  describe('export', () => {
    it("n'envoie que les centres rapprochés à une unité DHIS2", async () => {
      // Un centre sans unité est absent de l'export. Deviner son unité
      // écrirait ses chiffres sur un autre centre, sans que rien ne le montre.
      const r = await service.exporterMois('2026-09');

      expect(r.centresRetenus).toBe(1);
      expect(r.centresNonRapproches).toEqual(['CSB I Beta']);
      expect(envoye!.corps.dataValues).toHaveLength(2);
      expect(envoye!.corps.dataValues).toEqual([
        {
          dataElement: 'fbfJHSPpUQD',
          period: '202609',
          orgUnit: 'Rp268JB6Ne4',
          value: '12',
          categoryOptionCombo: 'pq2XI5kz2BY',
        },
        {
          dataElement: 'aaaaaaaaaaa',
          period: '202609',
          orgUnit: 'Rp268JB6Ne4',
          value: '5',
        },
      ]);
    });

    it('omet la combinaison de catégories quand elle est absente', async () => {
      // DHIS2 applique alors la combinaison par défaut. En envoyer une vide
      // ferait rejeter la valeur.
      await service.exporterMois('2026-09');
      expect(envoye!.corps.dataValues[1]).not.toHaveProperty('categoryOptionCombo');
    });

    it('signale les indicateurs qui ne sont pas rapprochés', async () => {
      const r = await service.exporterMois('2026-09');
      expect(r.indicateursNonRapproches).toEqual([
        'vaccinations',
        'planificationFamiliale',
        'nouveauxDossiers',
      ]);
    });

    it('propose une simulation qui ne change rien côté DHIS2', async () => {
      await service.exporterMois('2026-09', { simulation: true });
      expect(envoye!.url).toContain('dryRun=true');
    });

    it('écrit pour de bon quand la simulation est désactivée', async () => {
      await service.exporterMois('2026-09');
      expect(envoye!.url).toContain('dryRun=false');
      expect(envoye!.url).toContain('importStrategy=CREATE_AND_UPDATE');
    });

    it("reprend le compte rendu d'import de DHIS2", async () => {
      const r = await service.exporterMois('2026-09');
      expect(r.resume).toMatchObject({ statut: 'SUCCESS', importes: 2 });
    });

    it("n'appelle pas DHIS2 quand il n'y a rien à envoyer", async () => {
      prisma.csb.findMany.mockResolvedValue([]);
      const r = await service.exporterMois('2026-09');

      expect(r.valeursEnvoyees).toBe(0);
      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('refuse quand aucun indicateur n’est rapproché', async () => {
      prisma.dhis2ElementMapping.findMany.mockResolvedValue([]);
      await expect(service.exporterMois('2026-09')).rejects.toThrow();
    });

    it("refuse quand la connexion n'est pas configurée", async () => {
      const nu = new Dhis2Service(
        prisma as unknown as PrismaService,
        { get: () => undefined } as unknown as ConfigService,
      );
      await expect(nu.exporterMois('2026-09')).rejects.toThrow();
    });
  });

  describe('état', () => {
    it("ne renvoie jamais l'identifiant ni le mot de passe", async () => {
      prisma.csb.count.mockResolvedValue(2);
      const e = await service.etat();

      expect(e.serveur).toBe(CONFIG.DHIS2_URL);
      expect(JSON.stringify(e)).not.toContain('district');
      expect(JSON.stringify(e)).not.toContain('admin');
    });
  });
});
