// lib/features/complaints/data/models/complaint_model.dart

class Complaint {
  final String id;
  final String ticketNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String? productName;
  final bool hasActiveAmc;
  final String amcExpiry;
  final String priority; // High Priority, Medium Priority, Low Priority
  final String title;
  final String description;
  final String status; // pending, assigned, in_progress, resolved, closed
  final String? technicianId;
  final String? technicianName;
  final String? technicianAvatarUrl;
  final String tatRemaining;
  final String? beforeImageUrl;
  final String? afterImageUrl;
  final String? customerSignatureUrl;
  final String? technicianSignatureUrl;
  final String source; // 'staff' or 'customer'
  final String? notes;
  final DateTime createdAt;

  Complaint({
    required this.id,
    required this.ticketNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    this.productName,
    this.hasActiveAmc = false,
    this.amcExpiry = '',
    required this.priority,
    required this.title,
    required this.description,
    this.status = 'pending',
    this.technicianId,
    this.technicianName,
    this.technicianAvatarUrl,
    required this.tatRemaining,
    this.beforeImageUrl,
    this.afterImageUrl,
    this.customerSignatureUrl,
    this.technicianSignatureUrl,
    this.source = 'staff',
    this.notes,
    required this.createdAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] ?? '',
      ticketNumber: json['ticket_number'] ?? json['ticketNumber'] ?? '',
      customerId: json['customer_id'] ?? json['customerId'] ?? '',
      customerName: json['customer_name'] ?? json['customerName'] ?? 'Unknown Customer',
      customerPhone: json['customer_phone'] ?? json['customerPhone'] ?? '',
      customerAddress: json['customer_address'] ?? json['customerAddress'] ?? '',
      productName: json['product_name'] ?? json['productName'],
      hasActiveAmc: json['has_active_amc'] ?? json['hasActiveAmc'] ?? false,
      amcExpiry: json['amc_expiry'] ?? json['amcExpiry'] ?? '',
      priority: json['priority'] ?? 'Medium Priority',
      title: json['title'] ?? 'Service Complaint',
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      technicianId: json['technician_id'] ?? json['technicianId'],
      technicianName: json['technician_name'] ?? json['technicianName'],
      technicianAvatarUrl: json['technician_avatar_url'] ?? json['technicianAvatarUrl'],
      tatRemaining: json['tat_remaining'] ?? json['tatRemaining'] ?? '24h',
      beforeImageUrl: json['before_image_url'] ?? json['beforeImageUrl'],
      afterImageUrl: json['after_image_url'] ?? json['afterImageUrl'],
      customerSignatureUrl: json['customer_signature_url'] ?? json['customerSignatureUrl'],
      technicianSignatureUrl: json['technician_signature_url'] ?? json['technicianSignatureUrl'],
      source: json['source'] as String? ?? 'staff',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_number': ticketNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'product_name': productName,
      'has_active_amc': hasActiveAmc,
      'amc_expiry': amcExpiry,
      'priority': priority,
      'title': title,
      'description': description,
      'status': status,
      'technician_id': technicianId,
      'technician_name': technicianName,
      'technician_avatar_url': technicianAvatarUrl,
      'tat_remaining': tatRemaining,
      'before_image_url': beforeImageUrl,
      'after_image_url': afterImageUrl,
      'customer_signature_url': customerSignatureUrl,
      'technician_signature_url': technicianSignatureUrl,
      'source': source,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Complaint copyWith({
    String? id,
    String? ticketNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? productName,
    bool? hasActiveAmc,
    String? amcExpiry,
    String? priority,
    String? title,
    String? description,
    String? status,
    String? technicianId,
    String? technicianName,
    String? technicianAvatarUrl,
    String? tatRemaining,
    String? beforeImageUrl,
    String? afterImageUrl,
    String? customerSignatureUrl,
    String? technicianSignatureUrl,
    String? source,
    String? notes,
    DateTime? createdAt,
  }) {
    return Complaint(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      productName: productName ?? this.productName,
      hasActiveAmc: hasActiveAmc ?? this.hasActiveAmc,
      amcExpiry: amcExpiry ?? this.amcExpiry,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      technicianAvatarUrl: technicianAvatarUrl ?? this.technicianAvatarUrl,
      tatRemaining: tatRemaining ?? this.tatRemaining,
      beforeImageUrl: beforeImageUrl ?? this.beforeImageUrl,
      afterImageUrl: afterImageUrl ?? this.afterImageUrl,
      customerSignatureUrl: customerSignatureUrl ?? this.customerSignatureUrl,
      technicianSignatureUrl: technicianSignatureUrl ?? this.technicianSignatureUrl,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class TechnicianInfo {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String avatarUrl;
  final String status; // Available, On Job, Offline
  final String distance;
  final int activeTasksCount;
  final double rating;

  TechnicianInfo({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.avatarUrl,
    required this.status,
    required this.distance,
    required this.activeTasksCount,
    required this.rating,
  });
}
