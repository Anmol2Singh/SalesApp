// lib/core/models/service_visit.dart

class SparePartItem {
  final String partName;
  final double qty;
  final double unitPrice;
  final double total;

  const SparePartItem({
    required this.partName,
    required this.qty,
    required this.unitPrice,
    required this.total,
  });

  factory SparePartItem.fromJson(Map<String, dynamic> json) {
    final q = (json['qty'] as num? ?? 1).toDouble();
    final rate = (json['unit_price'] as num? ?? 0).toDouble();
    return SparePartItem(
      partName: json['part_name'] as String? ?? '',
      qty: q,
      unitPrice: rate,
      total: (json['total'] as num? ?? (q * rate)).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'part_name': partName,
    'qty': qty,
    'unit_price': unitPrice,
    'total': total,
  };
}

class ServiceVisit {
  final String id;
  final String? contractId;
  final String? pipelineId;
  final String customerId;
  final DateTime visitDate;
  final String? technicianName;
  final String? serviceNotes;
  final List<SparePartItem> items;
  final double laborCharge;
  final double totalCost;
  final String? receiptPdfUrl;
  final DateTime createdAt;

  const ServiceVisit({
    required this.id,
    this.contractId,
    this.pipelineId,
    required this.customerId,
    required this.visitDate,
    this.technicianName,
    this.serviceNotes,
    required this.items,
    this.laborCharge = 0.0,
    required this.totalCost,
    this.receiptPdfUrl,
    required this.createdAt,
  });

  factory ServiceVisit.fromJson(Map<String, dynamic> json) {
    return ServiceVisit(
      id: json['id'] as String? ?? '',
      contractId: json['contract_id'] as String?,
      pipelineId: json['pipeline_id'] as String?,
      customerId: json['customer_id'] as String? ?? '',
      visitDate: json['visit_date'] != null
          ? (DateTime.tryParse(json['visit_date'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      technicianName: json['technician_name'] as String?,
      serviceNotes: json['service_notes'] as String?,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => SparePartItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      laborCharge: (json['labor_charge'] as num? ?? 0).toDouble(),
      totalCost: (json['total_cost'] as num? ?? 0).toDouble(),
      receiptPdfUrl: json['receipt_pdf_url'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'contract_id': contractId,
    'pipeline_id': pipelineId,
    'customer_id': customerId,
    'visit_date': visitDate.toIso8601String(),
    'technician_name': technicianName,
    'service_notes': serviceNotes,
    'items': items.map((i) => i.toJson()).toList(),
    'labor_charge': laborCharge,
    'total_cost': totalCost,
    'receipt_pdf_url': receiptPdfUrl,
  };
}
