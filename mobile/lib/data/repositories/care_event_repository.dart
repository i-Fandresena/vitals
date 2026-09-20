import 'package:uuid/uuid.dart';

import '../../core/utils/iso_date.dart';
import '../../domain/enums/clinical_enums.dart';
import '../local/app_database.dart';
import '../local/daos/care_event_dao.dart';

/// Événements de soin : consultations, vaccinations, CPN (tickets 2.3 à 2.6).
///
/// Tout passe par la base locale, comme les dossiers. Enregistrer un acte ne
/// demande aucun réseau et n'échoue jamais parce que le serveur est
/// injoignable — c'est la condition pour qu'un soignant puisse travailler en
/// consultation sans y penser (CDC §6).
class CareEventRepository {
  CareEventRepository({required CareEventDao careEventDao, Uuid? uuid})
    : _dao = careEventDao,
      _uuid = uuid ?? const Uuid();

  final CareEventDao _dao;
  final Uuid _uuid;

  // --- Consultations ---

  Future<Consultation> enregistrerConsultation({
    required String beneficiaryId,
    required ConsultationType type,
    required String occurredOn,
    required String motiveCode,
    required String recordedByUserId,
    double? weightKg,
    double? temperatureC,
    int? bloodPressureSys,
    int? bloodPressureDia,
    bool treatmentGiven = false,
    bool referred = false,
    String? referredTo,
    String? notes,
  }) {
    return _dao.createConsultation(
      // UUID v7, comme les dossiers : l'identifiant vient de l'appareil, ce
      // qui rend l'envoi idempotent et la création possible hors ligne.
      id: _uuid.v7(),
      beneficiaryId: beneficiaryId,
      type: type,
      occurredOn: occurredOn,
      motiveCode: motiveCode,
      recordedByUserId: recordedByUserId,
      weightKg: weightKg,
      temperatureC: temperatureC,
      bloodPressureSys: bloodPressureSys,
      bloodPressureDia: bloodPressureDia,
      treatmentGiven: treatmentGiven,
      referred: referred,
      referredTo: referredTo,
      notes: notes,
    );
  }

  // --- Vaccinations ---

  Future<Vaccination> enregistrerVaccination({
    required String beneficiaryId,
    required VaccineCode vaccine,
    required int doseNumber,
    required String occurredOn,
    required String recordedByUserId,
    String? lotNumber,
  }) {
    return _dao.createVaccination(
      id: _uuid.v7(),
      beneficiaryId: beneficiaryId,
      vaccine: vaccine,
      doseNumber: doseNumber,
      occurredOn: occurredOn,
      recordedByUserId: recordedByUserId,
      lotNumber: lotNumber,
    );
  }

  Future<Map<VaccineCode, List<Vaccination>>> vaccinationsDe(
    String beneficiaryId,
  ) => _dao.vaccinationsParAntigene(beneficiaryId);

  // --- Grossesse et CPN ---

  Future<Pregnancy?> grossesseEnCours(String beneficiaryId) =>
      _dao.grossesseEnCours(beneficiaryId);

  Future<List<PrenatalVisit>> cpnDe(String pregnancyId) =>
      _dao.cpnDe(pregnancyId);

  /// Ouvre un suivi de grossesse.
  ///
  /// Le terme se calcule depuis la date des dernières règles, selon la règle
  /// habituelle des 280 jours. Il reste indicatif : beaucoup de femmes ne
  /// connaissent pas cette date, et l'estimation se corrigera à la première
  /// mesure de hauteur utérine.
  Future<Pregnancy> ouvrirGrossesse({
    required String beneficiaryId,
    required String createdByUserId,
    DateTime? lastPeriodDate,
    int? gravida,
    int? para,
  }) {
    return _dao.createPregnancy(
      id: _uuid.v7(),
      beneficiaryId: beneficiaryId,
      createdByUserId: createdByUserId,
      lastPeriodDate: lastPeriodDate == null
          ? null
          : IsoDate.from(lastPeriodDate),
      expectedDeliveryOn: lastPeriodDate == null
          ? null
          : IsoDate.from(lastPeriodDate.add(const Duration(days: 280))),
      gravida: gravida,
      para: para,
    );
  }

  Future<PrenatalVisit> enregistrerCpn({
    required String pregnancyId,
    required String beneficiaryId,
    required int visitNumber,
    required String occurredOn,
    required String recordedByUserId,
    int? gestationalAgeWeeks,
    double? weightKg,
    int? bloodPressureSys,
    int? bloodPressureDia,
    double? fundalHeightCm,
    int? fetalHeartRate,
    bool tetanusVaccineGiven = false,
    bool ironFolateGiven = false,
    bool malariaPreventionGiven = false,
    bool insecticideNetGiven = false,
    List<String> riskFactorCodes = const [],
    bool referred = false,
    String? referredTo,
    String? notes,
  }) {
    return _dao.createPrenatalVisit(
      id: _uuid.v7(),
      pregnancyId: pregnancyId,
      beneficiaryId: beneficiaryId,
      visitNumber: visitNumber,
      occurredOn: occurredOn,
      recordedByUserId: recordedByUserId,
      gestationalAgeWeeks: gestationalAgeWeeks,
      weightKg: weightKg,
      bloodPressureSys: bloodPressureSys,
      bloodPressureDia: bloodPressureDia,
      fundalHeightCm: fundalHeightCm,
      fetalHeartRate: fetalHeartRate,
      tetanusVaccineGiven: tetanusVaccineGiven,
      ironFolateGiven: ironFolateGiven,
      malariaPreventionGiven: malariaPreventionGiven,
      insecticideNetGiven: insecticideNetGiven,
      riskFactorCodes: riskFactorCodes,
      referred: referred,
      referredTo: referredTo,
      notes: notes,
    );
  }

  // --- Historique (ticket 2.3) ---

  Future<List<CareEvent>> historique(String beneficiaryId) =>
      _dao.historique(beneficiaryId);
}
