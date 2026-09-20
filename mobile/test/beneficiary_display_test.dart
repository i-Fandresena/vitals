import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitals/core/utils/iso_date.dart';
import 'package:vitals/data/local/app_database.dart';
import 'package:vitals/domain/entities/beneficiary_display.dart';
import 'package:vitals/domain/enums/clinical_enums.dart';

/// Vérifie la façon dont un dossier est présenté au soignant.
///
/// L'unité de l'âge n'est pas un détail de confort : le calendrier vaccinal
/// d'un nourrisson se raisonne en jours puis en mois, et « 0 an » ne permet
/// aucune décision.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  /// Construit un dossier en mémoire à partir d'un âge exprimé en jours.
  Future<Beneficiary> withAge({
    required int days,
    bool estimated = false,
    String firstName = 'Prenom',
    String lastName = 'NOM',
  }) async {
    final birth = DateTime.now().subtract(Duration(days: days));
    const id = 'id-test';

    await db
        .into(db.beneficiaries)
        .insertOnConflictUpdate(
          BeneficiariesCompanion.insert(
            id: id,
            localId: 'CSB-0142-26-00001',
            firstName: firstName,
            lastName: lastName,
            sex: Sex.f,
            birthDate: IsoDate.from(birth),
            birthDateIsEstimated: Value(estimated),
            csbId: 'csb-test',
            deviceUpdatedAt: DateTime.now(),
            createdByUserId: 'user-test',
            createdAt: DateTime.now(),
          ),
        );

    return (db.select(
      db.beneficiaries,
    )..where((b) => b.id.equals(id))).getSingle();
  }

  group("Libellé de l'âge", () {
    test('un nouveau-né est compté en jours', () async {
      final row = await withAge(days: 12);
      expect(row.ageLabel, '12 jours');
    });

    test('le premier jour est au singulier', () async {
      final row = await withAge(days: 1);
      expect(row.ageLabel, '1 jour');
    });

    test('un nourrisson est compté en mois', () async {
      final row = await withAge(days: 200);
      expect(row.ageLabel, endsWith('mois'));
      // Le point central : un enfant de 6 mois ne doit jamais s'afficher
      // « 0 ans », sinon le calendrier vaccinal devient illisible.
      expect(row.ageLabel, isNot(contains('an')));
    });

    test('au-delà de deux ans, on passe aux années', () async {
      final row = await withAge(days: 365 * 5);
      expect(row.ageLabel, endsWith('ans'));
    });

    test('une date estimée est signalée par un tilde', () async {
      final row = await withAge(days: 365 * 30, estimated: true);
      expect(row.ageLabel, startsWith('~'));
      expect(row.ageLabel, endsWith('ans'));
    });

    test('une date exacte ne porte pas de tilde', () async {
      final row = await withAge(days: 365 * 30);
      expect(row.ageLabel, isNot(startsWith('~')));
    });
  });

  group('Signalements', () {
    test('une date de naissance future est détectée', () async {
      final row = await withAge(days: -30);
      expect(row.hasImpossibleBirthDate, isTrue);
    });

    test('une date passée est acceptée', () async {
      final row = await withAge(days: 400);
      expect(row.hasImpossibleBirthDate, isFalse);
    });

    test('un dossier jamais envoyé est marqué en attente', () async {
      final row = await withAge(days: 400);
      expect(row.isPendingSync, isTrue);
    });
  });

  group('Nom affiché', () {
    test(
      'le nom de famille vient en premier, comme sur les registres',
      () async {
        final row = await withAge(
          days: 400,
          firstName: 'Voahirana',
          lastName: 'RAKOTO',
        );
        expect(row.displayName, 'RAKOTO Voahirana');
      },
    );
  });
}
