// lib/core/models/customer.dart

class Customer {
  final String id;
  final String companyName;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? gstNumber;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? notes;
  final String? salesmanName;
  final String? assignedTo;
  final String? assignedToName;
  final String? convertedBy;
  final String? convertedByName;
  final bool reassignmentRequested;
  final String? reassignmentReason;

  // Optional: loaded with pipelines for detail view
  final List<SalesPipelineSummary>? pipelines;

  const Customer({
    required this.id,
    required this.companyName,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.gstNumber,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.salesmanName,
    this.assignedTo,
    this.assignedToName,
    this.convertedBy,
    this.convertedByName,
    this.reassignmentRequested = false,
    this.reassignmentReason,
    this.pipelines,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    List<SalesPipelineSummary>? pipelines;
    if (json['sales_pipelines'] != null) {
      pipelines = (json['sales_pipelines'] as List<dynamic>)
          .map((p) => SalesPipelineSummary.fromJson(p as Map<String, dynamic>))
          .toList();
    }
    final name = (json['customer_name'] as String?)?.isNotEmpty == true
        ? json['customer_name'] as String
        : ((json['company_name'] as String?)?.isNotEmpty == true
            ? json['company_name'] as String
            : (json['contact_person'] as String? ?? 'Valued Customer'));

    final rawNotes = json['notes'] as String? ?? '';
    String? reason = json['reassignment_reason'] as String?;
    bool req = json['reassignment_requested'] == true;
    if (reason == null && rawNotes.contains('[REASSIGNMENT_REQUEST:')) {
      req = true;
      final start = rawNotes.indexOf('[REASSIGNMENT_REQUEST:') + '[REASSIGNMENT_REQUEST:'.length;
      final end = rawNotes.indexOf(']', start);
      reason = end > start ? rawNotes.substring(start, end).trim() : rawNotes.substring(start).trim();
    }

    return Customer(
      id: json['id'] as String? ?? '',
      companyName: name,
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      gstNumber: json['gst_number'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String? ?? '')
          : null,
      salesmanName: (json['profiles'] is Map)
          ? (json['profiles'] as Map)['full_name'] as String?
          : (json['profiles'] is List && (json['profiles'] as List).isNotEmpty)
              ? (json['profiles'] as List).first['full_name'] as String?
              : json['assigned_to_name'] as String?,
      assignedTo: json['assigned_to'] as String?,
      assignedToName: json['assigned_to_name'] as String?,
      convertedBy: json['converted_by'] as String?,
      convertedByName: json['converted_by_name'] as String?,
      reassignmentRequested: req,
      reassignmentReason: reason,
      pipelines: pipelines,
    );
  }

  String get customerName => companyName;

  Map<String, dynamic> toJson() => {
    'customer_name': companyName,
    'company_name': companyName,
    'contact_person': contactPerson,
    'phone': phone,
    'email': email,
    'address': address,
    'gst_number': gstNumber,
    if (notes != null) 'notes': notes,
    'created_by': createdBy,
    if (assignedTo != null) 'assigned_to': assignedTo,
    if (assignedToName != null) 'assigned_to_name': assignedToName,
    if (convertedBy != null) 'converted_by': convertedBy,
    if (convertedByName != null) 'converted_by_name': convertedByName,
    'reassignment_requested': reassignmentRequested,
    if (reassignmentReason != null) 'reassignment_reason': reassignmentReason,
  };

  Customer copyWith({
    String? companyName,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? gstNumber,
    String? notes,
    String? salesmanName,
    String? assignedTo,
    String? assignedToName,
    String? convertedBy,
    String? convertedByName,
    bool? reassignmentRequested,
    String? reassignmentReason,
    List<SalesPipelineSummary>? pipelines,
  }) {
    return Customer(
      id: id,
      companyName: companyName ?? this.companyName,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      gstNumber: gstNumber ?? this.gstNumber,
      notes: notes ?? this.notes,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      salesmanName: salesmanName ?? this.salesmanName,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      convertedBy: convertedBy ?? this.convertedBy,
      convertedByName: convertedByName ?? this.convertedByName,
      reassignmentRequested: reassignmentRequested ?? this.reassignmentRequested,
      reassignmentReason: reassignmentReason ?? this.reassignmentReason,
      pipelines: pipelines ?? this.pipelines,
    );
  }
}

// Lightweight summary used in lists
class SalesPipelineSummary {
  final String id;
  final String productId;
  final String productName;
  final PipelineStep currentStep;
  final PipelineStatus status;
  final DateTime createdAt;
  final String createdBy;

  const SalesPipelineSummary({
    required this.id,
    required this.productId,
    required this.productName,
    required this.currentStep,
    required this.status,
    required this.createdAt,
    required this.createdBy,
  });

  factory SalesPipelineSummary.fromJson(Map<String, dynamic> json) {
    return SalesPipelineSummary(
      id: json['id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      productName: (json['products'] is Map)
          ? (json['products'] as Map)['name'] as String? ?? 'Unknown Product'
          : (json['products'] is List && (json['products'] as List).isNotEmpty)
              ? (json['products'] as List).first['name'] as String? ?? 'Unknown Product'
              : 'Unknown Product',
      currentStep: PipelineStep.fromString(json['current_step'] as String? ?? 'quotation'),
      status: PipelineStatus.fromString(json['status'] as String? ?? 'in_progress'),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      createdBy: json['created_by'] as String? ?? '',
    );
  }
}

enum PipelineStep {
  quotation,
  salesOrder,
  boq,
  factoryOrder,
  purchaseOrder,
  completed;

  static PipelineStep fromString(String value) {
    switch (value) {
      case 'quotation':
        return PipelineStep.quotation;
      case 'sales_order':
      case 'salesOrder':
        return PipelineStep.salesOrder;
      case 'boq':
        return PipelineStep.boq;
      case 'factory_order':
      case 'factoryOrder':
        return PipelineStep.factoryOrder;
      case 'purchase_order':
      case 'purchaseOrder':
        return PipelineStep.purchaseOrder;
      case 'completed':
        return PipelineStep.completed;
      default:
        return PipelineStep.quotation;
    }
  }

  String get dbValue {
    switch (this) {
      case PipelineStep.quotation:
        return 'quotation';
      case PipelineStep.salesOrder:
        return 'sales_order';
      case PipelineStep.boq:
        return 'boq';
      case PipelineStep.factoryOrder:
        return 'factory_order';
      case PipelineStep.purchaseOrder:
        return 'purchase_order';
      case PipelineStep.completed:
        return 'completed';
    }
  }

  String get displayName {
    switch (this) {
      case PipelineStep.quotation:
        return 'Quotation';
      case PipelineStep.salesOrder:
        return 'Sales Order';
      case PipelineStep.boq:
        return 'BOQ';
      case PipelineStep.factoryOrder:
        return 'Factory Order';
      case PipelineStep.purchaseOrder:
        return 'Material Requisition';
      case PipelineStep.completed:
        return 'Completed';
    }
  }

  int get stepIndex {
    switch (this) {
      case PipelineStep.quotation:
        return 0;
      case PipelineStep.salesOrder:
        return 1;
      case PipelineStep.boq:
        return 2;
      case PipelineStep.factoryOrder:
        return 3;
      case PipelineStep.purchaseOrder:
        return 4;
      case PipelineStep.completed:
        return 5;
    }
  }
}

enum PipelineStatus {
  inProgress,
  completed,
  onHold,
  cancelled,
  suspended;

  static PipelineStatus fromString(String value) {
    switch (value) {
      case 'in_progress':
        return PipelineStatus.inProgress;
      case 'completed':
        return PipelineStatus.completed;
      case 'on_hold':
        return PipelineStatus.onHold;
      case 'cancelled':
        return PipelineStatus.cancelled;
      case 'suspended':
        return PipelineStatus.suspended;
      default:
        return PipelineStatus.inProgress;
    }
  }

  String get dbValue {
    switch (this) {
      case PipelineStatus.inProgress:
        return 'in_progress';
      case PipelineStatus.completed:
        return 'completed';
      case PipelineStatus.onHold:
        return 'on_hold';
      case PipelineStatus.cancelled:
        return 'cancelled';
      case PipelineStatus.suspended:
        return 'suspended';
    }
  }

  String get displayName {
    switch (this) {
      case PipelineStatus.inProgress:
        return 'In Progress';
      case PipelineStatus.completed:
        return 'Completed';
      case PipelineStatus.onHold:
        return 'On Hold';
      case PipelineStatus.cancelled:
        return 'Cancelled';
      case PipelineStatus.suspended:
        return 'Suspended';
    }
  }
}
