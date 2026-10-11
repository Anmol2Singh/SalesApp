// test/quotation_generator/qg_proposal_draft_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/features/quotation_generator/models/deal_quotation_item.dart';
import 'package:salesapp/features/quotation_generator/models/qg_proposal_draft.dart';
import 'package:salesapp/features/quotation_generator/services/qg_catalog_service.dart';

void main() {
  group('QgProposalDraft & Catalog Service Unit Tests (Milestone M3)', () {
    final sampleDealQuotation = DealQuotationItem(
      id: 'quote-uuid-1234',
      quotationNumber: 'IZY/QT/2026/0042',
      status: 'confirmed',
      revision: 1,
      orderDate: DateTime(2026, 10, 11),
      createdAt: DateTime(2026, 10, 11),
      updatedAt: DateTime(2026, 10, 11),
      customerName: 'Panay Stay Hospitality LLP',
      customerPhone: '+91 98765 43210',
      customerAddress: 'Survey 42, Lonavala, Maharashtra 410401',
      customerGst: '27AABCP1234F1Z5',
      salesmanName: 'Sagar Farate',
      salesmanPhone: '+91 98220 12345',
      subtotal: 375000.0,
      supplementarySubtotal: 25000.0,
      cgstRate: 9.0,
      sgstRate: 9.0,
      igstRate: 0.0,
      cgstAmount: 36000.0,
      sgstAmount: 36000.0,
      igstAmount: 0.0,
      grandTotal: 472000.0,
      lineItems: [
        {
          'description': 'Heat Pump - 38kw Commercial Air Source',
          'qty': 1,
          'unit_price': 300000.0,
          'total': 300000.0,
        },
        {
          'description': 'GI Pressurised Storage Tank 3000L',
          'qty': 1,
          'unit_price': 75000.0,
          'total': 75000.0,
        },
      ],
      supplementaryTerms: [
        {
          'name': 'Transportation & Insurance',
          'type': 'Extra',
          'qty': 1,
          'rate': 25000.0,
          'gst_percent': 18.0,
        },
        {
          'name': 'Installation & Commissioning',
          'type': 'Included',
          'qty': 1,
          'rate': 0.0,
          'gst_percent': 18.0,
        },
      ],
      paymentTerms: [
        {'term': 'Advance with PO', 'percent': 50, 'amount': 236000.0},
        {'term': 'Against Proforma Invoice', 'percent': 40, 'amount': 188800.0},
        {'term': 'After Satisfactory Installation', 'percent': 10, 'amount': 47200.0},
      ],
    );

    test('Initializes QgProposalDraft faithfully from DealQuotationItem', () {
      final draft = QgProposalDraft.fromDealQuotation(sampleDealQuotation);

      expect(draft.quotationId, equals('quote-uuid-1234'));
      expect(draft.quotationNumber, equals('IZY/QT/2026/0042'));
      expect(draft.customerName, equals('Panay Stay Hospitality LLP'));
      expect(draft.customerGst, equals('27AABCP1234F1Z5'));
      expect(draft.salesmanName, equals('Sagar Farate'));
      expect(draft.salesmanPhone, equals('+91 98220 12345'));
      expect(draft.quoteDate, equals('11/10/2026'));
      expect(draft.isConfirmed, isTrue);

      // Verify HP derivation
      expect(draft.hpKw, equals(38));
      expect(draft.hpModel, equals('IZ-38C'));
      expect(draft.specCategoryId, equals('hp_38_100'));

      // Verify Tank derivation
      expect(draft.hasTank, isTrue);
      expect(draft.tankCapacityLitres, equals(3000));
      expect(draft.tankMaterial, equals('GI'));
      expect(draft.isTankPressurized, isTrue);

      // Verify Totals and Reconciliation
      expect(draft.subtotal, equals(375000.0));
      expect(draft.supplementarySubtotal, equals(25000.0));
      expect(draft.calculatedSubTotal, equals(400000.0));
      expect(draft.calculatedTotalGst, equals(72000.0));
      expect(draft.calculatedGrandTotal, equals(472000.0));
      expect(draft.hasReconciliationMismatch, isFalse);
    });

    test('Round-trip serialization to JSON preserves all draft fields for Hive', () {
      final draft = QgProposalDraft.fromDealQuotation(sampleDealQuotation);
      draft.customerSalutation = 'Mr.';
      draft.tankInsulation = 'Rockwool';
      draft.coverImagePath = 'custom_cover.png';

      final json = draft.toJson();
      final restored = QgProposalDraft.fromJson(json);

      expect(restored.quotationId, equals(draft.quotationId));
      expect(restored.customerSalutation, equals('Mr.'));
      expect(restored.tankInsulation, equals('Rockwool'));
      expect(restored.coverImagePath, equals('custom_cover.png'));
      expect(restored.hpModel, equals('IZ-38C'));
      expect(restored.hpKw, equals(38));
      expect(restored.items.length, equals(2));
      expect(restored.supplementaryItems.length, equals(2));
      expect(restored.hpSpecs.length, equals(13));
    });

    test('QgCatalogService resolves categories correctly across kW ranges and types', () {
      expect(QgCatalogService.resolveCategory(hpKw: 4).id, equals('hp_4_8'));
      expect(QgCatalogService.resolveCategory(hpKw: 8).id, equals('hp_4_8'));
      expect(QgCatalogService.resolveCategory(hpKw: 12).id, equals('hp_9_24'));
      expect(QgCatalogService.resolveCategory(hpKw: 24).id, equals('hp_9_24'));
      expect(QgCatalogService.resolveCategory(hpKw: 38).id, equals('hp_38_100'));
      expect(QgCatalogService.resolveCategory(hpKw: 50).id, equals('hp_38_100'));
      expect(QgCatalogService.resolveCategory(hpKw: 150).id, equals('other'));

      // Special product kinds
      expect(QgCatalogService.resolveCategory(hpKw: 38, isPool: true).id, equals('pool'));
      expect(QgCatalogService.resolveCategory(hpKw: 8, isAllInOne: true).id, equals('all_in_one'));
      expect(QgCatalogService.resolveCategory(hpKw: 8, isWallMounted: true).id, equals('wall_mounted'));
    });

    test('QgCatalogService tank presets adhere to specifications', () {
      final gi = QgCatalogService.getTankPreset('GI');
      expect(gi['shellThickness'], equals('3mm'));
      expect(gi['dishThickness'], equals('3mm'));
      expect(gi['warrantyYears'], equals(5));

      final enamel = QgCatalogService.getTankPreset('Enamel');
      expect(enamel['shellThickness'], equals('2mm'));
      expect(enamel['dishThickness'], equals('2mm'));
      expect(enamel['warrantyYears'], equals(15));

      final ms = QgCatalogService.getTankPreset('MS');
      expect(ms['shellThickness'], equals('5mm'));
      expect(ms['dishThickness'], equals('6mm'));

      final ss = QgCatalogService.getTankPreset('SS');
      expect(ss['shellThickness'], equals('3mm'));
      expect(ss['dishThickness'], equals('3mm'));
      expect(ss['isUnconfirmed'], isTrue);
    });

    test('Flags reconciliation mismatch when printed sum differs from source quotation', () {
      final mismatchedQuote = DealQuotationItem(
        id: 'quote-uuid-999',
        quotationNumber: 'IZY/QT/2026/0099',
        status: 'draft',
        revision: 1,
        orderDate: DateTime(2026, 10, 11),
        createdAt: DateTime(2026, 10, 11),
        updatedAt: DateTime(2026, 10, 11),
        customerName: 'Test Hotel',
        customerPhone: '9999999999',
        customerAddress: 'Pune',
        salesmanName: 'Sales Rep',
        salesmanPhone: '8888888888',
        subtotal: 100000.0,
        supplementarySubtotal: 0.0,
        cgstRate: 9.0,
        sgstRate: 9.0,
        igstRate: 0.0,
        cgstAmount: 9000.0,
        sgstAmount: 9000.0,
        igstAmount: 0.0,
        grandTotal: 150000.0, // Stored in DB as 150000, but 100k + 18k = 118000
        lineItems: [
          {'description': 'Heat Pump - 8kw', 'qty': 1, 'unit_price': 100000.0, 'total': 100000.0}
        ],
        supplementaryTerms: [],
        paymentTerms: [],
      );

      final draft = QgProposalDraft.fromDealQuotation(mismatchedQuote);
      expect(draft.hasReconciliationMismatch, isTrue);
      expect(draft.reconciliationWarning, isNotNull);
      expect(draft.reconciliationWarning, contains('differs from calculated sum'));
    });
  });
}
