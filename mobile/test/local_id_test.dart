import 'package:flutter_test/flutter_test.dart';
import 'package:vitals/core/utils/local_id.dart';

void main() {
  group('LocalId.format', () {
    test('produit le format attendu', () {
      expect(
        LocalId.format(csbCode: '0142', year: 2026, sequence: 731),
        'CSB-0142-26-00731',
      );
    });

    test("n'utilise que les deux derniers chiffres de l'année", () {
      expect(
        LocalId.format(csbCode: '0142', year: 2030, sequence: 1),
        'CSB-0142-30-00001',
      );
      // Le passage à 2100 donnerait « 00 », ce qui reste cohérent : aucun CSB
      // ne compare des dossiers à 74 ans d'écart par leur identifiant.
      expect(
        LocalId.format(csbCode: '0142', year: 2100, sequence: 1),
        'CSB-0142-00-00001',
      );
    });

    test('les identifiants du même centre se trient par ordre de création', () {
      final ids = [
        LocalId.format(csbCode: '0142', year: 2026, sequence: 10),
        LocalId.format(csbCode: '0142', year: 2026, sequence: 2),
        LocalId.format(csbCode: '0142', year: 2026, sequence: 1),
      ]..sort();

      // C'est l'intérêt du remplissage à cinq chiffres : sans lui, « 10 »
      // passerait avant « 2 » dans un tri alphabétique.
      expect(ids, [
        'CSB-0142-26-00001',
        'CSB-0142-26-00002',
        'CSB-0142-26-00010',
      ]);
    });
  });

  group('QR code', () {
    const id = '01941b2c-3d4e-7f80-a1b2-c3d4e5f60718';

    test('encode uniquement un UUID, sans donnée personnelle', () {
      final payload = LocalId.toQrPayload(id);

      expect(payload, 'vitals:b/$id');
      // Vérification de fond : le contenu du QR ne doit contenir que le
      // préfixe et l'UUID. Une carte perdue ne révèle rien.
      expect(payload.replaceFirst('vitals:b/', ''), id);
    });

    test('relit son propre encodage', () {
      expect(LocalId.parseQrPayload(LocalId.toQrPayload(id)), id);
    });

    test('tolère les espaces autour du code lu', () {
      expect(LocalId.parseQrPayload('  vitals:b/$id \n'), id);
    });

    test('rejette un code étranger à Vitals', () {
      expect(LocalId.parseQrPayload('https://example.org/$id'), isNull);
      expect(LocalId.parseQrPayload('8712345678906'), isNull);
      expect(LocalId.parseQrPayload('autre:b/$id'), isNull);
      expect(LocalId.parseQrPayload(null), isNull);
      expect(LocalId.parseQrPayload(''), isNull);
    });

    test('rejette un préfixe correct suivi de n\'importe quoi', () {
      expect(LocalId.parseQrPayload('vitals:b/pas-un-uuid'), isNull);
      expect(LocalId.parseQrPayload('vitals:b/'), isNull);
      // Un identifiant lisible n'a rien à faire dans un QR code : il est
      // devinable, contrairement à l'UUID.
      expect(LocalId.parseQrPayload('vitals:b/CSB-0142-26-00731'), isNull);
    });
  });

  group('Saisie manuelle', () {
    test('reconnaît un identifiant lisible', () {
      expect(LocalId.looksLikeLocalId('CSB-0142-26-00731'), isTrue);
      expect(LocalId.looksLikeLocalId('csb-0142-26-00731'), isTrue);
    });

    test('ne confond pas un nom avec un identifiant', () {
      expect(LocalId.looksLikeLocalId('Rasoa'), isFalse);
      expect(LocalId.looksLikeLocalId('Rakoto Jean'), isFalse);
      expect(LocalId.looksLikeLocalId('0142'), isFalse);
      expect(LocalId.looksLikeLocalId(''), isFalse);
    });

    test('normalise ce qu\'un agent recopie depuis un carnet', () {
      // Espaces au lieu des tirets, minuscules : tout doit retomber sur la
      // même valeur que celle enregistrée en base.
      expect(LocalId.normalize('csb 0142 26 00731'), 'CSB-0142-26-00731');
      expect(LocalId.normalize('  CSB-0142-26-00731  '), 'CSB-0142-26-00731');
      expect(LocalId.normalize('csb_0142_26_00731'), 'CSB-0142-26-00731');
    });
  });
}
