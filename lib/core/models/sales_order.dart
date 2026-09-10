// lib/core/models/sales_order.dart

class SalesOrderLineItem {
  final String description;
  final String? hsnSac;
  final double qty;
  final double freeQty;
  final String uom;
  final double rate;
  final double discPercent;
  final double amount;

  const SalesOrderLineItem({
    required this.description,
    this.hsnSac,
    required this.qty,
    required this.freeQty,
    required this.uom,
    required this.rate,
    required this.discPercent,
    required this.amount,
  });

  factory SalesOrderLineItem.fromJson(Map<String, dynamic> json) {
    return SalesOrderLineItem(
      description: json['description'] as String? ?? '',
      hsnSac: json['hsn_sac'] as String?,
      qty: (json['qty'] as num? ?? 0).toDouble(),
      freeQty: (json['free_qty'] as num? ?? 0).toDouble(),
      uom: json['uom'] as String? ?? 'nos',
      rate: (json['rate'] as num? ?? 0).toDouble(),
      discPercent: (json['disc_percent'] as num? ?? 0).toDouble(),
      amount: (json['amount'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'description': description,
    'hsn_sac': hsnSac,
    'qty': qty,
    'free_qty': freeQty,
    'uom': uom,
    'rate': rate,
    'disc_percent': discPercent,
    'amount': amount,
  };

  SalesOrderLineItem copyWith({
    String? description,
    String? hsnSac,
    double? qty,
    double? freeQty,
    String? uom,
    double? rate,
    double? discPercent,
  }) {
    final newQty = qty ?? this.qty;
    final newRate = rate ?? this.rate;
    final newDisc = discPercent ?? this.discPercent;
    final totalAmount = (newQty * newRate) * (1 - newDisc / 100);
    return SalesOrderLineItem(
      description: description ?? this.description,
      hsnSac: hsnSac ?? this.hsnSac,
      qty: newQty,
      freeQty: freeQty ?? this.freeQty,
      uom: uom ?? this.uom,
      rate: newRate,
      discPercent: newDisc,
      amount: totalAmount,
    );
  }
}

enum SalesOrderStatus {
  draft,
  confirmed;

  static SalesOrderStatus fromString(String value) {
    return SalesOrderStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => SalesOrderStatus.draft,
    );
  }

  String get displayName {
    switch (this) {
      case SalesOrderStatus.draft:
        return 'Draft';
      case SalesOrderStatus.confirmed:
        return 'Confirmed';
    }
  }
}

class SalesOrder {
  final String id;
  final String pipelineId;
  final String salesOrderNumber;
  final DateTime orderDate;
  final String? shippingCompany;
  final String? vehicleNumber;
  final String? distance;
  final String? grLrNo;
  final String? destination;
  final String? placeOfSupply;
  final String? paymentTerms;
  final String? billingAddress;
  final String? shippingAddress;
  final String? ewayBillNo;
  final String? ewayBillDate;
  final String? billType;
  final String? salesman;
  final String? partyContactPerson;
  final List<SalesOrderLineItem> lineItems;
  final double subtotal;
  final double cgstRate;
  final double sgstRate;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double grandTotal;
  final String? remarks;
  final String? pdfUrl;
  final String? confirmedBy;
  final DateTime? confirmedAt;
  final SalesOrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SalesOrder({
    required this.id,
    required this.pipelineId,
    required this.salesOrderNumber,
    required this.orderDate,
    this.shippingCompany,
    this.vehicleNumber,
    this.distance,
    this.grLrNo,
    this.destination,
    this.placeOfSupply,
    this.paymentTerms,
    this.billingAddress,
    this.shippingAddress,
    this.ewayBillNo,
    this.ewayBillDate,
    this.billType,
    this.salesman,
    this.partyContactPerson,
    required this.lineItems,
    required this.subtotal,
    this.cgstRate = 9.0,
    this.sgstRate = 9.0,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.grandTotal,
    this.remarks,
    this.pdfUrl,
    this.confirmedBy,
    this.confirmedAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> json) {
    return SalesOrder(
      id: json['id'] as String? ?? '',
      pipelineId: json['pipeline_id'] as String? ?? '',
      salesOrderNumber: json['sales_order_number'] as String? ?? '',
      orderDate: json['order_date'] != null
          ? (DateTime.tryParse(json['order_date'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      shippingCompany: json['shipping_company'] as String?,
      vehicleNumber: json['vehicle_number'] as String?,
      distance: json['distance'] as String?,
      grLrNo: json['gr_lr_no'] as String?,
      destination: json['destination'] as String?,
      placeOfSupply: json['place_of_supply'] as String?,
      paymentTerms: json['payment_terms'] as String?,
      billingAddress: json['billing_address'] as String?,
      shippingAddress: json['shipping_address'] as String?,
      ewayBillNo: json['eway_bill_no'] as String?,
      ewayBillDate: json['eway_bill_date'] as String?,
      billType: json['bill_type'] as String?,
      salesman: json['salesman'] as String?,
      partyContactPerson: json['party_contact_person'] as String?,
      lineItems: (json['line_items'] as List<dynamic>? ?? [])
          .map((item) => SalesOrderLineItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num? ?? 0).toDouble(),
      cgstRate: (json['cgst_rate'] as num? ?? 9.0).toDouble(),
      sgstRate: (json['sgst_rate'] as num? ?? 9.0).toDouble(),
      cgstAmount: (json['cgst_amount'] as num? ?? 0).toDouble(),
      sgstAmount: (json['sgst_amount'] as num? ?? 0).toDouble(),
      igstAmount: (json['igst_amount'] as num? ?? 0).toDouble(),
      grandTotal: (json['grand_total'] as num? ?? 0).toDouble(),
      remarks: json['remarks'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      confirmedBy: json['confirmed_by'] as String?,
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.tryParse(json['confirmed_at'] as String? ?? '')
          : null,
      status: SalesOrderStatus.fromString(json['status'] as String? ?? 'draft'),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'pipeline_id': pipelineId,
    'shipping_company': shippingCompany,
    'vehicle_number': vehicleNumber,
    'distance': distance,
    'gr_lr_no': grLrNo,
    'destination': destination,
    'place_of_supply': placeOfSupply,
    'payment_terms': paymentTerms,
    'billing_address': billingAddress,
    'shipping_address': shippingAddress,
    'eway_bill_no': ewayBillNo,
    'eway_bill_date': ewayBillDate,
    'bill_type': billType,
    'salesman': salesman,
    'party_contact_person': partyContactPerson,
    'line_items': lineItems.map((item) => item.toJson()).toList(),
    'subtotal': subtotal,
    'cgst_rate': cgstRate,
    'sgst_rate': sgstRate,
    'cgst_amount': cgstAmount,
    'sgst_amount': sgstAmount,
    'igst_amount': igstAmount,
    'grand_total': grandTotal,
    'remarks': remarks,
    'status': status.name,
  };

  bool get isConfirmed => status == SalesOrderStatus.confirmed;
  bool get hasPdf => pdfUrl != null && pdfUrl!.isNotEmpty;
}
