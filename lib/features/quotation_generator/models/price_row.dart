// lib/features/quotation_generator/models/price_row.dart

enum PriceRowStatus {
  included,
  extra,
  na,
  priced,
  customText,
}

extension PriceRowStatusX on PriceRowStatus {
  String get label {
    switch (this) {
      case PriceRowStatus.included:
        return 'Included';
      case PriceRowStatus.extra:
        return 'Extra';
      case PriceRowStatus.na:
        return 'NA';
      case PriceRowStatus.priced:
        return 'Priced (₹)';
      case PriceRowStatus.customText:
        return 'Custom';
    }
  }

  String displayAmount({int amount = 0, String? customText}) {
    switch (this) {
      case PriceRowStatus.included:
        return 'Included';
      case PriceRowStatus.extra:
        return 'Extra';
      case PriceRowStatus.na:
        return 'NA';
      case PriceRowStatus.customText:
        return customText?.isNotEmpty == true ? customText! : 'Custom';
      case PriceRowStatus.priced:
        return '₹$amount';
    }
  }
}

class PriceRow {
  final String id;
  final String serialNo;
  final String description;
  final PriceRowStatus status;
  final int qty;
  final int rate; // In integer rupees
  final int amount; // qty * rate if priced, else 0
  final String? customStatusText;
  final String? unitLabel; // "SET", "NOS", "LOT"
  final double? hpKw;
  final int? ratePerKw;
  final int? systemLph;
  final int? ratePerLtr;
  final int? systemRate;
  final int? discountAmount;
  final Map<String, dynamic>? metadata;

  const PriceRow({
    required this.id,
    this.serialNo = '',
    required this.description,
    this.status = PriceRowStatus.included,
    this.qty = 1,
    this.rate = 0,
    int? amount,
    this.customStatusText,
    this.unitLabel,
    this.hpKw,
    this.ratePerKw,
    this.systemLph,
    this.ratePerLtr,
    this.systemRate,
    this.discountAmount,
    this.metadata,
  }) : amount = amount ?? (status == PriceRowStatus.priced ? (qty * rate) : 0);

  bool get isPriced => status == PriceRowStatus.priced;

  int get computedAmount => isPriced ? (qty * rate) : 0;

  PriceRow copyWith({
    String? id,
    String? serialNo,
    String? description,
    PriceRowStatus? status,
    int? qty,
    int? rate,
    int? amount,
    String? customStatusText,
    String? unitLabel,
    double? hpKw,
    int? ratePerKw,
    int? systemLph,
    int? ratePerLtr,
    int? systemRate,
    int? discountAmount,
    Map<String, dynamic>? metadata,
  }) {
    final newStatus = status ?? this.status;
    final newQty = qty ?? this.qty;
    final newRate = rate ?? this.rate;
    final autoAmount = newStatus == PriceRowStatus.priced ? (newQty * newRate) : 0;

    return PriceRow(
      id: id ?? this.id,
      serialNo: serialNo ?? this.serialNo,
      description: description ?? this.description,
      status: newStatus,
      qty: newQty,
      rate: newRate,
      amount: amount ?? autoAmount,
      customStatusText: customStatusText ?? this.customStatusText,
      unitLabel: unitLabel ?? this.unitLabel,
      hpKw: hpKw ?? this.hpKw,
      ratePerKw: ratePerKw ?? this.ratePerKw,
      systemLph: systemLph ?? this.systemLph,
      ratePerLtr: ratePerLtr ?? this.ratePerLtr,
      systemRate: systemRate ?? this.systemRate,
      discountAmount: discountAmount ?? this.discountAmount,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'serialNo': serialNo,
        'description': description,
        'status': status.name,
        'qty': qty,
        'rate': rate,
        'amount': amount,
        'customStatusText': customStatusText,
        'unitLabel': unitLabel,
        'hpKw': hpKw,
        'ratePerKw': ratePerKw,
        'systemLph': systemLph,
        'ratePerLtr': ratePerLtr,
        'systemRate': systemRate,
        'discountAmount': discountAmount,
        'metadata': metadata,
      };

  factory PriceRow.fromJson(Map<String, dynamic> json) {
    PriceRowStatus st = PriceRowStatus.included;
    if (json['status'] != null) {
      try {
        st = PriceRowStatus.values.byName(json['status'] as String);
      } catch (_) {
        st = PriceRowStatus.included;
      }
    }
    final qty = (json['qty'] as num?)?.toInt() ?? 1;
    final rate = (json['rate'] as num?)?.toInt() ?? 0;
    final parsedAmount = (json['amount'] as num?)?.toInt();

    return PriceRow(
      id: json['id'] as String? ?? UniqueKey().toString(),
      serialNo: json['serialNo'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: st,
      qty: qty,
      rate: rate,
      amount: parsedAmount ?? (st == PriceRowStatus.priced ? qty * rate : 0),
      customStatusText: json['customStatusText'] as String?,
      unitLabel: json['unitLabel'] as String?,
      hpKw: (json['hpKw'] as num?)?.toDouble(),
      ratePerKw: (json['ratePerKw'] as num?)?.toInt(),
      systemLph: (json['systemLph'] as num?)?.toInt(),
      ratePerLtr: (json['ratePerLtr'] as num?)?.toInt(),
      systemRate: (json['systemRate'] as num?)?.toInt(),
      discountAmount: (json['discountAmount'] as num?)?.toInt(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class UniqueKey {
  @override
  String toString() => DateTime.now().microsecondsSinceEpoch.toString();
}
