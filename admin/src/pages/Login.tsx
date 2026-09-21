import { useState } from 'react';
import { ApiError, api, type SessionUser } from '../lib/api';
import { Alert, Button, Field, Input } from '../components/ui';
import { IconCentres, IconIndicateurs, IconJournal } from '../components/icons';

/**
 * Page de connexion à l'espace d'administration.
 *
 * Écran scindé : la marque et ce que fait l'outil à gauche, le formulaire seul
 * à droite. Ce n'est pas un ornement — cet espace se partage entre le
 * ministère et les responsables de centre, et la colonne de gauche répond à la
 * question « où suis-je, et qu'est-ce que je vais y trouver » avant qu'on ait
 * à la poser.
 *
 * Elle disparaît sous `lg` : sur une tablette, la moitié de l'écran vaut mieux
 * au formulaire.
 */
export function Login({ onSignedIn }: { onSignedIn: (user: SessionUser) => void }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [visible, setVisible] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const user = await api.login(username.trim(), password);

      // Un soignant n'a rien à faire ici : ses outils sont dans
      // l'application mobile. On le dit plutôt que d'afficher des écrans vides.
      if (user.role !== 'ADMIN_NATIONAL' && user.role !== 'RESPONSABLE_CSB') {
        await api.logout();
        setError(
          "Cet espace est réservé à l'administration et aux responsables de " +
            "centre.\nLes soignants utilisent l'application mobile MbolaTsara.",
        );
        return;
      }

      onSignedIn(user);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Connexion impossible.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="grid min-h-screen lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
      <PanneauMarque />

      <div className="flex items-center justify-center px-6 py-12">
        <form onSubmit={submit} className="w-full max-w-sm">
          {/* Le logo se répète ici pour les écrans où le panneau est masqué. */}
          <img
            src="/embleme-mbolatsara.png"
            alt=""
            className="mb-6 h-16 w-auto lg:hidden"
          />

          <h1 className="text-3xl font-bold tracking-tight">Connexion</h1>
          <p className="mt-1 text-on-surface-variant">
            Avec le compte fourni par l'administration.
          </p>

          {error && (
            <div className="mt-6">
              <Alert>{error}</Alert>
            </div>
          )}

          <div className="mt-8 flex flex-col gap-4">
            <Field label="Identifiant">
              <Input
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                autoFocus
                autoCapitalize="none"
                autoCorrect="off"
                autoComplete="username"
                required
                disabled={busy}
              />
            </Field>

            <Field label="Mot de passe">
              <div className="relative">
                <Input
                  type={visible ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                  required
                  disabled={busy}
                  className="pr-20"
                />
                {/* Afficher le mot de passe évite l'échec le plus courant :
                    une faute de frappe invisible. */}
                <button
                  type="button"
                  onClick={() => setVisible((v) => !v)}
                  className="absolute inset-y-0 right-0 px-3 text-sm font-semibold text-primary hover:underline"
                >
                  {visible ? 'Masquer' : 'Voir'}
                </button>
              </div>
            </Field>

            <Button type="submit" disabled={busy} className="mt-2">
              {busy ? 'Connexion…' : 'Se connecter'}
            </Button>
          </div>

          <p className="mt-8 text-sm text-on-surface-variant">
            Vous êtes soignant ? Vos outils sont dans l'application mobile, pas
            ici.
          </p>
        </form>
      </div>
    </main>
  );
}

/**
 * Colonne de marque.
 *
 * Dégradé en CSS et non en image : la page se charge parfois depuis
 * Madagascar sur une liaison médiocre, et un visuel de fond coûterait plus
 * cher que tout le reste de l'application réuni.
 */
function PanneauMarque() {
  const points = [
    [IconIndicateurs, "Indicateurs agrégés de l'activité des centres"],
    [IconCentres, 'Centres, comptes et découpage géographique'],
    [IconJournal, 'Journal des écritures, en lecture seule'],
  ] as const;

  return (
    <aside className="relative hidden flex-col justify-between overflow-hidden bg-primary p-12 text-white lg:flex">
      {/* Deux halos très doux pour que l'aplat ne paraisse pas plat. Aucun
          asset : deux dégradés radiaux. */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            'radial-gradient(60rem 40rem at 15% 10%, rgba(255,255,255,.14), transparent 60%),' +
            'radial-gradient(45rem 35rem at 90% 95%, rgba(255,94,91,.22), transparent 62%)',
        }}
      />

      {/* Le logo garde ses couleurs, sur une pastille claire. Le passer en
          blanc tiendrait mieux sur le fond, mais un logo décoloré n'est plus
          le logo — et c'est la seule fois qu'il est vu en grand. */}
      <div className="relative inline-flex w-fit rounded-3xl bg-white/95 p-5">
        <img src="/logo-mbolatsara.png" alt="MbolaTsara" className="h-24 w-auto" />
      </div>

      <div className="relative max-w-md">
        <h2 className="text-4xl font-bold leading-tight tracking-tight">
          Les chiffres des centres, à jour et au même endroit.
        </h2>
        <p className="mt-4 text-lg text-white/75">
          Chaque acte saisi dans un centre de santé remonte ici dès que
          l'appareil retrouve le réseau.
        </p>

        <ul className="mt-10 flex flex-col gap-4">
          {points.map(([Icone, texte]) => (
            <li key={texte} className="flex items-center gap-3">
              <span className="grid size-9 shrink-0 place-items-center rounded-xl bg-white/15">
                <Icone className="size-5" />
              </span>
              <span className="text-white/85">{texte}</span>
            </li>
          ))}
        </ul>
      </div>

      <p className="relative text-sm text-white/60">
        Données de santé — accès réservé et journalisé.
      </p>
    </aside>
  );
}
