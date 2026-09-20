import 'dart:convert';

// `isNull` existe dans drift (expression SQL) et dans matcher (assertion) :
// on garde celui de matcher, c'est un fichier de test.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitals/data/local/app_database.dart';
import 'package:vitals/domain/enums/clinical_enums.dart';

/// Tests du DAO des dossiers bénéficiaires, sur une base en mémoire.
///
/// Les données utilisées sont manifestement fictives : aucune donnée réelle de
/// patient ne doit entrer dans le dépôt, même en test (CDC §8).
void main() {
  late AppDatabase db;

  const csbId = 'csb-test';
  const userId = 'user-test';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    await db
        .into(db.csbs)
        .insert(
          CsbsCompanion.insert(id: csbId, code: '0142', name: 'CSB de test'),
        );
  });

  tearDown(() async => db.close());

  Future<Beneficiary> createOne({
    String firstName = 'Prenom',
    String lastName = 'NOM',
    Sex sex = Sex.f,
    String birthDate = '1995-03-12',
    bool estimated = false,
  }) {
    return db.beneficiaryDao.create(
      id: 'id-${DateTime.now().microsecondsSinceEpoch}-$lastName$firstName',
      firstName: firstName,
      lastName: lastName,
      sex: sex,
      birthDate: birthDate,
      birthDateIsEstimated: estimated,
      csbId: csbId,
      createdByUserId: userId,
    );
  }

  group('Identifiant lisible', () {
    test('la séquence commence à 1 et progresse', () async {
      final first = await createOne(lastName: 'RAKOTO');
      final second = await createOne(lastName: 'RASOA');

      final year = (DateTime.now().year % 100).toString().padLeft(2, '0');
      expect(first.localId, 'CSB-0142-$year-00001');
      expect(second.localId, 'CSB-0142-$year-00002');
    });

    test('deux dossiers ne partagent jamais le même identifiant', () async {
      final ids = <String>{};
      for (var i = 0; i < 25; i++) {
        final created = await createOne(lastName: 'NOM$i');
        ids.add(created.localId);
      }
      expect(ids, hasLength(25));
    });

    test('la séquence repart à 1 au changement d\'année', () async {
      // Le centre a enregistré 412 dossiers l'an dernier ; aucun cette année.
      await (db.update(db.csbs)..where((c) => c.id.equals(csbId))).write(
        CsbsCompanion(
          lastLocalSequence: const Value(412),
          lastLocalSequenceYear: Value(DateTime.now().year - 1),
        ),
      );

      final created = await createOne(lastName: 'NOUVEAU');
      final year = (DateTime.now().year % 100).toString().padLeft(2, '0');
      expect(created.localId, 'CSB-0142-$year-00001');
    });

    test(
      'une horloge qui recule ne réattribue pas un numéro déjà pris',
      () async {
        final first = await createOne(lastName: 'PREMIER');
        final second = await createOne(lastName: 'DEUXIEME');

        // Un téléphone dont la date part dans l'année précédente : le compteur
        // stocké désigne alors une autre année et repartirait à 1.
        await (db.update(db.csbs)..where((c) => c.id.equals(csbId))).write(
          CsbsCompanion(
            lastLocalSequence: const Value(0),
            lastLocalSequenceYear: Value(DateTime.now().year - 1),
          ),
        );

        final third = await createOne(lastName: 'TROISIEME');

        // Le numéro est repris au-dessus de ce qui existe réellement en base,
        // pas au-dessus du compteur corrompu.
        expect(third.localId, isNot(first.localId));
        expect(third.localId, isNot(second.localId));
        final year = (DateTime.now().year % 100).toString().padLeft(2, '0');
        expect(third.localId, 'CSB-0142-$year-00003');
      },
    );

    test('un centre inconnu est refusé explicitement', () async {
      expect(
        () => db.beneficiaryDao.create(
          id: 'id-orphelin',
          firstName: 'Prenom',
          lastName: 'NOM',
          sex: Sex.f,
          birthDate: '1990-01-01',
          birthDateIsEstimated: false,
          csbId: 'centre-inexistant',
          createdByUserId: userId,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('File de synchronisation', () {
    test('créer un dossier programme son envoi', () async {
      final created = await createOne(lastName: 'RANAIVO');

      final queue = await db.select(db.syncQueueEntries).get();
      expect(queue, hasLength(1));
      expect(queue.single.entityType, 'beneficiaries');
      expect(queue.single.entityId, created.id);
      expect(queue.single.operation, SyncOperation.create);
      expect(queue.single.status, SyncStatus.pending);
    });

    test('la charge utile contient les champs attendus', () async {
      final created = await createOne(lastName: 'RABE', sex: Sex.m);

      final entry = await db.select(db.syncQueueEntries).getSingle();
      final payload = jsonDecode(entry.payload) as Map<String, dynamic>;

      expect(payload['id'], created.id);
      expect(payload['localId'], created.localId);
      expect(payload['lastName'], 'RABE');
      // Le code du serveur, pas le nom Dart de la valeur d'énumération.
      expect(payload['sex'], 'M');
    });

    test('un échec laisse la base intacte, file comprise', () async {
      await expectLater(
        db.beneficiaryDao.create(
          id: 'id-echec',
          firstName: 'Prenom',
          lastName: 'NOM',
          sex: Sex.f,
          birthDate: '1990-01-01',
          birthDateIsEstimated: false,
          csbId: 'centre-inexistant',
          createdByUserId: userId,
        ),
        throwsA(isA<StateError>()),
      );

      // Tout se fait dans une transaction : il ne doit rester ni dossier
      // orphelin, ni entrée de file sans dossier.
      expect(await db.select(db.beneficiaries).get(), isEmpty);
      expect(await db.select(db.syncQueueEntries).get(), isEmpty);
    });
  });

  group('Recherche', () {
    setUp(() async {
      await createOne(firstName: 'Voahirana', lastName: 'RAKOTO');
      await createOne(firstName: 'Jean', lastName: 'RASOAMANANA');
      await createOne(firstName: 'Hery', lastName: 'ANDRIA');
    });

    test('trouve par début de nom', () async {
      final results = await db.beneficiaryDao.searchByName(
        csbId: csbId,
        query: 'RAKO',
      );
      expect(results, hasLength(1));
      expect(results.single.firstName, 'Voahirana');
    });

    test('trouve aussi par prénom', () async {
      final results = await db.beneficiaryDao.searchByName(
        csbId: csbId,
        query: 'Hery',
      );
      expect(results, hasLength(1));
    });

    test('trouve par fragment au milieu du nom', () async {
      // Les noms malgaches sont longs et souvent mal orthographiés de
      // mémoire : une recherche ancrée au début seulement serait trop stricte.
      final results = await db.beneficiaryDao.searchByName(
        csbId: csbId,
        query: 'MANANA',
      );
      expect(results, hasLength(1));
      expect(results.single.lastName, 'RASOAMANANA');
    });

    test('les résultats sont triés par nom', () async {
      final results = await db.beneficiaryDao.searchByName(
        csbId: csbId,
        query: 'A',
      );
      final names = results.map((b) => b.lastName).toList();
      expect(names, orderedEquals([...names]..sort()));
    });

    test('ne renvoie rien pour un autre centre', () async {
      final results = await db.beneficiaryDao.searchByName(
        csbId: 'un-autre-csb',
        query: 'RAKO',
      );
      expect(results, isEmpty);
    });

    test('exclut les dossiers archivés', () async {
      await (db.update(db.beneficiaries)
            ..where((b) => b.lastName.equals('ANDRIA')))
          .write(BeneficiariesCompanion(archivedAt: Value(DateTime.now())));

      final results = await db.beneficiaryDao.searchByName(
        csbId: csbId,
        query: 'ANDRIA',
      );
      expect(results, isEmpty);

      // Archivé ne veut pas dire supprimé : la ligne reste en base (CDC §8).
      final all = await db.select(db.beneficiaries).get();
      expect(all.where((b) => b.lastName == 'ANDRIA'), hasLength(1));
    });
  });

  group('Ouverture par identifiant', () {
    test('retrouve par identifiant lisible, casse indifférente', () async {
      final created = await createOne(lastName: 'RAZAFY');

      final found = await db.beneficiaryDao.findByLocalId(
        csbId: csbId,
        localId: created.localId.toLowerCase(),
      );
      expect(found?.id, created.id);
    });

    test('le cloisonnement par centre s\'applique aussi au scan', () async {
      final created = await createOne(lastName: 'RAZAFY');

      final found = await db.beneficiaryDao.findById(
        csbId: 'un-autre-csb',
        id: created.id,
      );
      // Scanner la carte d'une personne suivie ailleurs ne doit pas ouvrir
      // son dossier.
      expect(found, isNull);
    });
  });
}
