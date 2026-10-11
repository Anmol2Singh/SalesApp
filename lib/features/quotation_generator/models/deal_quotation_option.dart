// lib/features/quotation_generator/models/deal_quotation_option.dart

import 'package:intl/intl.dart';

/// Represents a quotation generated within Deals (sales_pipelines / quotations table)
/// that can be linked and imported into the Quotation Generator.
class DealQuotationOption {
  final String quotationNumber;
  final String productName;
  final String? productId;
  final String? pipelineId;
  final String? salesman;
  final String? salesmanPhone;
  final List<dynamic> lineItems;
  final List<dynamic> paymentTerms;
  final String? termsText;
  final double grandTotal;
  final DateTime? createdAt;

  const DealQuotationOption({
    required this.quotationNumber,
    required this.productName,
    this.productId,
    this.pipelineId,
    this.salesman,
    this.salesmanPhone,
    this.lineItems = const [],
    this.paymentTerms = const [],
    this.termsText,
    this.grandTotal = 0.0,
    this.createdAt,
  });

  String get formattedDate {
    if (createdAt == null) return '';
    return DateFormat('dd/MM/yyyy').format(createdAt!);
  }

  String get formattedAmount {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(grandTotal);
  }

  String get paymentTermsSummary {
    if (paymentTerms.isEmpty) return '';
    final parts = <String>[];
    for (final term in paymentTerms) {
      if (term is Map) {
        final name = term['term']?.toString() ?? '';
        final pct = term['percent'] as num?;
        if (name.isNotEmpty && pct != null) {
          parts.add('$name ${pct.round()}%');
        }
      }
    }
    return parts.join(' • ');
  }

  String get lineItemsSummary {
    if (lineItems.isEmpty) return 'No line items';
    final count = lineItems.length;
    final firstItem = lineItems.first;
    final firstDesc = firstItem is Map ? (firstItem['description']?.toString() ?? '') : '';
    if (firstDesc.isNotEmpty && count > 1) {
      return '$count items ($firstDesc, ...)';
    } else if (firstDesc.isNotEmpty) {
      return '1 item ($firstDesc)';
    }
    return '$count items';
  }
}
