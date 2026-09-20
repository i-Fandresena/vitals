/**
 * Crée le premier compte d'administration nationale.
 *
 * C'est l'amorçage du système : sans lui, personne ne peut se connecter à
 * l'espace d'administration, donc aucun centre ni aucun compte de soignant ne
 * peut être créé. Le script `seed` ne convient pas ici — il est réservé au
 * développement et refuse de tourner en production.
 *
 * JavaScript simple et non TypeScript : l'image de production ne contient pas
 * ts-node, retiré avec les dépendances de développement.
 *
 * Usage, depuis deploy/ :
 *   docker compose exec api node scripts/creer-admin.js <identifiant> "<Nom complet>"
 *
 * Le mot de passe est généré et affiché une seule fois.
 */
const { PrismaClient } = require('@prisma/client');
const argon2 = require('argon2');
const crypto = require('node:crypto');
const { uuidv7 } = require('uuidv7');

const prisma = new PrismaClient();

/**
 * Mot de passe lisible à voix haute : les caractères ambigus (0 et O, 1 et l
 * et I) sont écartés, puisqu'il sera recopié à la main à la première
 * connexion.
 */
function motDePasse() {
  const alphabet = 'abcdefghjkmnpqrstuvwxyzACDEFGHJKLMNPQRSTUVWXYZ23456789';
  return Array.from(
    crypto.randomBytes(20),
    (o) => alphabet[o % alphabet.length],
  ).join('');
}

async function main() {
  const [username, fullName] = process.argv.slice(2);

  if (!username || !fullName) {
    console.error(
      'Usage : node scripts/creer-admin.js <identifiant> "<Nom complet>"',
    );
    process.exit(1);
  }

  if (!/^[a-z0-9._-]{3,64}$/.test(username)) {
    console.error(
      "L'identifiant ne contient que des minuscules, chiffres, point, tiret " +
        'ou souligné, et fait au moins 3 caractères.',
    );
    process.exit(1);
  }

  const existant = await prisma.user.findUnique({ where: { username } });
  if (existant) {
    console.error(`L'identifiant « ${username} » est déjà utilisé.`);
    process.exit(1);
  }

  // Ce script n'existe que pour l'amorçage. Une fois un administrateur en
  // place, les comptes suivants se créent depuis l'espace d'administration,
  // où chaque création est journalisée avec son auteur (CDC §8).
  const dejaAdmin = await prisma.user.count({
    where: { role: 'ADMIN_NATIONAL', isActive: true },
  });
  if (dejaAdmin > 0) {
    console.error(
      `Il existe déjà ${dejaAdmin} compte(s) d'administration active(s).\n` +
        "Créez les comptes suivants depuis l'espace d'administration, pour " +
        "qu'ils soient tracés.",
    );
    process.exit(1);
  }

  const motdepasse = motDePasse();

  await prisma.user.create({
    data: {
      id: uuidv7(),
      username,
      fullName,
      role: 'ADMIN_NATIONAL',
      // L'administration nationale n'accède à aucun dossier individuel
      // (CDC §5) : elle n'est rattachée à aucun centre.
      csbId: null,
      passwordHash: await argon2.hash(motdepasse, { type: argon2.argon2id }),
    },
  });

  console.log('');
  console.log("  Compte d'administration créé.");
  console.log('');
  console.log(`    Identifiant   : ${username}`);
  console.log(`    Mot de passe  : ${motdepasse}`);
  console.log('');
  console.log('  Notez-le maintenant : il ne sera plus affiché.');
  console.log('  Changez-le dès la première connexion.');
  console.log('');
}

main()
  .catch((erreur) => {
    console.error(erreur);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
