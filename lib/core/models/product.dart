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

  const ProductBaseSpecs({
    required this.quotationFields,
    required this.boqRequiredFields,
  });

  factory ProductBaseSpecs.fromJson(Map<String, dynamic> json) {
    return ProductBaseSpecs(
      quotationFields: (json['quotation_fields'] as List<dynamic>? ?? [])
          .map((f) => ProductField.fromJson(f as Map<String, dynamic>))
          .toList(),
      boqRequiredFields: (json['boq_required_fields'] as List<dynamic>? ?? [])
          .map((f) => ProductField.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
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

    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String?,
      baseSpecs: ProductBaseSpecs.fromJson(
        json['base_specs'] as Map<String, dynamic>? ?? {},
      ),
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
    'is_active': isActive,
    'image_urls': imageUrls,
    'brochure_urls': brochures.map((b) => b.toJson()).toList(),
  };
}
