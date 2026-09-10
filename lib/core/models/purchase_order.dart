// lib/core/models/purchase_order.dart

enum PurchaseOrderStatus {
  pending,
  ordered,
  received;

  static PurchaseOrderStatus fromString(String value) {
    return PurchaseOrderStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PurchaseOrderStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case PurchaseOrderStatus.pending:
        return 'Pending';
      case PurchaseOrderStatus.ordered:
        return 'Ordered';
      case PurchaseOrderStatus.received:
        return 'Received';
    }
  }
}

class VendorDetails {
  final String vendorName;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? gstNumber;

  const VendorDetails({
    required this.vendorName,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.gstNumber,
  });

  factory VendorDetails.fromJson(Map<String, dynamic> json) {
    return VendorDetails(
      vendorName: json['vendor_name'] as String? ?? '',
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      gstNumber: json['gst_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'vendor_name': vendorName,
    'contact_person': contactPerson,
    'phone': phone,
    'email': email,
    'address': address,
    'gst_number': gstNumber,
  };
}

class PoItem {
  final String description;
  final double qty;
  final String unit;
  final double unitPrice;
  final double total;

  const PoItem({
    required this.description,
    required this.qty,
    required this.unit,
    required this.unitPrice,
    required this.total,
  });

  factory PoItem.fromJson(Map<String, dynamic> json) {
    return PoItem(
      description: json['description'] as String? ?? '',
      qty: (json['qty'] as num? ?? 0).toDouble(),
      unit: json['unit'] as String? ?? 'nos',
      unitPrice: (json['unit_price'] as num? ?? 0).toDouble(),
      total: (json['total'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'description': description,
    'qty': qty,
    'unit': unit,
    'unit_price': unitPrice,
    'total': total,
  };
}

class PurchaseOrder {
  final String id;
  final String pipelineId;
  final String poNumber;
  final VendorDetails vendorDetails;
  final List<PoItem> items;
  final double totalAmount;
  final String? pdfUrl;
  final PurchaseOrderStatus status;
  final String? purchaseNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? billNumber;
  final DateTime? billDate;
  final double? billAmount;

  const PurchaseOrder({
    required this.id,
    required this.pipelineId,
    required this.poNumber,
    required this.vendorDetails,
    required this.items,
    required this.totalAmount,
    this.pdfUrl,
    required this.status,
    this.purchaseNotes,
    required this.createdAt,
    required this.updatedAt,
    this.billNumber,
    this.billDate,
    this.billAmount,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      id: json['id'] as String? ?? '',
      pipelineId: json['pipeline_id'] as String? ?? '',
      poNumber: json['po_number'] as String? ?? '',
      vendorDetails: VendorDetails.fromJson(
        json['vendor_details'] as Map<String, dynamic>? ?? {},
      ),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => PoItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalAmount: (json['total_amount'] as num? ?? 0).toDouble(),
      pdfUrl: json['pdf_url'] as String?,
      status: PurchaseOrderStatus.fromString(json['status'] as String? ?? 'pending'),
      purchaseNotes: json['purchase_notes'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      billNumber: json['bill_number'] as String?,
      billDate: json['bill_date'] != null ? DateTime.tryParse(json['bill_date'] as String) : null,
      billAmount: json['bill_amount'] != null ? (json['bill_amount'] as num).toDouble() : null,
    );
  }

  bool get isReceived => status == PurchaseOrderStatus.received;
  bool get hasPdf => pdfUrl != null && pdfUrl!.isNotEmpty;
}
