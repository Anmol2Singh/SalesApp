// lib/features/crm/data/models/prospect_model.dart

class Prospect {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final String? gst;
  final String? company;
  final String source;
  final String? notes;
  final String? convertedToLeadId;
  final String createdBy;
  final String? createdByName;
  final String? createdByRole;
  final String? assignedTo;
  final String? assignedByName;
  final bool reassignmentRequested;
  final String? reassignmentReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Prospect({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.gst,
    this.company,
    this.source = 'Manual',
    this.notes,
    this.convertedToLeadId,
    required this.createdBy,
    this.createdByName,
    this.createdByRole,
    this.assignedTo,
    this.assignedByName,
    this.reassignmentRequested = false,
    this.reassignmentReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Prospect.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    final assignee = json['assignee'] as Map<String, dynamic>?;

    final rawNotes = json['notes'] as String? ?? '';
    String? reason = json['reassignment_reason'] as String?;
    bool req = json['reassignment_requested'] == true;
    if (reason == null && rawNotes.contains('[REASSIGNMENT_REQUEST:')) {
      req = true;
      final start = rawNotes.indexOf('[REASSIGNMENT_REQUEST:') + '[REASSIGNMENT_REQUEST:'.length;
      final end = rawNotes.indexOf(']', start);
      reason = end > start ? rawNotes.substring(start, end).trim() : rawNotes.substring(start).trim();
    }

    return Prospect(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      address: json['address'] as String?,
      gst: json['gst'] as String?,
      company: json['company'] as String?,
      source: json['source'] as String? ?? 'Manual',
      notes: json['notes'] as String?,
      convertedToLeadId: json['converted_to_lead_id'] as String?,
      createdBy: json['created_by'] as String? ?? '',
      createdByName: creator?['full_name'] as String? ?? json['creator_name'] as String?,
      createdByRole: (creator?['primary_role'] ?? creator?['role'] ?? json['creator_role']) as String?,
      assignedTo: json['assigned_to'] as String?,
      assignedByName: assignee?['full_name'] as String? ?? json['assignee_name'] as String?,
      reassignmentRequested: req,
      reassignmentReason: reason,
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
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'gst': gst,
      'company': company,
      'source': source,
      if (notes != null) 'notes': notes,
      if (convertedToLeadId != null) 'converted_to_lead_id': convertedToLeadId,
      'created_by': createdBy,
      if (assignedTo != null) 'assigned_to': assignedTo,
    };
  }

  Prospect copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? gst,
    String? company,
    String? source,
    String? notes,
    String? convertedToLeadId,
    String? createdBy,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Prospect(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      gst: gst ?? this.gst,
      company: company ?? this.company,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      convertedToLeadId: convertedToLeadId ?? this.convertedToLeadId,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
