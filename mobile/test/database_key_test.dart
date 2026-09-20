import 'package:flutter_test/flutter_test.dart';
import 'package:vitals/data/local/database_key.dart';

/// Vérifie la clé de chiffrement de la base locale (ticket 3.3).
///
/// Le test d'acceptation du ticket — extraire le fichier SQLite d'un appareil
/// et constater qu'aucun nom n'y est lisible — demande un vrai téléphone et
/// figure dans `docs/03-verification.md`, section 9.2. Ce fichier couvre ce
/// qui se vérifie sans appareil : la forme de la clé et son échappement.
void main() {
  group('Forme de la clé', () {
    test('256 bits en hexadécimal', () {
      // 32 octets, soit 64 caractères hexadécimaux. Plus court affaiblirait le
      // chiffrement ; plus long serait tronqué en silence par SQLCipher.
      expect(DatabaseKey.estValide('a' * 64), isTrue);
      expect(DatabaseKey.estValide('a' * 63), isFalse);
      expect(DatabaseKey.estValide('a' * 65), isFalse);
    });

    test('refuse ce qui n\'est pas de l\'hexadécimal minuscule', () {
      expect(DatabaseKey.estValide('Z' * 64), isFalse);
      expect(DatabaseKey.estValide('A' * 64), isFalse);
      expect(DatabaseKey.estValide('${'a' * 63}!'), isFalse);
      expect(DatabaseKey.estValide(''), isFalse);
    });
  });

  group('Échappement pour PRAGMA key', () {
    test('utilise la notation binaire', () {
      // `x'...'` passe les octets bruts. Sans elle, SQLCipher traiterait la
      // clé comme une phrase de passe et y appliquerait PBKDF2 : inutile sur
      // une valeur déjà aléatoire sur 256 bits, et coûteux à chaque ouverture.
      expect(DatabaseKey.pragma('abc123'), "x'abc123'");
    });

    test('ne laisse pas la clé s\'échapper de la chaîne', () {
      // La clé étant validée comme hexadécimale, elle ne peut pas contenir
      // d'apostrophe : la requête ne peut donc pas être détournée.
      final cle = 'f' * 64;
      final pragma = DatabaseKey.pragma(cle);
      expect(pragma.startsWith("x'"), isTrue);
      expect(pragma.endsWith("'"), isTrue);
      expect(pragma.substring(2, pragma.length - 1), cle);
    });
  });

  group('Empreinte de diagnostic', () {
    test('ne révèle pas la clé', () {
      final cle = 'a1b2c3d4' * 8;
      final empreinte = DatabaseKey.empreinte(cle);

      expect(empreinte.length, lessThan(cle.length));
      expect(cle.contains(empreinte), isFalse);
    });

    test('est stable pour une même clé', () {
      final cle = 'b' * 64;
      expect(DatabaseKey.empreinte(cle), DatabaseKey.empreinte(cle));
    });

    test('diffère entre deux clés', () {
      expect(
        DatabaseKey.empreinte('a' * 64),
        isNot(DatabaseKey.empreinte('c' * 64)),
      );
    });
  });
}
