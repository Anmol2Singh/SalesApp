class PmCallingRecord {
  final String id;
  final String? projectId;
  final String? purchaseId;
  final int srNo;
  final DateTime date;
  final String? description;
  final DateTime createdAt;

  const PmCallingRecord({
    required this.id,
    this.projectId,
    this.purchaseId,
    this.srNo = 1,
    required this.date,
    this.description,
    required this.createdAt,
  });

  factory PmCallingRecord.fromJson(Map<String, dynamic> json) {
    return PmCallingRecord(
      id: json['id'] as String? ?? '',
      projectId: json['project_id'] as String?,
      purchaseId: json['purchase_id'] as String?,
      srNo: (json['sr_no'] as num?)?.toInt() ?? 1,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (projectId != null) 'project_id': projectId,
    if (purchaseId != null) 'purchase_id': purchaseId,
    'sr_no': srNo,
    'date': date.toIso8601String().split('T').first,
    if (description != null) 'description': description,
  };

  PmCallingRecord copyWith({
    String? id,
    String? projectId,
    String? purchaseId,
    int? srNo,
    DateTime? date,
    String? description,
    DateTime? createdAt,
  }) {
    return PmCallingRecord(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      purchaseId: purchaseId ?? this.purchaseId,
      srNo: srNo ?? this.srNo,
      date: date ?? this.date,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
