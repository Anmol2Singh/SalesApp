// lib/features/quotation_generator/templates/qg_product_template.dart

import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import '../models/deal_quotation_item.dart';
import '../models/qg_product_profile.dart';

/// Strategy interface for product quotation templates inside the quotation_generator module.
abstract class QgProductTemplate {
  /// Unique template identifier (e.g. 'heat_pump_proposal', 'boom_barrier_quotation')
  String get key;

  /// User-friendly label (e.g. 'Heat Pump', 'Boom Barrier')
  String get label;

  /// Determines if this template handles the given deal product name.
  bool matchesProduct(String productName);

  /// Builds the editor UI body for this product template.
  Widget buildBuilderBody(
    BuildContext context, {
    required String quotationId,
    required DealQuotationItem dealOption,
    required QgProductProfile profile,
  });

  /// Builds the final quotation PDF bytes.
  Future<Uint8List> buildPdf({
    required dynamic draft,
    required QgProductProfile profile,
    Map<String, dynamic>? assets,
  });
}
