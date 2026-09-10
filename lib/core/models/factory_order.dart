// lib/core/models/factory_order.dart

enum FactoryOrderStatus {
  pending,
  inProduction,
  completed;

  static FactoryOrderStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return FactoryOrderStatus.pending;
      case 'in_production':
        return FactoryOrderStatus.inProduction;
      case 'completed':
        return FactoryOrderStatus.completed;
      default:
        return FactoryOrderStatus.pending;
    }
  }

  String get dbValue {
    switch (this) {
      case FactoryOrderStatus.pending:
        return 'pending';
      case FactoryOrderStatus.inProduction:
        return 'in_production';
      case FactoryOrderStatus.completed:
        return 'completed';
    }
  }

  String get displayName {
    switch (this) {
      case FactoryOrderStatus.pending:
        return 'Pending';
      case FactoryOrderStatus.inProduction:
        return 'In Production';
      case FactoryOrderStatus.completed:
        return 'Completed';
    }
  }
}

class FactoryOrderItem {
  final String itemName;
  final double qty;
  final String? remarks;

  const FactoryOrderItem({
    required this.itemName,
    required this.qty,
    this.remarks,
  });

  factory FactoryOrderItem.fromJson(Map<String, dynamic> json) {
    return FactoryOrderItem(
      itemName: json['item_name'] as String? ?? json['description'] as String? ?? '',
      qty: (json['qty'] as num? ?? 0).toDouble(),
      remarks: json['remarks'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'item_name': itemName,
    'qty': qty,
    'remarks': remarks,
  };
}

class FactoryOrder {
  final String id;
  final String pipelineId;
  final String orderNumber;
  final Map<String, dynamic> productionSpecs;
  final List<FactoryOrderItem> items;
  final DateTime? expectedCompletionDate;
  final String? assignedFactoryStaff;
  final String? pdfUrl;
  final FactoryOrderStatus status;
  final String? factoryNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FactoryOrder({
    required this.id,
    required this.pipelineId,
    required this.orderNumber,
    required this.productionSpecs,
    required this.items,
    this.expectedCompletionDate,
    this.assignedFactoryStaff,
    this.pdfUrl,
    required this.status,
    this.factoryNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FactoryOrder.fromJson(Map<String, dynamic> json) {
    return FactoryOrder(
      id: json['id'] as String? ?? '',
      pipelineId: json['pipeline_id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      productionSpecs: Map<String, dynamic>.from(
        json['production_specs'] as Map<String, dynamic>? ?? {},
      ),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => FactoryOrderItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      expectedCompletionDate: json['expected_completion_date'] != null
          ? DateTime.tryParse(json['expected_completion_date'] as String? ?? '')
          : null,
      assignedFactoryStaff: json['assigned_factory_staff'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      status: FactoryOrderStatus.fromString(json['status'] as String? ?? 'pending'),
      factoryNotes: json['factory_notes'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
    );
  }

  bool get isCompleted => status == FactoryOrderStatus.completed;
  bool get hasPdf => pdfUrl != null && pdfUrl!.isNotEmpty;
}
