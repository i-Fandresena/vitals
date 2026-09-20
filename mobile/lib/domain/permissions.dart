import 'enums/user_role.dart';

/// Permissions de l'application.
///
/// Traduction directe de `docs/01-matrice-droits.md`. Ce fichier et son miroir
/// serveur (`backend/src/auth/permissions.ts`) doivent rester identiques : une
/// permission ajoutée d'un seul côté crée soit un bouton qui échoue, soit un
/// endpoint ouvert sans interface.
///
/// **Le masquage d'un bouton n'est pas une permission.** Ce modèle sert à ne
/// pas proposer l'impossible ; c'est le serveur qui refuse (ticket 2.2).
enum Permission {
  /// Ouvrir un dossier et voir l'identité : nom, âge, identifiant, village.
  beneficiaryViewIdentity,

  /// Voir l'historique de soin : consultations, vaccinations, CPN, PF.
  ///
  /// Séparé de l'identité parce que c'est exactement la ligne que l'agent
  /// communautaire ne franchit pas : il oriente vers le CSB, il ne soigne pas.
  beneficiaryViewCareHistory,

  beneficiaryCreate,
  beneficiaryUpdateIdentity,

  /// Retirer un dossier des recherches courantes. La suppression n'existe pas.
  beneficiaryArchive,

  consultationRecord,

  /// Consultation prénatale et suivi de grossesse.
  antenatalRecord,
  postnatalRecord,

  vaccinationRecord,
  familyPlanningRecord,
  communityDataRecord,

  /// Indicateurs de sa propre activité.
  dashboardOwnActivity,

  /// Indicateurs de tout le centre.
  dashboardCsb,

  /// Indicateurs consolidés au-delà d'un seul centre.
  ///
  /// Distincte de [dashboardCsb] : le CDC §5 veut que les niveaux supérieurs
  /// voient des totaux par district et par région, sans jamais accéder aux
  /// dossiers individuels. Cette permission ouvre l'un sans ouvrir l'autre.
  dashboardAggregated,

  dataExport,
  manageCsbUsers,
  manageCsbs,
  viewAuditLog,
}

/// Permissions attachées à chaque profil.
extension RolePermissions on UserRole {
  Set<Permission> get permissions => switch (this) {
    // L'agent communautaire travaille hors du centre, souvent sur un appareil
    // partagé : c'est le profil le plus exposé, donc celui qui porte le moins
    // de données sensibles. Il identifie et oriente, il ne consulte pas.
    UserRole.agentCommunautaire => const {
      Permission.beneficiaryViewIdentity,
      Permission.beneficiaryCreate,
      Permission.communityDataRecord,
    },

    UserRole.infirmier => const {
      Permission.beneficiaryViewIdentity,
      Permission.beneficiaryViewCareHistory,
      Permission.beneficiaryCreate,
      Permission.beneficiaryUpdateIdentity,
      Permission.consultationRecord,
      Permission.vaccinationRecord,
      Permission.familyPlanningRecord,
      Permission.communityDataRecord,
      Permission.dashboardOwnActivity,
      // La saisie des CPN dépend du centre, pas du rôle : voir
      // [permissionsFor] et `Csb.allowsNurseAntenatalCare`.
    },

    UserRole.sageFemme => const {
      Permission.beneficiaryViewIdentity,
      Permission.beneficiaryViewCareHistory,
      Permission.beneficiaryCreate,
      Permission.beneficiaryUpdateIdentity,
      Permission.consultationRecord,
      Permission.antenatalRecord,
      Permission.postnatalRecord,
      Permission.vaccinationRecord,
      Permission.familyPlanningRecord,
      Permission.communityDataRecord,
      Permission.dashboardOwnActivity,
    },

    // Le médecin d'un CSB II. Mêmes droits cliniques que la sage-femme : la
    // distinction entre les deux est professionnelle et sert la traçabilité,
    // elle ne correspond à aucune différence d'accès.
    UserRole.medecin => const {
      Permission.beneficiaryViewIdentity,
      Permission.beneficiaryViewCareHistory,
      Permission.beneficiaryCreate,
      Permission.beneficiaryUpdateIdentity,
      Permission.consultationRecord,
      Permission.antenatalRecord,
      Permission.postnatalRecord,
      Permission.vaccinationRecord,
      Permission.familyPlanningRecord,
      Permission.communityDataRecord,
      Permission.dashboardOwnActivity,
    },

    UserRole.responsableCsb => const {
      Permission.beneficiaryViewIdentity,
      Permission.beneficiaryViewCareHistory,
      Permission.beneficiaryCreate,
      Permission.beneficiaryUpdateIdentity,
      Permission.beneficiaryArchive,
      Permission.consultationRecord,
      Permission.antenatalRecord,
      Permission.postnatalRecord,
      Permission.vaccinationRecord,
      Permission.familyPlanningRecord,
      Permission.communityDataRecord,
      Permission.dashboardOwnActivity,
      Permission.dashboardCsb,
      Permission.dashboardAggregated,
      Permission.dataExport,
      Permission.manageCsbUsers,
      Permission.viewAuditLog,
    },

    // L'administration nationale ne consulte aucun dossier individuel : elle
    // ne voit que des indicateurs agrégés (CDC §5). L'absence totale de
    // permission « bénéficiaire » est voulue, pas un oubli.
    UserRole.adminNational => const {
      Permission.dashboardAggregated,
      Permission.manageCsbUsers,
      Permission.manageCsbs,
      Permission.viewAuditLog,
    },
  };
}

/// Permissions effectives, une fois le contexte du centre pris en compte.
///
/// Beaucoup de CSB n'ont pas de sage-femme affectée. Interdire la saisie des
/// CPN aux infirmiers y bloquerait le suivi de grossesse, précisément là où il
/// manque le plus de personnel. Le réglage appartient donc au centre
/// (`allowsNurseAntenatalCare`), pas à l'individu.
Set<Permission> permissionsFor(
  UserRole role, {
  bool csbAllowsNurseAntenatalCare = false,
}) {
  final base = role.permissions;

  if (role == UserRole.infirmier && csbAllowsNurseAntenatalCare) {
    return {...base, Permission.antenatalRecord, Permission.postnatalRecord};
  }

  return base;
}
