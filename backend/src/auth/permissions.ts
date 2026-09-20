import { UserRole } from '@prisma/client';

/**
 * Permissions de l'application.
 *
 * Traduction directe de `docs/01-matrice-droits.md`. Ce fichier et son miroir
 * mobile (`mobile/lib/domain/permissions.dart`) doivent rester identiques.
 *
 * **C'est ce fichier qui fait autorité.** L'application mobile s'en sert pour
 * ne pas proposer l'impossible ; le serveur s'en sert pour refuser. Un appel
 * direct à l'API avec un jeton valide mais un rôle insuffisant doit échouer
 * ici, indépendamment de ce que l'interface affiche (ticket 2.2).
 */
export enum Permission {
  /** Ouvrir un dossier et voir l'identité : nom, âge, identifiant, village. */
  BeneficiaryViewIdentity = 'beneficiary:view_identity',

  /**
   * Voir l'historique de soin : consultations, vaccinations, CPN, PF.
   *
   * Séparé de l'identité parce que c'est exactement la ligne que l'agent
   * communautaire ne franchit pas : il oriente vers le CSB, il ne soigne pas.
   */
  BeneficiaryViewCareHistory = 'beneficiary:view_care_history',

  BeneficiaryCreate = 'beneficiary:create',
  BeneficiaryUpdateIdentity = 'beneficiary:update_identity',

  /** Retirer un dossier des recherches courantes. La suppression n'existe pas. */
  BeneficiaryArchive = 'beneficiary:archive',

  ConsultationRecord = 'consultation:record',

  /** Consultation prénatale et suivi de grossesse. */
  AntenatalRecord = 'antenatal:record',
  PostnatalRecord = 'postnatal:record',

  VaccinationRecord = 'vaccination:record',
  FamilyPlanningRecord = 'family_planning:record',
  CommunityDataRecord = 'community_data:record',

  /** Indicateurs de sa propre activité. */
  DashboardOwnActivity = 'dashboard:own_activity',

  /** Indicateurs de tout le centre. */
  DashboardCsb = 'dashboard:csb',

  /**
   * Indicateurs consolidés au-delà d'un seul centre.
   *
   * Distincte de [DashboardCsb] : le CDC §5 veut que les niveaux supérieurs
   * voient des totaux par district et par région, sans jamais accéder aux
   * dossiers individuels. Cette permission ouvre l'un sans ouvrir l'autre.
   */
  DashboardAggregated = 'dashboard:aggregated',

  DataExport = 'data:export',
  ManageCsbUsers = 'users:manage_csb',
  ManageCsbs = 'csbs:manage',
  ViewAuditLog = 'audit:view',
}

/**
 * Permissions attachées à chaque profil.
 *
 * `Readonly` volontaire : un appel qui modifierait ces ensembles à l'exécution
 * changerait les droits de tous les utilisateurs du processus.
 */
export const ROLE_PERMISSIONS: Readonly<Record<UserRole, readonly Permission[]>> = {
  // L'agent communautaire travaille hors du centre, souvent sur un appareil
  // partagé : c'est le profil le plus exposé, donc celui qui porte le moins de
  // données sensibles. Il identifie et oriente, il ne consulte pas.
  [UserRole.AGENT_COMMUNAUTAIRE]: [
    Permission.BeneficiaryViewIdentity,
    Permission.BeneficiaryCreate,
    Permission.CommunityDataRecord,
  ],

  [UserRole.INFIRMIER]: [
    Permission.BeneficiaryViewIdentity,
    Permission.BeneficiaryViewCareHistory,
    Permission.BeneficiaryCreate,
    Permission.BeneficiaryUpdateIdentity,
    Permission.ConsultationRecord,
    Permission.VaccinationRecord,
    Permission.FamilyPlanningRecord,
    Permission.CommunityDataRecord,
    Permission.DashboardOwnActivity,
    // La saisie des CPN dépend du centre, pas du rôle : voir permissionsFor().
  ],

  [UserRole.SAGE_FEMME]: [
    Permission.BeneficiaryViewIdentity,
    Permission.BeneficiaryViewCareHistory,
    Permission.BeneficiaryCreate,
    Permission.BeneficiaryUpdateIdentity,
    Permission.ConsultationRecord,
    Permission.AntenatalRecord,
    Permission.PostnatalRecord,
    Permission.VaccinationRecord,
    Permission.FamilyPlanningRecord,
    Permission.CommunityDataRecord,
    Permission.DashboardOwnActivity,
  ],

  // Le médecin d'un CSB II. Mêmes droits cliniques que la sage-femme : la
  // distinction entre les deux est professionnelle et sert la traçabilité,
  // elle ne correspond à aucune différence d'accès.
  [UserRole.MEDECIN]: [
    Permission.BeneficiaryViewIdentity,
    Permission.BeneficiaryViewCareHistory,
    Permission.BeneficiaryCreate,
    Permission.BeneficiaryUpdateIdentity,
    Permission.ConsultationRecord,
    Permission.AntenatalRecord,
    Permission.PostnatalRecord,
    Permission.VaccinationRecord,
    Permission.FamilyPlanningRecord,
    Permission.CommunityDataRecord,
    Permission.DashboardOwnActivity,
  ],

  [UserRole.RESPONSABLE_CSB]: [
    Permission.BeneficiaryViewIdentity,
    Permission.BeneficiaryViewCareHistory,
    Permission.BeneficiaryCreate,
    Permission.BeneficiaryUpdateIdentity,
    Permission.BeneficiaryArchive,
    Permission.ConsultationRecord,
    Permission.AntenatalRecord,
    Permission.PostnatalRecord,
    Permission.VaccinationRecord,
    Permission.FamilyPlanningRecord,
    Permission.CommunityDataRecord,
    Permission.DashboardOwnActivity,
    Permission.DashboardCsb,
    Permission.DashboardAggregated,
    Permission.DataExport,
    Permission.ManageCsbUsers,
    Permission.ViewAuditLog,
  ],

  // L'administration nationale ne consulte aucun dossier individuel : elle ne
  // voit que des indicateurs agrégés (CDC §5). L'absence totale de permission
  // « bénéficiaire » est voulue, pas un oubli.
  [UserRole.ADMIN_NATIONAL]: [
    Permission.DashboardAggregated,
    Permission.ManageCsbUsers,
    Permission.ManageCsbs,
    Permission.ViewAuditLog,
  ],
};

/**
 * Permissions effectives, une fois le contexte du centre pris en compte.
 *
 * Beaucoup de CSB n'ont pas de sage-femme affectée. Interdire la saisie des
 * CPN aux infirmiers y bloquerait le suivi de grossesse, précisément là où il
 * manque le plus de personnel. Le réglage appartient donc au centre
 * (`allowsNurseAntenatalCare`), pas à l'individu.
 */
export function permissionsFor(
  role: UserRole,
  options: { csbAllowsNurseAntenatalCare?: boolean } = {},
): ReadonlySet<Permission> {
  const base = new Set(ROLE_PERMISSIONS[role]);

  if (role === UserRole.INFIRMIER && options.csbAllowsNurseAntenatalCare) {
    base.add(Permission.AntenatalRecord);
    base.add(Permission.PostnatalRecord);
  }

  return base;
}

export function hasPermission(
  role: UserRole,
  permission: Permission,
  options: { csbAllowsNurseAntenatalCare?: boolean } = {},
): boolean {
  return permissionsFor(role, options).has(permission);
}
