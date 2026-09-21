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

              <RapprochementDhis2 csb={csb} onEnregistre={reload} />
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

/**
 * Unité d'organisation DHIS2 d'un centre.
 *
 * Éditable ici et non dans un écran à part : c'est une propriété du centre, et
 * la personne qui fait le rapprochement a la liste des centres sous les yeux.
 * Un centre sans unité ne part pas dans l'export — mieux vaut le voir sur sa
 * fiche que le découvrir au moment d'envoyer.
 */
function RapprochementDhis2({
  csb,
  onEnregistre,
}: {
  csb: Csb;
  onEnregistre: () => Promise<void> | void;
}) {
  const [ouvert, setOuvert] = useState(false);
  const [valeur, setValeur] = useState(csb.dhis2OrgUnit ?? '');
  const [occupe, setOccupe] = useState(false);
  const [erreur, setErreur] = useState<string | null>(null);

  async function enregistrer() {
    setErreur(null);
    setOccupe(true);
    try {
      await api.updateCsb(csb.id, { dhis2OrgUnit: valeur.trim() });
      await onEnregistre();
      setOuvert(false);
    } catch (e) {
      setErreur(e instanceof ApiError ? e.message : 'Enregistrement impossible.');
    } finally {
      setOccupe(false);
    }
  }

  if (!ouvert) {
    return (
      <button
        onClick={() => setOuvert(true)}
        className="mt-3 flex w-full items-center justify-between gap-2 rounded-lg border border-outline-variant px-3 py-2 text-left text-sm transition-colors hover:bg-surface-container"
      >
        <span className="text-on-surface-variant">DHIS2</span>
        <span className={csb.dhis2OrgUnit ? 'font-medium' : 'text-on-surface-variant'}>
          {csb.dhis2OrgUnit ?? 'Non rapproché'}
        </span>
      </button>
    );
  }

  return (
    <div className="mt-3 flex flex-col gap-2 rounded-lg border border-outline-variant p-3">
      <Field
        label="Unité d'organisation DHIS2"
        hint="Onze caractères. Laisser vide pour retirer le centre de l'export."
      >
        <Input
          value={valeur}
          onChange={(e) => setValeur(e.target.value)}
          placeholder="Rp268JB6Ne4"
          autoFocus
          disabled={occupe}
        />
      </Field>
      {erreur && <p className="text-sm text-danger">{erreur}</p>}
      <div className="flex gap-2">
        <Button onClick={enregistrer} disabled={occupe}>
          Enregistrer
        </Button>
        <Button variant="secondary" onClick={() => setOuvert(false)} disabled={occupe}>
          Annuler
        </Button>
      </div>
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
