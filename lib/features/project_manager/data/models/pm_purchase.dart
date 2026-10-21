class PmPurchase {
  final String id;
  final int idNo;
  final String orderType;
  final String siteName; // Official Vendor Name
  final String? partyPrintName;
  final String? mobileNumber;
  final String? address;
  final String? firmName;
  final double quotationValue;
  final double paymentPaid;
  final double balance;
  final String companyId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Compatibility getters matching Project interface
  double get orderValue => quotationValue;
  double get paymentReceived => paymentPaid;
  double get extraWorkValue => 0.0;
  String? get salesMan => null;
  String? get salesmanName => null;
  String? get gstNo => null;
  String? get itemPurchased => null;
  int? get itemQuantity => null;
  String? get tankType => null;
  int? get tankCapacity => null;
  dynamic get customer => null;
  String? get customerId => null;

  // Derived follow-up fields
  final DateTime? reminderDate;
  final String? lastCallRemark;

  const PmPurchase({
    required this.id,
    required this.idNo,
    required this.orderType,
    required this.siteName,
    this.partyPrintName,
    this.mobileNumber,
    this.address,
    this.firmName,
    this.quotationValue = 0,
    this.paymentPaid = 0,
    this.balance = 0,
    this.companyId = 'insiya-solar',
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.reminderDate,
    this.lastCallRemark,
  });

  factory PmPurchase.fromJson(Map<String, dynamic> json) {
    final qVal = (json['quotation_value'] as num?)?.toDouble() ??
        (json['order_value'] as num?)?.toDouble() ?? 0.0;
    final pPaid = (json['payment_paid'] as num?)?.toDouble() ??
        (json['payment_received'] as num?)?.toDouble() ?? 0.0;
    final bal = (json['balance'] as num?)?.toDouble() ?? (qVal - pPaid);

    return PmPurchase(
      id: json['id'] as String? ?? '',
      idNo: (json['id_no'] as num?)?.toInt() ?? 0,
      orderType: json['order_type'] as String? ?? 'Vendor Order',
      siteName: json['site_name'] as String? ?? '',
      partyPrintName: json['party_print_name'] as String?,
      mobileNumber: json['mobile_number'] as String?,
      address: json['address'] as String?,
      firmName: json['firm_name'] as String?,
      quotationValue: qVal,
      paymentPaid: pPaid,
      balance: bal,
      companyId: json['company_id'] as String? ?? 'insiya-solar',
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      reminderDate: json['reminder_date'] != null
          ? DateTime.tryParse(json['reminder_date'] as String)
          : null,
      lastCallRemark: json['last_call_remark'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id_no': idNo,
    'order_type': orderType,
    'site_name': siteName,
    if (partyPrintName != null) 'party_print_name': partyPrintName,
    if (mobileNumber != null) 'mobile_number': mobileNumber,
    if (address != null) 'address': address,
    if (firmName != null) 'firm_name': firmName,
    'quotation_value': quotationValue,
    'payment_paid': paymentPaid,
    'balance': balance,
    'company_id': companyId,
    if (createdBy != null) 'created_by': createdBy,
    // Compat columns
    'order_value': quotationValue,
    'payment_received': paymentPaid,
  };

  PmPurchase copyWith({
    String? id,
    int? idNo,
    String? orderType,
    String? siteName,
    String? partyPrintName,
    String? mobileNumber,
    String? address,
    String? firmName,
    double? quotationValue,
    double? paymentPaid,
    double? balance,
    String? companyId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reminderDate,
    String? lastCallRemark,
  }) {
    return PmPurchase(
      id: id ?? this.id,
      idNo: idNo ?? this.idNo,
      orderType: orderType ?? this.orderType,
      siteName: siteName ?? this.siteName,
      partyPrintName: partyPrintName ?? this.partyPrintName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      address: address ?? this.address,
      firmName: firmName ?? this.firmName,
      quotationValue: quotationValue ?? this.quotationValue,
      paymentPaid: paymentPaid ?? this.paymentPaid,
      balance: balance ?? this.balance,
      companyId: companyId ?? this.companyId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderDate: reminderDate ?? this.reminderDate,
      lastCallRemark: lastCallRemark ?? this.lastCallRemark,
    );
  }
}
