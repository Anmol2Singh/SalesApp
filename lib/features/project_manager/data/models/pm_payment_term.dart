class PmPaymentTerm {
  final String id;
  final String projectId;
  final String paymentTerm;
  final double termPercentage;
  final double amount;
  final double receivedAmount;
  final double pendingAmount;
  final String? remark;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PmPaymentTerm({
    required this.id,
    required this.projectId,
    required this.paymentTerm,
    this.termPercentage = 0,
    this.amount = 0,
    this.receivedAmount = 0,
    this.pendingAmount = 0,
    this.remark,
    required this.createdAt,
    this.updatedAt,
  });

  factory PmPaymentTerm.fromJson(Map<String, dynamic> json) {
    return PmPaymentTerm(
      id: json['id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      paymentTerm: json['payment_term'] as String? ?? '',
      termPercentage: (json['term_percentage'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      receivedAmount: (json['received_amount'] as num?)?.toDouble() ?? 0.0,
      pendingAmount: (json['pending_amount'] as num?)?.toDouble() ?? 0.0,
      remark: json['remark'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'payment_term': paymentTerm,
    'term_percentage': termPercentage,
    'amount': amount,
    'received_amount': receivedAmount,
    'pending_amount': pendingAmount,
    if (remark != null) 'remark': remark,
  };

  PmPaymentTerm copyWith({
    String? id,
    String? projectId,
    String? paymentTerm,
    double? termPercentage,
    double? amount,
    double? receivedAmount,
    double? pendingAmount,
    String? remark,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PmPaymentTerm(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      paymentTerm: paymentTerm ?? this.paymentTerm,
      termPercentage: termPercentage ?? this.termPercentage,
      amount: amount ?? this.amount,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
