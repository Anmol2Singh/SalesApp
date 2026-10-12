class PmChecklistItem {
  final String id;
  final String projectId;
  final int srNo;
  final String itemName;
  final double reqQty;
  final bool customerScope;
  final bool ourScope;
  final double dispatchQty;
  final bool dispatchYesNo;
  final double installedQty;
  final bool installationYesNo;
  final double dispatchBalanceQty;
  final String? remark;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PmChecklistItem({
    required this.id,
    required this.projectId,
    this.srNo = 1,
    required this.itemName,
    this.reqQty = 0,
    this.customerScope = false,
    this.ourScope = false,
    this.dispatchQty = 0,
    this.dispatchYesNo = false,
    this.installedQty = 0,
    this.installationYesNo = false,
    this.dispatchBalanceQty = 0,
    this.remark,
    required this.createdAt,
    this.updatedAt,
  });

  factory PmChecklistItem.fromJson(Map<String, dynamic> json) {
    return PmChecklistItem(
      id: json['id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      srNo: (json['sr_no'] as num?)?.toInt() ?? 1,
      itemName: json['item_name'] as String? ?? '',
      reqQty: (json['req_qty'] as num?)?.toDouble() ?? 0.0,
      customerScope: json['customer_scope'] == true,
      ourScope: json['our_scope'] == true,
      dispatchQty: (json['dispatch_qty'] as num?)?.toDouble() ?? 0.0,
      dispatchYesNo: json['dispatch_yes_no'] == true,
      installedQty: (json['installed_qty'] as num?)?.toDouble() ?? 0.0,
      installationYesNo: json['installation_yes_no'] == true,
      dispatchBalanceQty: (json['dispatch_balance_qty'] as num?)?.toDouble() ?? 0.0,
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
    'sr_no': srNo,
    'item_name': itemName,
    'req_qty': reqQty,
    'customer_scope': customerScope,
    'our_scope': ourScope,
    'dispatch_qty': dispatchQty,
    'dispatch_yes_no': dispatchYesNo,
    'installed_qty': installedQty,
    'installation_yes_no': installationYesNo,
    'dispatch_balance_qty': reqQty - dispatchQty,
    if (remark != null) 'remark': remark,
  };

  PmChecklistItem copyWith({
    String? id,
    String? projectId,
    int? srNo,
    String? itemName,
    double? reqQty,
    bool? customerScope,
    bool? ourScope,
    double? dispatchQty,
    bool? dispatchYesNo,
    double? installedQty,
    bool? installationYesNo,
    double? dispatchBalanceQty,
    String? remark,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PmChecklistItem(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      srNo: srNo ?? this.srNo,
      itemName: itemName ?? this.itemName,
      reqQty: reqQty ?? this.reqQty,
      customerScope: customerScope ?? this.customerScope,
      ourScope: ourScope ?? this.ourScope,
      dispatchQty: dispatchQty ?? this.dispatchQty,
      dispatchYesNo: dispatchYesNo ?? this.dispatchYesNo,
      installedQty: installedQty ?? this.installedQty,
      installationYesNo: installationYesNo ?? this.installationYesNo,
      dispatchBalanceQty: dispatchBalanceQty ?? this.dispatchBalanceQty,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
