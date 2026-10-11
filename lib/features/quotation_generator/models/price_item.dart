// lib/features/quotation_generator/models/price_item.dart

enum PriceRowType {
  included,
  extra,
  amount,
  customText;

  static PriceRowType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'included':
        return PriceRowType.included;
      case 'extra':
        return PriceRowType.extra;
      case 'amount':
        return PriceRowType.amount;
      default:
        return PriceRowType.customText;
    }
  }

  String get displayName {
    switch (this) {
      case PriceRowType.included:
        return 'Included';
      case PriceRowType.extra:
        return 'Extra';
      case PriceRowType.amount:
        return 'Numeric Amount (₹)';
      case PriceRowType.customText:
        return 'Custom Text';
    }
  }
}

class PriceItem {
  final String serialNo;
  final String description;
  final String systemLph;
  final String hpKw;
  final String qty;
  final String ratePerLiter;
  final String systemRate;
  final PriceRowType amountType;
  final int numericAmount; // Stored in rupees as integer to prevent float inaccuracies
  final String customText;

  const PriceItem({
    required this.serialNo,
    required this.description,
    this.systemLph = '',
    this.hpKw = '',
    this.qty = '',
    this.ratePerLiter = '',
    this.systemRate = '',
    this.amountType = PriceRowType.extra,
    this.numericAmount = 0,
    this.customText = '',
  });

  String get displayAmount {
    switch (amountType) {
      case PriceRowType.included:
        return 'Included';
      case PriceRowType.extra:
        return 'Extra';
      case PriceRowType.amount:
        return '₹${_formatIndian(numericAmount)}';
      case PriceRowType.customText:
        return customText.isNotEmpty ? customText : 'Extra';
    }
  }

  static String _formatIndian(int number) {
    final str = number.toString();
    if (str.length <= 3) return str;
    final last3 = str.substring(str.length - 3);
    final rest = str.substring(0, str.length - 3);
    final buffer = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(rest[i]);
    }
    buffer.write(',');
    buffer.write(last3);
    return buffer.toString();
  }

  PriceItem copyWith({
    String? serialNo,
    String? description,
    String? systemLph,
    String? hpKw,
    String? qty,
    String? ratePerLiter,
    String? systemRate,
    PriceRowType? amountType,
    int? numericAmount,
    String? customText,
  }) {
    return PriceItem(
      serialNo: serialNo ?? this.serialNo,
      description: description ?? this.description,
      systemLph: systemLph ?? this.systemLph,
      hpKw: hpKw ?? this.hpKw,
      qty: qty ?? this.qty,
      ratePerLiter: ratePerLiter ?? this.ratePerLiter,
      systemRate: systemRate ?? this.systemRate,
      amountType: amountType ?? this.amountType,
      numericAmount: numericAmount ?? this.numericAmount,
      customText: customText ?? this.customText,
    );
  }

  Map<String, dynamic> toJson() => {
    'serialNo': serialNo,
    'description': description,
    'systemLph': systemLph,
    'hpKw': hpKw,
    'qty': qty,
    'ratePerLiter': ratePerLiter,
    'systemRate': systemRate,
    'amountType': amountType.name,
    'numericAmount': numericAmount,
    'customText': customText,
  };

  factory PriceItem.fromJson(Map<String, dynamic> json) {
    return PriceItem(
      serialNo: json['serialNo'] as String? ?? '01',
      description: json['description'] as String? ?? '',
      systemLph: json['systemLph'] as String? ?? '',
      hpKw: json['hpKw'] as String? ?? '',
      qty: json['qty'] as String? ?? '',
      ratePerLiter: json['ratePerLiter'] as String? ?? '',
      systemRate: json['systemRate'] as String? ?? '',
      amountType: PriceRowType.fromString(json['amountType'] as String? ?? 'extra'),
      numericAmount: (json['numericAmount'] as num? ?? 0).toInt(),
      customText: json['customText'] as String? ?? '',
    );
  }

  static List<PriceItem> defaultExtraRows() {
    return [
      const PriceItem(
        serialNo: '03',
        description: 'Transportation',
        amountType: PriceRowType.extra,
      ),
      const PriceItem(
        serialNo: '04',
        description: 'Lifting',
        amountType: PriceRowType.extra,
      ),
      const PriceItem(
        serialNo: '05',
        description: 'Installation',
        amountType: PriceRowType.extra,
      ),
      const PriceItem(
        serialNo: '06',
        description: 'Circulation pump (Kirloskar/Wilo)',
        amountType: PriceRowType.included,
      ),
      const PriceItem(
        serialNo: '07',
        description: 'Plumbing & wiring material',
        amountType: PriceRowType.extra,
      ),
    ];
  }
}
