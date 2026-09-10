// lib/core/models/boq.dart

class BoqItem {
  final String component;
  final String? spec;
  final double qty;
  final String unit;
  final String? remarks;
  final String scope; // 'company' or 'customer'

  const BoqItem({
    required this.component,
    this.spec,
    required this.qty,
    required this.unit,
    this.remarks,
    this.scope = 'company',
  });

  factory BoqItem.fromJson(Map<String, dynamic> json) {
    return BoqItem(
      component: json['component'] as String? ?? '',
      spec: json['spec'] as String?,
      qty: (json['qty'] as num? ?? 0).toDouble(),
      unit: json['unit'] as String? ?? 'nos',
      remarks: json['remarks'] as String?,
      scope: json['scope'] as String? ?? 'company',
    );
  }

  Map<String, dynamic> toJson() => {
    'component': component,
    'spec': spec,
    'qty': qty,
    'unit': unit,
    'remarks': remarks,
    'scope': scope,
  };

  BoqItem copyWith({
    String? component,
    String? spec,
    double? qty,
    String? unit,
    String? remarks,
    String? scope,
  }) {
    return BoqItem(
      component: component ?? this.component,
      spec: spec ?? this.spec,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      remarks: remarks ?? this.remarks,
      scope: scope ?? this.scope,
    );
  }
}

enum BoqStatus {
  draft,
  submitted;

  static BoqStatus fromString(String value) {
    return BoqStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BoqStatus.draft,
    );
  }

  String get displayName {
    switch (this) {
      case BoqStatus.draft:
        return 'Draft';
      case BoqStatus.submitted:
        return 'Submitted';
    }
  }
}

class Boq {
  final String id;
  final String pipelineId;
  final String boqNumber;
  final List<BoqItem> items;
  final Map<String, dynamic> extraFields;
  final String? pdfUrl;
  final DateTime? tentativeDispatchDate;
  final String? remarks;
  final BoqStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Boq({
    required this.id,
    required this.pipelineId,
    required this.boqNumber,
    required this.items,
    required this.extraFields,
    this.pdfUrl,
    this.tentativeDispatchDate,
    this.remarks,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Boq.fromJson(Map<String, dynamic> json) {
    return Boq(
      id: json['id'] as String? ?? '',
      pipelineId: json['pipeline_id'] as String? ?? '',
      boqNumber: json['boq_number'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => BoqItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      extraFields: Map<String, dynamic>.from(
        json['extra_fields'] as Map<String, dynamic>? ?? {},
      ),
      pdfUrl: json['pdf_url'] as String?,
      tentativeDispatchDate: json['tentative_dispatch_date'] != null
          ? DateTime.tryParse(json['tentative_dispatch_date'] as String? ?? '')
          : null,
      remarks: json['remarks'] as String?,
      status: BoqStatus.fromString(json['status'] as String? ?? 'draft'),
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
    'boq_number': boqNumber,
    'items': items.map((item) => item.toJson()).toList(),
    'extra_fields': extraFields,
    'pdf_url': pdfUrl,
    'tentative_dispatch_date': tentativeDispatchDate?.toIso8601String(),
    'remarks': remarks,
    'status': status.name,
  };

  bool get isSubmitted => status == BoqStatus.submitted;
  bool get hasPdf => pdfUrl != null && pdfUrl!.isNotEmpty;
}
