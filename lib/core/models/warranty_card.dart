// lib/core/models/warranty_card.dart

import 'dart:convert';

class ProductWarrantyItem {
  final String productName;
  final int warrantyYears;
  final int warrantyMonths;
  final DateTime? startDate;
  final DateTime? endDate;

  ProductWarrantyItem({
    required this.productName,
    required this.warrantyYears,
    this.warrantyMonths = 12,
    this.startDate,
    this.endDate,
  });

  factory ProductWarrantyItem.fromJson(Map<String, dynamic> json) {
    return ProductWarrantyItem(
      productName: json['name']?.toString() ?? json['product_name']?.toString() ?? 'Product',
      warrantyYears: (json['warranty_years'] as num?)?.toInt() ?? 1,
      warrantyMonths: (json['warranty_months'] as num?)?.toInt() ?? 12,
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'].toString()) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': productName,
    'warranty_years': warrantyYears,
    'warranty_months': warrantyMonths,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
  };
}

class WarrantyCard {
  final String id;
  final String pipelineId;
  final String customerId;
  final String? warrantyNumber;
  final String? invoiceNumber;
  final String? amcDetails;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final int warrantyYears;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActivated;
  final String? activatedBy;
  final DateTime? activatedAt;
  final DateTime createdAt;

  const WarrantyCard({
    required this.id,
    required this.pipelineId,
    required this.customerId,
    this.warrantyNumber,
    this.invoiceNumber,
    this.amcDetails,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.warrantyYears = 1,
    this.startDate,
    this.endDate,
    this.isActivated = false,
    this.activatedBy,
    this.activatedAt,
    required this.createdAt,
  });

  List<ProductWarrantyItem> get productWarranties {
    if (amcDetails != null && (amcDetails!.trim().startsWith('{') || amcDetails!.trim().startsWith('['))) {
      try {
        final decoded = jsonDecode(amcDetails!);
        if (decoded is List) {
          return decoded.map((e) => ProductWarrantyItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        } else if (decoded is Map && decoded['products'] is List) {
          return (decoded['products'] as List)
              .map((e) => ProductWarrantyItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } catch (_) {}
    }
    return [
      ProductWarrantyItem(
        productName: 'Equipment / System',
        warrantyYears: warrantyYears,
        warrantyMonths: warrantyYears * 12,
        startDate: startDate,
        endDate: endDate,
      ),
    ];
  }

  factory WarrantyCard.fromJson(Map<String, dynamic> json) {
    String? amcDetailsStr;
    if (json['amc_details'] != null) {
      if (json['amc_details'] is String) {
        amcDetailsStr = json['amc_details'] as String;
      } else {
        try {
          amcDetailsStr = jsonEncode(json['amc_details']);
        } catch (_) {
          amcDetailsStr = json['amc_details'].toString();
        }
      }
    }

    return WarrantyCard(
      id: json['id']?.toString() ?? '',
      pipelineId: json['pipeline_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      warrantyNumber: json['warranty_number']?.toString() ?? json['invoice_number']?.toString(),
      invoiceNumber: json['invoice_number']?.toString(),
      amcDetails: amcDetailsStr,
      customerName: json['customer_name']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
      customerEmail: json['customer_email']?.toString(),
      warrantyYears: (json['warranty_years'] as num?)?.toInt() ?? 1,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString())
          : null,
      isActivated: json['is_activated'] == true || json['is_activated'] == 'true' || json['is_activated'] == 1,
      activatedBy: json['activated_by']?.toString(),
      activatedAt: json['activated_at'] != null
          ? DateTime.tryParse(json['activated_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'pipeline_id': pipelineId,
    'customer_id': customerId,
    'warranty_number': warrantyNumber,
    'invoice_number': invoiceNumber,
    'amc_details': amcDetails,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'customer_email': customerEmail,
    'warranty_years': warrantyYears,
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'is_activated': isActivated,
    'activated_by': activatedBy,
    'activated_at': activatedAt?.toIso8601String(),
  };
}
