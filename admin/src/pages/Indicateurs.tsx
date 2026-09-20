import { useEffect, useState } from 'react';
import {
  ApiError,
  api,
  type Granularite,
  type Indicateurs,
  type Niveau,
  type SessionUser,
} from '../lib/api';
import { Alert, Card, EmptyState } from '../components/ui';

const GRANULARITES: Array<[Granularite, string]> = [
  ['semaine', 'Par semaine'],
  ['mois', 'Par mois'],
  ['annee', 'Par année'],
];

const NIVEAUX: Array<[Niveau, string]> = [
  ['csb', 'Par centre'],
  ['district', 'Par district'],
  ['region', 'Par région'],
];

/**
 * Tableau de bord des indicateurs (CDC §4 et §5).
 *
 * **Aucun dossier individuel n'apparaît ici**, uniquement des dénombrements :
 * c'est la règle du CDC §5 pour les niveaux supérieurs, et le serveur ne sait
 * de toute façon rien renvoyer d'autre sur ces routes.
 */
export function Indicateurs({ user }: { user: SessionUser }) {
  const [data, setData] = useState<Indicateurs | null>(null);
  const [granularite, setGranularite] = useState<Granularite>('mois');
  const [niveau, setNiveau] = useState<Niveau>('csb');
  const [erreur, setErreur] = useState<string | null>(null);
  const [chargement, setChargement] = useState(true);

  const national = user.role === 'ADMIN_NATIONAL';

  useEffect(() => {
    setChargement(true);
    api
      .indicateurs({ granularite, niveau: national ? niveau : 'csb' })
      .then((d) => {
        setData(d);
        setErreur(null);
      })
      .catch((e) =>
        setErreur(e instanceof ApiError ? e.message : 'Chargement impossible.'),
      )
      .finally(() => setChargement(false));
  }, [granularite, niveau, national]);

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold">Indicateurs</h2>
          <p className="text-on-surface-variant">
            {data
              ? `Du ${formatDate(data.periode.debut)} au ${formatDate(data.periode.fin)}`
              : 'Chargement…'}
          </p>
        </div>

        <div className="flex flex-wrap gap-2">
          <SegmentedControl
            options={GRANULARITES}
            value={granularite}
            onChange={setGranularite}
          />
          {national && (
            <SegmentedControl options={NIVEAUX} value={niveau} onChange={setNiveau} />
          )}
        </div>
      </div>

      {erreur && <Alert>{erreur}</Alert>}

      {data && (
        <>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <Tuile
              libelle="Consultations"
              valeur={data.totaux.consultations}
              teinte="primary"
            />
            <Tuile
              libelle="Consultations prénatales"
              valeur={data.totaux.cpn}
              teinte="accent"
            />
            <Tuile
              libelle="Vaccinations"
              valeur={data.totaux.vaccinations}
              teinte="success"
            />
            <Tuile
              libelle="Planification familiale"
              valeur={data.totaux.planificationFamiliale}
              teinte="primary"
            />
            <Tuile
              libelle="Nouveaux dossiers"
              valeur={data.totaux.nouveauxDossiers}
              teinte="primary"
            />
            <Tuile
              libelle="Dossiers actifs"
              valeur={data.totaux.dossiersActifs}
              teinte="neutre"
              note="Hors dossiers archivés"
            />
          </div>

          <Evolution serie={data.serie} granularite={data.periode.granularite} />
          <Repartition data={data} />
        </>
      )}

      {!chargement && data && data.totaux.consultations === 0 && (
        <Alert tone="info">
          Aucune activité enregistrée sur la période. C'est attendu tant que la
          synchronisation n'est pas livrée (ticket 3.1) : les données saisies
          dans l'application mobile restent aujourd'hui sur les téléphones.
        </Alert>
      )}
    </div>
  );
}

/** Chiffre isolé, lisible d'un coup d'œil. */
function Tuile({
  libelle,
  valeur,
  teinte,
  note,
}: {
  libelle: string;
  valeur: number;
  teinte: 'primary' | 'accent' | 'success' | 'neutre';
  note?: string;
}) {
  // La couleur n'est qu'un trait latéral : elle distingue les familles sans
  // jamais porter l'information seule, qui reste dans le libellé.
  const trait = {
    primary: 'bg-primary',
    accent: 'bg-accent',
    success: 'bg-success',
    neutre: 'bg-outline',
  }[teinte];

  return (
    <div className="flex overflow-hidden rounded-xl border border-outline-variant bg-surface-card">
      <div className={`w-1.5 shrink-0 ${trait}`} />
      <div className="p-5">
        <p className="text-sm font-medium text-on-surface-variant">{libelle}</p>
        <p className="mt-1 text-3xl font-bold tabular-nums">
          {valeur.toLocaleString('fr-FR')}
        </p>
        {note && <p className="mt-1 text-xs text-on-surface-variant">{note}</p>}
      </div>
    </div>
  );
}

/**
 * Évolution dans le temps.
 *
 * Barres empilées dessinées en SVG plutôt qu'avec une bibliothèque de
 * graphiques : quatre séries sur douze périodes ne justifient pas 200 Ko de
 * JavaScript supplémentaires, sur des connexions qui sont déjà le point
 * faible du projet.
 */
function Evolution({
  serie,
  granularite,
}: {
  serie: Indicateurs['serie'];
  granularite: Granularite;
}) {
  if (serie.length === 0) {
    return (
      <EmptyState
        title="Pas encore de données à représenter"
        hint="Le graphique apparaîtra dès que des actes auront été enregistrés."
      />
    );
  }

  const totaux = serie.map(
    (p) => p.consultations + p.cpn + p.vaccinations + p.planificationFamiliale,
  );
  const max = Math.max(...totaux, 1);

  const series = [
    { cle: 'consultations' as const, libelle: 'Consultations', couleur: '#1a4f76' },
    { cle: 'cpn' as const, libelle: 'CPN', couleur: '#cc4a45' },
    { cle: 'vaccinations' as const, libelle: 'Vaccinations', couleur: '#0f7a4d' },
    {
      cle: 'planificationFamiliale' as const,
      libelle: 'Planification familiale',
      couleur: '#9a6300',
    },
  ];

  return (
    <Card>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <h3 className="text-lg font-semibold">Évolution</h3>
        <div className="flex flex-wrap gap-4">
          {series.map((s) => (
            <span key={s.cle} className="flex items-center gap-1.5 text-sm">
              <span
                className="inline-block size-3 rounded-sm"
                style={{ backgroundColor: s.couleur }}
                aria-hidden
              />
              {s.libelle}
            </span>
          ))}
        </div>
      </div>

      <div className="flex items-end gap-1 overflow-x-auto pb-2" style={{ height: 220 }}>
        {serie.map((p, i) => {
          const total = totaux[i];
          return (
            <div
              key={p.periode}
              className="flex min-w-10 flex-1 flex-col items-center gap-1"
              title={`${formatPeriode(p.periode, granularite)} — ${total} acte${total > 1 ? 's' : ''}`}
            >
              <div
                className="flex w-full flex-col-reverse justify-start rounded-t"
                style={{ height: `${(total / max) * 170}px` }}
              >
                {series.map((s) => {
                  const v = p[s.cle];
                  if (v === 0) return null;
                  return (
                    <div
                      key={s.cle}
                      style={{
                        height: `${(v / Math.max(total, 1)) * 100}%`,
                        backgroundColor: s.couleur,
                      }}
                    />
                  );
                })}
              </div>
              <span className="whitespace-nowrap text-xs text-on-surface-variant">
                {formatPeriode(p.periode, granularite)}
              </span>
            </div>
          );
        })}
      </div>
    </Card>
  );
}

function Repartition({ data }: { data: Indicateurs }) {
  const titre = {
    csb: 'Par centre de santé',
    district: 'Par district',
    region: 'Par région',
  }[data.niveau];

  if (data.repartition.length === 0) {
    return <EmptyState title="Aucun centre enregistré" />;
  }

  return (
    <div>
      <h3 className="mb-3 text-lg font-semibold">{titre}</h3>
      <div className="overflow-x-auto rounded-xl border border-outline-variant bg-surface-card">
        <table className="w-full text-left">
          <thead className="border-b border-outline-variant bg-surface-container">
            <tr>
              <th className="p-3 font-semibold">Nom</th>
              <th className="p-3 text-right font-semibold">Consultations</th>
              <th className="p-3 text-right font-semibold">CPN</th>
              <th className="p-3 text-right font-semibold">Vaccinations</th>
              <th className="p-3 text-right font-semibold">PF</th>
              <th className="p-3 text-right font-semibold">Nouveaux dossiers</th>
            </tr>
          </thead>
          <tbody>
            {data.repartition.map((l) => (
              <tr key={l.cle} className="border-b border-outline-variant last:border-0">
                <td className="p-3 font-medium">{l.libelle}</td>
                <td className="p-3 text-right tabular-nums">{l.consultations}</td>
                <td className="p-3 text-right tabular-nums">{l.cpn}</td>
                <td className="p-3 text-right tabular-nums">{l.vaccinations}</td>
                <td className="p-3 text-right tabular-nums">
                  {l.planificationFamiliale}
                </td>
                <td className="p-3 text-right tabular-nums">{l.nouveauxDossiers}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function SegmentedControl<T extends string>({
  options,
  value,
  onChange,
}: {
  options: Array<[T, string]>;
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <div className="inline-flex rounded-lg border border-outline bg-surface-card p-0.5">
      {options.map(([cle, libelle]) => (
        <button
          key={cle}
          onClick={() => onChange(cle)}
          aria-pressed={value === cle}
          className={`min-h-9 rounded-md px-3 text-sm font-medium transition-colors ${
            value === cle
              ? 'bg-primary text-white'
              : 'text-on-surface-variant hover:text-on-surface'
          }`}
        >
          {libelle}
        </button>
      ))}
    </div>
  );
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString('fr-FR', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
}

function formatPeriode(iso: string, granularite: Granularite): string {
  const d = new Date(iso);
  if (granularite === 'annee') return String(d.getFullYear());
  if (granularite === 'semaine')
    return d.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
  return d.toLocaleDateString('fr-FR', { month: 'short', year: '2-digit' });
}
