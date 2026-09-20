import { useEffect, useState } from 'react';
import { ApiError, ROLE_LABELS, api, type AuditEntry } from '../lib/api';
import { Alert, Badge, Card, EmptyState } from '../components/ui';

/** Libellés des opérations tracées. */
const ACTIONS: Record<string, string> = {
  CREATE: 'Création',
  UPDATE: 'Modification',
  ARCHIVE: 'Archivage',
  CANCEL: 'Annulation',
  LOGIN: 'Connexion',
  LOGIN_FAILED: 'Connexion refusée',
  SYNC_CONFLICT: 'Conflit de synchronisation',
  EXPORT: 'Export',
};

const ENTITES: Record<string, string> = {
  User: 'Compte',
  Csb: 'Centre',
  Region: 'Région',
  District: 'District',
  Beneficiary: 'Dossier',
};

/**
 * Journal d'audit (CDC §8).
 *
 * En lecture seule : un journal qu'on peut modifier ne prouve rien. Aucune
 * route d'écriture ni de suppression n'existe côté serveur.
 *
 * Les entrées ne citent que les **noms des champs modifiés**, jamais leurs
 * valeurs — un journal qui recopierait les données de santé deviendrait
 * lui-même une base de données de santé.
 */
export function Journal() {
  const [entrees, setEntrees] = useState<AuditEntry[] | null>(null);
  const [echecs, setEchecs] = useState<number | null>(null);
  const [erreur, setErreur] = useState<string | null>(null);

  useEffect(() => {
    api
      .audit(150)
      .then(setEntrees)
      .catch((e) =>
        setErreur(e instanceof ApiError ? e.message : 'Chargement impossible.'),
      );
    api
      .connexionsEchouees()
      .then((d) => setEchecs(d.total24h))
      .catch(() => setEchecs(null));
  }, []);

  return (
    <div className="flex flex-col gap-5">

      {erreur && <Alert>{erreur}</Alert>}

      {echecs !== null && echecs > 0 && (
        <Card>
          <div className="flex items-start gap-3">
            <span
              className="mt-1.5 inline-block size-2.5 shrink-0 rounded-full bg-accent"
              aria-hidden
            />
            <p>
              <span className="font-semibold">
                {echecs} tentative{echecs > 1 ? 's' : ''} de connexion refusée
                {echecs > 1 ? 's' : ''}
              </span>{' '}
              dans les dernières 24 heures.
              <br />
              <span className="text-sm text-on-surface-variant">
                Souvent un mot de passe oublié. Si le nombre est élevé et
                inattendu, cela peut aussi signaler une tentative d'intrusion.
              </span>
            </p>
          </div>
        </Card>
      )}

      {entrees === null ? (
        <p className="text-on-surface-variant">Chargement…</p>
      ) : entrees.length === 0 ? (
        <EmptyState title="Aucune opération enregistrée" />
      ) : (
        <div className="overflow-x-auto rounded-xl border border-outline-variant bg-surface-card">
          <table className="w-full text-left">
            <thead className="border-b border-outline-variant bg-surface-container">
              <tr>
                <th className="p-3 font-semibold">Quand</th>
                <th className="p-3 font-semibold">Qui</th>
                <th className="p-3 font-semibold">Quoi</th>
                <th className="p-3 font-semibold">Sur</th>
                <th className="p-3 font-semibold">Champs</th>
              </tr>
            </thead>
            <tbody>
              {entrees.map((e) => (
                <tr key={e.id} className="border-b border-outline-variant last:border-0">
                  <td className="whitespace-nowrap p-3 text-sm tabular-nums">
                    {formatInstant(e.serverTimestamp)}
                  </td>
                  <td className="p-3">
                    {e.auteur ? (
                      <>
                        <span className="block">{e.auteur.fullName}</span>
                        <span className="text-xs text-on-surface-variant">
                          {ROLE_LABELS[e.auteur.role]}
                        </span>
                      </>
                    ) : (
                      <span className="text-on-surface-variant">—</span>
                    )}
                  </td>
                  <td className="p-3">
                    {e.action === 'LOGIN_FAILED' ? (
                      <Badge tone="warning">{ACTIONS[e.action] ?? e.action}</Badge>
                    ) : (
                      <Badge>{ACTIONS[e.action] ?? e.action}</Badge>
                    )}
                  </td>
                  <td className="p-3 text-sm">
                    {ENTITES[e.entityType] ?? e.entityType}
                    {e.csb && (
                      <span className="block text-xs text-on-surface-variant">
                        {e.csb.name}
                      </span>
                    )}
                  </td>
                  <td className="p-3 text-sm text-on-surface-variant">
                    {e.changedFields.length > 0 ? e.changedFields.join(', ') : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <p className="text-sm text-on-surface-variant">
        Seuls les noms des champs modifiés sont conservés, jamais leurs valeurs.
      </p>
    </div>
  );
}

function formatInstant(iso: string): string {
  return new Date(iso).toLocaleString('fr-FR', {
    day: '2-digit',
    month: '2-digit',
    year: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}
