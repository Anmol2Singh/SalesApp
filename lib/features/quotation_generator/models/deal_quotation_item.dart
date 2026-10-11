// lib/features/quotation_generator/models/deal_quotation_item.dart

import 'package:intl/intl.dart';

/// Represents a source quotation originating from a deal in core CRM/Pipelines.
/// Strictly read-only representation.
class DealQuotationItem {
  final String id;
  final String quotationNumber;
  final String status;
  final int revision;
  final DateTime orderDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Customer details
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String? customerGst;
  
  // Salesperson details
  final String salesmanName;
  final String salesmanPhone;
  
  // Financial totals
  final double subtotal;
  final double supplementarySubtotal;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double grandTotal;
  final double cgstRate;
  final double sgstRate;
  final double igstRate;
  
  // Items & terms
  final List<Map<String, dynamic>> lineItems;
  final List<Map<String, dynamic>> supplementaryTerms;
  final List<Map<String, dynamic>> paymentTerms;
  final String? termsText;
  
  // Deal & Product association
  final String? pipelineId;
  final String? productId;
  final String productName;
  
  // Proposal state in module
  final bool hasFinalizedProposal;
  final String? finalizedPdfPath;
  final String? finalizedRefNo;
  final DateTime? finalizedAt;

  const DealQuotationItem({
    required this.id,
    required this.quotationNumber,
    required this.status,
    required this.revision,
    required this.orderDate,
    required this.createdAt,
    required this.updatedAt,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    this.customerGst,
    required this.salesmanName,
    required this.salesmanPhone,
    required this.subtotal,
    required this.supplementarySubtotal,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.grandTotal,
    required this.cgstRate,
    required this.sgstRate,
    required this.igstRate,
    required this.lineItems,
    required this.supplementaryTerms,
    required this.paymentTerms,
    this.termsText,
    this.pipelineId,
    this.productId,
    this.productName = 'Heat Pump',
    this.hasFinalizedProposal = false,
    this.finalizedPdfPath,
    this.finalizedRefNo,
    this.finalizedAt,
  });

  bool get isConfirmed => status.trim().toLowerCase() == 'confirmed';

  String get formattedDate {
    return DateFormat('dd/MM/yyyy').format(orderDate);
  }

  String get formattedGrandTotal {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(grandTotal);
  }

  double get totalGstAmount => cgstAmount + sgstAmount + igstAmount;

  factory DealQuotationItem.fromSupabase(
    Map<String, dynamic> row, {
    Map<String, dynamic>? proposalRecord,
  }) {
    final pipeline = row['sales_pipelines'] is Map
        ? Map<String, dynamic>.from(row['sales_pipelines'] as Map)
        : null;

    final customer = pipeline != null && pipeline['customers'] is Map
        ? Map<String, dynamic>.from(pipeline['customers'] as Map)
        : null;

    final product = pipeline != null && pipeline['products'] is Map
        ? Map<String, dynamic>.from(pipeline['products'] as Map)
        : null;

    final creatorProfile = pipeline != null && pipeline['profiles'] is Map
        ? Map<String, dynamic>.from(pipeline['profiles'] as Map)
        : null;

    // Customer details resolution
    String cName = (row['customer_name'] as String?)?.trim() ?? '';
    if (cName.isEmpty && customer != null) {
      cName = (customer['company_name'] as String?)?.trim() ??
          (customer['customer_name'] as String?)?.trim() ??
          (customer['contact_person'] as String?)?.trim() ??
          '';
    }
    if (cName.isEmpty) cName = 'Valued Customer';

    String cPhone = (row['customer_phone'] as String?)?.trim() ?? '';
    if (cPhone.isEmpty && customer != null) {
      cPhone = (customer['phone'] as String?)?.trim() ?? '';
    }

    String cAddr = (row['billing_address'] as String?)?.trim() ?? '';
    if (cAddr.isEmpty && customer != null) {
      cAddr = (customer['address'] as String?)?.trim() ?? '';
    }

    final cGst = customer != null ? (customer['gst_number'] as String?) : null;

    // Salesperson resolution
    String sName = (row['salesman'] as String?)?.trim() ?? '';
    if (sName.isEmpty && creatorProfile != null) {
      sName = (creatorProfile['full_name'] as String?)?.trim() ?? '';
    }
    if (sName.isEmpty) sName = 'Insiya Sales';

    String sPhone = '';
    if (creatorProfile != null) {
      sPhone = (creatorProfile['phone'] as String?)?.trim() ?? '';
    }

    // Dates
    final created = row['created_at'] != null
        ? DateTime.tryParse(row['created_at'] as String) ?? DateTime.now()
        : DateTime.now();
    final updated = row['updated_at'] != null
        ? DateTime.tryParse(row['updated_at'] as String) ?? created
        : created;
    final orderD = row['order_date'] != null
        ? DateTime.tryParse(row['order_date'] as String) ?? created
        : created;

    // Line items & supplementary
    final rawLines = row['line_items'];
    final List<Map<String, dynamic>> lines = [];
    if (rawLines is List) {
      for (final item in rawLines) {
        if (item is Map) lines.add(Map<String, dynamic>.from(item));
      }
    }

    final rawSupp = row['supplementary_terms'];
    final List<Map<String, dynamic>> supp = [];
    if (rawSupp is List) {
      for (final item in rawSupp) {
        if (item is Map) supp.add(Map<String, dynamic>.from(item));
      }
    }

    final rawPay = row['payment_terms'];
    final List<Map<String, dynamic>> pay = [];
    if (rawPay is List) {
      for (final item in rawPay) {
        if (item is Map) pay.add(Map<String, dynamic>.from(item));
      }
    }

    return DealQuotationItem(
      id: row['id'] as String? ?? '',
      quotationNumber: row['quotation_number'] as String? ?? '',
      status: row['status'] as String? ?? 'Draft',
      revision: (row['revision'] as num?)?.toInt() ?? 1,
      orderDate: orderD,
      createdAt: created,
      updatedAt: updated,
      customerName: cName,
      customerPhone: cPhone,
      customerAddress: cAddr,
      customerGst: cGst,
      salesmanName: sName,
      salesmanPhone: sPhone,
      subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0.0,
      supplementarySubtotal: (row['supplementary_subtotal'] as num?)?.toDouble() ?? 0.0,
      cgstAmount: (row['cgst_amount'] as num?)?.toDouble() ?? 0.0,
      sgstAmount: (row['sgst_amount'] as num?)?.toDouble() ?? 0.0,
      igstAmount: (row['igst_amount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (row['grand_total'] as num?)?.toDouble() ?? 0.0,
      cgstRate: (row['cgst_rate'] as num?)?.toDouble() ?? 0.0,
      sgstRate: (row['sgst_rate'] as num?)?.toDouble() ?? 0.0,
      igstRate: (row['igst_rate'] as num?)?.toDouble() ?? 0.0,
      lineItems: lines,
      supplementaryTerms: supp,
      paymentTerms: pay,
      termsText: row['terms_text'] as String?,
      pipelineId: pipeline != null ? pipeline['id'] as String? : (row['pipeline_id'] as String?),
      productId: product != null ? product['id'] as String? : null,
      productName: product != null ? (product['name'] as String? ?? 'Heat Pump') : 'Heat Pump',
      hasFinalizedProposal: proposalRecord != null,
      finalizedPdfPath: proposalRecord?['pdf_path'] as String?,
      finalizedRefNo: proposalRecord?['ref_no'] as String?,
      finalizedAt: proposalRecord?['finalized_at'] != null
          ? DateTime.tryParse(proposalRecord!['finalized_at'] as String)
          : null,
    );
  }

  DealQuotationItem copyWith({
    bool? hasFinalizedProposal,
    String? finalizedPdfPath,
    String? finalizedRefNo,
    DateTime? finalizedAt,
  }) {
    return DealQuotationItem(
      id: id,
      quotationNumber: quotationNumber,
      status: status,
      revision: revision,
      orderDate: orderDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      customerGst: customerGst,
      salesmanName: salesmanName,
      salesmanPhone: salesmanPhone,
      subtotal: subtotal,
      supplementarySubtotal: supplementarySubtotal,
      cgstAmount: cgstAmount,
      sgstAmount: sgstAmount,
      igstAmount: igstAmount,
      grandTotal: grandTotal,
      cgstRate: cgstRate,
      sgstRate: sgstRate,
      igstRate: igstRate,
      lineItems: lineItems,
      supplementaryTerms: supplementaryTerms,
      paymentTerms: paymentTerms,
      termsText: termsText,
      pipelineId: pipelineId,
      productId: productId,
      productName: productName,
      hasFinalizedProposal: hasFinalizedProposal ?? this.hasFinalizedProposal,
      finalizedPdfPath: finalizedPdfPath ?? this.finalizedPdfPath,
      finalizedRefNo: finalizedRefNo ?? this.finalizedRefNo,
      finalizedAt: finalizedAt ?? this.finalizedAt,
    );
  }
}
