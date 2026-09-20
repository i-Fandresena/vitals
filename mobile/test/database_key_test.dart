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

  group('Instruction qui pose la clé', () {
    test('utilise hexkey, pas la notation binaire de SQLCipher', () {
      // Régression vécue sur un Pixel 4 : `PRAGMA key = x'...'` est une
      // extension de l'analyseur de SQLCipher. La grammaire SQLite n'admet
      // après un `PRAGMA` qu'un nom, une chaîne ou un nombre — jamais un
      // littéral binaire. SQLite3 Multiple Ciphers, que l'application
      // embarque, le refusait avec « syntax error » à la première écriture,
      // c'est-à-dire au moment de la toute première connexion.
      final instruction = DatabaseKey.instructionCle('abc123');

      expect(instruction, "PRAGMA hexkey = 'abc123';");
      expect(instruction.contains("x'"), isFalse);
    });

    test('passe les octets bruts, sans dérivation', () {
      // La clé est déjà aléatoire sur 256 bits : lui appliquer PBKDF2
      // n'ajouterait rien et ralentirait chaque ouverture.
      final cle = 'f' * 64;
      expect(DatabaseKey.instructionCle(cle), contains(cle));
    });

    test('ne laisse pas la clé s\'échapper de la chaîne', () {
      // La clé étant validée comme hexadécimale, elle ne peut pas contenir
      // d'apostrophe : la requête ne peut donc pas être détournée.
      final cle = 'a1b2c3d4' * 8;
      expect(DatabaseKey.estValide(cle), isTrue);
      expect(DatabaseKey.instructionCle(cle).split("'").length, 3);
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
