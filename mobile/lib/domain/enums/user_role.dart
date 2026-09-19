/// Profils utilisateur.
///
/// Les noms correspondent exactement à l'énumération `UserRole` du serveur
/// (`backend/prisma/schema.prisma`) : ils transitent tels quels dans le JWT et
/// dans les réponses de l'API.
///
/// Le détail des permissions est spécifié dans `docs/01-matrice-droits.md` et
/// sera appliqué au ticket 2.2.
enum UserRole {
  agentCommunautaire('AGENT_COMMUNAUTAIRE', 'Agent communautaire'),
  infirmier('INFIRMIER', 'Infirmier'),
  sageFemme('SAGE_FEMME', 'Sage-femme'),
  responsableCsb('RESPONSABLE_CSB', 'Responsable du CSB'),
  adminNational('ADMIN_NATIONAL', 'Administration');

  const UserRole(this.code, this.label);

  /// Valeur échangée avec le serveur.
  final String code;

  /// Libellé affiché, en français.
  final String label;

  static UserRole? tryParse(String? code) {
    if (code == null) return null;
    for (final role in UserRole.values) {
      if (role.code == code) return role;
    }
    return null;
  }

  /// Un compte sans rattachement à un CSB n'accède à aucun dossier individuel
  /// (CDC §5 : les niveaux supérieurs ne voient que des indicateurs agrégés).
  bool get accessesIndividualRecords => this != UserRole.adminNational;
}
