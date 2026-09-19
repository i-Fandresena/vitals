import 'package:flutter_test/flutter_test.dart';

import 'package:vitals/core/utils/iso_date.dart';

void main() {
  group('IsoDate', () {
    test('conserve le jour local, sans décalage de fuseau', () {
      // Le piège que ce format évite : minuit local converti en UTC recule
      // d'un jour à Madagascar (UTC+3). Une vaccination du 1er du mois serait
      // alors comptée le dernier jour du mois précédent.
      final premierDuMois = DateTime(2026, 9, 1);
      expect(IsoDate.from(premierDuMois), '2026-09-01');
    });

    test('complète les mois et jours à deux chiffres', () {
      expect(IsoDate.from(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('relit une date valide', () {
      expect(IsoDate.parse('2026-09-19'), DateTime(2026, 9, 19));
    });

    test('rejette une chaîne mal formée', () {
      expect(IsoDate.parse('19/09/2026'), isNull);
      expect(IsoDate.parse('2026-9-19'), isNull);
      expect(IsoDate.parse(null), isNull);
      expect(IsoDate.isValid('pas une date'), isFalse);
    });

    test('les dates ISO se trient comme des dates', () {
      final dates = ['2026-10-01', '2026-09-30', '2026-09-02']..sort();
      expect(dates, ['2026-09-02', '2026-09-30', '2026-10-01']);
    });
  });
}
