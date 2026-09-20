import { useState } from 'react';
import { ApiError, api, type SessionUser } from '../lib/api';
import { Alert, Button, Field, Input } from '../components/ui';

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
            "centre.\nLes soignants utilisent l'application mobile Vitals.",
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
    <main className="flex min-h-screen items-center justify-center p-6">
      <form onSubmit={submit} className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <h1 className="text-3xl font-bold text-primary">Vitals</h1>
          <p className="mt-1 text-on-surface-variant">Espace d'administration</p>
        </div>

        {error && (
          <div className="mb-4">
            <Alert>{error}</Alert>
          </div>
        )}

        <div className="flex flex-col gap-4">
          <Field label="Identifiant">
            <Input
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              autoFocus
              autoCapitalize="none"
              autoCorrect="off"
              required
              disabled={busy}
            />
          </Field>

          <Field label="Mot de passe">
            <div className="flex gap-2">
              <Input
                type={visible ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                disabled={busy}
              />
              {/* Afficher le mot de passe évite l'échec le plus courant :
                  une faute de frappe invisible. */}
              <Button
                type="button"
                variant="secondary"
                onClick={() => setVisible((v) => !v)}
                aria-label={visible ? 'Masquer' : 'Afficher'}
              >
                {visible ? 'Masquer' : 'Voir'}
              </Button>
            </div>
          </Field>

          <Button type="submit" disabled={busy} className="mt-2">
            {busy ? 'Connexion…' : 'Se connecter'}
          </Button>
        </div>
      </form>
    </main>
  );
}
