// lib/features/quotation_generator/templates/heat_pump_template.dart

import 'dart:typed_data';
import 'package:flutter/widgets.dart';

import '../models/deal_quotation_item.dart';
import '../models/generator_company_settings.dart';
import '../models/generator_quotation.dart';
import '../models/qg_product_profile.dart';
import '../services/pdf_quotation_builder.dart';
import '../ui/screens/heat_pump_proposal_builder_screen.dart';
import 'qg_product_template.dart';

/// Heat Pump template implementation. Thin wrapper around existing Heat Pump classes.
class HeatPumpTemplate implements QgProductTemplate {
  const HeatPumpTemplate();

  @override
  String get key => 'heat_pump_proposal';

  @override
  String get label => 'Heat Pump';

  @override
  bool matchesProduct(String productName) {
    final lower = productName.toLowerCase();
    return lower.contains('heat pump') || lower.contains('heatpump');
  }

  @override
  Widget buildBuilderBody(
    BuildContext context, {
    required String quotationId,
    required DealQuotationItem dealOption,
    required QgProductProfile profile,
  }) {
    return HeatPumpProposalBuilderScreen(
      quotationId: quotationId,
      initialDealQuotation: dealOption,
    );
  }

  @override
  Future<Uint8List> buildPdf({
    required dynamic draft,
    required QgProductProfile profile,
    Map<String, dynamic>? assets,
  }) async {
    if (draft is GeneratorQuotation) {
      final settings = GeneratorCompanySettings(
        companyName: profile.companyName,
        companyAddress: profile.companyAddressLines.join(', '),
        companyPhone: profile.companyMobile,
        companyEmail: profile.companyEmail,
        companyWebsite: profile.companyWebsite,
        bankName: profile.bankName,
        bankAccountName: profile.bankAccountName,
        bankAccountNumber: profile.bankAccountNo,
        bankBranch: profile.bankBranch,
        bankIfsc: profile.bankIfsc,
        defaultWarrantyHpYears: profile.warrantyYears,
        nextRunningNumber: profile.nextRefNumber,
      );
      return PdfQuotationBuilder.buildQuotationPdf(draft, settings);
    }
    throw ArgumentError('Draft must be of type GeneratorQuotation for HeatPumpTemplate');
  }
}
