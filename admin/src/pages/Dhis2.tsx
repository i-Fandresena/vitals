import { useEffect, useState } from 'react';
import {
  ApiError,
  api,
  type CorrespondanceDhis2,
  type EtatDhis2,
  type ResultatExportDhis2,
} from '../lib/api';
import { Alert, Button, Field, Input, Panel } from '../components/ui';

/** Les indicateurs remontés, avec leur libellé à l'écran. */
const INDICATEURS: Array<[string, string]> = [
  ['consultations', 'Consultations'],
  ['cpn', 'Consultations prénatales'],
  ['vaccinations', 'Vaccinations'],
  ['planificationFamiliale', 'Planification familiale'],
  ['nouveauxDossiers', 'Nouveaux dossiers'],
];

/**
 * Remontée des indicateurs vers DHIS2.
 *
 * Deux rapprochements sont nécessaires : chaque centre vers une unité
 * d'organisation (page « Centres »), et chaque indicateur vers un élément de
 * données (ici). Ce qui n'est pas rapproché ne part pas — l'export le dit
 * plutôt que de laisser croire à une remontée complète.
 */
export function Dhis2() {
  const [etat, setEtat] = useState<EtatDhis2 | null>(null);
  const [erreur, setErreur] = useState<string | null>(null);
  const [resultat, setResultat] = useState<ResultatExportDhis2 | null>(null);
  const [occupe, setOccupe] = useState(false);

  // Le mois écoulé : on remonte un mois clos, pas celui en cours.
  const [periode, setPeriode] = useState(() => {
    const d = new Date();
    d.setMonth(d.getMonth() - 1);
    return d.toISOString().slice(0, 7);
  });

  const [brouillon, setBrouillon] = useState<Record<string, CorrespondanceDhis2>>({});

  useEffect(() => {
    api
      .dhis2()
      .then((e) => {
        setEtat(e);
        setBrouillon(Object.fromEntries(e.correspondances.map((c) => [c.indicator, c])));
      })
      .catch((e) =>
        setErreur(e instanceof ApiError ? e.message : 'Chargement impossible.'),
      );
  }, []);

  function modifier(indicateur: string, champ: keyof CorrespondanceDhis2, v: string) {
    setBrouillon((b) => {
      const existant: CorrespondanceDhis2 = b[indicateur] ?? {
        indicator: indicateur,
        dataElement: '',
        categoryOptionCombo: null,
        label: null,
      };
      return { ...b, [indicateur]: { ...existant, [champ]: v } };
    });
  }

  async function enregistrer() {
    setErreur(null);
    setOccupe(true);
    try {
      // Les lignes laissées vides ne sont pas envoyées : elles signifient
      // « pas encore rapproché », pas « rapproché à rien ».
      const lignes = Object.values(brouillon).filter((c) => c.dataElement.trim());
      setEtat(
        await api.dhis2Correspondances(
          lignes.map((c) => ({
            ...c,
            dataElement: c.dataElement.trim(),
            categoryOptionCombo: c.categoryOptionCombo?.trim() || null,
          })),
        ),
      );
    } catch (e) {
      setErreur(e instanceof ApiError ? e.message : 'Enregistrement impossible.');
    } finally {
      setOccupe(false);
    }
  }

  async function exporter(simulation: boolean) {
    setErreur(null);
    setResultat(null);
    setOccupe(true);
    try {
      setResultat(await api.dhis2Export(periode, simulation));
    } catch (e) {
      setErreur(e instanceof ApiError ? e.message : 'Export impossible.');
    } finally {
      setOccupe(false);
    }
  }

  if (!etat && !erreur) return <p className="text-on-surface-variant">Chargement…</p>;

  return (
    <div className="flex flex-col gap-5">
      {erreur && <Alert>{erreur}</Alert>}

      {etat && !etat.configure && (
        <Alert tone="info">
          Aucun serveur DHIS2 n'est configuré sur cette installation. Renseignez
          DHIS2_URL, DHIS2_USERNAME et DHIS2_PASSWORD dans le fichier .env du
          serveur, puis redémarrez l'API.
        </Alert>
      )}

      {etat && (
        <>
          <Panel titre="Serveur" sous="Renseigné dans la configuration de l'API">
            <dl className="grid gap-4 sm:grid-cols-3">
              <Donnee libelle="Adresse" valeur={etat.serveur ?? 'Non configuré'} />
              <Donnee
                libelle="Centres rapprochés"
                valeur={`${etat.centresRapproches} sur ${etat.centres}`}
              />
              <Donnee
                libelle="Indicateurs rapprochés"
                valeur={`${etat.correspondances.length} sur ${INDICATEURS.length}`}
              />
            </dl>
            {etat.centresRapproches < etat.centres && (
              <p className="mt-4 text-sm text-on-surface-variant">
                Les centres sans unité d'organisation ne partent pas. Leur
                identifiant DHIS2 se renseigne sur la page « Centres ».
              </p>
            )}
          </Panel>

          <Panel
            titre="Correspondance des indicateurs"
            sous="Identifiants à onze caractères, relevés dans DHIS2"
            action={
              <Button onClick={enregistrer} disabled={occupe}>
                Enregistrer
              </Button>
            }
          >
            <div className="flex flex-col gap-4">
              {INDICATEURS.map(([cle, libelle]) => (
                <div key={cle} className="grid gap-3 sm:grid-cols-[1fr_1fr_1fr]">
                  <Field label={libelle}>
                    <Input
                      value={brouillon[cle]?.dataElement ?? ''}
                      onChange={(e) => modifier(cle, 'dataElement', e.target.value)}
                      placeholder="Élément de données"
                      disabled={occupe}
                    />
                  </Field>
                  <Field
                    label="Combinaison de catégories"
                    hint="Vide si la combinaison par défaut s'applique."
                  >
                    <Input
                      value={brouillon[cle]?.categoryOptionCombo ?? ''}
                      onChange={(e) =>
                        modifier(cle, 'categoryOptionCombo', e.target.value)
                      }
                      placeholder="Facultatif"
                      disabled={occupe}
                    />
                  </Field>
                  <Field label="Libellé DHIS2" hint="Pour vous relire plus tard.">
                    <Input
                      value={brouillon[cle]?.label ?? ''}
                      onChange={(e) => modifier(cle, 'label', e.target.value)}
                      placeholder="Facultatif"
                      disabled={occupe}
                    />
                  </Field>
                </div>
              ))}
            </div>
          </Panel>

          <Panel
            titre="Envoyer un mois"
            sous="Les actes sont comptés à leur date, pas à leur date de saisie"
          >
            <div className="flex flex-wrap items-end gap-3">
              <div className="w-48">
                <Field label="Mois">
                  <Input
                    type="month"
                    value={periode}
                    onChange={(e) => setPeriode(e.target.value)}
                    disabled={occupe}
                  />
                </Field>
              </div>
              {/* La simulation d'abord, et dans cet ordre : c'est le seul
                  moyen de vérifier un rapprochement avant de publier des
                  chiffres nationaux. */}
              <Button
                variant="secondary"
                onClick={() => exporter(true)}
                disabled={occupe || !etat.configure}
              >
                Simuler
              </Button>
              <Button onClick={() => exporter(false)} disabled={occupe || !etat.configure}>
                Envoyer
              </Button>
            </div>

            {resultat && <Compte resultat={resultat} />}
          </Panel>
        </>
      )}
    </div>
  );
}

function Donnee({ libelle, valeur }: { libelle: string; valeur: string }) {
  return (
    <div>
      <dt className="text-sm text-on-surface-variant">{libelle}</dt>
      <dd className="break-all font-medium">{valeur}</dd>
    </div>
  );
}

function Compte({ resultat }: { resultat: ResultatExportDhis2 }) {
  const r = resultat.resume;

  return (
    <div className="mt-5 rounded-xl border border-outline-variant bg-surface p-4">
      <p className="font-semibold">
        {resultat.simulation ? 'Simulation' : 'Envoi'} du {resultat.periode} —{' '}
        {resultat.valeursEnvoyees} valeur
        {resultat.valeursEnvoyees > 1 ? 's' : ''} pour {resultat.centresRetenus}{' '}
        centre{resultat.centresRetenus > 1 ? 's' : ''}
      </p>

      {r && (
        <p className="mt-1 text-on-surface-variant">
          DHIS2 : {r.statut} · {r.importes} importée{r.importes > 1 ? 's' : ''} ·{' '}
          {r.misAJour} mise{r.misAJour > 1 ? 's' : ''} à jour · {r.ignores} ignorée
          {r.ignores > 1 ? 's' : ''}
        </p>
      )}

      {resultat.simulation && (
        <p className="mt-2 text-sm text-on-surface-variant">
          Rien n'a été écrit dans DHIS2.
        </p>
      )}

      {resultat.centresNonRapproches.length > 0 && (
        <p className="mt-3 text-sm text-on-surface-variant">
          Hors export, faute d'unité d'organisation :{' '}
          {resultat.centresNonRapproches.join(', ')}.
        </p>
      )}

      {resultat.indicateursNonRapproches.length > 0 && (
        <p className="mt-1 text-sm text-on-surface-variant">
          Indicateurs non rapprochés :{' '}
          {resultat.indicateursNonRapproches.join(', ')}.
        </p>
      )}

      {r && r.messages.length > 0 && (
        <ul className="mt-3 flex flex-col gap-1 text-sm text-danger">
          {r.messages.map((m, i) => (
            <li key={i}>{m}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
