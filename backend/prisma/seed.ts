/**
 * Jeu de données minimal pour le développement local.
 *
 * Ne contient que des utilisateurs et un découpage géographique fictif :
 * aucun dossier bénéficiaire, donc aucune donnée de santé, même inventée.
 * Le jeu de démonstration complet est l'objet du ticket 4.2.
 *
 * Refuse de s'exécuter en production.
 */
import { PrismaClient, UserRole } from '@prisma/client';
import * as argon2 from 'argon2';
import { uuidv7 } from 'uuidv7';

const prisma = new PrismaClient();

/** Mot de passe unique en développement — jamais utilisable ailleurs. */
const DEV_PASSWORD = 'Vitals-dev-2026';

async function main(): Promise<void> {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('Le seed ne doit jamais être exécuté en production.');
  }

  const regionId = uuidv7();
  const districtId = uuidv7();
  const csbId = uuidv7();

  await prisma.region.upsert({
    where: { code: 'REG-DEV' },
    update: {},
    create: { id: regionId, code: 'REG-DEV', name: 'Région de démonstration' },
  });

  const region = await prisma.region.findUniqueOrThrow({ where: { code: 'REG-DEV' } });

  await prisma.district.upsert({
    where: { code: 'DIS-DEV' },
    update: {},
    create: {
      id: districtId,
      code: 'DIS-DEV',
      name: 'District de démonstration',
      regionId: region.id,
    },
  });

  const district = await prisma.district.findUniqueOrThrow({ where: { code: 'DIS-DEV' } });

  await prisma.csb.upsert({
    where: { code: '0142' },
    update: {},
    create: {
      id: csbId,
      code: '0142',
      name: 'CSB II de démonstration',
      commune: 'Commune de démonstration',
      districtId: district.id,
      // Ce centre n'a pas de sage-femme : les infirmiers peuvent saisir les CPN.
      allowsNurseAntenatalCare: true,
    },
  });

  const csb = await prisma.csb.findUniqueOrThrow({ where: { code: '0142' } });

  const passwordHash = await argon2.hash(DEV_PASSWORD, { type: argon2.argon2id });

  const users: Array<{ username: string; fullName: string; role: UserRole; csbId: string | null }> =
    [
      { username: 'agent', fullName: 'Agent communautaire (démo)', role: UserRole.AGENT_COMMUNAUTAIRE, csbId: csb.id },
      { username: 'infirmier', fullName: 'Infirmier (démo)', role: UserRole.INFIRMIER, csbId: csb.id },
      { username: 'sagefemme', fullName: 'Sage-femme (démo)', role: UserRole.SAGE_FEMME, csbId: csb.id },
      { username: 'responsable', fullName: 'Responsable CSB (démo)', role: UserRole.RESPONSABLE_CSB, csbId: csb.id },
      { username: 'admin', fullName: 'Admin national (démo)', role: UserRole.ADMIN_NATIONAL, csbId: null },
    ];

  for (const user of users) {
    await prisma.user.upsert({
      where: { username: user.username },
      update: {},
      create: { id: uuidv7(), passwordHash, ...user },
    });
  }

  console.log(`CSB créé : ${csb.name} (code ${csb.code})`);
  console.log(`${users.length} comptes créés — mot de passe commun : ${DEV_PASSWORD}`);
  console.log(`Identifiants : ${users.map((u) => u.username).join(', ')}`);
}

main()
  .catch((error: unknown) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => void prisma.$disconnect());
