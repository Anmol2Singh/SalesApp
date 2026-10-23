// lib/features/crm/data/models/communication_model.dart

class Communication {
  final String id;
  final String leadId;
  final String type; // 'Call', 'WhatsApp', 'Email', 'Meeting', 'Note'
  final String summary;
  final String loggedBy;
  final String? loggedByName;
  final DateTime createdAt;

  const Communication({
    required this.id,
    required this.leadId,
    required this.type,
    required this.summary,
    required this.loggedBy,
    this.loggedByName,
    required this.createdAt,
  });

  factory Communication.fromJson(Map<String, dynamic> json) {
    String? name = json['logged_by_name'] as String?;
    if (name == null || name.isEmpty) {
      if (json['profiles'] is Map) {
        name = json['profiles']['full_name'] as String?;
      }
    }

    return Communication(
      id: json['id'] as String? ?? '',
      leadId: json['lead_id'] as String? ?? '',
      type: json['type'] as String? ?? 'Note',
      summary: json['summary'] as String? ?? '',
      loggedBy: json['logged_by'] as String? ?? '',
      loggedByName: name,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lead_id': leadId,
      'type': type,
      'summary': summary,
      'logged_by': loggedBy,
    };
  }
}
