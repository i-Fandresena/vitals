import { useEffect, useState } from 'react';
import { ApiError, api, type District, type Region, type SessionUser } from '../lib/api';
import { Alert, Button, Card, EmptyState, Field, Input, Select } from '../components/ui';

/**
 * Régions et districts.
 *
 * Sans ce découpage, aucun centre ne peut être créé, donc aucun compte de
 * soignant : c'est la toute première chose à renseigner sur une installation
 * neuve. Les indicateurs remontent ensuite par cette hiérarchie (CDC §5).
 */
export function Geographie({ user }: { user: SessionUser }) {
  const [regions, setRegions] = useState<Region[] | null>(null);
  const [districts, setDistricts] = useState<District[]>([]);
  const [erreur, setErreur] = useState<string | null>(null);
  const [creation, setCreation] = useState<'region' | 'district' | null>(null);

  const national = user.role === 'ADMIN_NATIONAL';

  async function recharger() {
    try {
      const [r, d] = await Promise.all([api.regions(), api.districts()]);
      setRegions(r);
      setDistricts(d);
      setErreur(null);
    } catch (e) {
      setErreur(e instanceof ApiError ? e.message : 'Chargement impossible.');
    }
  }

  useEffect(() => {
    void recharger();
  }, []);

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap justify-end gap-3">
        {national && !creation && (
          <div className="flex gap-2">
            <Button variant="secondary" onClick={() => setCreation('region')}>
              Nouvelle région
            </Button>
            <Button
              onClick={() => setCreation('district')}
              disabled={(regions?.length ?? 0) === 0}
            >
              Nouveau district
            </Button>
          </div>
        )}
      </div>

      {erreur && <Alert>{erreur}</Alert>}

      {creation === 'region' && (
        <FormulaireRegion
          onAnnuler={() => setCreation(null)}
          onCree={() => {
            setCreation(null);
            void recharger();
          }}
        />
      )}

      {creation === 'district' && (
        <FormulaireDistrict
          regions={regions ?? []}
          onAnnuler={() => setCreation(null)}
          onCree={() => {
            setCreation(null);
            void recharger();
          }}
        />
      )}

      {regions === null ? (
        <p className="text-on-surface-variant">Chargement…</p>
      ) : regions.length === 0 ? (
        <EmptyState
          title="Aucune région enregistrée"
          hint={
            national
              ? 'Commencez par une région, puis un district, puis un centre.'
              : "Contactez l'administration nationale."
          }
        />
      ) : (
        <div className="flex flex-col gap-4">
          {regions.map((r) => {
            const siens = districts.filter((d) => d.regionId === r.id);
            return (
              <Card key={r.id}>
                <div className="flex items-baseline justify-between gap-3">
                  <h3 className="text-lg font-semibold">{r.name}</h3>
                  <span className="font-mono text-sm text-on-surface-variant">
                    {r.code}
                  </span>
                </div>

                {siens.length === 0 ? (
                  <p className="mt-3 text-sm text-on-surface-variant">
                    Aucun district. Un centre ne peut pas encore être créé dans
                    cette région.
                  </p>
                ) : (
                  <ul className="mt-3 flex flex-col divide-y divide-outline-variant">
                    {siens.map((d) => (
                      <li
                        key={d.id}
                        className="flex items-center justify-between gap-3 py-2"
                      >
                        <span>{d.name}</span>
                        <span className="flex items-center gap-3 text-sm text-on-surface-variant">
                          <span className="font-mono">{d.code}</span>
                          <span>
                            {d.csbCount ?? 0} centre{(d.csbCount ?? 0) > 1 ? 's' : ''}
                          </span>
                        </span>
                      </li>
                    ))}
                  </ul>
                )}
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}

function FormulaireRegion({
  onAnnuler,
  onCree,
}: {
  onAnnuler: () => void;
  onCree: () => void;
}) {
  const [code, setCode] = useState('');
  const [nom, setNom] = useState('');
  const [busy, setBusy] = useState(false);
  const [erreur, setErreur] = useState<string | null>(null);

  async function envoyer(e: React.FormEvent) {
    e.preventDefault();
    setErreur(null);
    setBusy(true);
    try {
      await api.createRegion({ code: code.trim().toUpperCase(), name: nom.trim() });
      onCree();
    } catch (err) {
      setErreur(err instanceof ApiError ? err.message : 'Création impossible.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <form onSubmit={envoyer} className="flex flex-col gap-4">
        <h3 className="text-lg font-semibold">Nouvelle région</h3>
        {erreur && <Alert>{erreur}</Alert>}
        <div className="grid gap-4 md:grid-cols-2">
          <Field label="Code" hint="Majuscules, chiffres et tirets. Définitif.">
            <Input
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              placeholder="ANALAMANGA"
              required
              disabled={busy}
            />
          </Field>
          <Field label="Nom">
            <Input
              value={nom}
              onChange={(e) => setNom(e.target.value)}
              placeholder="Analamanga"
              required
              disabled={busy}
            />
          </Field>
        </div>
        <div className="flex gap-3">
          <Button type="submit" disabled={busy}>
            {busy ? 'Enregistrement…' : 'Créer la région'}
          </Button>
          <Button type="button" variant="secondary" onClick={onAnnuler} disabled={busy}>
            Annuler
          </Button>
        </div>
      </form>
    </Card>
  );
}

function FormulaireDistrict({
  regions,
  onAnnuler,
  onCree,
}: {
  regions: Region[];
  onAnnuler: () => void;
  onCree: () => void;
}) {
  const [code, setCode] = useState('');
  const [nom, setNom] = useState('');
  const [regionId, setRegionId] = useState('');
  const [busy, setBusy] = useState(false);
  const [erreur, setErreur] = useState<string | null>(null);

  async function envoyer(e: React.FormEvent) {
    e.preventDefault();
    setErreur(null);
    setBusy(true);
    try {
      await api.createDistrict({
        code: code.trim().toUpperCase(),
        name: nom.trim(),
        regionId,
      });
      onCree();
    } catch (err) {
      setErreur(err instanceof ApiError ? err.message : 'Création impossible.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <form onSubmit={envoyer} className="flex flex-col gap-4">
        <h3 className="text-lg font-semibold">Nouveau district</h3>
        {erreur && <Alert>{erreur}</Alert>}
        <div className="grid gap-4 md:grid-cols-3">
          <Field label="Région">
            <Select
              value={regionId}
              onChange={(e) => setRegionId(e.target.value)}
              required
              disabled={busy}
            >
              <option value="">Choisir…</option>
              {regions.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.name}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Code" hint="Définitif.">
            <Input
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              placeholder="AMBOHIDRATRIMO"
              required
              disabled={busy}
            />
          </Field>
          <Field label="Nom">
            <Input
              value={nom}
              onChange={(e) => setNom(e.target.value)}
              placeholder="Ambohidratrimo"
              required
              disabled={busy}
            />
          </Field>
        </div>
        <div className="flex gap-3">
          <Button type="submit" disabled={busy || !regionId}>
            {busy ? 'Enregistrement…' : 'Créer le district'}
          </Button>
          <Button type="button" variant="secondary" onClick={onAnnuler} disabled={busy}>
            Annuler
          </Button>
        </div>
      </form>
    </Card>
  );
}
