// test/quotation_supabase_repository_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/features/quotation_generator/models/generator_company_settings.dart';
import 'package:salesapp/features/quotation_generator/models/generator_quotation.dart';
import 'package:salesapp/features/quotation_generator/models/heat_pump_model.dart';
import 'package:salesapp/features/quotation_generator/models/price_item.dart';
import 'package:salesapp/features/quotation_generator/models/tank_spec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quotation Supabase Schema & Serialization Tests', () {
    test('Serializes GeneratorQuotation to and from JSON faithfully for Supabase JSONB column', () {
      final quotation = GeneratorQuotation(
        id: 'c86f7b92-9443-4a18-b2ef-37ec07e5f3ad',
        customerName: 'Tata Motors Pune',
        customerAddress: 'Pimpri, Pune, MH',
        customerMobile: '9876543210',
        date: DateTime(2026, 10, 8),
        quoteRefNo: 'IN/HP/SS/26-27/0059',
        salesRef: 'Sales Head',
        salesMobile: '9292922992',
        model: const HeatPumpModel(
          id: 'IZ-8C',
          modelName: 'IZ-8C',
          displayCapacityKw: 8.0,
          ratedHeatingCapacity: '7.2kw',
          descriptionLine: 'Air Source Heat pump 7.2kw',
          makeModelLine: 'Make: IZYHEAT Heat Pump Model: IZ-8C',
          powerInputText: 'Power Input 1.72kw',
          defaultImagePath: 'https://dnhbtkhcjpkthvyhyzmt.supabase.co/storage/v1/object/public/product-images/models/sample.png',
          specs: {'Compressor': 'Panasonic Scroll'},
        ),
        tankRate: 230000,
        tankCapacityLitres: 1000,
        tankSpec: TankSpec.defaultFor(capacityLitres: 1000, isPressurized: true),
        extraPriceRows: PriceItem.defaultExtraRows(),
        subtotal: 230000,
        gstPercent: 18.0,
        gstAmount: 41400,
        grandTotal: 271400,
        paymentSplitAdvance: 70,
        paymentSplitDelivery: 20,
        paymentSplitCommissioning: 10,
        termsAndConditions: const ['Standard warranty terms apply'],
        coverImagePath: 'https://dnhbtkhcjpkthvyhyzmt.supabase.co/storage/v1/object/public/company-assets/branding/cover.png',
        bannerImagePath: 'https://dnhbtkhcjpkthvyhyzmt.supabase.co/storage/v1/object/public/company-assets/branding/banner.png',
        pdfUrl: 'https://dnhbtkhcjpkthvyhyzmt.supabase.co/storage/v1/object/public/pdfs/quotation.pdf',
        status: 'Draft',
        createdAt: DateTime(2026, 10, 8, 10, 0),
        updatedAt: DateTime(2026, 10, 8, 10, 0),
      );

      final json = quotation.toJson();
      expect(json['id'], quotation.id);
      expect(json['customerName'], 'Tata Motors Pune');
      expect(json['grandTotal'], 271400);
      expect(json['pdfUrl'], contains('https://'));
      expect(json['coverImagePath'], contains('https://'));

      // Reconstruct from JSON
      final reconstructed = GeneratorQuotation.fromJson(json);
      expect(reconstructed.id, quotation.id);
      expect(reconstructed.customerName, quotation.customerName);
      expect(reconstructed.grandTotal, 271400);
      expect(reconstructed.pdfUrl, quotation.pdfUrl);
      expect(reconstructed.model.modelName, 'IZ-8C');
    });

    test('Company settings serialization handles Supabase storage URLs and custom models', () {
      final settings = GeneratorCompanySettings(
        companyName: 'INSIYA SOLAR INDUSTRY',
        defaultCoverImagePath: 'https://dnhbtkhcjpkthvyhyzmt.supabase.co/storage/v1/object/public/company-assets/branding/cover.jpg',
        defaultBannerImagePath: 'https://dnhbtkhcjpkthvyhyzmt.supabase.co/storage/v1/object/public/company-assets/branding/banner.jpg',
        stampImagePath: 'https://dnhbtkhcjpkthvyhyzmt.supabase.co/storage/v1/object/public/company-assets/branding/stamp.png',
        nextRunningNumber: 1408,
      );

      final json = settings.toJson();
      expect(json['defaultCoverImagePath'], contains('https://'));
      expect(json['defaultBannerImagePath'], contains('https://'));
      expect(json['stampImagePath'], contains('https://'));

      final fromJson = GeneratorCompanySettings.fromJson(json);
      expect(fromJson.companyName, 'INSIYA SOLAR INDUSTRY');
      expect(fromJson.defaultCoverImagePath, settings.defaultCoverImagePath);
      expect(fromJson.defaultBannerImagePath, settings.defaultBannerImagePath);
      expect(fromJson.stampImagePath, settings.stampImagePath);
      expect(fromJson.nextRunningNumber, 1408);
    });
  });
}
