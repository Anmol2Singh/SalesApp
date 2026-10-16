// lib/features/quotation_generator/models/boom_barrier_catalog_model.dart

/// Represents a catalog entry for Boom Barrier equipment stored in qg_catalog.
class BoomBarrierCatalogModel {
  final String? id;
  final String kind; // 'boom_barrier'
  final String modelNo; // e.g. 'IZ-2001', 'IZ-2026', 'IZ-2004', 'NPRS'
  final String displayName;
  final String variantLabel;
  final String modelType; // 'barrier', 'lpr', 'other'
  final String imagePath;
  final int sortOrder;
  final String descriptionTitle;
  final List<String> inclusions;
  final List<Map<String, dynamic>> specRows;
  final List<dynamic> dataFlags;
  final bool isActive;
  final DateTime? archivedAt;

  const BoomBarrierCatalogModel({
    this.id,
    this.kind = 'boom_barrier',
    required this.modelNo,
    required this.displayName,
    this.variantLabel = '',
    this.modelType = 'barrier',
    this.imagePath = '',
    this.sortOrder = 0,
    this.descriptionTitle = '',
    this.inclusions = const [],
    this.specRows = const [],
    this.dataFlags = const [],
    this.isActive = true,
    this.archivedAt,
  });

  bool get isBarrier => modelType.toLowerCase() == 'barrier';
  bool get isLpr => modelType.toLowerCase() == 'lpr';

  factory BoomBarrierCatalogModel.fromJson(Map<String, dynamic> json) {
    // Specs JSON can either be a list of rows or an object with {'rows': [...]}
    List<Map<String, dynamic>> rows = [];
    final rawSpecs = json['specs'];
    if (rawSpecs is Map && rawSpecs['rows'] is List) {
      rows = (rawSpecs['rows'] as List)
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } else if (rawSpecs is List) {
      rows = rawSpecs
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    }

    List<String> inc = [];
    final rawInclusions = json['inclusions'];
    if (rawInclusions is List) {
      inc = rawInclusions.map((e) => e.toString()).toList();
    }

    return BoomBarrierCatalogModel(
      id: json['id'] as String?,
      kind: json['kind'] as String? ?? 'boom_barrier',
      modelNo: json['model_no'] as String? ?? '',
      displayName: json['display_name'] as String? ?? json['model_no'] as String? ?? '',
      variantLabel: json['variant_label'] as String? ?? '',
      modelType: json['model_type'] as String? ?? 'barrier',
      imagePath: json['image_path'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      descriptionTitle: json['description_title'] as String? ?? '',
      inclusions: inc,
      specRows: rows,
      dataFlags: (json['data_flags'] as List?) ?? const [],
      isActive: json['is_active'] as bool? ?? true,
      archivedAt: json['archived_at'] != null ? DateTime.tryParse(json['archived_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'kind': kind,
      'model_no': modelNo,
      'display_name': displayName,
      'variant_label': variantLabel,
      'model_type': modelType,
      'image_path': imagePath,
      'sort_order': sortOrder,
      'description_title': descriptionTitle,
      'inclusions': inclusions,
      'specs': {'rows': specRows},
      'data_flags': dataFlags,
      'is_active': isActive,
      if (archivedAt != null) 'archived_at': archivedAt!.toIso8601String(),
    };
  }

  BoomBarrierCatalogModel copyWith({
    String? id,
    String? kind,
    String? modelNo,
    String? displayName,
    String? variantLabel,
    String? modelType,
    String? imagePath,
    int? sortOrder,
    String? descriptionTitle,
    List<String>? inclusions,
    List<Map<String, dynamic>>? specRows,
    List<dynamic>? dataFlags,
    bool? isActive,
    DateTime? archivedAt,
  }) {
    return BoomBarrierCatalogModel(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      modelNo: modelNo ?? this.modelNo,
      displayName: displayName ?? this.displayName,
      variantLabel: variantLabel ?? this.variantLabel,
      modelType: modelType ?? this.modelType,
      imagePath: imagePath ?? this.imagePath,
      sortOrder: sortOrder ?? this.sortOrder,
      descriptionTitle: descriptionTitle ?? this.descriptionTitle,
      inclusions: inclusions ?? this.inclusions,
      specRows: specRows ?? this.specRows,
      dataFlags: dataFlags ?? this.dataFlags,
      isActive: isActive ?? this.isActive,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}
