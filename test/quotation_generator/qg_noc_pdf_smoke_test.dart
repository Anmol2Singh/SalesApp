// test/quotation_generator/qg_noc_pdf_smoke_test.dart

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/features/quotation_generator/models/qg_noc_builder_state.dart';
import 'package:salesapp/features/quotation_generator/models/qg_noc_profile.dart';
import 'package:salesapp/features/quotation_generator/services/pdf_noc_builder.dart';
import 'package:salesapp/features/quotation_generator/services/qg_noc_extractor.dart';

void main() {
  group('PdfNocBuilder Smoke & Fidelity Tests', () {
    final templateDataPayload = QgNocPayload(
      companyName: 'INSIYA TRADING CORPORATION',
      companyAddress: 'Office no.807,finswell,behind Hyatt Hotel,\n Viman Nagar, Pune 411014',
      companyEmail: 'insiyaindia@gmail.com    info@insiyacorp.com',
      companyPhone: '+91 7588874019 & +91 9292922992',
      companyWebsite: 'www.insiyacorp.com',
      salutation: 'M/s',
      customerName: 'TURQUOISE PUNE',
      address: 'S.NO. 134 GROUND AND SIX FLOORS TURQUOISE PUNE, NAGAR ROAD Pune, \nMaharashtra  411014',
      productName: 'Boom Barrier',
      subject: 'No Objection Certificate for Installation & Commissioning of Boom Barrier.',
      date: DateTime(2026, 10, 10),
      equipmentLabel: 'Boom Barrier',
      equipmentLines: const [
        NocEquipmentLine(
          product: 'Boom Barrier',
          model: 'IZ-2001',
          quantity: 2,
          uom: 'Nos',
        ),
      ],
      workType: 'Boom Barrier Installation work',
      wiring: 'Done',
      testing: 'Done',
      remark: 'All Installation & Commissioning work Completed as per work order',
      confirmations: const [
        '1. The installation of the Boom Barrier is permitted at the above location.',
        '3. Necessary precautions has been.',
      ],
      closingSentence: 'This NOC is issued upon request for installation and operationBoom \nBarrier System.',
      wordingMode: NocWordingMode.templateExact,
    );

    test('1. Generates valid non-empty PDF in template_exact mode with template data', () async {
      final bytes = await PdfNocBuilder.buildNocPdf(templateDataPayload);

      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(5000));

      final outFile = File('scratch/noc_template_exact_generated.pdf');
      outFile.writeAsBytesSync(bytes);
      expect(outFile.existsSync(), isTrue);
    });

    test('2. Generates valid non-empty PDF in enhanced mode', () async {
      final enhancedPayload = QgNocExtractor.buildPayload(
        deal: {'product_name': 'Boom Barrier'},
        quotation: {
          'quotation_number': 'QT/26-27/005',
          'line_items': [
            {'description': 'IZ-2001 Boom Barrier', 'qty': 2}
          ],
        },
        customer: {'company_name': 'TURQUOISE PUNE'},
        installation: {
          'customer_address': 'S.NO. 134 TURQUOISE PUNE, NAGAR ROAD Pune, Maharashtra 411014',
          'ticket_number': 'INST-2026-001',
          'updated_at': '2026-10-10T00:00:00Z',
        },
        profile: QgNocProfile(
          id: 'boom',
          productName: 'Boom Barrier',
          equipmentLabel: 'Boom Barrier',
          workTypeText: '{Product} Installation work',
          confirmationLines: [
            'The installation of the {Product} is permitted at the above location.',
            'The installation and commissioning work has been completed as per the work order.',
            'The {Product} has been tested and handed over in proper working condition.',
            'Necessary precautions have been taken during installation and commissioning.',
            'We have no objection to the operation of the {Product} at the above location.',
          ],
          closingSentence: 'This NOC is issued upon request for installation and operation of the {Product} System.',
        ),
        companyConfig: {
          'company_name': 'INSIYA TRADING CORPORATION',
          'company_address': 'Office no.807,finswell,behind Hyatt Hotel, Pune 411014',
          'company_email': 'insiyaindia@gmail.com',
          'company_phone': '+91 7588874019',
          'company_website': 'www.insiyacorp.com',
        },
        wordingMode: NocWordingMode.enhanced,
      );

      final bytes = await PdfNocBuilder.buildNocPdf(enhancedPayload);

      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(5000));

      final outFile = File('scratch/noc_enhanced_generated.pdf');
      outFile.writeAsBytesSync(bytes);
      expect(outFile.existsSync(), isTrue);
    });

    test('3. Generates valid non-empty PDF for Heat Pump with multi equipment lines', () async {
      final hpPayload = QgNocExtractor.buildPayload(
        deal: {'product_name': 'Heat Pump'},
        quotation: {
          'quotation_number': 'QT/26-27/088',
          'line_items': [
            {'description': 'Commercial Heat Pump 38kW', 'qty': 1},
            {'description': '500 Ltr Pressurized GI Tank', 'qty': 2},
          ],
        },
        customer: {'company_name': 'Hotel Grand Palace'},
        installation: {
          'customer_address': 'Plot 44, Hinjewadi, Pune',
          'ticket_number': 'INST-HP-04',
          'updated_at': '2026-10-11T00:00:00Z',
        },
        profile: QgNocProfile.defaultProfile(productName: 'Heat Pump'),
        companyConfig: {
          'company_name': 'INSIYA TRADING CORPORATION',
          'company_address': 'Office 807, Pune',
          'company_email': 'info@insiyacorp.com',
          'company_phone': '+91 9292922992',
          'company_website': 'www.insiyacorp.com',
        },
        wordingMode: NocWordingMode.enhanced,
      );

      final bytes = await PdfNocBuilder.buildNocPdf(hpPayload);

      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(5000));

      final outFile = File('scratch/noc_heat_pump_generated.pdf');
      outFile.writeAsBytesSync(bytes);
      expect(outFile.existsSync(), isTrue);
    });
  });
}
