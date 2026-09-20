import { useEffect, useState } from 'react';
import {
  ApiError,
  api,
  type Granularite,
  type Indicateurs,
  type Niveau,
  type SessionUser,
} from '../lib/api';
import { Alert, EmptyState, Panel, StatCard } from '../components/ui';
import {
  IconConsultation,
  IconDossier,
  IconGrossesse,
  IconPlanification,
  IconVaccin,
} from '../components/icons';

const GRANULARITES: Array<[Granularite, string]> = [
  ['semaine', 'Semaine'],
  ['mois', 'Mois'],
  ['annee', 'Année'],
];

const NIVEAUX: Array<[Niveau, string]> = [
  ['csb', 'Centre'],
  ['district', 'District'],
  ['region', 'Région'],
];

/** Les quatre familles d'actes, dans l'ordre où elles apparaissent partout.
 *
 * Une seule définition pour la légende, le graphique et la répartition : trois
 * listes séparées finiraient par diverger, et une couleur qui ne veut pas dire
 * la même chose d'un graphique à l'autre est pire que pas de couleur. */
const FAMILLES = [
  {
    cle: 'consultations',
    libelle: 'Consultations',
    couleur: '#1a4f76',
    Icone: IconConsultation,
  },
  { cle: 'cpn', libelle: 'CPN', couleur: '#cc4a45', Icone: IconGrossesse },
  {
    cle: 'vaccinations',
    libelle: 'Vaccinations',
    couleur: '#0f7a4d',
    Icone: IconVaccin,
  },
  {
    cle: 'planificationFamiliale',
    libelle: 'Planification familiale',
    couleur: '#9a6300',
    Icone: IconPlanification,
  },
] as const;

type CleFamille = (typeof FAMILLES)[number]['cle'];

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

  const total = data
    ? FAMILLES.reduce((n, f) => n + data.totaux[f.cle], 0)
    : 0;
  const part = (v: number) => (total === 0 ? 0 : (v / total) * 100);

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-on-surface-variant">
          {data
            ? `Du ${formatDate(data.periode.debut)} au ${formatDate(data.periode.fin)}`
            : 'Chargement…'}
        </p>
        <div className="flex flex-wrap gap-2">
          <Segments
            options={GRANULARITES}
            value={granularite}
            onChange={setGranularite}
            etiquette="Pas de temps"
          />
          {national && (
            <Segments
              options={NIVEAUX}
              value={niveau}
              onChange={setNiveau}
              etiquette="Regroupement"
            />
          )}
        </div>
      </div>

      {erreur && <Alert>{erreur}</Alert>}

      {data && (
        <>
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {FAMILLES.map((f, i) => (
              <StatCard
                key={f.cle}
                libelle={f.libelle}
                valeur={data.totaux[f.cle]}
                part={part(data.totaux[f.cle])}
                note="Part de l'activité de la période"
                icone={<f.Icone className="size-5" />}
                // La première tuile seulement : l'œil doit savoir où se poser.
                enAvant={i === 0}
              />
            ))}
            <StatCard
              libelle="Nouveaux dossiers"
              valeur={data.totaux.nouveauxDossiers}
              note="Créés pendant la période"
              icone={<IconDossier className="size-5" />}
            />
            <StatCard
              libelle="Dossiers suivis"
              valeur={data.totaux.dossiersActifs}
              note="Hors dossiers archivés"
              icone={<IconDossier className="size-5" />}
            />
          </div>

          <div className="grid gap-5 xl:grid-cols-[2fr_1fr]">
            <Evolution serie={data.serie} granularite={data.periode.granularite} />
            <RepartitionActes totaux={data.totaux} total={total} />
          </div>

          <Repartition data={data} />
        </>
      )}

      {!chargement && data && total === 0 && (
        <Alert tone="info">
          Aucun acte enregistré sur la période. Les saisies faites dans
          l'application mobile apparaissent ici dès que les appareils se sont
          synchronisés.
        </Alert>
      )}
    </div>
  );
}

/**
 * Évolution dans le temps.
 *
 * Barres empilées dessinées à la main plutôt qu'avec une bibliothèque de
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
      <Panel titre="Évolution" sous="Actes enregistrés, par période">
        <EmptyState
          title="Pas encore de données à représenter"
          hint="Le graphique apparaîtra dès que des actes auront été enregistrés."
        />
      </Panel>
    );
  }

  const totaux = serie.map((p) =>
    FAMILLES.reduce((n, f) => n + p[f.cle], 0),
  );
  const max = Math.max(...totaux, 1);
  const graduations = echelle(max);

  return (
    <Panel
      titre="Évolution"
      sous="Actes enregistrés, comptés à la date de l'acte"
      action={<Legende />}
    >
      <div className="flex gap-3">
        {/* Les graduations rendent les hauteurs lisibles : sans elles, on ne
            compare que des rapports, jamais des nombres. */}
        <div
          className="flex w-10 shrink-0 flex-col justify-between text-right text-xs tabular-nums text-on-surface-variant"
          style={{ height: 200 }}
        >
          {/* Indice en clé : sur une petite série, deux graduations arrondies
              peuvent tomber sur le même nombre. */}
          {[...graduations].reverse().map((g, i) => (
            <span key={i}>{g.toLocaleString('fr-FR')}</span>
          ))}
        </div>

        <div className="min-w-0 flex-1 overflow-x-auto">
          <div className="flex items-end gap-2" style={{ height: 200 }}>
            {serie.map((p, i) => {
              const total = totaux[i];
              return (
                <div
                  key={p.periode}
                  className="flex min-w-8 flex-1 flex-col justify-end"
                  style={{ height: '100%' }}
                  title={`${formatPeriode(p.periode, granularite)} — ${total} acte${total > 1 ? 's' : ''}`}
                >
                  <div
                    className="flex w-full flex-col-reverse overflow-hidden rounded-lg"
                    style={{
                      height: `${(total / graduations[graduations.length - 1]) * 100}%`,
                    }}
                  >
                    {FAMILLES.map((f) => {
                      const v = p[f.cle];
                      if (v === 0) return null;
                      return (
                        <div
                          key={f.cle}
                          style={{
                            height: `${(v / Math.max(total, 1)) * 100}%`,
                            backgroundColor: f.couleur,
                          }}
                        />
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>

          <div className="mt-2 flex gap-2">
            {serie.map((p) => (
              <span
                key={p.periode}
                className="min-w-8 flex-1 truncate text-center text-xs text-on-surface-variant"
              >
                {formatPeriode(p.periode, granularite)}
              </span>
            ))}
          </div>
        </div>
      </div>
    </Panel>
  );
}

function Legende() {
  return (
    <div className="flex flex-wrap gap-x-4 gap-y-1">
      {FAMILLES.map((f) => (
        <span key={f.cle} className="flex items-center gap-1.5 text-sm">
          <span
            className="inline-block size-3 rounded-sm"
            style={{ backgroundColor: f.couleur }}
            aria-hidden
          />
          {f.libelle}
        </span>
      ))}
    </div>
  );
}

/**
 * Part de chaque famille d'actes.
 *
 * Un anneau et non un camembert : la découpe se lit mieux sur l'arc que sur
 * l'aire, et le centre accueille le total, qui est l'information qu'on cherche
 * en même temps que la répartition.
 */
function RepartitionActes({
  totaux,
  total,
}: {
  totaux: Indicateurs['totaux'];
  total: number;
}) {
  if (total === 0) {
    return (
      <Panel titre="Répartition" sous="Par famille d'actes">
        <EmptyState title="Aucun acte sur la période" />
      </Panel>
    );
  }

  const rayon = 54;
  const circonference = 2 * Math.PI * rayon;

  // Les arcs sont calculés avant le rendu plutôt qu'accumulés en le
  // parcourant : un compteur muté dans le JSX repart de travers dès qu'une
  // portion est sautée.
  const arcs: Array<{ couleur: string; portion: number; depart: number }> = [];
  let depart = 0;
  for (const f of FAMILLES) {
    const portion = totaux[f.cle] / total;
    if (portion > 0) arcs.push({ couleur: f.couleur, portion, depart });
    depart += portion;
  }

  return (
    <Panel titre="Répartition" sous="Par famille d'actes">
      <div className="flex flex-col items-center gap-5">
        <div className="relative">
          <svg viewBox="0 0 140 140" className="size-40" role="img">
            <title>Répartition des actes par famille</title>
            {arcs.map((a) => (
              <circle
                key={a.couleur}
                cx="70"
                cy="70"
                r={rayon}
                fill="none"
                stroke={a.couleur}
                strokeWidth="20"
                strokeDasharray={`${a.portion * circonference} ${circonference}`}
                strokeDashoffset={-a.depart * circonference}
                transform="rotate(-90 70 70)"
              />
            ))}
          </svg>
          <div className="absolute inset-0 grid place-items-center">
            <div className="text-center">
              <p className="text-2xl font-bold tabular-nums">
                {total.toLocaleString('fr-FR')}
              </p>
              <p className="text-xs text-on-surface-variant">actes</p>
            </div>
          </div>
        </div>

        <ul className="w-full">
          {FAMILLES.map((f) => (
            <li
              key={f.cle}
              className="flex items-center gap-3 border-b border-outline-variant py-2 last:border-0"
            >
              <span
                className="size-3 shrink-0 rounded-sm"
                style={{ backgroundColor: f.couleur }}
                aria-hidden
              />
              <span className="min-w-0 flex-1 truncate">{f.libelle}</span>
              <span className="tabular-nums">
                {totaux[f.cle].toLocaleString('fr-FR')}
              </span>
              <span className="w-14 rounded-full bg-surface-container py-0.5 text-center text-sm font-semibold tabular-nums">
                {Math.round((totaux[f.cle] / total) * 100)} %
              </span>
            </li>
          ))}
        </ul>
      </div>
    </Panel>
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
    <Panel titre={titre} sous="Dénombrements sur la période">
      <div className="-mx-5 overflow-x-auto px-5">
        <table className="w-full text-left">
          <thead>
            <tr className="border-b border-outline-variant">
              <th className="pb-3 font-semibold">Nom</th>
              {FAMILLES.map((f) => (
                <th key={f.cle} className="pb-3 pl-3 text-right font-semibold">
                  {f.cle === 'planificationFamiliale' ? 'PF' : f.libelle}
                </th>
              ))}
              <th className="pb-3 pl-3 text-right font-semibold">Nouveaux</th>
            </tr>
          </thead>
          <tbody>
            {data.repartition.map((l) => (
              <tr key={l.cle} className="border-b border-outline-variant last:border-0">
                <td className="py-3 font-medium">{l.libelle}</td>
                {FAMILLES.map((f) => (
                  <td key={f.cle} className="py-3 pl-3 text-right tabular-nums">
                    {l[f.cle as CleFamille].toLocaleString('fr-FR')}
                  </td>
                ))}
                <td className="py-3 pl-3 text-right tabular-nums">
                  {l.nouveauxDossiers.toLocaleString('fr-FR')}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Panel>
  );
}

function Segments<T extends string>({
  options,
  value,
  onChange,
  etiquette,
}: {
  options: Array<[T, string]>;
  value: T;
  onChange: (v: T) => void;
  etiquette: string;
}) {
  return (
    <div
      className="inline-flex rounded-xl border border-outline-variant bg-surface-card p-1"
      role="group"
      aria-label={etiquette}
    >
      {options.map(([cle, libelle]) => (
        <button
          key={cle}
          onClick={() => onChange(cle)}
          aria-pressed={value === cle}
          className={`min-h-9 rounded-lg px-3 text-sm font-medium transition-colors ${
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

/** Graduations rondes qui englobent le maximum. */
function echelle(max: number): number[] {
  const pas = Math.pow(10, Math.floor(Math.log10(Math.max(max, 1))));
  const haut = Math.ceil(max / pas) * pas;
  return [0, haut / 4, haut / 2, (haut * 3) / 4, haut].map((n) => Math.round(n));
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
