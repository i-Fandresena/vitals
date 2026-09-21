/**
 * Client HTTP de l'espace d'administration.
 *
 * Le jeton d'accès vit en mémoire, jamais dans `localStorage` : un script
 * injecté sur la page pourrait l'y lire. Le jeton de rafraîchissement, lui,
 * est conservé pour éviter une reconnexion à chaque rechargement — compromis
 * assumé, borné par sa révocation côté serveur.
 */

const BASE_URL: string =
  import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000/api/v1';

/** Identifiant de cet appareil, attendu par l'API pour tracer les sessions. */
const DEVICE_KEY = 'vitals.admin.device';
const REFRESH_KEY = 'vitals.admin.refresh';

function deviceId(): string {
  let id = localStorage.getItem(DEVICE_KEY);
  if (!id) {
    id = `admin-${crypto.randomUUID()}`;
    localStorage.setItem(DEVICE_KEY, id);
  }
  return id;
}

let accessToken: string | null = null;

export class ApiError extends Error {
  readonly status: number;

  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

async function request<T>(
  path: string,
  init: RequestInit = {},
  retry = true,
): Promise<T> {
  let response: Response;

  try {
    response = await fetch(`${BASE_URL}${path}`, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
        ...init.headers,
      },
    });
  } catch {
    throw new ApiError('Le serveur est injoignable.', 0);
  }

  // Une seule tentative de renouvellement : sans ce garde-fou, un jeton
  // définitivement refusé provoquerait une boucle de requêtes.
  if (response.status === 401 && retry && (await tryRefresh())) {
    return request<T>(path, init, false);
  }

  if (response.status === 204) return undefined as T;

  const body: unknown = await response.json().catch(() => null);

  if (!response.ok) {
    const message =
      body && typeof body === 'object' && 'message' in body
        ? Array.isArray(body.message)
          ? body.message.join('\n')
          : String(body.message)
        : 'Une erreur est survenue.';
    throw new ApiError(message, response.status);
  }

  return body as T;
}

async function tryRefresh(): Promise<boolean> {
  const refreshToken = localStorage.getItem(REFRESH_KEY);
  if (!refreshToken) return false;

  try {
    const response = await fetch(`${BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken, deviceId: deviceId() }),
    });
    if (!response.ok) {
      localStorage.removeItem(REFRESH_KEY);
      return false;
    }
    const data = (await response.json()) as AuthTokens;
    accessToken = data.accessToken;
    localStorage.setItem(REFRESH_KEY, data.refreshToken);
    return true;
  } catch {
    return false;
  }
}

// --- Types échangés avec l'API ---

export type UserRole =
  | 'AGENT_COMMUNAUTAIRE'
  | 'INFIRMIER'
  | 'SAGE_FEMME'
  | 'MEDECIN'
  | 'RESPONSABLE_CSB'
  | 'ADMIN_NATIONAL';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

export interface SessionUser {
  id: string;
  username: string;
  fullName: string;
  role: UserRole;
  csbId: string | null;
  csbName: string | null;
}

export interface Csb {
  id: string;
  code: string;
  name: string;
  commune: string | null;
  districtId: string;
  districtName: string;
  regionName: string;
  allowsNurseAntenatalCare: boolean;
  /** Unité d'organisation DHIS2, nulle tant que le centre n'est pas rapproché. */
  dhis2OrgUnit: string | null;
  userCount: number;
  beneficiaryCount: number;
}

export interface CorrespondanceDhis2 {
  indicator: string;
  dataElement: string;
  categoryOptionCombo: string | null;
  label: string | null;
}

export interface EtatDhis2 {
  serveur: string | null;
  configure: boolean;
  correspondances: CorrespondanceDhis2[];
  centres: number;
  centresRapproches: number;
}

export interface ResultatExportDhis2 {
  periode: string;
  simulation: boolean;
  valeursEnvoyees: number;
  centresRetenus: number;
  centresNonRapproches: string[];
  indicateursNonRapproches: string[];
  resume?: {
    statut: string;
    importes: number;
    misAJour: number;
    ignores: number;
    rejetes: number;
    messages: string[];
  };
}

export interface AdminUser {
  id: string;
  username: string;
  fullName: string;
  role: UserRole;
  phone: string | null;
  csbId: string | null;
  isActive: boolean;
  lastLoginAt: string | null;
  createdAt: string;
}

export interface District {
  id: string;
  code: string;
  name: string;
  regionId: string;
  regionName?: string;
  csbCount?: number;
}

export interface Region {
  id: string;
  code: string;
  name: string;
  districtCount?: number;
}

export interface AuditEntry {
  id: string;
  action: string;
  entityType: string;
  entityId: string | null;
  changedFields: string[];
  auteur: { username: string; fullName: string; role: UserRole } | null;
  csb: { code: string; name: string } | null;
  deviceId: string | null;
  serverTimestamp: string;
}

export type Granularite = 'semaine' | 'mois' | 'annee';
export type Niveau = 'csb' | 'district' | 'region';

export interface LigneIndicateur {
  cle: string;
  libelle: string;
  consultations: number;
  cpn: number;
  vaccinations: number;
  planificationFamiliale: number;
  nouveauxDossiers: number;
}

export interface Indicateurs {
  periode: { debut: string; fin: string; granularite: Granularite };
  niveau: Niveau;
  totaux: {
    consultations: number;
    cpn: number;
    vaccinations: number;
    planificationFamiliale: number;
    nouveauxDossiers: number;
    dossiersActifs: number;
  };
  repartition: LigneIndicateur[];
  serie: Array<{
    periode: string;
    consultations: number;
    cpn: number;
    vaccinations: number;
    planificationFamiliale: number;
  }>;
}

// --- Appels ---

export const api = {
  async login(username: string, password: string) {
    const data = await request<AuthTokens & { user: SessionUser }>(
      '/auth/login',
      {
        method: 'POST',
        body: JSON.stringify({ username, password, deviceId: deviceId() }),
      },
      false,
    );
    accessToken = data.accessToken;
    localStorage.setItem(REFRESH_KEY, data.refreshToken);
    return data.user;
  },

  async restore(): Promise<SessionUser | null> {
    if (!(await tryRefresh())) return null;
    try {
      return await request<SessionUser>('/auth/me');
    } catch {
      return null;
    }
  },

  async logout() {
    try {
      await request<void>('/auth/logout', { method: 'POST' });
    } finally {
      accessToken = null;
      localStorage.removeItem(REFRESH_KEY);
    }
  },

  regions: () => request<Region[]>('/admin/regions'),
  createRegion: (body: unknown) =>
    request<Region>('/admin/regions', { method: 'POST', body: JSON.stringify(body) }),

  districts: () => request<District[]>('/admin/districts'),
  createDistrict: (body: unknown) =>
    request<District>('/admin/districts', {
      method: 'POST',
      body: JSON.stringify(body),
    }),

  indicateurs: (params: {
    granularite?: Granularite;
    niveau?: Niveau;
    debut?: string;
    fin?: string;
  }) => {
    const q = new URLSearchParams(
      Object.entries(params).filter(([, v]) => v) as [string, string][],
    );
    return request<Indicateurs>(`/admin/indicateurs?${q.toString()}`);
  },

  audit: (limit = 100) => request<AuditEntry[]>(`/admin/audit?limit=${limit}`),
  connexionsEchouees: () =>
    request<{ total24h: number }>('/admin/audit/connexions-echouees'),

  csbs: () => request<Csb[]>('/admin/csbs'),

  dhis2: () => request<EtatDhis2>('/admin/dhis2'),

  dhis2Correspondances: (correspondances: CorrespondanceDhis2[]) =>
    request<EtatDhis2>('/admin/dhis2/correspondances', {
      method: 'PUT',
      body: JSON.stringify({ correspondances }),
    }),

  dhis2Export: (periode: string, simulation: boolean) =>
    request<ResultatExportDhis2>('/admin/dhis2/export', {
      method: 'POST',
      body: JSON.stringify({ periode, simulation }),
    }),
  createCsb: (body: unknown) =>
    request<Csb>('/admin/csbs', { method: 'POST', body: JSON.stringify(body) }),
  updateCsb: (id: string, body: unknown) =>
    request<Csb>(`/admin/csbs/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),

  users: (csbId?: string) =>
    request<AdminUser[]>(`/admin/users${csbId ? `?csbId=${csbId}` : ''}`),
  createUser: (body: unknown) =>
    request<AdminUser>('/admin/users', { method: 'POST', body: JSON.stringify(body) }),
  updateUser: (id: string, body: unknown) =>
    request<AdminUser>(`/admin/users/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(body),
    }),
  resetPassword: (id: string, password: string) =>
    request<{ ok: boolean }>(`/admin/users/${id}/reset-password`, {
      method: 'POST',
      body: JSON.stringify({ password }),
    }),
};

export const ROLE_LABELS: Record<UserRole, string> = {
  AGENT_COMMUNAUTAIRE: 'Agent communautaire',
  INFIRMIER: 'Infirmier',
  SAGE_FEMME: 'Sage-femme',
  MEDECIN: 'Médecin',
  RESPONSABLE_CSB: 'Responsable du CSB',
  ADMIN_NATIONAL: 'Administration nationale',
};
