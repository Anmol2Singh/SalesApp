// lib/features/crm/data/models/lead_model.dart

class Lead {
  final String id;
  final String? prospectId;
  final String? prospectName;
  final String? contactPhone;
  final String productName;
  final double estimatedValue;
  final DateTime? expectedDate;
  final String status; // 'New', 'In Progress', 'Negotiating', 'Won', 'Lost'
  final String? notes;
  final String? convertedToCustomerId;
  final String? convertedBy;
  final String? convertedByName;
  final String createdBy;
  final String? assignedTo;
  final String? assignedByName;
  final bool reassignmentRequested;
  final String? reassignmentReason;
  final String? capacity;
  final List<dynamic>? components;
  final DateTime? reminderDate;
  final String? reminderNote;
  final List<Map<String, dynamic>> reminders;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Lead({
    required this.id,
    this.prospectId,
    this.prospectName,
    this.contactPhone,
    required this.productName,
    this.estimatedValue = 0.0,
    this.expectedDate,
    this.status = 'New',
    this.notes,
    this.convertedToCustomerId,
    this.convertedBy,
    this.convertedByName,
    required this.createdBy,
    this.assignedTo,
    this.assignedByName,
    this.reassignmentRequested = false,
    this.reassignmentReason,
    this.capacity,
    this.components,
    this.reminderDate,
    this.reminderNote,
    this.reminders = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['notes'] as String? ?? '';
    String? reason = json['reassignment_reason'] as String?;
    bool req = json['reassignment_requested'] == true;
    if (reason == null && rawNotes.contains('[REASSIGNMENT_REQUEST:')) {
      req = true;
      final start = rawNotes.indexOf('[REASSIGNMENT_REQUEST:') + '[REASSIGNMENT_REQUEST:'.length;
      final end = rawNotes.indexOf(']', start);
      reason = end > start ? rawNotes.substring(start, end).trim() : rawNotes.substring(start).trim();
    }

    return Lead(
      id: json['id'] as String? ?? '',
      prospectId: json['prospect_id'] as String?,
      prospectName: json['prospect_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      productName: json['product_name'] as String? ?? 'Solar System',
      estimatedValue: (json['estimated_value'] is num)
          ? (json['estimated_value'] as num).toDouble()
          : (double.tryParse(json['estimated_value']?.toString() ?? '0') ?? 0.0),
      expectedDate: json['expected_date'] != null
          ? DateTime.tryParse(json['expected_date'].toString())
          : null,
      status: json['status'] as String? ?? 'New',
      notes: json['notes'] as String?,
      convertedToCustomerId: json['converted_to_customer_id'] as String?,
      convertedBy: json['converted_by'] as String?,
      convertedByName: json['converted_by_name'] as String?,
      createdBy: json['created_by'] as String? ?? '',
      assignedTo: json['assigned_to'] as String?,
      assignedByName: (json['assignee'] as Map<String, dynamic>?)?['full_name'] as String? ?? json['assignee_name'] as String?,
      reassignmentRequested: req,
      reassignmentReason: reason,
      capacity: json['capacity'] as String?,
      components: json['components'] as List<dynamic>?,
      reminderDate: json['reminder_date'] != null
          ? DateTime.tryParse(json['reminder_date'].toString())
          : null,
      reminderNote: json['reminder_note'] as String?,
      reminders: (json['reminders'] is List)
          ? (json['reminders'] as List)
              .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
              .toList()
          : [],
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (prospectId != null) 'prospect_id': prospectId,
      if (prospectName != null) 'prospect_name': prospectName,
      if (contactPhone != null) 'contact_phone': contactPhone,
      'product_name': productName,
      'estimated_value': estimatedValue,
      if (expectedDate != null) 'expected_date': expectedDate!.toIso8601String(),
      'status': status,
      if (notes != null) 'notes': notes,
      if (convertedToCustomerId != null) 'converted_to_customer_id': convertedToCustomerId,
      if (convertedBy != null) 'converted_by': convertedBy,
      if (convertedByName != null) 'converted_by_name': convertedByName,
      'created_by': createdBy,
      if (assignedTo != null) 'assigned_to': assignedTo,
      if (capacity != null) 'capacity': capacity,
      if (components != null) 'components': components,
      if (reminderDate != null) 'reminder_date': reminderDate!.toIso8601String(),
      if (reminderNote != null) 'reminder_note': reminderNote,
      'reminders': reminders,
    };
  }

  Lead copyWith({
    String? id,
    String? prospectId,
    String? prospectName,
    String? contactPhone,
    String? productName,
    double? estimatedValue,
    DateTime? expectedDate,
    String? status,
    String? notes,
    String? convertedToCustomerId,
    String? convertedBy,
    String? convertedByName,
    String? createdBy,
    String? assignedTo,
    String? assignedByName,
    String? capacity,
    List<dynamic>? components,
    DateTime? reminderDate,
    String? reminderNote,
    List<Map<String, dynamic>>? reminders,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lead(
      id: id ?? this.id,
      prospectId: prospectId ?? this.prospectId,
      prospectName: prospectName ?? this.prospectName,
      contactPhone: contactPhone ?? this.contactPhone,
      productName: productName ?? this.productName,
      estimatedValue: estimatedValue ?? this.estimatedValue,
      expectedDate: expectedDate ?? this.expectedDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      convertedToCustomerId: convertedToCustomerId ?? this.convertedToCustomerId,
      convertedBy: convertedBy ?? this.convertedBy,
      convertedByName: convertedByName ?? this.convertedByName,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedByName: assignedByName ?? this.assignedByName,
      capacity: capacity ?? this.capacity,
      components: components ?? this.components,
      reminderDate: reminderDate ?? this.reminderDate,
      reminderNote: reminderNote ?? this.reminderNote,
      reminders: reminders ?? this.reminders,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
