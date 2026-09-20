import 'package:uuid/uuid.dart';

import '../../core/utils/local_id.dart';
import '../../domain/enums/clinical_enums.dart';
import '../local/app_database.dart';
import '../local/daos/beneficiary_dao.dart';

/// Dossiers bénéficiaires.
///
/// Tout passe par la base locale, sans exception : créer un dossier ne demande
/// aucun réseau et n'échoue jamais parce que le serveur est injoignable
/// (CDC §6). L'envoi se fait plus tard, depuis la file de synchronisation.
class BeneficiaryRepository {
  BeneficiaryRepository({required BeneficiaryDao beneficiaryDao, Uuid? uuid})
    : _dao = beneficiaryDao,
      _uuid = uuid ?? const Uuid();

  final BeneficiaryDao _dao;
  final Uuid _uuid;

  Future<Beneficiary> create({
    required String firstName,
    required String lastName,
    required Sex sex,
    required String birthDate,
    required bool birthDateIsEstimated,
    required String csbId,
    required String createdByUserId,
    String? phone,
    String? fokontany,
    String? address,
  }) {
    return _dao.create(
      // UUID v7 : ordonné dans le temps, donc les index restent efficaces et
      // les dossiers s'ordonnent naturellement par date de création, sans
      // qu'aucun serveur n'ait à attribuer l'identifiant.
      id: _uuid.v7(),
      firstName: firstName,
      lastName: lastName,
      sex: sex,
      birthDate: birthDate,
      birthDateIsEstimated: birthDateIsEstimated,
      csbId: csbId,
      createdByUserId: createdByUserId,
      phone: phone,
      fokontany: fokontany,
      address: address,
    );
  }

  /// Recherche unique, qui devine ce que l'utilisateur a saisi.
  ///
  /// Un seul champ plutôt que deux : le personnel tape ce qu'il a sous les yeux
  /// — un nom recopié d'un registre, ou un numéro lu sur une carte — sans avoir
  /// à choisir au préalable dans quel champ le mettre. C'est une étape de moins
  /// sur le parcours le plus fréquent de la journée (CDC §7).
  Future<List<Beneficiary>> search({
    required String csbId,
    required String query,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return _dao.recent(csbId: csbId);

    if (LocalId.looksLikeLocalId(trimmed)) {
      final match = await _dao.findByLocalId(csbId: csbId, localId: trimmed);
      // Repli sur la recherche par nom si le numéro ne correspond à rien :
      // mieux vaut proposer des pistes qu'un écran vide.
      if (match != null) return [match];
    }

    return _dao.searchByName(csbId: csbId, query: trimmed);
  }

  /// Ouvre un dossier depuis un QR code scanné.
  ///
  /// Renvoie `null` si le code n'est pas un dossier Vitals, ou si le dossier
  /// n'appartient pas au centre de l'utilisateur.
  Future<Beneficiary?> findByQrPayload({
    required String csbId,
    required String? payload,
  }) async {
    final id = LocalId.parseQrPayload(payload);
    if (id == null) return null;
    return _dao.findById(csbId: csbId, id: id);
  }

  Future<Beneficiary?> findById({required String csbId, required String id}) =>
      _dao.findById(csbId: csbId, id: id);

  Future<List<Beneficiary>> recent({required String csbId}) =>
      _dao.recent(csbId: csbId);

  Future<int> count({required String csbId}) => _dao.countForCsb(csbId);
}
