// lib/core/models/supplementary_item.dart

class SupplementaryItem {
  final String? id;
  final String name;
  final int qty;
  final double rate;
  final double gstPercent;
  final double amount;
  final String type;

  const SupplementaryItem({
    this.id,
    required this.name,
    this.qty = 1,
    required this.rate,
    this.gstPercent = 18.0,
    required this.amount,
    this.type = 'Extra',
  });

  /// Factory helper that calculates amount = qty * rate * (1 + gstPercent / 100)
  factory SupplementaryItem.create({
    String? id,
    required String name,
    required int qty,
    required double rate,
    double gstPercent = 18.0,
    String type = 'Extra',
  }) {
    final amt = type == 'Included' ? 0.0 : qty * rate * (1 + gstPercent / 100);
    return SupplementaryItem(
      id: id,
      name: name,
      qty: qty,
      rate: rate,
      gstPercent: gstPercent,
      amount: amt,
      type: type,
    );
  }

  factory SupplementaryItem.fromJson(Map<String, dynamic> json) {
    final q = (json['qty'] as num? ?? 1).toInt();
    final r = (json['rate'] as num? ?? 0.0).toDouble();
    final gst = (json['gst_percent'] as num? ?? json['gstPercent'] as num? ?? 18.0).toDouble();
    final typeStr = json['type'] as String? ?? 'Extra';
    final amt = (json['amount'] as num?)?.toDouble() ?? (typeStr == 'Included' ? 0.0 : (q * r * (1 + gst / 100)));

    return SupplementaryItem(
      id: json['id'] as String?,
      name: json['name'] as String? ?? json['item_name'] as String? ?? '',
      qty: q,
      rate: r,
      gstPercent: gst,
      amount: amt,
      type: typeStr,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'qty': qty,
      'rate': rate,
      'gst_percent': gstPercent,
      'amount': amount,
      'type': type,
    };
  }

  SupplementaryItem copyWith({
    String? id,
    String? name,
    int? qty,
    double? rate,
    double? gstPercent,
    String? type,
  }) {
    final newQty = qty ?? this.qty;
    final newRate = rate ?? this.rate;
    final newGst = gstPercent ?? this.gstPercent;
    final newType = type ?? this.type;
    return SupplementaryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      qty: newQty,
      rate: newRate,
      gstPercent: newGst,
      amount: newType == 'Included' ? 0.0 : newQty * newRate * (1 + newGst / 100),
      type: newType,
    );
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SupplementaryItem &&
        other.name == name &&
        other.rate == rate &&
        other.gstPercent == gstPercent &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(name, rate, gstPercent, type);
}
