// lib/core/models/warranty_card.dart

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

  factory WarrantyCard.fromJson(Map<String, dynamic> json) {
    return WarrantyCard(
      id: json['id'] as String? ?? '',
      pipelineId: json['pipeline_id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      warrantyNumber: json['warranty_number'] as String? ?? json['invoice_number'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      amcDetails: json['amc_details'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerEmail: json['customer_email'] as String?,
      warrantyYears: json['warranty_years'] as int? ?? 1,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String? ?? '')
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String? ?? '')
          : null,
      isActivated: json['is_activated'] as bool? ?? false,
      activatedBy: json['activated_by'] as String?,
      activatedAt: json['activated_at'] != null
          ? DateTime.tryParse(json['activated_at'] as String? ?? '')
          : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now())
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
