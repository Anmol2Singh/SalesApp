class PmLedgerEntry {
  final String id;
  final String projectId;
  final int srNo;
  final DateTime date;
  final String? paymentType;
  final String? referenceNumber;
  final String? invoiceNo;
  final String? particulars;
  final bool billSubmitted;
  final bool paymentReceipt;
  final double salesMValue;
  final double mOutwardValue;
  final double orderValue;
  final double extraWorkValue;
  final double paymentReceived;
  final String? workRemark;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Compatibility fields for purchase ledger
  final bool billReceived;
  final bool paymentBill;

  const PmLedgerEntry({
    required this.id,
    required this.projectId,
    required this.srNo,
    required this.date,
    this.paymentType,
    this.referenceNumber,
    this.invoiceNo,
    this.particulars,
    this.billSubmitted = false,
    this.paymentReceipt = false,
    this.salesMValue = 0,
    this.mOutwardValue = 0,
    this.orderValue = 0,
    this.extraWorkValue = 0,
    this.paymentReceived = 0,
    this.workRemark,
    required this.createdAt,
    this.updatedAt,
    this.billReceived = false,
    this.paymentBill = false,
  });

  factory PmLedgerEntry.fromJson(Map<String, dynamic> json) {
    return PmLedgerEntry(
      id: json['id'] as String? ?? '',
      projectId: (json['project_id'] ?? json['purchase_id']) as String? ?? '',
      srNo: (json['sr_no'] as num?)?.toInt() ?? 1,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      paymentType: json['payment_type'] as String?,
      referenceNumber: json['reference_number'] as String?,
      invoiceNo: json['invoice_no'] as String?,
      particulars: json['particulars'] as String?,
      billSubmitted: json['bill_submitted'] == true || json['bill_received'] == true,
      paymentReceipt: json['payment_receipt'] == true || json['payment_bill'] == true,
      salesMValue: (json['sales_m_value'] as num?)?.toDouble() ?? 0.0,
      mOutwardValue: (json['m_outward_value'] as num?)?.toDouble() ?? 0.0,
      orderValue: (json['order_value'] ?? json['quotation_value'] as num?)?.toDouble() ?? 0.0,
      extraWorkValue: (json['extra_work_value'] as num?)?.toDouble() ?? 0.0,
      paymentReceived: (json['payment_received'] ?? json['payment_paid'] as num?)?.toDouble() ?? 0.0,
      workRemark: json['work_remark'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      billReceived: json['bill_received'] == true,
      paymentBill: json['payment_bill'] == true,
    );
  }

  Map<String, dynamic> toJson({bool isPurchase = false}) {
    if (isPurchase) {
      return {
        'purchase_id': projectId,
        'sr_no': srNo,
        'date': date.toIso8601String().split('T').first,
        if (paymentType != null) 'payment_type': paymentType,
        if (referenceNumber != null) 'reference_number': referenceNumber,
        if (invoiceNo != null) 'invoice_no': invoiceNo,
        if (particulars != null) 'particulars': particulars,
        'bill_received': billSubmitted,
        'payment_bill': paymentReceipt,
        'quotation_value': orderValue,
        'payment_paid': paymentReceived,
      };
    }
    return {
      'project_id': projectId,
      'sr_no': srNo,
      'date': date.toIso8601String().split('T').first,
      if (paymentType != null) 'payment_type': paymentType,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (invoiceNo != null) 'invoice_no': invoiceNo,
      if (particulars != null) 'particulars': particulars,
      'bill_submitted': billSubmitted,
      'payment_receipt': paymentReceipt,
      'sales_m_value': salesMValue,
      'm_outward_value': mOutwardValue,
      'order_value': orderValue,
      'extra_work_value': extraWorkValue,
      'payment_received': paymentReceived,
      if (workRemark != null) 'work_remark': workRemark,
    };
  }

  PmLedgerEntry copyWith({
    String? id,
    String? projectId,
    int? srNo,
    DateTime? date,
    String? paymentType,
    String? referenceNumber,
    String? invoiceNo,
    String? particulars,
    bool? billSubmitted,
    bool? paymentReceipt,
    double? salesMValue,
    double? mOutwardValue,
    double? orderValue,
    double? extraWorkValue,
    double? paymentReceived,
    String? workRemark,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? billReceived,
    bool? paymentBill,
  }) {
    return PmLedgerEntry(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      srNo: srNo ?? this.srNo,
      date: date ?? this.date,
      paymentType: paymentType ?? this.paymentType,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      particulars: particulars ?? this.particulars,
      billSubmitted: billSubmitted ?? this.billSubmitted,
      paymentReceipt: paymentReceipt ?? this.paymentReceipt,
      salesMValue: salesMValue ?? this.salesMValue,
      mOutwardValue: mOutwardValue ?? this.mOutwardValue,
      orderValue: orderValue ?? this.orderValue,
      extraWorkValue: extraWorkValue ?? this.extraWorkValue,
      paymentReceived: paymentReceived ?? this.paymentReceived,
      workRemark: workRemark ?? this.workRemark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      billReceived: billReceived ?? this.billReceived,
      paymentBill: paymentBill ?? this.paymentBill,
    );
  }

  double get quotationValue => orderValue;
  double get paymentPaid => paymentReceived;
}
