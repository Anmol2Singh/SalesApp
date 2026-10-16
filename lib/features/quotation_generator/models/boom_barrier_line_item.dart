// lib/features/quotation_generator/models/boom_barrier_line_item.dart

/// Represents a single priced or scope row in the Boom Barrier quotation Option 1 table.
class BoomBarrierLineItem {
  final int srNo;
  final String description;
  final String? modelNo; // e.g. 'IZ-2001', 'IZ-2026', 'IZ-2004', 'NPRS'
  final List<String> inclusions; // bullet points under the barrier description
  final int qty;
  final double rate;
  final double discount;
  final double price; // qty * rate
  final bool isExtra; // Displays "Extra" in price column
  final bool isIncluded; // Displays "Included" in price column
  final String? customNote;

  const BoomBarrierLineItem({
    required this.srNo,
    required this.description,
    this.modelNo,
    this.inclusions = const [],
    this.qty = 1,
    this.rate = 0.0,
    this.discount = 0.0,
    this.price = 0.0,
    this.isExtra = false,
    this.isIncluded = false,
    this.customNote,
  });

  /// True if this row contributes to the subtotal amount.
  bool get hasMonetaryValue => !isExtra && !isIncluded && price > 0;

  /// String formatted representation for the price column.
  String get formattedPriceText {
    if (isExtra) return 'Extra';
    if (isIncluded) return 'Included';
    if (price == 0 && rate == 0) return 'Extra';
    return price.toStringAsFixed(0);
  }

  /// String formatted representation for the rate column.
  String get formattedRateText {
    if (isExtra || isIncluded) return '';
    return rate.toStringAsFixed(0);
  }

  factory BoomBarrierLineItem.fromJson(Map<String, dynamic> json) {
    List<String> inc = [];
    final rawInc = json['inclusions'];
    if (rawInc is List) {
      inc = rawInc.map((e) => e.toString()).toList();
    }

    final q = (json['qty'] as num?)?.toInt() ?? 1;
    final r = (json['rate'] as num?)?.toDouble() ?? 0.0;
    final p = (json['price'] as num?)?.toDouble() ?? (q * r);

    return BoomBarrierLineItem(
      srNo: (json['sr_no'] as num?)?.toInt() ?? 1,
      description: json['description'] as String? ?? '',
      modelNo: json['model_no'] as String?,
      inclusions: inc,
      qty: q,
      rate: r,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      price: p,
      isExtra: json['is_extra'] as bool? ?? false,
      isIncluded: json['is_included'] as bool? ?? false,
      customNote: json['custom_note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sr_no': srNo,
      'description': description,
      if (modelNo != null) 'model_no': modelNo,
      'inclusions': inclusions,
      'qty': qty,
      'rate': rate,
      'discount': discount,
      'price': price,
      'is_extra': isExtra,
      'is_included': isIncluded,
      if (customNote != null) 'custom_note': customNote,
    };
  }

  BoomBarrierLineItem copyWith({
    int? srNo,
    String? description,
    String? modelNo,
    List<String>? inclusions,
    int? qty,
    double? rate,
    double? discount,
    double? price,
    bool? isExtra,
    bool? isIncluded,
    String? customNote,
  }) {
    return BoomBarrierLineItem(
      srNo: srNo ?? this.srNo,
      description: description ?? this.description,
      modelNo: modelNo ?? this.modelNo,
      inclusions: inclusions ?? this.inclusions,
      qty: qty ?? this.qty,
      rate: rate ?? this.rate,
      discount: discount ?? this.discount,
      price: price ?? this.price,
      isExtra: isExtra ?? this.isExtra,
      isIncluded: isIncluded ?? this.isIncluded,
      customNote: customNote ?? this.customNote,
    );
  }
}
