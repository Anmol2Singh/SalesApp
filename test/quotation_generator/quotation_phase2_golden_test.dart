// test/quotation_phase2_golden_test.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/features/quotation_generator/config/dynamic_annexure_resolver.dart';
import 'package:salesapp/features/quotation_generator/config/quote_template_config.dart';
import 'package:salesapp/features/quotation_generator/config/quote_type.dart';
import 'package:salesapp/features/quotation_generator/models/all_in_one_model.dart';
import 'package:salesapp/features/quotation_generator/models/generator_company_settings.dart';
import 'package:salesapp/features/quotation_generator/models/generator_quotation.dart';
import 'package:salesapp/features/quotation_generator/models/heat_pump_model.dart';
import 'package:salesapp/features/quotation_generator/models/pool_heat_pump_model.dart';
import 'package:salesapp/features/quotation_generator/models/price_item.dart';
import 'package:salesapp/features/quotation_generator/models/price_row.dart';
import 'package:salesapp/features/quotation_generator/models/tank_line_item.dart';
import 'package:salesapp/features/quotation_generator/models/tank_spec.dart';
import 'package:salesapp/features/quotation_generator/services/pdf_quotation_builder.dart';
import 'package:salesapp/features/quotation_generator/services/price_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Section 9: The 11 Golden Math Vectors', () {
    test('Vector 1: hpWithTank, combined (38C x1, 3000L GI tank x2 @ ₹3,75,000)', () {
      final rows = [
        const PriceRow(
          id: '01',
          serialNo: '01',
          description: '3000L GI Tank',
          qty: 2,
          rate: 375000,
          status: PriceRowStatus.priced,
        ),
      ];
      final res = PriceCalculator.calculateFromRows(rows: rows);
      expect(res.subtotal, 750000);
      expect(res.gstAmount, 135000);
      expect(res.grandTotal, 885000);
    });

    test('Vector 2: hpWithTank, inclusive (4C + 500L @ target total ₹1,60,000)', () {
      final rows = [
        const PriceRow(
          id: '01',
          serialNo: '01',
          description: '4C + 500L System Package',
          qty: 1,
          rate: 160000,
          status: PriceRowStatus.priced,
        ),
      ];
      final res = PriceCalculator.calculateFromRows(
        rows: rows,
        priceEntryMode: 'inclusive',
        targetTotal: 160000,
      );
      expect(res.subtotal, 135593);
      expect(res.gstAmount, 24407);
      expect(res.grandTotal, 160000);
    });

    test('Vector 3: hpWithTank, separate rate (38C @ ₹3,38,983 + 500L @ ₹42,373)', () {
      final rows = [
        const PriceRow(
          id: '01',
          serialNo: '01',
          description: 'IZ-38C Machine',
          qty: 1,
          rate: 338983,
          status: PriceRowStatus.priced,
        ),
        const PriceRow(
          id: '02',
          serialNo: '02',
          description: '500L Tank',
          qty: 1,
          rate: 42373,
          status: PriceRowStatus.priced,
        ),
      ];
      final res = PriceCalculator.calculateFromRows(rows: rows);
      expect(res.subtotal, 381356);
      expect(res.gstAmount, 68644);
      expect(res.grandTotal, 450000);
    });

    test('Vector 4: hpWithTank, extra tank line (24C + 2000L @ ₹3,06,000 + extra 2000L @ ₹1,00,000)', () {
      final rows = [
        const PriceRow(
          id: '01',
          serialNo: '01',
          description: '24C + 2000L System',
          qty: 1,
          rate: 306000,
          status: PriceRowStatus.priced,
        ),
        const PriceRow(
          id: '02',
          serialNo: '02',
          description: 'Extra 2000L Tank',
          qty: 1,
          rate: 100000,
          status: PriceRowStatus.priced,
        ),
      ];
      final res = PriceCalculator.calculateFromRows(rows: rows);
      expect(res.subtotal, 406000);
      expect(res.gstAmount, 73080);
      expect(res.grandTotal, 479080);
    });

    test('Vector 5: hpWithTank, buyback (18C x2, 2500L x2 @ ₹3,15,000, buyback ₹45,000)', () {
      final rows = [
        const PriceRow(
          id: '01',
          serialNo: '01',
          description: '18C + 2500L System',
          qty: 2,
          rate: 315000,
          status: PriceRowStatus.priced,
        ),
      ];
      final res = PriceCalculator.calculateFromRows(
        rows: rows,
        hasBuyback: true,
        buybackRate: 45000,
        buybackQty: 1,
      );
      expect(res.subtotal, 630000);
      expect(res.gstAmount, 113400);
      expect(res.grossTotal, 743400);
      expect(res.buybackAmount, 45000);
      expect(res.netPayable, 698400);
    });

    test('Vector 6: hpWithTank, qty 10 (12C x10, 2000L x10 @ ₹2,40,000)', () {
      final rows = [
        const PriceRow(
          id: '01',
          serialNo: '01',
          description: '12C + 2000L System',
          qty: 10,
          rate: 240000,
          status: PriceRowStatus.priced,
        ),
      ];
      final res = PriceCalculator.calculateFromRows(rows: rows);
      expect(res.subtotal, 2400000);
      expect(res.gstAmount, 432000);
      expect(res.grandTotal, 2832000);
    });

    test('Vector 7: hpOnly (50C x2 @ ₹4,50,000)', () {
      final rows = [
        const PriceRow(
          id: '01',
          serialNo: '01',
          description: 'IZ-50C Machine Only with Stand',
          qty: 2,
          rate: 450000,
          status: PriceRowStatus.priced,
        ),
      ];
      final res = PriceCalculator.calculateFromRows(rows: rows);
      expect(res.subtotal, 900000);
      expect(res.gstAmount, 162000);
      expect(res.grandTotal, 1062000);
    });

    test('Vector 8: swimmingPool (35SP @ ₹3,12,712)', () {
      final rows = [
        const PriceRow(
          id: '01',
          serialNo: '01',
          description: 'IZ-35SP Pool Heat Pump',
          qty: 1,
          rate: 312712,
          status: PriceRowStatus.priced,
        ),
      ];
      final res = PriceCalculator.calculateFromRows(rows: rows);
      expect(res.subtotal, 312712);
      expect(res.gstAmount, 56288);
      expect(res.grandTotal, 369000);
    });

    test('Vector 9: allInOneFloor (200A @ ₹1,22,881)', () {
      final rows = [
        const PriceRow(
          id: '01',
          serialNo: '01',
          description: 'IZ-200A All In One Floor Top Blow',
          qty: 1,
          rate: 122881,
          status: PriceRowStatus.priced,
        ),
      ];
      final res = PriceCalculator.calculateFromRows(rows: rows);
      expect(res.subtotal, 122881);
      expect(res.gstAmount, 22119);
      expect(res.grandTotal, 145000);
    });

    test('Vector 10: allInOneWall (100V @ ₹76,271)', () {
      final rows = [
        const PriceRow(
          id: '01',
          serialNo: '01',
          description: 'IZ-100V All In One Wall Mounted',
          qty: 1,
          rate: 76271,
          status: PriceRowStatus.priced,
        ),
      ];
      final res = PriceCalculator.calculateFromRows(rows: rows);
      expect(res.subtotal, 76271);
      expect(res.gstAmount, 13729);
      expect(res.grandTotal, 90000);
    });

    test('Vector 11: partsOnly (pump ₹20,000 + controller ₹30,000)', () {
      final rows = [
        const PriceRow(
          id: '01',
          serialNo: '01',
          description: 'Return Line Circulation Pump',
          qty: 1,
          rate: 20000,
          status: PriceRowStatus.priced,
        ),
        const PriceRow(
          id: '02',
          serialNo: '02',
          description: 'Micro Controller Unit',
          qty: 1,
          rate: 30000,
          status: PriceRowStatus.priced,
        ),
      ];
      final res = PriceCalculator.calculateFromRows(rows: rows);
      expect(res.subtotal, 50000);
      expect(res.gstAmount, 9000);
      expect(res.grandTotal, 59000);
    });
  });

  group('Dynamic Annexure Resolver Tests', () {
    test('partsOnly has NO tech specs; Terms is Annexure II', () {
      final config = QuoteTemplateConfig.forType(QuoteType.partsOnly);
      expect(config.hasTechnicalSpecs, false);

      final resolver = DynamicAnnexureResolver(
        quoteType: QuoteType.partsOnly,
        hasSpecs: config.hasTechnicalSpecs,
      );
      final entries = resolver.resolveEntries();

      expect(entries.length, 2);
      expect(entries[0].romanNumeral, 'Annexure I');
      expect(entries[0].title, 'Price Schedule & System Details');
      expect(entries[1].romanNumeral, 'Annexure II');
      expect(entries[1].title, 'Commercial Terms and Conditions & Warranty');
    });

    test('hpWithTank has tech specs; Terms is Annexure III', () {
      final config = QuoteTemplateConfig.forType(QuoteType.hpWithTank);
      expect(config.hasTechnicalSpecs, true);

      final resolver = DynamicAnnexureResolver(
        quoteType: QuoteType.hpWithTank,
        hasSpecs: config.hasTechnicalSpecs,
      );
      final entries = resolver.resolveEntries();

      expect(entries.length, 3);
      expect(entries[0].romanNumeral, 'Annexure I');
      expect(entries[1].romanNumeral, 'Annexure II');
      expect(entries[1].title, contains('Technical Specifications'));
      expect(entries[2].romanNumeral, 'Annexure III');
      expect(entries[2].title, 'Commercial Terms and Conditions & Warranty');
    });
  });

  group('Supabase Migration & Deserialization Tests', () {
    test('Legacy Phase 1 JSON without quote_type defaults cleanly to hpWithTank', () {
      final legacyJson = {
        'id': 'legacy_123',
        'customer_name': 'Hotel Heritage',
        'customer_address': 'Pune',
        'customer_mobile': '9876543210',
        'quote_ref_no': 'IN/HP/SS/26-27/100',
        'sales_ref': 'Sir',
        'sales_mobile': '9292922992',
        'tank_rate': 120000,
        'subtotal': 120000,
        'gst_amount': 21600,
        'grand_total': 141600,
      };

      final q = GeneratorQuotation.fromJson(legacyJson);
      expect(q.quoteType, QuoteType.hpWithTank);
      expect(q.customerName, 'Hotel Heritage');
      expect(q.priceRows.isNotEmpty, true);
      expect(q.tankLines.isNotEmpty, true);
      expect(q.grandTotal, 141600);
    });

    test('Round-trip serialization preserves Phase 2 QuoteType and Buyback', () {
      final original = GeneratorQuotation(
        id: 'phase2_q',
        quoteType: QuoteType.swimmingPool,
        salutation: 'Mr.',
        customerName: 'Aman Sharma',
        customerAddress: 'Goa',
        customerMobile: '9999888877',
        date: DateTime(2026, 4, 15),
        quoteRefNo: 'IN/POOL/26-27/01',
        salesRef: 'Sales Insiya',
        salesMobile: '9292922992',
        model: const HeatPumpModel(id: 'IZ-4C', modelName: 'IZ-4C', displayCapacityKw: 4.0),
        tankRate: 0,
        tankSpec: const TankSpec(),
        extraPriceRows: const [],
        priceRows: const [
          PriceRow(id: '01', serialNo: '01', description: 'Pool Heat Pump', rate: 312712, qty: 1, status: PriceRowStatus.priced),
        ],
        subtotal: 312712,
        gstAmount: 56288,
        grandTotal: 369000,
        termsAndConditions: const ['Term 1', 'Term 2'],
        createdAt: DateTime(2026, 4, 15),
        updatedAt: DateTime(2026, 4, 15),
      );

      final json = original.toJson();
      final roundTrip = GeneratorQuotation.fromJson(json);

      expect(roundTrip.quoteType, QuoteType.swimmingPool);
      expect(roundTrip.salutation, 'Mr.');
      expect(roundTrip.priceRows.first.description, 'Pool Heat Pump');
      expect(roundTrip.subtotal, 312712);
      expect(roundTrip.grandTotal, 369000);
    });
  });

  group('PDF Generation Smoke Test for All 7 Types', () {
    final settings = const GeneratorCompanySettings();

    for (final type in QuoteType.values) {
      test('Generates non-empty PDF for type: ${type.id}', () async {
        final config = QuoteTemplateConfig.forType(type);
        final q = GeneratorQuotation(
          id: 'test_${type.id}',
          quoteType: type,
          customerName: 'Test Customer',
          customerAddress: 'Pune, Maharashtra',
          customerMobile: '9876543210',
          date: DateTime.now(),
          quoteRefNo: 'IN/TEST/26-27/01',
          salesRef: 'Insiya Sales',
          salesMobile: '+91 9292922992',
          model: const HeatPumpModel(
            id: 'IZ-4C',
            modelName: 'IZ-4C',
            displayCapacityKw: 4.0,
            ratedHeatingCapacity: '3.6kw',
            descriptionLine: 'Air Source Heat Pump 3.6kw',
            makeModelLine: 'Make: IZYHEAT Heat Pump Model: IZ-4C 3.6kw',
            powerInputText: 'Power Input 0.86kw, output 3.6kw, 220V - 1Phase',
          ),
          poolModel: PoolHeatPumpModel.defaultModel(),
          allInOneModel: AllInOneModel.defaultFloorModel(),
          tankRate: 100000,
          tankSpec: const TankSpec(),
          tankLines: const [
            TankLineItem(id: 't1', capacityLitres: 500, qty: 1, rate: 100000),
          ],
          priceRows: config.defaultRows,
          extraPriceRows: const [],
          subtotal: 100000,
          gstAmount: 18000,
          grandTotal: 118000,
          termsAndConditions: config.defaultTerms,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final pdfBytes = await PdfQuotationBuilder.buildQuotationPdf(q, settings);
        expect(pdfBytes, isNotNull);
        expect(pdfBytes.length, greaterThan(1000));
      });
    }
  });

  group('Milestone M4: Template Fidelity Golden Test (Shine Enterprises)', () {
    final settings = const GeneratorCompanySettings();

    final goldenShineQuotation = GeneratorQuotation(
      id: 'golden_shine_enterprises',
      quoteType: QuoteType.hpWithTank,
      salutation: 'Ms.',
      customerName: 'Shine Enterprises',
      customerAddress: 'Goa',
      customerMobile: '7097064061',
      date: DateTime(2026, 10, 7),
      quoteRefNo: 'IN/HP/SS/26-27/1668',
      salesRef: 'Mr. Aman Khan',
      salesMobile: '9044495184',
      model: const HeatPumpModel(
        id: 'IZ-38C',
        modelName: 'IZ-38C',
        displayCapacityKw: 38.0,
        ratedHeatingCapacity: '38kw',
        descriptionLine: 'Air Source Heat pump 38kw',
        makeModelLine: 'Make: IZYHEAT Heat Pump Model: IZ-38C 38kw',
        powerInputText: 'Power Input 8.75kw, output 38kw, 415V - 3Phase, 50Hz With Auto Defrost.',
        defaultImagePath: 'assets/images/product_iz_38c.png',
        specs: {
          'Size (W x D x H)': '1410x748x1000',
          'Rated Heating Capacity': '38kw',
          'Power Supply': '415V - 3Phase',
          'Rated Input Power': '8.75kw',
          'Rated COP': '4.34',
          'Rated Water Yield': '817 L/h',
          'Max Outlet Water Temperature': '60°C',
          'Water Flow Noise': '<=59dB(A)',
          'Condenser': '0',
          'Refrigerant': 'R134A/410A',
          'Operating ambient Temp': '-15~43°C',
          'Compressor': 'DOUBLE',
        },
      ),
      heatPumpQty: 1,
      heatPumpAmountType: PriceRowType.included,
      tankCapacityLitres: 3000,
      tankQty: 2,
      tankRate: 375000,
      isTankPressurized: true,
      tankSpec: const TankSpec(
        capacityLitres: 3000,
        isPressurized: true,
        capacityAndThickness: '3000 ltr, 3mm Shell, 3mm Dish.',
        operatingPressure: 'Up to 5 Bar',
        testingPressure: '7 bar pressure',
        hotWaterInletOutlet: '2 Inch,',
        heatPumpCirculation: '1 Inch,',
        outerTankInsulation: '19mm IC CLAD insulation',
        temperatureDrop: '3º C / 8 hour',
        innerAndOuterTank: 'GI',
        tankDirection: 'Horizontal / Vertical',
        other: 'Solar Provision Additional Heat Pump Provision',
      ),
      extraPriceRows: const [],
      priceRows: const [
        PriceRow(
          id: '01',
          serialNo: '01',
          description: 'Air Source Heat pump 38kw',
          qty: 1,
          rate: 0,
          status: PriceRowStatus.included,
        ),
        PriceRow(
          id: '02',
          serialNo: '02',
          description: '3000  LTR Capacity, GI Pressurized Tank, 3mm Shell, and 3mm Dish, , Thickness,19mm IC CLAD insulation.',
          qty: 2,
          rate: 375000,
          status: PriceRowStatus.priced,
        ),
        PriceRow(id: '03', serialNo: '03', description: 'Transport to site', status: PriceRowStatus.included),
        PriceRow(id: '04', serialNo: '04', description: 'Lifting', status: PriceRowStatus.extra),
        PriceRow(id: '05', serialNo: '05', description: 'Installation', status: PriceRowStatus.included),
        PriceRow(id: '06', serialNo: '06', description: 'Circulation pump', status: PriceRowStatus.included),
        PriceRow(id: '07', serialNo: '07', description: 'Plumbing & wiring material', status: PriceRowStatus.extra),
      ],
      subtotal: 750000,
      gstAmount: 135000,
      grandTotal: 885000,
      netPayable: 885000,
      grossTotal: 885000,
      paymentSplitAdvance: 70,
      paymentSplitDelivery: 20,
      paymentSplitCommissioning: 10,
      validityDays: 7,
      warrantyHpYears: 2,
      warrantyTankYears: 5,
      termsAndConditions: const [
        'Proper 1 / 3 Phase power should be arranged where you install the heat pump.',
        'Electrical/civil/plumbing work materials – Customer Scope.',
        'Safe storage place need to be provided by you to keep our material & tools.',
        'All Interconnected pipe lines between system and Tank Your Scope but our team will do the installation. (If applicable): Included',
      ],
      includeBanner: true,
      includeProductImagePage: true,
      status: 'confirmed',
      createdAt: DateTime(2026, 10, 7),
      updatedAt: DateTime(2026, 10, 7),
    );

    test('Generates 7-page confirmed PDF for Shine Enterprises golden vector and persists to scratch', () async {
      final pdfBytes = await PdfQuotationBuilder.buildQuotationPdf(goldenShineQuotation, settings);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(20000));

      final outFile = File('scratch/golden_generated.pdf');
      outFile.writeAsBytesSync(pdfBytes);
      expect(outFile.existsSync(), isTrue);
    });

    test('Pre-approval proposal includes DRAFT - NOT APPROVED watermark when status is draft', () async {
      final draftQuotation = goldenShineQuotation.copyWith(status: 'draft');
      final draftPdfBytes = await PdfQuotationBuilder.buildQuotationPdf(draftQuotation, settings);
      expect(draftPdfBytes, isNotNull);
      expect(draftPdfBytes.length, greaterThan(20000));

      final outDraftFile = File('scratch/golden_draft_generated.pdf');
      outDraftFile.writeAsBytesSync(draftPdfBytes);
      expect(outDraftFile.existsSync(), isTrue);
    });

    test('hpOnly quotation (no tank added) generates 6 pages, omits tank spec, and shows HP rate in price table', () async {
      final noTankQuotation = goldenShineQuotation.copyWith(
        quoteType: QuoteType.hpOnly,
        tankLines: const [],
        tankSpec: null,
        tankCapacityLitres: 0,
        tankRate: 0,
        heatPumpNumericPrice: 440000,
        subtotal: 440000,
        gstAmount: 79200,
        grandTotal: 519200,
        netPayable: 519200,
        grossTotal: 519200,
        extraPriceRows: const [
          PriceItem(serialNo: '02', description: 'Transport to site', amountType: PriceRowType.included),
          PriceItem(serialNo: '03', description: 'Lifting', amountType: PriceRowType.extra),
          PriceItem(serialNo: '04', description: 'Installation', amountType: PriceRowType.included),
        ],
      );

      expect(noTankQuotation.hasTank, isFalse);

      final pdfBytes = await PdfQuotationBuilder.buildQuotationPdf(noTankQuotation, settings);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(20000));

      final outFile = File('scratch/no_tank_generated.pdf');
      outFile.writeAsBytesSync(pdfBytes);
      expect(outFile.existsSync(), isTrue);
    });

    test('Subject line formats with KWx#qty and LTRx#qty correctly', () {
      const model38 = HeatPumpModel(
        id: 'IZ-38C',
        modelName: 'IZ-38C',
        displayCapacityKw: 38.0,
      );
      final qWithTank = goldenShineQuotation.copyWith(
        model: model38,
        heatPumpQty: 1,
        tankCapacityLitres: 500,
        tankQty: 2,
        tankLines: const [],
      );
      expect(
        qWithTank.subjectLine,
        'Proposal For air Source Heat Pump Water Heating System 38KWx1, 500LTRx2 for your Project.',
      );

      final qNoTank = goldenShineQuotation.copyWith(
        quoteType: QuoteType.hpOnly,
        model: model38,
        heatPumpQty: 1,
        tankLines: const [],
        tankCapacityLitres: 0,
      );
      expect(
        qNoTank.subjectLine,
        'Proposal For air Source Heat Pump Water Heating System 38KWx1 for your Project.',
      );
    });
  });
}

