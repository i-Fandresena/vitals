import { useEffect, useState } from 'react';
import {
  ApiError,
  ROLE_LABELS,
  api,
  type AdminUser,
  type Csb,
  type SessionUser,
  type UserRole,
} from '../lib/api';
import {
  Alert,
  Badge,
  Button,
  Card,
  EmptyState,
  Field,
  Input,
  Select,
} from '../components/ui';

/**
 * Profils qu'un responsable de CSB peut attribuer.
 *
 * Il ne peut créer ni un autre responsable, ni un compte d'administration :
 * ce serait s'attribuer indirectement des droits qu'il n'a pas. Le serveur
 * refuse de toute façon — cette liste évite seulement de proposer
 * l'impossible.
 */
const ROLES_CSB: UserRole[] = ['AGENT_COMMUNAUTAIRE', 'INFIRMIER', 'SAGE_FEMME'];
const ROLES_ADMIN: UserRole[] = [...ROLES_CSB, 'RESPONSABLE_CSB', 'ADMIN_NATIONAL'];

export function Comptes({ user }: { user: SessionUser }) {
  const [users, setUsers] = useState<AdminUser[] | null>(null);
  const [csbs, setCsbs] = useState<Csb[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);

  async function reload() {
    try {
      setUsers(await api.users());
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Chargement impossible.');
    }
  }

  useEffect(() => {
    void reload();
    api
      .csbs()
      .then(setCsbs)
      .catch(() => setCsbs([]));
  }, []);

  async function toggleActive(target: AdminUser) {
    setError(null);
    setNotice(null);
    try {
      await api.updateUser(target.id, { isActive: !target.isActive });
      setNotice(
        target.isActive
          ? `${target.fullName} est désactivé. Ses sessions déjà ouvertes restent valides jusqu'à expiration : réinitialisez son mot de passe pour les couper immédiatement.`
          : `${target.fullName} est réactivé.`,
      );
      void reload();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Modification impossible.');
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold">Comptes</h2>
          <p className="text-on-surface-variant">
            Les soignants se connectent avec ces comptes depuis l'application
            mobile.
          </p>
        </div>
        {!creating && (
          <Button onClick={() => setCreating(true)}>Nouveau compte</Button>
        )}
      </div>

      {error && <Alert>{error}</Alert>}
      {notice && <Alert tone="info">{notice}</Alert>}

      {creating && (
        <UserForm
          session={user}
          csbs={csbs}
          onCancel={() => setCreating(false)}
          onCreated={(created, password) => {
            setCreating(false);
            setNotice(
              `Compte « ${created.username} » créé.\n` +
                `Mot de passe provisoire : ${password}\n` +
                'Notez-le maintenant, il ne sera plus affiché. Demandez à la ' +
                'personne de le changer dès sa première connexion.',
            );
            void reload();
          }}
        />
      )}

      {users === null ? (
        <p className="text-on-surface-variant">Chargement…</p>
      ) : users.length === 0 ? (
        <EmptyState
          title="Aucun compte"
          hint="Créez le premier compte du centre."
        />
      ) : (
        <div className="overflow-x-auto rounded-xl border border-outline-variant bg-white">
          <table className="w-full text-left">
            <thead className="border-b border-outline-variant bg-surface-container">
              <tr>
                <th className="p-3 font-semibold">Nom</th>
                <th className="p-3 font-semibold">Identifiant</th>
                <th className="p-3 font-semibold">Profil</th>
                <th className="p-3 font-semibold">État</th>
                <th className="p-3" />
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr
                  key={u.id}
                  className="border-b border-outline-variant last:border-0"
                >
                  <td className="p-3">{u.fullName}</td>
                  <td className="p-3 font-mono text-sm">{u.username}</td>
                  <td className="p-3">{ROLE_LABELS[u.role]}</td>
                  <td className="p-3">
                    {u.isActive ? (
                      <Badge tone="success">Actif</Badge>
                    ) : (
                      <Badge>Désactivé</Badge>
                    )}
                  </td>
                  <td className="p-3 text-right">
                    {u.id !== user.id && (
                      <Button
                        variant={u.isActive ? 'danger' : 'secondary'}
                        onClick={() => void toggleActive(u)}
                      >
                        {u.isActive ? 'Désactiver' : 'Réactiver'}
                      </Button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function UserForm({
  session,
  csbs,
  onCancel,
  onCreated,
}: {
  session: SessionUser;
  csbs: Csb[];
  onCancel: () => void;
  onCreated: (user: AdminUser, password: string) => void;
}) {
  const isNational = session.role === 'ADMIN_NATIONAL';
  const roles = isNational ? ROLES_ADMIN : ROLES_CSB;

  const [username, setUsername] = useState('');
  const [fullName, setFullName] = useState('');
  const [role, setRole] = useState<UserRole>('INFIRMIER');
  const [csbId, setCsbId] = useState(session.csbId ?? '');
  const [password, setPassword] = useState(() => generatePassword());
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const needsCsb = role !== 'ADMIN_NATIONAL';

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const created = await api.createUser({
        username: username.trim().toLowerCase(),
        fullName: fullName.trim(),
        role,
        csbId: needsCsb ? csbId || undefined : undefined,
        password,
      });
      onCreated(created, password);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Création impossible.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <form onSubmit={submit} className="flex flex-col gap-4">
        <h3 className="text-lg font-semibold">Nouveau compte</h3>
        {error && <Alert>{error}</Alert>}

        <div className="grid gap-4 md:grid-cols-2">
          <Field label="Nom complet">
            <Input
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              placeholder="Rasoa Voahirana"
              required
              disabled={busy}
            />
          </Field>

          <Field
            label="Identifiant de connexion"
            hint="Minuscules, chiffres, point ou tiret. Pas une adresse e-mail : le personnel n'en a pas toujours."
          >
            <Input
              value={username}
              onChange={(e) => setUsername(e.target.value.toLowerCase())}
              placeholder="rasoa.voahirana"
              required
              disabled={busy}
            />
          </Field>

          <Field label="Profil">
            <Select
              value={role}
              onChange={(e) => setRole(e.target.value as UserRole)}
              disabled={busy}
            >
              {roles.map((r) => (
                <option key={r} value={r}>
                  {ROLE_LABELS[r]}
                </option>
              ))}
            </Select>
          </Field>

          {needsCsb && (
            <Field label="Centre de rattachement">
              <Select
                value={csbId}
                onChange={(e) => setCsbId(e.target.value)}
                required
                disabled={busy || !isNational}
              >
                <option value="">Choisir…</option>
                {csbs.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </Select>
            </Field>
          )}
        </div>

        <Field
          label="Mot de passe provisoire"
          hint="12 caractères minimum. Affiché une seule fois : notez-le avant de valider."
        >
          <div className="flex gap-2">
            <Input
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              minLength={12}
              required
              disabled={busy}
              className="font-mono"
            />
            <Button
              type="button"
              variant="secondary"
              onClick={() => setPassword(generatePassword())}
              disabled={busy}
            >
              Regénérer
            </Button>
          </div>
        </Field>

        <div className="flex gap-3">
          <Button type="submit" disabled={busy || (needsCsb && !csbId)}>
            {busy ? 'Création…' : 'Créer le compte'}
          </Button>
          <Button
            type="button"
            variant="secondary"
            onClick={onCancel}
            disabled={busy}
          >
            Annuler
          </Button>
        </div>
      </form>
    </Card>
  );
}

/**
 * Mot de passe provisoire lisible à voix haute et transcrivable sans erreur.
 *
 * Les caractères ambigus sont écartés (0 et O, 1 et l et I) : ces mots de
 * passe sont dictés au téléphone ou recopiés sur papier avant la première
 * connexion, et une confusion coûte un appel de plus.
 */
function generatePassword(): string {
  const alphabet = 'abcdefghjkmnpqrstuvwxyzACDEFGHJKLMNPQRSTUVWXYZ23456789';
  const values = crypto.getRandomValues(new Uint32Array(14));
  return Array.from(values, (v) => alphabet[v % alphabet.length]).join('');
}
