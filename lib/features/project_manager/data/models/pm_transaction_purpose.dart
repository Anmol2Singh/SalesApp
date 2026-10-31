class PmTransactionPurpose {
  final String id;
  final String name;
  final bool isActive;
  final int sortOrder;

  const PmTransactionPurpose({
    required this.id,
    required this.name,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory PmTransactionPurpose.fromJson(Map<String, dynamic> json) {
    return PmTransactionPurpose(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'name': name,
    'is_active': isActive,
    'sort_order': sortOrder,
  };

  PmTransactionPurpose copyWith({
    String? id,
    String? name,
    bool? isActive,
    int? sortOrder,
  }) {
    return PmTransactionPurpose(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

