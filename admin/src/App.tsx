import { useEffect, useState, type ReactNode } from 'react';
import { ROLE_LABELS, api, type SessionUser } from './lib/api';
import {
  IconCentres,
  IconComptes,
  IconDeconnexion,
  IconExport,
  IconGeographie,
  IconIndicateurs,
  IconJournal,
} from './components/icons';
import { Centres } from './pages/Centres';
import { Comptes } from './pages/Comptes';
import { Dhis2 } from './pages/Dhis2';
import { Geographie } from './pages/Geographie';
import { Indicateurs } from './pages/Indicateurs';
import { Journal } from './pages/Journal';
import { Login } from './pages/Login';

type Onglet =
  | 'indicateurs'
  | 'dhis2'
  | 'comptes'
  | 'centres'
  | 'geographie'
  | 'journal';

/** Les entrées, groupées par ce qu'on vient y faire.
 *
 * Trois blocs plutôt qu'une liste plate : consulter, administrer, tenir à jour
 * le référentiel. Un responsable passe sa semaine dans le premier et ne touche
 * au troisième que deux fois par an. */
const SECTIONS: Array<{
  titre: string;
  entrees: Array<[Onglet, string, (p: { className?: string }) => ReactNode]>;
}> = [
  {
    titre: 'Suivi',
    entrees: [
      ['indicateurs', 'Indicateurs', IconIndicateurs],
      ['dhis2', 'Remontée DHIS2', IconExport],
    ],
  },
  {
    titre: 'Administration',
    entrees: [
      ['comptes', 'Comptes', IconComptes],
      ['centres', 'Centres', IconCentres],
    ],
  },
  {
    titre: 'Référentiel',
    entrees: [
      ['geographie', 'Géographie', IconGeographie],
      ['journal', 'Journal', IconJournal],
    ],
  },
];

/** Titre et explication de chaque page.
 *
 * Rassemblés ici plutôt que répétés dans chaque page : l'en-tête est commun,
 * et deux titres pour le même écran est exactement le genre de bruit que le
 * CDC §7 demande d'éviter. */
const TITRES: Record<Onglet, { titre: string; sous: string }> = {
  dhis2: {
    titre: 'Remontée DHIS2',
    sous: "Envoi des dénombrements mensuels vers l'entrepôt national.",
  },
  indicateurs: {
    titre: "Indicateurs",
    sous: "Activité agrégée des centres — aucun dossier individuel n'y figure.",
  },
  comptes: {
    titre: "Comptes",
    sous: "Les soignants se connectent avec ces comptes depuis l'application mobile.",
  },
  centres: {
    titre: "Centres de santé",
    sous: "Le code du centre préfixe les identifiants de dossier et n'est plus modifiable ensuite.",
  },
  geographie: {
    titre: "Découpage géographique",
    sous: "Les codes sont figés après création : ils servent de clé de rapprochement avec DHIS2 et les publications nationales.",
  },
  journal: {
    titre: "Journal d'audit",
    sous: "Qui a créé ou modifié quoi, et quand. En lecture seule : rien ne peut y être effacé.",
  },
};

export default function App() {
  const [user, setUser] = useState<SessionUser | null>(null);
  const [chargement, setChargement] = useState(true);
  // Les indicateurs en premier : c'est ce qu'un responsable vient consulter
  // au quotidien, alors qu'un centre se crée une fois puis n'est plus touché.
  const [onglet, setOnglet] = useState<Onglet>('indicateurs');

  useEffect(() => {
    api
      .restore()
      .then(setUser)
      .finally(() => setChargement(false));
  }, []);

  if (chargement) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p className="text-on-surface-variant">Chargement…</p>
      </main>
    );
  }

  if (!user) {
    return <Login onSignedIn={setUser} />;
  }

  const deconnexion = () => {
    void api.logout().then(() => setUser(null));
  };

  return (
    <div className="min-h-screen lg:flex lg:gap-6 lg:p-6">
      <BarreLaterale
        onglet={onglet}
        onChange={setOnglet}
        user={user}
        onDeconnexion={deconnexion}
      />

      <div className="min-w-0 flex-1">
        <header className="flex flex-wrap items-center justify-between gap-4 px-5 pt-6 lg:px-0 lg:pt-0">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">{TITRES[onglet].titre}</h1>
            <p className="text-on-surface-variant">{TITRES[onglet].sous}</p>
          </div>
          <ChipUtilisateur user={user} />
        </header>

        <main className="px-5 py-6 lg:px-0">
          {onglet === 'indicateurs' && <Indicateurs user={user} />}
          {onglet === 'dhis2' && <Dhis2 />}
          {onglet === 'comptes' && <Comptes user={user} />}
          {onglet === 'centres' && <Centres user={user} />}
          {onglet === 'geographie' && <Geographie user={user} />}
          {onglet === 'journal' && <Journal />}
        </main>
      </div>
    </div>
  );
}

/**
 * Navigation permanente.
 *
 * En colonne sur grand écran, en bandeau défilant en dessous de `lg` : ces
 * écrans se consultent aussi depuis une tablette, et une colonne fixe y
 * mangerait la moitié de la largeur utile.
 */
function BarreLaterale({
  onglet,
  onChange,
  user,
  onDeconnexion,
}: {
  onglet: Onglet;
  onChange: (o: Onglet) => void;
  user: SessionUser;
  onDeconnexion: () => void;
}) {
  return (
    <aside className="border-b border-outline-variant bg-surface-card lg:sticky lg:top-6 lg:h-[calc(100vh-3rem)] lg:w-60 lg:shrink-0 lg:rounded-2xl lg:border lg:p-4 lg:shadow-[var(--shadow-carte)]">
      <div className="flex items-center gap-2.5 px-5 py-4 lg:px-1 lg:pb-6 lg:pt-1">
        {/* L'emblème seul : le mot est écrit à côté, en texte, où il reste
            net à toutes les tailles et lisible par un lecteur d'écran. */}
        <img
          src="/embleme-mbolatsara.png"
          alt=""
          className="size-9 shrink-0 object-contain"
        />
        <span className="text-lg font-bold tracking-tight">MbolaTsara</span>
      </div>

      <nav className="flex gap-1 overflow-x-auto px-5 pb-3 lg:flex-col lg:gap-0 lg:overflow-visible lg:px-0 lg:pb-0">
        {SECTIONS.map((section) => (
          <div key={section.titre} className="contents lg:block">
            <p className="hidden px-3 pb-1.5 pt-4 text-xs font-semibold uppercase tracking-wider text-on-surface-variant lg:block">
              {section.titre}
            </p>
            {section.entrees.map(([cle, libelle, Icone]) => (
              <button
                key={cle}
                onClick={() => onChange(cle)}
                aria-current={onglet === cle ? 'page' : undefined}
                className={`flex min-h-11 w-full shrink-0 items-center gap-2.5 whitespace-nowrap rounded-xl px-3 font-medium transition-colors ${
                  onglet === cle
                    ? 'bg-primary text-white shadow-[var(--shadow-carte-active)]'
                    : 'text-on-surface-variant hover:bg-surface-container hover:text-on-surface'
                }`}
              >
                <Icone className="size-5 shrink-0" />
                {libelle}
              </button>
            ))}
          </div>
        ))}
      </nav>

      {/* Le nom du compte connecté reste sous les yeux : ces écrans modifient
          des droits, et l'auteur de chaque écriture est journalisé. */}
      <div className="hidden lg:absolute lg:inset-x-4 lg:bottom-4 lg:block">
        <div className="rounded-xl bg-surface-container p-3">
          <p className="truncate font-medium">{user.fullName}</p>
          <p className="truncate text-sm text-on-surface-variant">
            {ROLE_LABELS[user.role]}
          </p>
          <button
            onClick={onDeconnexion}
            className="mt-2.5 flex min-h-9 w-full items-center justify-center gap-2 rounded-lg border border-outline bg-surface-card font-medium transition-colors hover:bg-surface"
          >
            <IconDeconnexion className="size-4" />
            Se déconnecter
          </button>
        </div>
      </div>
    </aside>
  );
}

function ChipUtilisateur({ user }: { user: SessionUser }) {
  const initiales = user.fullName
    .split(/\s+/)
    .slice(0, 2)
    .map((m) => m[0]?.toUpperCase() ?? '')
    .join('');

  return (
    <div className="flex items-center gap-2.5 rounded-full border border-outline-variant bg-surface-card py-1.5 pl-1.5 pr-4">
      <span className="grid size-9 shrink-0 place-items-center rounded-full bg-primary-container font-semibold text-on-primary-container">
        {initiales}
      </span>
      <span className="min-w-0">
        <span className="block truncate font-medium leading-tight">
          {user.fullName}
        </span>
        <span className="block truncate text-sm leading-tight text-on-surface-variant">
          {ROLE_LABELS[user.role]}
          {user.csbName ? ` · ${user.csbName}` : ''}
        </span>
      </span>
    </div>
  );
}
