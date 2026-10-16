import '../../../../core/models/customer.dart';
import 'pm_company.dart';

class PmProject {
  final String id;
  final int idNo;
  final String customerId;
  final String? pipelineId;
  final String orderType;
  final String siteName;
  final String? address;
  final String? hpType;
  final int hpQty;
  final String? tankType;
  final int tankQty;
  final int gl;
  final double salesMValue;
  final double mOutwardValue;
  final double mBalance;
  final double orderValue;
  final double extraWorkValue;
  final double paymentReceived;
  final String? workRemark;
  final String? salesmanName;
  final String companyId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Joined customer details (never copied)
  final Customer? customer;

  // Derived or joined follow-up info
  final DateTime? reminderDate;
  final String? lastCallRemark;

  const PmProject({
    required this.id,
    required this.idNo,
    required this.customerId,
    this.pipelineId,
    required this.orderType,
    required this.siteName,
    this.address,
    this.hpType,
    this.hpQty = 0,
    this.tankType,
    this.tankQty = 0,
    this.gl = 0,
    this.salesMValue = 0,
    this.mOutwardValue = 0,
    this.mBalance = 0,
    this.orderValue = 0,
    this.extraWorkValue = 0,
    this.paymentReceived = 0,
    this.workRemark,
    this.salesmanName,
    this.companyId = 'insiya-solar',
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.customer,
    this.reminderDate,
    this.lastCallRemark,
  });

  /// Dynamic calculated outstanding balance
  double get balance => (orderValue + extraWorkValue) - paymentReceived;

  /// Dynamic getters from joined Customer record
  String? get partyPrintName => customer?.companyName;
  String? get mobileNumber => customer?.phone;
  String get firmName {
    try {
      final comp = PmCompany.defaultCompanies.firstWhere(
        (c) => c.id == companyId,
        orElse: () => const PmCompany(id: 'insiya-solar', name: 'Insiya Solar Industry'),
      );
      return comp.name;
    } catch (_) {
      return 'Insiya Solar Industry';
    }
  }

  String? get salesMan {
    if (salesmanName != null && salesmanName!.trim().isNotEmpty) {
      return salesmanName!.trim();
    }
    if (customer?.salesmanName != null && customer!.salesmanName!.trim().isNotEmpty) {
      return customer!.salesmanName!.trim();
    }
    if (customer?.assignedToName != null && customer!.assignedToName!.trim().isNotEmpty) {
      return customer!.assignedToName!.trim();
    }
    return null;
  }
  String? get gstNo => customer?.gstNumber;
  String? get itemPurchased => hpType ?? tankType;
  int get itemQuantity => hpQty > 0 ? hpQty : tankQty;
  int get tankCapacity => gl > 0 ? gl : tankQty;

  factory PmProject.fromJson(Map<String, dynamic> json) {
    Customer? linkedCustomer;
    if (json['customers'] != null && json['customers'] is Map) {
      linkedCustomer = Customer.fromJson(Map<String, dynamic>.from(json['customers']));
    }

    return PmProject(
      id: json['id'] as String? ?? '',
      idNo: (json['id_no'] as num?)?.toInt() ?? 0,
      customerId: json['customer_id'] as String? ?? '',
      pipelineId: json['pipeline_id'] as String?,
      orderType: json['order_type'] as String? ?? 'Solar System',
      siteName: json['site_name'] as String? ?? '',
      address: json['address'] as String?,
      hpType: json['hp_type'] as String?,
      hpQty: (json['hp_qty'] as num?)?.toInt() ?? 0,
      tankType: json['tank_type'] as String?,
      tankQty: (json['tank_qty'] as num?)?.toInt() ?? 0,
      gl: (json['gl'] as num?)?.toInt() ?? 0,
      salesMValue: (json['sales_m_value'] as num?)?.toDouble() ?? 0.0,
      mOutwardValue: (json['m_outward_value'] as num?)?.toDouble() ?? 0.0,
      mBalance: (json['m_balance'] as num?)?.toDouble() ?? 0.0,
      orderValue: (json['order_value'] as num?)?.toDouble() ?? 0.0,
      extraWorkValue: (json['extra_work_value'] as num?)?.toDouble() ?? 0.0,
      paymentReceived: (json['payment_received'] as num?)?.toDouble() ?? 0.0,
      workRemark: json['work_remark'] as String?,
      salesmanName: json['salesman_name'] as String?,
      companyId: json['company_id'] as String? ?? 'insiya-solar',
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      customer: linkedCustomer,
      reminderDate: json['reminder_date'] != null
          ? DateTime.tryParse(json['reminder_date'] as String)
          : null,
      lastCallRemark: json['last_call_remark'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id_no': idNo,
    'customer_id': customerId,
    if (pipelineId != null) 'pipeline_id': pipelineId,
    'order_type': orderType,
    'site_name': siteName,
    if (address != null) 'address': address,
    if (hpType != null) 'hp_type': hpType,
    'hp_qty': hpQty,
    if (tankType != null) 'tank_type': tankType,
    'tank_qty': tankQty,
    'gl': gl,
    'sales_m_value': salesMValue,
    'm_outward_value': mOutwardValue,
    'm_balance': mBalance,
    'order_value': orderValue,
    'extra_work_value': extraWorkValue,
    'payment_received': paymentReceived,
    if (workRemark != null) 'work_remark': workRemark,
    if (salesmanName != null) 'salesman_name': salesmanName,
    'company_id': companyId,
    if (createdBy != null) 'created_by': createdBy,
  };

  PmProject copyWith({
    String? id,
    int? idNo,
    String? customerId,
    String? pipelineId,
    String? orderType,
    String? siteName,
    String? address,
    String? hpType,
    int? hpQty,
    String? tankType,
    int? tankQty,
    int? gl,
    double? salesMValue,
    double? mOutwardValue,
    double? mBalance,
    double? orderValue,
    double? extraWorkValue,
    double? paymentReceived,
    String? workRemark,
    String? salesmanName,
    String? companyId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Customer? customer,
    DateTime? reminderDate,
    String? lastCallRemark,
  }) {
    return PmProject(
      id: id ?? this.id,
      idNo: idNo ?? this.idNo,
      customerId: customerId ?? this.customerId,
      pipelineId: pipelineId ?? this.pipelineId,
      orderType: orderType ?? this.orderType,
      siteName: siteName ?? this.siteName,
      address: address ?? this.address,
      hpType: hpType ?? this.hpType,
      hpQty: hpQty ?? this.hpQty,
      tankType: tankType ?? this.tankType,
      tankQty: tankQty ?? this.tankQty,
      gl: gl ?? this.gl,
      salesMValue: salesMValue ?? this.salesMValue,
      mOutwardValue: mOutwardValue ?? this.mOutwardValue,
      mBalance: mBalance ?? this.mBalance,
      orderValue: orderValue ?? this.orderValue,
      extraWorkValue: extraWorkValue ?? this.extraWorkValue,
      paymentReceived: paymentReceived ?? this.paymentReceived,
      workRemark: workRemark ?? this.workRemark,
      salesmanName: salesmanName ?? this.salesmanName,
      companyId: companyId ?? this.companyId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customer: customer ?? this.customer,
      reminderDate: reminderDate ?? this.reminderDate,
      lastCallRemark: lastCallRemark ?? this.lastCallRemark,
    );
  }
}
