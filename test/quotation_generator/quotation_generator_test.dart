// test/quotation_generator_test.dart

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/features/quotation_generator/models/generator_company_settings.dart';
import 'package:salesapp/features/quotation_generator/models/generator_quotation.dart';
import 'package:salesapp/features/quotation_generator/models/heat_pump_model.dart';
import 'package:salesapp/features/quotation_generator/models/price_item.dart';
import 'package:salesapp/features/quotation_generator/models/tank_spec.dart';
import 'package:salesapp/features/quotation_generator/config/quote_type.dart';
import 'package:salesapp/features/quotation_generator/config/quote_template_config.dart';
import 'package:salesapp/features/quotation_generator/models/deal_quotation_option.dart';
import 'package:salesapp/features/quotation_generator/services/pdf_quotation_builder.dart';
import 'package:salesapp/features/quotation_generator/services/price_calculator.dart';
import 'package:salesapp/features/quotation_generator/services/quote_number_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PriceCalculator Tests', () {
    test('Calculates sample Panay Stay quotation correctly (Total ₹1,41,600)', () {
      final result = PriceCalculator.calculate(
        tankRate: 120000,
        tankQty: 1,
        hpAmountType: PriceRowType.included,
        hpNumericPrice: 0,
        hpQty: 1,
        extraRows: PriceItem.defaultExtraRows(),
        gstPercent: 18.0,
      );

      expect(result.subtotal, 120000);
      expect(result.gstAmount, 21600);
      expect(result.grandTotal, 141600);
    });

    test('Includes numeric extra rows in subtotal without floating-point errors', () {
      final extraRows = [
        const PriceItem(
          serialNo: '03',
          description: 'Transportation',
          amountType: PriceRowType.amount,
          numericAmount: 5000,
        ),
        const PriceItem(
          serialNo: '04',
          description: 'Lifting',
          amountType: PriceRowType.extra,
        ),
      ];

      final result = PriceCalculator.calculate(
        tankRate: 120000,
        tankQty: 1,
        extraRows: extraRows,
        gstPercent: 18.0,
      );

      expect(result.subtotal, 125000);
      expect(result.gstAmount, 22500); // 125000 * 0.18 = 22500
      expect(result.grandTotal, 147500);
    });

    test('Formats Indian currency with correct commas and rupee symbol', () {
      expect(PriceCalculator.formatIndianCurrency(0), '₹0');
      expect(PriceCalculator.formatIndianCurrency(500), '₹500');
      expect(PriceCalculator.formatIndianCurrency(1200), '₹1,200');
      expect(PriceCalculator.formatIndianCurrency(21600), '₹21,600');
      expect(PriceCalculator.formatIndianCurrency(120000), '₹1,20,000');
      expect(PriceCalculator.formatIndianCurrency(141600), '₹1,41,600');
      expect(PriceCalculator.formatIndianCurrency(141600, includeSymbol: false), '1,41,600');
    });
  });

  group('QuoteNumberService Tests', () {
    test('Derives correct FY from dates within fiscal year 2026-27', () {
      final dateJune = DateTime(2026, 6, 26);
      expect(QuoteNumberService.computeFinancialYear(dateJune), '26-27');

      final dateDec = DateTime(2026, 12, 31);
      expect(QuoteNumberService.computeFinancialYear(dateDec), '26-27');

      final dateMarch = DateTime(2027, 3, 31);
      expect(QuoteNumberService.computeFinancialYear(dateMarch), '26-27');

      final ref = QuoteNumberService.formatQuoteRef(
        prefix: 'IN/HP/SS',
        date: dateJune,
        runningNumber: 1406,
      );
      expect(ref, 'IN/HP/SS/26-27/1406');
    });

    test('Handles FY rollover on 1 April', () {
      final dateRollover = DateTime(2027, 4, 1);
      expect(QuoteNumberService.computeFinancialYear(dateRollover), '27-28');

      final ref = QuoteNumberService.formatQuoteRef(
        prefix: 'IN/HP/SS',
        date: dateRollover,
        runningNumber: 1407,
      );
      expect(ref, 'IN/HP/SS/27-28/1407');
    });
  });

  group('Payment Terms Text Generation Tests', () {
    test('Generates expected payment terms sentence template', () {
      final q = GeneratorQuotation(
        id: 'test-1',
        customerName: 'Panay stay',
        customerAddress: 'Bhor',
        customerMobile: '8752878777',
        date: DateTime(2026, 6, 26),
        quoteRefNo: 'IN/HP/SS/26-27/1406',
        salesRef: 'Sir',
        salesMobile: '9292922992',
        model: const HeatPumpModel(
          id: 'IZ-4C',
          modelName: 'IZ-4C',
          displayCapacityKw: 4.0,
          ratedHeatingCapacity: '3.6kw',
          descriptionLine: 'Air Source Heat pump 3.6kw',
          makeModelLine: 'Make: IZYHEAT Heat Pump Model: IZ-4C 3.6kw',
          powerInputText: 'Power Input 0.86kw, output 3.6kw, 220V - 1Phase, 50Hz With Auto Defrost.',
          defaultImagePath: 'assets/images/model_iz_4c.png',
          specs: {},
        ),
        tankRate: 120000,
        tankSpec: TankSpec.defaultFor(capacityLitres: 500, isPressurized: true),
        extraPriceRows: PriceItem.defaultExtraRows(),
        subtotal: 120000,
        gstAmount: 21600,
        grandTotal: 141600,
        paymentSplitAdvance: 70,
        paymentSplitDelivery: 20,
        paymentSplitCommissioning: 10,
        termsAndConditions: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        q.paymentTermsText,
        'Advance will be 70% against PO, and 20% against delivery, the balance 10% against satisfactory installation and commissioning.',
      );
    });
  });

  group('Smoke & PDF Generation Golden Test', () {
    test('Generates complete PDF for sample Panay Stay quotation', () async {
      final sampleQuotation = GeneratorQuotation(
        id: 'sample-panay-stay',
        customerName: 'Panay stay',
        customerAddress: 'Bhor',
        customerMobile: '8752878777',
        date: DateTime(2026, 6, 26),
        quoteRefNo: 'IN/HP/SS/26-27/1406',
        salesRef: 'Sir',
        salesMobile: '9292922992',
        model: const HeatPumpModel(
          id: 'IZ-4C',
          modelName: 'IZ-4C',
          displayCapacityKw: 4.0,
          ratedHeatingCapacity: '3.6kw',
          descriptionLine: 'Air Source Heat pump 3.6kw',
          makeModelLine: 'Make: IZYHEAT Heat Pump Model: IZ-4C 3.6kw',
          powerInputText: 'Power Input 0.86kw, output 3.6kw, 220V - 1Phase, 50Hz With Auto Defrost.',
          defaultImagePath: 'assets/images/model_iz_4c.png',
          specs: {
            'Size (W x D x H)': '936x385x550mm',
            'Rated Heating Capacity': '3.6kw',
            'Power Supply': '220V - 1Phase',
            'Rated Input Power': '0.86kw',
            'Rated COP': '4.18',
            'Rated Water Yield': '78 L/h',
            'Max Outlet Water Temperature': '60°C',
            'Water Flow Noise': '<=47dB(A)',
            'Condenser': 'Shell and tube heat exchanger',
            'Refrigerant': 'R134A/410A',
            'Operating ambient Temp': '-15~43°C',
            'Capacity in litre': '500',
            'Compressor': 'SINGLE',
          },
        ),
        tankRate: 120000,
        tankSpec: TankSpec.defaultFor(capacityLitres: 500, isPressurized: true),
        priceRows: QuoteTemplateConfig.forType(QuoteType.hpWithTank).defaultRows,
        extraPriceRows: PriceItem.defaultExtraRows(),
        subtotal: 120000,
        gstPercent: 18.0,
        gstAmount: 21600,
        grandTotal: 141600,
        paymentSplitAdvance: 70,
        paymentSplitDelivery: 20,
        paymentSplitCommissioning: 10,
        termsAndConditions: const [
          'Proper 1 / 3 Phase power should be arranged where you install the heat pump.',
          'Electrical/civil/plumbing work materials – Customer Scope.',
          'Safe storage place need to be provided by you to keep our material & tools.',
          'All Interconnected pipe lines between system and Tank Your Scope but our team will do the installation. (If applicable): Extra',
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const settings = GeneratorCompanySettings();

      expect(sampleQuotation.subtotal, 120000);
      expect(sampleQuotation.gstAmount, 21600);
      expect(sampleQuotation.grandTotal, 141600);
      expect(sampleQuotation.customerNameUppercase, 'PANAY STAY');
      expect(sampleQuotation.customerNameTitleCase, 'Panay Stay');

      // Generate the PDF
      final Uint8List pdfBytes = await PdfQuotationBuilder.buildQuotationPdf(
        sampleQuotation,
        settings,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(10000)); // Non-empty valid PDF bytes
    });
  });

  group('Deal Quotation Integration Tests', () {
    test('DealQuotationOption formats summaries and payment terms correctly', () {
      final deal = DealQuotationOption(
        quotationNumber: 'IZY/QT/2026/0075',
        productName: 'Heat Pump',
        salesman: 'Admin User',
        grandTotal: 151305.02,
        createdAt: DateTime(2026, 10, 8),
        lineItems: const [
          {'description': 'Heat Pump - 12KW', 'qty': 1, 'unit_price': 0, 'hsn_sac': '84186100'},
          {'description': 'GI pressurised Tank 500Ltr', 'qty': 6, 'unit_price': 48033.34, 'hsn_sac': '841919'},
        ],
        paymentTerms: const [
          {'term': 'Advance', 'percent': 50.0},
          {'term': 'Dispatch', 'percent': 30.0},
          {'term': 'Installation', 'percent': 10.0},
          {'term': 'Completion', 'percent': 10.0},
        ],
      );

      expect(deal.quotationNumber, 'IZY/QT/2026/0075');
      expect(deal.productName, 'Heat Pump');
      expect(deal.salesman, 'Admin User');
      expect(deal.lineItemsSummary, '2 items (Heat Pump - 12KW, ...)');
      expect(deal.paymentTermsSummary, 'Advance 50% • Dispatch 30% • Installation 10% • Completion 10%');
      expect(deal.formattedDate, '08/10/2026');
      expect(deal.formattedAmount.contains('1,51,305'), isTrue);
    });
  });
}

