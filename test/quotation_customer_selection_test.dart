// test/quotation_customer_selection_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:salesapp/core/models/customer.dart';
import 'package:salesapp/features/quotation_generator/models/generator_quotation.dart';
import 'package:salesapp/features/quotation_generator/models/heat_pump_model.dart';
import 'package:salesapp/features/quotation_generator/models/price_item.dart';
import 'package:salesapp/features/quotation_generator/models/tank_spec.dart';

void main() {
  group('Customer Auto-Fill Tests', () {
    test('Customer fields map correctly to quotation fields', () {
      final customer = Customer(
        id: 'cust-123',
        companyName: 'Acme Resorts & Spa',
        contactPerson: 'Mr. Rajesh Sharma',
        phone: '9876543210',
        email: 'rajesh@acmeresorts.com',
        address: 'Plot 42, Hill View Road, Mahabaleshwar, Maharashtra',
        gstNumber: '27AABCU9603R1ZM',
        createdBy: 'user-001',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

      // Emulate auto-fill logic in QuotationGeneratorFormScreen
      final name = customer.companyName.trim().isNotEmpty
          ? customer.companyName.trim()
          : (customer.contactPerson?.trim() ?? '');
      final address = customer.address?.trim() ?? '';
      final mobile = customer.phone?.trim() ?? '';

      expect(name, 'Acme Resorts & Spa');
      expect(address, 'Plot 42, Hill View Road, Mahabaleshwar, Maharashtra');
      expect(mobile, '9876543210');

      final quotation = GeneratorQuotation(
        id: 'quote-001',
        customerName: name,
        customerAddress: address,
        customerMobile: mobile,
        date: DateTime(2026, 10, 9),
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
        heatPumpQty: 1,
        heatPumpAmountType: PriceRowType.included,
        heatPumpNumericPrice: 0,
        tankCapacityLitres: 500,
        tankQty: 1,
        isTankPressurized: true,
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

      expect(quotation.customerName, 'Acme Resorts & Spa');
      expect(quotation.customerAddress, 'Plot 42, Hill View Road, Mahabaleshwar, Maharashtra');
      expect(quotation.customerMobile, '9876543210');
    });

    test('Fallback to contactPerson when companyName is empty', () {
      final customer = Customer(
        id: 'cust-456',
        companyName: '',
        contactPerson: 'Sunil Patil',
        phone: '9123456789',
        address: 'Bhor, Pune',
        createdBy: 'user-001',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

      final name = customer.companyName.trim().isNotEmpty
          ? customer.companyName.trim()
          : (customer.contactPerson?.trim() ?? '');

      expect(name, 'Sunil Patil');
      expect(customer.address, 'Bhor, Pune');
      expect(customer.phone, '9123456789');
    });
  });
}
