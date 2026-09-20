import { useEffect, useState } from 'react';
import { ROLE_LABELS, api, type SessionUser } from './lib/api';
import { Button } from './components/ui';
import { Centres } from './pages/Centres';
import { Comptes } from './pages/Comptes';
import { Login } from './pages/Login';

type Onglet = 'comptes' | 'centres';

export default function App() {
  const [user, setUser] = useState<SessionUser | null>(null);
  const [chargement, setChargement] = useState(true);
  // Les comptes d'abord : créer un compte est ce qu'on vient faire ici le plus
  // souvent, alors qu'un centre se crée une fois puis n'est plus touché.
  const [onglet, setOnglet] = useState<Onglet>('comptes');

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
        <div className="mx-auto flex max-w-5xl items-center justify-between gap-4 px-6 py-4">
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

        <nav className="mx-auto flex max-w-5xl gap-1 px-6">
          {(
            [
              ['comptes', 'Comptes'],
              ['centres', 'Centres'],
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

      <main className="mx-auto max-w-5xl px-6 py-8">
        {onglet === 'comptes' ? <Comptes user={user} /> : <Centres user={user} />}
      </main>
    </div>
  );
}
