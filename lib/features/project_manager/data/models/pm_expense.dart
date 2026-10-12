class PmExpense {
  final String id;
  final String projectId;
  final int srNo;
  final DateTime date;
  final String? particular;
  final double expense;
  final DateTime createdAt;

  const PmExpense({
    required this.id,
    required this.projectId,
    required this.srNo,
    required this.date,
    this.particular,
    this.expense = 0,
    required this.createdAt,
  });

  factory PmExpense.fromJson(Map<String, dynamic> json) {
    return PmExpense(
      id: json['id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      srNo: (json['sr_no'] as num?)?.toInt() ?? 1,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      particular: json['particular'] as String?,
      expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'sr_no': srNo,
    'date': date.toIso8601String().split('T').first,
    if (particular != null) 'particular': particular,
    'expense': expense,
  };

  PmExpense copyWith({
    String? id,
    String? projectId,
    int? srNo,
    DateTime? date,
    String? particular,
    double? expense,
    DateTime? createdAt,
  }) {
    return PmExpense(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      srNo: srNo ?? this.srNo,
      date: date ?? this.date,
      particular: particular ?? this.particular,
      expense: expense ?? this.expense,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
