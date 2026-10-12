// test/quotation_generator/qg_noc_extractor_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/features/quotation_generator/models/qg_noc_profile.dart';
import 'package:salesapp/features/quotation_generator/services/qg_noc_extractor.dart';

void main() {
  group('QgNocExtractor Model & Quantity Extraction Tests', () {
    test('1. Boom Barrier line "... IZ-2001" qty 2 -> Model: IZ-2001, Quantity: 2 Nos', () {
      final items = [
        {
          'description': 'Boom Barrier Automated Gate Model IZ-2001 Heavy Duty',
          'qty': 2,
          'uom': 'Nos',
        }
      ];

      final lines = QgNocExtractor.extractEquipmentLines(
        lineItems: items,
        defaultProductName: 'Boom Barrier',
      );

      expect(lines.length, equals(1));
      expect(lines[0].product, equals('Boom Barrier'));
      expect(lines[0].model, equals('IZ-2001'));
      expect(lines[0].quantity, equals(2));
      expect(lines[0].uom, equals('Nos'));
      expect(lines[0].isAmbiguous, isFalse);
    });

    test('2. Heat Pump 38kw line -> Model: IZ-38C', () {
      final items = [
        {
          'description': 'Commercial Heat Pump 38kW R134A Water Heating System',
          'qty': 1,
        }
      ];

      final lines = QgNocExtractor.extractEquipmentLines(
        lineItems: items,
        defaultProductName: 'Heat Pump',
      );

      expect(lines.length, equals(1));
      expect(lines[0].product, equals('Heat Pump'));
      expect(lines[0].model, equals('IZ-38C'));
      expect(lines[0].quantity, equals(1));
    });

    test('3. Heat Pump + Storage Tank lines -> Two distinct equipment rows', () {
      final items = [
        {
          'description': 'Heat Pump 12kW System',
          'qty': 1,
          'uom': 'Nos',
        },
        {
          'description': '500 Ltr Pressurized GI Storage Tank 3mm Shell',
          'qty': 2,
          'uom': 'Nos',
        },
      ];

      final lines = QgNocExtractor.extractEquipmentLines(
        lineItems: items,
        defaultProductName: 'Heat Pump',
      );

      expect(lines.length, equals(2));
      expect(lines[0].product, equals('Heat Pump'));
      expect(lines[0].model, equals('IZ-12C'));
      expect(lines[0].quantity, equals(1));

      expect(lines[1].product, equals('Storage Tank'));
      expect(lines[1].model, equals('500 Ltr GI Tank'));
      expect(lines[1].quantity, equals(2));
    });

    test('4. Ambiguous line flagged with "Check model"', () {
      final items = [
        {
          'description': 'Custom accessories and brackets without standard code',
          'qty': 1,
        }
      ];

      final lines = QgNocExtractor.extractEquipmentLines(
        lineItems: items,
        defaultProductName: 'Heat Pump',
      );

      expect(lines.length, equals(1));
      expect(lines[0].isAmbiguous, isTrue);
      expect(lines[0].ambiguityReason, equals('Check model'));
    });

    test('5. Supplementary items are excluded from equipment lines', () {
      final items = [
        {
          'description': 'Boom Barrier IZ-2001',
          'qty': 1,
          'is_supplementary': false,
        },
        {
          'description': 'Extra Wiring Charges',
          'qty': 1,
          'is_supplementary': true,
        },
      ];

      final lines = QgNocExtractor.extractEquipmentLines(
        lineItems: items,
        defaultProductName: 'Boom Barrier',
      );

      expect(lines.length, equals(1));
      expect(lines[0].model, equals('IZ-2001'));
    });

    test('6. Address resolution precedence: installation > shipping > billing > customer', () {
      final inst = {'customer_address': 'Site Address from Installation Job'};
      final quotShip = {'shipping_address': 'Shipping Address from Quotation'};
      final quotBill = {'billing_address': 'Billing Address from Quotation'};
      final cust = {'address': 'Customer Master Address'};

      // 1. Installation takes highest precedence
      expect(
        QgNocExtractor.resolveSiteAddress(installation: inst, quotation: quotShip, customer: cust),
        equals('Site Address from Installation Job'),
      );

      // 2. Shipping address takes second precedence
      expect(
        QgNocExtractor.resolveSiteAddress(installation: null, quotation: quotShip, customer: cust),
        equals('Shipping Address from Quotation'),
      );

      // 3. Billing address takes third precedence
      expect(
        QgNocExtractor.resolveSiteAddress(installation: null, quotation: quotBill, customer: cust),
        equals('Billing Address from Quotation'),
      );

      // 4. Customer master address is final fallback
      expect(
        QgNocExtractor.resolveSiteAddress(installation: null, quotation: null, customer: cust),
        equals('Customer Master Address'),
      );
    });

    test('7. Customer name formatting in UPPERCASE with M/s salutation', () {
      final cust = {'company_name': 'Turquoise Pune'};
      final name = QgNocExtractor.resolveCustomerName(customer: cust);

      expect(name, equals('TURQUOISE PUNE'));
    });

    test('8. Full Payload building populates company block and replaces product placeholders', () {
      final profile = QgNocProfile(
        id: 'p1',
        productName: 'Boom Barrier',
        equipmentLabel: 'Boom Barrier',
        workTypeText: '{Product} Installation work',
        confirmationLines: [
          '1. The installation of the {Product} is permitted.',
        ],
        closingSentence: 'Issued for operation of {Product}.',
      );

      final deal = {
        'product_name': 'Boom Barrier',
      };

      final payload = QgNocExtractor.buildPayload(
        deal: deal,
        quotation: {
          'quotation_number': 'QT/26-27/005',
          'line_items': [
            {'description': 'IZ-2001 Gate', 'qty': 2}
          ],
        },
        customer: {'company_name': 'M/s TURQUOISE PUNE'},
        installation: {'customer_address': 'Viman Nagar, Pune', 'ticket_number': 'INST-99'},
        profile: profile,
        companyConfig: {
          'company_name': 'INSIYA TRADING CORPORATION',
          'company_address': 'Office 807, Pune',
        },
      );

      expect(payload.customerName, equals('TURQUOISE PUNE'));
      expect(payload.address, equals('Viman Nagar, Pune'));
      expect(payload.quotationNumber, equals('QT/26-27/005'));
      expect(payload.installationTicketNo, equals('INST-99'));
      expect(payload.workType, equals('Boom Barrier Installation work'));
      expect(payload.confirmations[0], equals('1. The installation of the Boom Barrier is permitted.'));
      expect(payload.closingSentence, equals('Issued for operation of Boom Barrier.'));
    });

    test('9. Inventory product filtering drops accessories, pumps, sensors, contactors', () {
      final items = [
        {'description': 'IZ-4C', 'qty': 5},
        {'description': '500 Ltr GI Tank', 'qty': 5},
        {'description': 'Wilo circulation pump 25/6', 'qty': 1},
        {'description': '500 Ltr GI Tank', 'qty': 1},
        {'description': 'Sensor Reverse line', 'qty': 1},
        {'description': 'HP Contractor 3Ph', 'qty': 1},
        {'description': 'IZ-38C', 'qty': 1},
      ];

      final lines = QgNocExtractor.extractEquipmentLines(
        lineItems: items,
        defaultProductName: 'Heat Pump',
      );

      // Only IZ-4C, 500 Ltr GI Tank (aggregated 5+1=6), and IZ-38C should remain
      expect(lines.length, equals(3));
      expect(lines.any((l) => l.model == 'IZ-4C' && l.quantity == 5), isTrue);
      expect(lines.any((l) => l.model == '500 Ltr GI Tank' && l.quantity == 6), isTrue);
      expect(lines.any((l) => l.model == 'IZ-38C' && l.quantity == 1), isTrue);

      // None of the non-products should be present
      expect(lines.any((l) => l.model.contains('Wilo')), isFalse);
      expect(lines.any((l) => l.model.contains('Sensor')), isFalse);
      expect(lines.any((l) => l.model.contains('Contractor')), isFalse);
    });
  });
}
