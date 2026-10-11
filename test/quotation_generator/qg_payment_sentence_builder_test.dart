// test/quotation_generator/qg_payment_sentence_builder_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/features/quotation_generator/services/qg_payment_sentence_builder.dart';

void main() {
  group('QgPaymentSentenceBuilder Tests (Milestone M4)', () {
    test('Builds exact 70/20/10 sentence with Annexure III quirk', () {
      final terms = [
        {'term': 'Advance with PO', 'percent': 70},
        {'term': 'Against Delivery', 'percent': 20},
        {'term': 'Against Installation and Commissioning', 'percent': 10},
      ];

      final sentence = QgPaymentSentenceBuilder.buildSentence(
        paymentTerms: terms,
        isAnnexureQuirk: true,
      );

      expect(
        sentence,
        equals('Advance will be 70% against PO, and 20% against delivery, the balance 10% against satisfactoryinstallation and commissioning.'),
      );
    });

    test('Builds standard 70/20/10 sentence for Acceptance Letter (proper spacing)', () {
      final terms = [
        {'term': 'Advance with PO', 'percent': 70},
        {'term': 'Against Delivery', 'percent': 20},
        {'term': 'Against Installation and Commissioning', 'percent': 10},
      ];

      final sentence = QgPaymentSentenceBuilder.buildSentence(
        paymentTerms: terms,
        isAnnexureQuirk: false,
      );

      expect(
        sentence,
        equals('Advance will be 70% against PO, and 20% against delivery, the balance 10% against satisfactory installation and commissioning.'),
      );
    });

    test('Builds multi-stage sentence correctly (e.g. 50/40/10)', () {
      final terms = [
        {'term': 'Advance with PO', 'percent': 50},
        {'term': 'Against Proforma', 'percent': 40},
        {'term': 'After Commissioning', 'percent': 10},
      ];

      final sentence = QgPaymentSentenceBuilder.buildSentence(
        paymentTerms: terms,
        isAnnexureQuirk: false,
      );

      expect(
        sentence,
        equals('Advance will be 50% against PO, and 40% against delivery, the balance 10% against satisfactory installation and commissioning.'),
      );
    });

    test('Builds 100% advance sentence', () {
      final terms = [
        {'term': 'Advance against PO', 'percent': 100},
      ];

      final sentence = QgPaymentSentenceBuilder.buildSentence(
        paymentTerms: terms,
      );

      expect(sentence, equals('100% Advance against PO.'));
    });
  });
}
