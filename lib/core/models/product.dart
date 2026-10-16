// lib/core/models/product.dart

class ProductField {
  final String key;
  final String label;
  final String type; // text, number, select, boolean, textarea
  final bool required;
  final List<String>? options;
  final double? min;
  final double? max;

  const ProductField({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
    this.options,
    this.min,
    this.max,
  });

  factory ProductField.fromJson(Map<String, dynamic> json) {
    return ProductField(
      key: json['key'] as String,
      label: json['label'] as String,
      type: json['type'] as String,
      required: json['required'] as bool? ?? false,
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : null,
      min: json['min'] != null ? (json['min'] as num).toDouble() : null,
      max: json['max'] != null ? (json['max'] as num).toDouble() : null,
    );
  }
}

class ProductBaseSpecs {
  final List<ProductField> quotationFields;
  final List<ProductField> boqRequiredFields;
  final List<String> capacities;
  final List<String> linkedItems;
  final Map<String, dynamic> raw;

  const ProductBaseSpecs({
    required this.quotationFields,
    required this.boqRequiredFields,
    this.capacities = const [],
    this.linkedItems = const [],
    this.raw = const {},
  });

  factory ProductBaseSpecs.fromJson(Map<String, dynamic> json) {
    List<String> caps = [];
    if (json['capacities'] is List) {
      caps = (json['capacities'] as List).map((e) => e.toString()).toList();
    }
    List<String> items = [];
    if (json['linked_items'] is List) {
      items = (json['linked_items'] as List).map((e) => e.toString()).toList();
    }
    return ProductBaseSpecs(
      quotationFields: (json['quotation_fields'] as List<dynamic>? ?? [])
          .map((f) => ProductField.fromJson(f as Map<String, dynamic>))
          .toList(),
      boqRequiredFields: (json['boq_required_fields'] as List<dynamic>? ?? [])
          .map((f) => ProductField.fromJson(f as Map<String, dynamic>))
          .toList(),
      capacities: caps,
      linkedItems: items,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);
}

class ProductBrochure {
  final String title;
  final String url;

  const ProductBrochure({
    required this.title,
    required this.url,
  });

  factory ProductBrochure.fromJson(Map<String, dynamic> json) {
    return ProductBrochure(
      title: json['title'] as String? ?? json['name'] as String? ?? 'Brochure',
      url: json['url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
  };
}

class Product {
  final String id;
  final String name;
  final String? category;
  final String? companyId;
  final ProductBaseSpecs baseSpecs;
  final bool isActive;
  final List<String> imageUrls;
  final List<ProductBrochure> brochures;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.name,
    this.category,
    this.companyId,
    required this.baseSpecs,
    required this.isActive,
    this.imageUrls = const [],
    this.brochures = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawImages = json['image_urls'];
    List<String> parsedImages = [];
    if (rawImages is List) {
      parsedImages = rawImages.map((e) => e.toString()).toList();
    }

    final rawBrochures = json['brochure_urls'];
    List<ProductBrochure> parsedBrochures = [];
    if (rawBrochures is List) {
      parsedBrochures = rawBrochures
          .whereType<Map<String, dynamic>>()
          .map((e) => ProductBrochure.fromJson(e))
          .toList();
    }

    final baseSpecsMap = json['base_specs'] as Map<String, dynamic>? ?? {};
    final resolvedCompanyId = json['company_id'] as String? ?? baseSpecsMap['company_id'] as String?;

    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String?,
      companyId: resolvedCompanyId,
      baseSpecs: ProductBaseSpecs.fromJson(baseSpecsMap),
      isActive: json['is_active'] as bool? ?? true,
      imageUrls: parsedImages,
      brochures: parsedBrochures,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'company_id': companyId,
    'is_active': isActive,
    'image_urls': imageUrls,
    'brochure_urls': brochures.map((b) => b.toJson()).toList(),
  };

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? companyId,
    ProductBaseSpecs? baseSpecs,
    bool? isActive,
    List<String>? imageUrls,
    List<ProductBrochure>? brochures,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      companyId: companyId ?? this.companyId,
      baseSpecs: baseSpecs ?? this.baseSpecs,
      isActive: isActive ?? this.isActive,
      imageUrls: imageUrls ?? this.imageUrls,
      brochures: brochures ?? this.brochures,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
