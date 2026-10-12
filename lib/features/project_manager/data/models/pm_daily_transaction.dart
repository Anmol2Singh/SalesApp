enum PmEntryNature {
  purchase,
  sale,
  expense;

  static PmEntryNature fromString(String val) {
    switch (val.toLowerCase()) {
      case 'purchase': return PmEntryNature.purchase;
      case 'sale': return PmEntryNature.sale;
      case 'expense': return PmEntryNature.expense;
      default: return PmEntryNature.sale;
    }
  }

  String get dbValue {
    switch (this) {
      case PmEntryNature.purchase: return 'Purchase';
      case PmEntryNature.sale: return 'Sale';
      case PmEntryNature.expense: return 'Expense';
    }
  }

  String get displayName => dbValue;
}

enum PmTransactionFlow {
  credit,
  debit;

  static PmTransactionFlow fromString(String val) {
    return val.toLowerCase() == 'debit' ? PmTransactionFlow.debit : PmTransactionFlow.credit;
  }

  String get dbValue => name;
  String get displayName => name.toUpperCase();
}

class PmDailyTransaction {
  final String id;
  final String companyId;
  final int srNo;
  final DateTime date;
  final String firmName;
  final String partyName;
  final String paymentMode;
  final String transactionName;
  final PmEntryNature entryNature;
  final PmTransactionFlow type;
  final double debitAmount;
  final double creditAmount;
  final String? remark;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PmDailyTransaction({
    required this.id,
    this.companyId = 'insiya-solar',
    required this.srNo,
    required this.date,
    required this.firmName,
    required this.partyName,
    required this.paymentMode,
    required this.transactionName,
    required this.entryNature,
    required this.type,
    this.debitAmount = 0,
    this.creditAmount = 0,
    this.remark,
    required this.createdAt,
    this.updatedAt,
  });

  factory PmDailyTransaction.fromJson(Map<String, dynamic> json) {
    return PmDailyTransaction(
      id: json['id'] as String? ?? '',
      companyId: json['company_id'] as String? ?? 'insiya-solar',
      srNo: (json['sr_no'] as num?)?.toInt() ?? 1,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      firmName: json['firm_name'] as String? ?? '',
      partyName: json['party_name'] as String? ?? '',
      paymentMode: json['payment_mode'] as String? ?? 'Cash',
      transactionName: json['transaction_name'] as String? ?? '',
      entryNature: PmEntryNature.fromString(json['entry_nature'] as String? ?? 'Sale'),
      type: PmTransactionFlow.fromString(json['type'] as String? ?? 'credit'),
      debitAmount: (json['debit_amount'] as num?)?.toDouble() ?? 0.0,
      creditAmount: (json['credit_amount'] as num?)?.toDouble() ?? 0.0,
      remark: json['remark'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'company_id': companyId,
    'sr_no': srNo,
    'date': date.toIso8601String().split('T').first,
    'firm_name': firmName,
    'party_name': partyName,
    'payment_mode': paymentMode,
    'transaction_name': transactionName,
    'entry_nature': entryNature.dbValue,
    'type': type.dbValue,
    'debit_amount': debitAmount,
    'credit_amount': creditAmount,
    if (remark != null) 'remark': remark,
  };

  PmDailyTransaction copyWith({
    String? id,
    String? companyId,
    int? srNo,
    DateTime? date,
    String? firmName,
    String? partyName,
    String? paymentMode,
    String? transactionName,
    PmEntryNature? entryNature,
    PmTransactionFlow? type,
    double? debitAmount,
    double? creditAmount,
    String? remark,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PmDailyTransaction(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      srNo: srNo ?? this.srNo,
      date: date ?? this.date,
      firmName: firmName ?? this.firmName,
      partyName: partyName ?? this.partyName,
      paymentMode: paymentMode ?? this.paymentMode,
      transactionName: transactionName ?? this.transactionName,
      entryNature: entryNature ?? this.entryNature,
      type: type ?? this.type,
      debitAmount: debitAmount ?? this.debitAmount,
      creditAmount: creditAmount ?? this.creditAmount,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
