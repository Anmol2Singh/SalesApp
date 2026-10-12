class PmWorkRemark {
  final String id;
  final String projectId;
  final int srNo;
  final DateTime date;
  final String? remark;
  final DateTime createdAt;

  const PmWorkRemark({
    required this.id,
    required this.projectId,
    required this.srNo,
    required this.date,
    this.remark,
    required this.createdAt,
  });

  factory PmWorkRemark.fromJson(Map<String, dynamic> json) {
    return PmWorkRemark(
      id: json['id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      srNo: (json['sr_no'] as num?)?.toInt() ?? 1,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      remark: json['remark'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'sr_no': srNo,
    'date': date.toIso8601String().split('T').first,
    if (remark != null) 'remark': remark,
  };

  PmWorkRemark copyWith({
    String? id,
    String? projectId,
    int? srNo,
    DateTime? date,
    String? remark,
    DateTime? createdAt,
  }) {
    return PmWorkRemark(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      srNo: srNo ?? this.srNo,
      date: date ?? this.date,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
