/**
 * Jeu de données de démonstration.
 *
 * ⚠️ **Aucune donnée réelle de patient.** Les noms sont tirés d'une liste fixe
 * et manifestement inventée, les dates sont générées, et chaque dossier porte
 * le fokontany « Démonstration ». Rien ici ne provient d'un centre réel, et
 * rien ne doit jamais y être recopié depuis un registre.
 *
 * Le script refuse de s'exécuter si le centre contient déjà des dossiers qui
 * ne sont pas de démonstration : on ne mélange pas un jeu d'essai avec des
 * données de soin.
 *
 * Usage, depuis deploy/ :
 *   docker compose exec api node scripts/donnees-demo.js <code-csb>
 *   docker compose exec api node scripts/donnees-demo.js <code-csb> --effacer
 */
const { PrismaClient } = require('@prisma/client');
const { uuidv7 } = require('uuidv7');

const prisma = new PrismaClient();

/** Marque qui distingue un dossier de démonstration d'un dossier réel. */
const MARQUEUR = 'Démonstration';

const NOMS = [
  'RAKOTOARISOA', 'RASOANAIVO', 'ANDRIANARIVO', 'RAZAFINDRAKOTO',
  'RANAIVOSON', 'RABEMANANJARA', 'RAHARIMALALA', 'ANDRIAMASINORO',
  'RAKOTONDRABE', 'RAVELOSON', 'RANDRIANARISOA', 'RAMANANTSOA',
];
const PRENOMS_F = [
  'Voahirana', 'Hanitra', 'Tahiry', 'Mialy', 'Faniry', 'Soa',
  'Onja', 'Vola', 'Nirina', 'Lalaina',
];
const PRENOMS_M = [
  'Hery', 'Tiana', 'Fara', 'Naina', 'Rado', 'Mamy', 'Jaona', 'Toky',
];

const MOTIFS = ['FIEVRE', 'TOUX', 'DIARRHEE', 'PALUDISME_SUSPECT', 'PLAIE', 'SUIVI'];
const FOKONTANY = [
  'Ambohimanga (démo)', 'Antanetibe (démo)', 'Mahitsy (démo)',
  'Anosiala (démo)', 'Ampanotokana (démo)',
];

/** Générateur déterministe : deux exécutions produisent le même jeu. */
let graine = 20260920;
function alea() {
  graine = (graine * 1103515245 + 12345) & 0x7fffffff;
  return graine / 0x7fffffff;
}
const choisir = (liste) => liste[Math.floor(alea() * liste.length)];
const entier = (min, max) => min + Math.floor(alea() * (max - min + 1));

function jourIso(decalageJours) {
  const d = new Date();
  d.setDate(d.getDate() - decalageJours);
  return new Date(d.toISOString().slice(0, 10));
}

async function main() {
  const [codeCsb, drapeau] = process.argv.slice(2);

  if (!codeCsb) {
    console.error('Usage : node scripts/donnees-demo.js <code-csb> [--effacer]');
    process.exit(1);
  }

  const csb = await prisma.csb.findUnique({ where: { code: codeCsb } });
  if (!csb) {
    console.error(`Aucun centre avec le code « ${codeCsb} ».`);
    process.exit(1);
  }

  if (drapeau === '--effacer') {
    return effacer(csb);
  }

  const soignants = await prisma.user.findMany({
    where: {
      csbId: csb.id,
      isActive: true,
      role: { in: ['MEDECIN', 'SAGE_FEMME', 'INFIRMIER', 'RESPONSABLE_CSB'] },
    },
    select: { id: true, fullName: true, role: true },
  });

  if (soignants.length === 0) {
    console.error(
      `Aucun soignant actif dans « ${csb.name} ».\n` +
        "Créez d'abord des comptes depuis l'espace d'administration.",
    );
    process.exit(1);
  }

  const existants = await prisma.beneficiary.count({ where: { csbId: csb.id } });
  const demo = await prisma.beneficiary.count({
    where: { csbId: csb.id, fokontany: { contains: 'démo' } },
  });

  if (existants > 0 && existants !== demo) {
    console.error(
      `« ${csb.name} » contient ${existants - demo} dossier(s) qui ne sont pas\n` +
        "de démonstration. Le script s'arrête : un jeu d'essai ne se mélange\n" +
        'pas à des données de soin.',
    );
    process.exit(1);
  }

  console.log(`Centre   : ${csb.name} (${csb.code})`);
  console.log(`Soignants: ${soignants.map((s) => s.fullName).join(', ')}`);
  console.log('');

  const parRole = (role) => soignants.filter((s) => s.role === role);
  const medecinOuSf = [...parRole('MEDECIN'), ...parRole('SAGE_FEMME'), ...soignants];
  const sageFemmes = [...parRole('SAGE_FEMME'), ...parRole('MEDECIN'), ...soignants];

  let sequence = csb.lastLocalSequenceYear === new Date().getFullYear()
    ? csb.lastLocalSequence
    : 0;

  const stats = { dossiers: 0, consultations: 0, cpn: 0, vaccinations: 0, pf: 0 };
  const annee = String(new Date().getFullYear() % 100).padStart(2, '0');

  // 24 dossiers : assez pour remplir une liste, un graphique et une
  // répartition sans rendre la base illisible.
  for (let i = 0; i < 24; i++) {
    // Deux tiers de femmes : la santé maternelle est le cœur du dispositif,
    // et le jeu doit ressembler à la file active d'un CSB.
    const femme = alea() < 0.68;
    const sexe = femme ? 'F' : 'M';

    // Un tiers d'enfants de moins de cinq ans, pour que les vaccinations et
    // les consultations pédiatriques aient des sujets crédibles.
    const enfant = alea() < 0.34;
    const ageJours = enfant ? entier(20, 1800) : entier(6000, 16000);

    sequence += 1;
    const id = uuidv7();
    const creeIlYa = entier(0, 330);

    await prisma.beneficiary.create({
      data: {
        id,
        localId: `CSB-${csb.code}-${annee}-${String(sequence).padStart(5, '0')}`,
        firstName: femme ? choisir(PRENOMS_F) : choisir(PRENOMS_M),
        lastName: choisir(NOMS),
        sex: sexe,
        birthDate: jourIso(ageJours),
        // Une partie des dates est estimée : c'est le cas réel sur le terrain,
        // et cela permet de voir le « ~ » dans l'application.
        birthDateIsEstimated: alea() < 0.3,
        fokontany: choisir(FOKONTANY),
        csbId: csb.id,
        deviceUpdatedAt: jourIso(creeIlYa),
        createdByUserId: choisir(soignants).id,
        createdAt: jourIso(creeIlYa),
      },
    });
    stats.dossiers += 1;

    // --- Consultations ---
    for (let c = 0; c < entier(0, 4); c++) {
      const jour = entier(0, Math.min(creeIlYa, 330));
      await prisma.consultation.create({
        data: {
          id: uuidv7(),
          beneficiaryId: id,
          type: enfant ? 'ENFANT' : 'CURATIVE',
          occurredOn: jourIso(jour),
          motiveCode: choisir(MOTIFS),
          weightKg: enfant ? entier(4, 18) : entier(45, 78),
          temperatureC: 36.5 + alea() * 2.5,
          referred: alea() < 0.08,
          recordedByUserId: choisir(soignants).id,
          deviceCreatedAt: jourIso(jour),
          createdAt: jourIso(jour),
        },
      });
      stats.consultations += 1;
    }

    // --- Vaccinations, pour les enfants ---
    if (enfant) {
      const antigenes = ['BCG', 'VPO', 'PENTA', 'PNEUMO', 'ROTA', 'VAR'];
      const nb = entier(1, 4);
      for (let v = 0; v < nb; v++) {
        const jour = entier(0, Math.min(creeIlYa, 330));
        try {
          await prisma.vaccination.create({
            data: {
              id: uuidv7(),
              beneficiaryId: id,
              vaccine: antigenes[v % antigenes.length],
              doseNumber: (v % 3) + 1,
              occurredOn: jourIso(jour),
              recordedByUserId: choisir(soignants).id,
              deviceCreatedAt: jourIso(jour),
              createdAt: jourIso(jour),
            },
          });
          stats.vaccinations += 1;
        } catch {
          // Contrainte d'unicité (même antigène, même dose, même jour) :
          // c'est exactement ce qu'elle doit empêcher, on passe.
        }
      }
    }

    // --- Grossesse et CPN, pour une partie des femmes en âge de procréer ---
    const ageAns = ageJours / 365;
    if (femme && ageAns >= 15 && ageAns <= 45 && alea() < 0.45) {
      const ddr = entier(30, 250);
      const grossesseId = uuidv7();
      await prisma.pregnancy.create({
        data: {
          id: grossesseId,
          beneficiaryId: id,
          lastPeriodDate: jourIso(ddr),
          expectedDeliveryOn: jourIso(ddr - 280),
          gravida: entier(1, 5),
          para: entier(0, 4),
          outcome: ddr > 280 ? 'ACCOUCHEMENT_VIVANT' : 'EN_COURS',
          outcomeDate: ddr > 280 ? jourIso(ddr - 280) : null,
          deviceUpdatedAt: jourIso(ddr),
          createdByUserId: choisir(sageFemmes).id,
          createdAt: jourIso(ddr),
        },
      });

      const nbCpn = entier(1, 4);
      for (let v = 1; v <= nbCpn; v++) {
        const jour = Math.max(0, ddr - v * 55);
        await prisma.prenatalVisit.create({
          data: {
            id: uuidv7(),
            pregnancyId: grossesseId,
            visitNumber: v,
            occurredOn: jourIso(jour),
            gestationalAgeWeeks: Math.round((ddr - jour) / 7),
            weightKg: entier(48, 80),
            bloodPressureSys: entier(100, 135),
            bloodPressureDia: entier(60, 88),
            tetanusVaccineGiven: v <= 2,
            ironFolateGiven: true,
            malariaPreventionGiven: v >= 2,
            insecticideNetGiven: v === 1,
            riskFactorCodes: alea() < 0.2 ? ['AGE_ELEVE'] : [],
            referred: alea() < 0.1,
            recordedByUserId: choisir(sageFemmes).id,
            deviceCreatedAt: jourIso(jour),
            createdAt: jourIso(jour),
          },
        });
        stats.cpn += 1;
      }
    }

    // --- Planification familiale ---
    if (femme && ageAns >= 15 && ageAns <= 49 && alea() < 0.4) {
      const methodes = ['PILULE', 'INJECTABLE', 'IMPLANT', 'DIU', 'COLLIER_DU_CYCLE'];
      const methode = choisir(methodes);
      const nb = entier(1, 3);
      for (let f = 0; f < nb; f++) {
        const jour = entier(0, Math.min(creeIlYa, 330));
        await prisma.familyPlanningActivity.create({
          data: {
            id: uuidv7(),
            beneficiaryId: id,
            method: methode,
            actType: f === 0 ? 'NOUVELLE_ADHERENTE' : 'RENOUVELLEMENT',
            occurredOn: jourIso(jour),
            quantity: methode === 'PILULE' ? 3 : null,
            recordedByUserId: choisir(medecinOuSf).id,
            deviceCreatedAt: jourIso(jour),
            createdAt: jourIso(jour),
          },
        });
        stats.pf += 1;
      }
    }
  }

  await prisma.csb.update({
    where: { id: csb.id },
    data: {
      lastLocalSequence: sequence,
      lastLocalSequenceYear: new Date().getFullYear(),
    },
  });

  console.log('Jeu de démonstration créé :');
  console.log(`  ${stats.dossiers} dossiers`);
  console.log(`  ${stats.consultations} consultations`);
  console.log(`  ${stats.cpn} consultations prénatales`);
  console.log(`  ${stats.vaccinations} vaccinations`);
  console.log(`  ${stats.pf} activités de planification familiale`);
  console.log('');
  console.log(`Tous marqués « ${MARQUEUR} » par leur fokontany.`);
  console.log('Pour les retirer :  node scripts/donnees-demo.js ' + codeCsb + ' --effacer');
}

/** Retire le jeu de démonstration, et lui seul. */
async function effacer(csb) {
  const dossiers = await prisma.beneficiary.findMany({
    where: { csbId: csb.id, fokontany: { contains: 'démo' } },
    select: { id: true },
  });
  const ids = dossiers.map((d) => d.id);

  if (ids.length === 0) {
    console.log('Aucun dossier de démonstration à retirer.');
    return;
  }

  const grossesses = await prisma.pregnancy.findMany({
    where: { beneficiaryId: { in: ids } },
    select: { id: true },
  });

  // Ordre imposé par les clés étrangères : les feuilles d'abord.
  await prisma.prenatalVisit.deleteMany({
    where: { pregnancyId: { in: grossesses.map((g) => g.id) } },
  });
  await prisma.pregnancy.deleteMany({ where: { beneficiaryId: { in: ids } } });
  await prisma.consultation.deleteMany({ where: { beneficiaryId: { in: ids } } });
  await prisma.vaccination.deleteMany({ where: { beneficiaryId: { in: ids } } });
  await prisma.familyPlanningActivity.deleteMany({
    where: { beneficiaryId: { in: ids } },
  });
  await prisma.beneficiary.deleteMany({ where: { id: { in: ids } } });

  console.log(`${ids.length} dossiers de démonstration retirés.`);
}

main()
  .catch((erreur) => {
    console.error(erreur);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
