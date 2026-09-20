import { useEffect, useState } from 'react';
import { ROLE_LABELS, api, type SessionUser } from './lib/api';
import { Button } from './components/ui';
import { Centres } from './pages/Centres';
import { Comptes } from './pages/Comptes';
import { Geographie } from './pages/Geographie';
import { Indicateurs } from './pages/Indicateurs';
import { Journal } from './pages/Journal';
import { Login } from './pages/Login';

type Onglet = 'indicateurs' | 'comptes' | 'centres' | 'geographie' | 'journal';

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

  return (
    <div className="min-h-screen">
      <header className="border-b border-outline-variant bg-white">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-6 py-4">
          <div>
            <p className="text-xl font-bold text-primary">Vitals</p>
            <p className="text-sm text-on-surface-variant">
              {user.fullName} · {ROLE_LABELS[user.role]}
              {user.csbName ? ` · ${user.csbName}` : ''}
            </p>
          </div>
          <Button
            variant="secondary"
            onClick={() => {
              void api.logout().then(() => setUser(null));
            }}
          >
            Se déconnecter
          </Button>
        </div>

        <nav className="mx-auto flex max-w-6xl gap-1 overflow-x-auto px-6">
          {(
            [
              ['indicateurs', 'Indicateurs'],
              ['comptes', 'Comptes'],
              ['centres', 'Centres'],
              ['geographie', 'Géographie'],
              ['journal', 'Journal'],
            ] as const
          ).map(([cle, libelle]) => (
            <button
              key={cle}
              onClick={() => setOnglet(cle)}
              aria-current={onglet === cle ? 'page' : undefined}
              className={`-mb-px border-b-2 px-4 py-3 font-medium transition-colors ${
                onglet === cle
                  ? 'border-primary text-primary'
                  : 'border-transparent text-on-surface-variant hover:text-on-surface'
              }`}
            >
              {libelle}
            </button>
          ))}
        </nav>
      </header>

      <main className="mx-auto max-w-6xl px-6 py-8">
        {onglet === 'indicateurs' && <Indicateurs user={user} />}
        {onglet === 'comptes' && <Comptes user={user} />}
        {onglet === 'centres' && <Centres user={user} />}
        {onglet === 'geographie' && <Geographie user={user} />}
        {onglet === 'journal' && <Journal />}
      </main>
    </div>
  );
}
