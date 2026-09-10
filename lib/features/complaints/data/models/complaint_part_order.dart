// lib/features/complaints/data/models/complaint_part_order.dart

class ComplaintPartOrder {
  final String id;
  final String complaintId;
  final String? customerId;
  final String? customerName;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final bool isWarranty;
  final String paymentStatus; // 'pending', 'paid', 'not_required'
  final DateTime? paidAt;
  final String? paymentReference;
  final DateTime createdAt;
  final String? createdBy;

  ComplaintPartOrder({
    required this.id,
    required this.complaintId,
    this.customerId,
    this.customerName,
    required this.items,
    required this.totalAmount,
    required this.isWarranty,
    required this.paymentStatus,
    this.paidAt,
    this.paymentReference,
    required this.createdAt,
    this.createdBy,
  });

  factory ComplaintPartOrder.fromJson(Map<String, dynamic> json) {
    return ComplaintPartOrder(
      id: json['id'] as String,
      complaintId: json['complaint_id'] as String,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String?,
      items: (json['items'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      isWarranty: json['is_warranty'] as bool? ?? false,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'] as String) : null,
      paymentReference: json['payment_reference'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now() : DateTime.now(),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'complaint_id': complaintId,
      'customer_id': customerId,
      'customer_name': customerName,
      'items': items,
      'total_amount': totalAmount,
      'is_warranty': isWarranty,
      'payment_status': paymentStatus,
      'paid_at': paidAt?.toIso8601String(),
      'payment_reference': paymentReference,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}
