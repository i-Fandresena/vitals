import { useEffect, useState } from 'react';
import {
  ApiError,
  api,
  type Csb,
  type District,
  type SessionUser,
} from '../lib/api';
import { Alert, Badge, Button, Card, EmptyState, Field, Input, Select } from '../components/ui';

export function Centres({ user }: { user: SessionUser }) {
  const [csbs, setCsbs] = useState<Csb[] | null>(null);
  const [districts, setDistricts] = useState<District[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);

  const mayCreate = user.role === 'ADMIN_NATIONAL';

  async function reload() {
    try {
      setCsbs(await api.csbs());
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Chargement impossible.');
    }
  }

  useEffect(() => {
    void reload();
    if (mayCreate) api.districts().then(setDistricts).catch(() => setDistricts([]));
  }, [mayCreate]);

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap justify-end gap-3">
        {mayCreate && !creating && (
          <Button onClick={() => setCreating(true)}>Nouveau centre</Button>
        )}
      </div>

      {error && <Alert>{error}</Alert>}

      {creating && (
        <CsbForm
          districts={districts}
          onCancel={() => setCreating(false)}
          onCreated={() => {
            setCreating(false);
            void reload();
          }}
        />
      )}

      {csbs === null ? (
        <p className="text-on-surface-variant">Chargement…</p>
      ) : csbs.length === 0 ? (
        <EmptyState
          title="Aucun centre enregistré"
          hint={mayCreate ? 'Créez le premier centre pour commencer.' : undefined}
        />
      ) : (
        <div className="grid gap-3 md:grid-cols-2">
          {csbs.map((csb) => (
            <Card key={csb.id}>
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="font-semibold">{csb.name}</p>
                  <p className="text-sm text-on-surface-variant">
                    Code {csb.code} · {csb.districtName} · {csb.regionName}
                  </p>
                </div>
                {csb.allowsNurseAntenatalCare && (
                  <Badge tone="warning">Infirmiers CPN</Badge>
                )}
              </div>
              <div className="mt-3 flex gap-4 text-sm text-on-surface-variant">
                <span>{csb.userCount} compte{csb.userCount > 1 ? 's' : ''}</span>
                <span>
                  {csb.beneficiaryCount} dossier{csb.beneficiaryCount > 1 ? 's' : ''}
                </span>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

function CsbForm({
  districts,
  onCancel,
  onCreated,
}: {
  districts: District[];
  onCancel: () => void;
  onCreated: () => void;
}) {
  const [code, setCode] = useState('');
  const [name, setName] = useState('');
  const [commune, setCommune] = useState('');
  const [districtId, setDistrictId] = useState('');
  const [nurseCpn, setNurseCpn] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await api.createCsb({
        code: code.trim().toUpperCase(),
        name: name.trim(),
        commune: commune.trim() || undefined,
        districtId,
        allowsNurseAntenatalCare: nurseCpn,
      });
      onCreated();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Enregistrement impossible.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <form onSubmit={submit} className="flex flex-col gap-4">
        <h3 className="text-lg font-semibold">Nouveau centre</h3>
        {error && <Alert>{error}</Alert>}

        <div className="grid gap-4 md:grid-cols-2">
          <Field
            label="Code"
            hint="Majuscules et chiffres. Figé après la création : il apparaît dans chaque identifiant de dossier."
          >
            <Input
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              placeholder="0142"
              required
              disabled={busy}
            />
          </Field>

          <Field label="Nom">
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="CSB II d'Ambohidratrimo"
              required
              disabled={busy}
            />
          </Field>

          <Field label="District">
            <Select
              value={districtId}
              onChange={(e) => setDistrictId(e.target.value)}
              required
              disabled={busy}
            >
              <option value="">Choisir…</option>
              {districts.map((d) => (
                <option key={d.id} value={d.id}>
                  {d.name}
                </option>
              ))}
            </Select>
          </Field>

          <Field label="Commune" hint="Facultatif">
            <Input
              value={commune}
              onChange={(e) => setCommune(e.target.value)}
              disabled={busy}
            />
          </Field>
        </div>

        <label className="flex items-start gap-3 rounded-lg bg-surface-container p-3">
          <input
            type="checkbox"
            checked={nurseCpn}
            onChange={(e) => setNurseCpn(e.target.checked)}
            disabled={busy}
            className="mt-1 size-5 accent-primary"
          />
          <span className="text-sm">
            <span className="font-medium">
              Ce centre n'a pas de sage-femme affectée
            </span>
            <br />
            Les infirmiers pourront alors saisir les consultations prénatales.
            Sans cette option, le suivi de grossesse serait bloqué là où il
            manque le plus de personnel.
          </span>
        </label>

        <div className="flex gap-3">
          <Button type="submit" disabled={busy || !districtId}>
            {busy ? 'Enregistrement…' : 'Créer le centre'}
          </Button>
          <Button type="button" variant="secondary" onClick={onCancel} disabled={busy}>
            Annuler
          </Button>
        </div>

        {districts.length === 0 && (
          <Alert tone="info">
            Aucun district n'est enregistré. Le découpage géographique doit être
            chargé en base avant de pouvoir créer un centre.
          </Alert>
        )}
      </form>
    </Card>
  );
}
