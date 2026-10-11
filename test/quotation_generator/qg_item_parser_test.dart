// test/quotation_generator/qg_item_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/features/quotation_generator/services/qg_item_parser.dart';

void main() {
  group('QgItemParser Unit Tests', () {
    test('HP Model Auto-generation: whole-number kW rule (IZ-{kw}C)', () {
      expect(QgItemParser.deriveHpModelFromKw(38), 'IZ-38C');
      expect(QgItemParser.deriveHpModelFromKw(8), 'IZ-8C');
      expect(QgItemParser.deriveHpModelFromKw(4), 'IZ-4C');
      expect(QgItemParser.deriveHpModelFromKw(20), 'IZ-20C');
      expect(QgItemParser.deriveHpModelFromKw(150), 'IZ-150C');
    });

    test('HP Whole-number parsing and normalization for variations ("8 KW", "8kW", "Heat Pump - 8KW")', () {
      final p1 = QgItemParser.parseLineItem('8 KW');
      expect(p1.type, ParsedItemType.heatPump);
      expect(p1.status, ItemResolveStatus.resolved);
      expect(p1.hpKw, 8);
      expect(p1.hpModel, 'IZ-8C');

      final p2 = QgItemParser.parseLineItem('8kW');
      expect(p2.type, ParsedItemType.heatPump);
      expect(p2.status, ItemResolveStatus.resolved);
      expect(p2.hpKw, 8);
      expect(p2.hpModel, 'IZ-8C');

      final p3 = QgItemParser.parseLineItem('Heat Pump - 8KW');
      expect(p3.type, ParsedItemType.heatPump);
      expect(p3.status, ItemResolveStatus.resolved);
      expect(p3.hpKw, 8);
      expect(p3.hpModel, 'IZ-8C');
    });

    test('Decimal kW Rule: Allowed and mapped to closest whole-number kW model', () {
      // 3.6kw -> 4kW (IZ-4C)
      final r1 = QgItemParser.parseLineItem('Heat Pump - 3.6kw');
      expect(r1.status, ItemResolveStatus.resolved);
      expect(r1.hpKw, 4);
      expect(r1.hpModel, 'IZ-4C');

      // 9.58kw -> 10kW (IZ-10C)
      final r2 = QgItemParser.parseLineItem('9.58kw Heat Pump');
      expect(r2.status, ItemResolveStatus.resolved);
      expect(r2.hpKw, 10);
      expect(r2.hpModel, 'IZ-10C');

      // 8.0kw -> 8kW (IZ-8C)
      final r3 = QgItemParser.parseLineItem('Heat Pump 8.0kw');
      expect(r3.status, ItemResolveStatus.resolved);
      expect(r3.hpKw, 8);
      expect(r3.hpModel, 'IZ-8C');

      // 75.5kw -> 76kW (IZ-76C)
      final r4 = QgItemParser.parseLineItem('Heat pump- 75.5kw');
      expect(r4.status, ItemResolveStatus.resolved);
      expect(r4.hpKw, 76);
      expect(r4.hpModel, 'IZ-76C');
    });

    test('Known mismatch: 88 kW derives IZ-88C with catalog warning chip', () {
      final res = QgItemParser.parseLineItem('Heat Pump - 88kw');
      expect(res.status, ItemResolveStatus.resolved);
      expect(res.hpKw, 88);
      expect(res.hpModel, 'IZ-88C');
      expect(res.catalogModel, 'IZ-90C');
      expect(res.warningMessage, contains('Catalog lists this unit as IZ-90C'));
    });

    test('Parses 25+ real strings from production inventory & quotations faithfully', () {
      final fixtures = <String, Map<String, dynamic>>{
        'Heat Pump - 10KW': {'type': ParsedItemType.heatPump, 'kw': 10, 'model': 'IZ-10C'},
        'Heat Pump - 12KW': {'type': ParsedItemType.heatPump, 'kw': 12, 'model': 'IZ-12C'},
        'Heat Pump - 18KW': {'type': ParsedItemType.heatPump, 'kw': 18, 'model': 'IZ-18C'},
        'Heat Pump - 20KW': {'type': ParsedItemType.heatPump, 'kw': 20, 'model': 'IZ-20C'},
        'Heat Pump - 25KW': {'type': ParsedItemType.heatPump, 'kw': 25, 'model': 'IZ-25C'},
        'Heat Pump - 38KW': {'type': ParsedItemType.heatPump, 'kw': 38, 'model': 'IZ-38C'},
        'Heat Pump - 4KW': {'type': ParsedItemType.heatPump, 'kw': 4, 'model': 'IZ-4C'},
        'Heat Pump - 8KW': {'type': ParsedItemType.heatPump, 'kw': 8, 'model': 'IZ-8C'},
        'Heat Pump 40kw': {'type': ParsedItemType.heatPump, 'kw': 40, 'model': 'IZ-40C'},
        'GI pressurised Tank 1000Ltr': {'type': ParsedItemType.tank, 'litres': 1000, 'mat': 'GI'},
        'GI pressurised Tank 1500Ltr': {'type': ParsedItemType.tank, 'litres': 1500, 'mat': 'GI'},
        'GI pressurised Tank 2000Ltr': {'type': ParsedItemType.tank, 'litres': 2000, 'mat': 'GI'},
        'GI pressurised Tank 2500Ltr': {'type': ParsedItemType.tank, 'litres': 2500, 'mat': 'GI'},
        'GI pressurised Tank 3000Ltr': {'type': ParsedItemType.tank, 'litres': 3000, 'mat': 'GI'},
        'GI Pressurised Tank 300Ltr': {'type': ParsedItemType.tank, 'litres': 300, 'mat': 'GI'},
        'GI pressurised Tank 500Ltr': {'type': ParsedItemType.tank, 'litres': 500, 'mat': 'GI'},
        'MS Pressurized Tank 3000Ltr': {'type': ParsedItemType.tank, 'litres': 3000, 'mat': 'MS'},
        'Tank Enamel coat 500Ltr': {'type': ParsedItemType.tank, 'litres': 500, 'mat': 'Enamel'},
        'GI Pressurise Tank 300Ltr': {'type': ParsedItemType.tank, 'litres': 300, 'mat': 'GI'},
        'GI pressurised  Tank 500Ltr': {'type': ParsedItemType.tank, 'litres': 500, 'mat': 'GI'},
        'Hot Water Storage Tank (500L)': {'type': ParsedItemType.tank, 'litres': 500, 'mat': 'GI'},
        'All in one 100Ltr': {'type': ParsedItemType.allInOne, 'litres': 100},
        'All in one 200Ltr': {'type': ParsedItemType.allInOne, 'litres': 200},
        'All in one 300Ltr': {'type': ParsedItemType.allInOne, 'litres': 300},
        'All in one 80Ltr': {'type': ParsedItemType.allInOne, 'litres': 80},
        'Swimming Pool Heat Pump 35kw': {'type': ParsedItemType.pool, 'kw': 35, 'model': 'IZ-35SP'},
        'Transportation': {'type': ParsedItemType.supplementary},
        'Installation': {'type': ParsedItemType.supplementary},
        'Lifting': {'type': ParsedItemType.supplementary},
        'Circulation pump': {'type': ParsedItemType.supplementary},
        'Plumbing & wiring': {'type': ParsedItemType.supplementary},
        'HP Contractor 3Ph': {'type': ParsedItemType.parts},
        'Boom Barrier': {'type': ParsedItemType.parts},
      };

      expect(fixtures.length, greaterThanOrEqualTo(25));

      for (final entry in fixtures.entries) {
        final parsed = QgItemParser.parseLineItem(entry.key);
        final expected = entry.value;

        expect(parsed.type, expected['type'], reason: 'Failed type for "${entry.key}"');
        expect(parsed.status, ItemResolveStatus.resolved, reason: 'Failed resolve for "${entry.key}"');

        if (expected.containsKey('kw')) {
          expect(parsed.hpKw ?? parsed.poolKw, expected['kw'], reason: 'Failed kW for "${entry.key}"');
        }
        if (expected.containsKey('model')) {
          expect(parsed.hpModel ?? parsed.poolModel, expected['model'], reason: 'Failed model for "${entry.key}"');
        }
        if (expected.containsKey('litres')) {
          expect(parsed.tankCapacityLitres ?? parsed.aioCapacityLitres, expected['litres'], reason: 'Failed litres for "${entry.key}"');
        }
        if (expected.containsKey('mat')) {
          expect(parsed.tankMaterial, expected['mat'], reason: 'Failed material for "${entry.key}"');
        }
      }
    });
  });
}
