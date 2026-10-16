// lib/features/quotation_generator/models/boom_barrier_at_actual_line.dart

/// Represents an "At Actual" rate row placed below the price table.
/// e.g. "Wiring charges CAT6 + 3 core Power cable 1 mtr 150.00 At Actual"
class BoomBarrierAtActualLine {
  final int srNo;
  final String description;
  final String qty;
  final String rate;
  final String total;

  const BoomBarrierAtActualLine({
    required this.srNo,
    required this.description,
    required this.qty,
    required this.rate,
    this.total = 'At Actual',
  });

  factory BoomBarrierAtActualLine.fromJson(Map<String, dynamic> json) {
    return BoomBarrierAtActualLine(
      srNo: (json['sr_no'] as num?)?.toInt() ?? 1,
      description: json['description'] as String? ?? '',
      qty: json['qty'] as String? ?? '',
      rate: json['rate'] as String? ?? '',
      total: json['total'] as String? ?? 'At Actual',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sr_no': srNo,
      'description': description,
      'qty': qty,
      'rate': rate,
      'total': total,
    };
  }

  BoomBarrierAtActualLine copyWith({
    int? srNo,
    String? description,
    String? qty,
    String? rate,
    String? total,
  }) {
    return BoomBarrierAtActualLine(
      srNo: srNo ?? this.srNo,
      description: description ?? this.description,
      qty: qty ?? this.qty,
      rate: rate ?? this.rate,
      total: total ?? this.total,
    );
  }
}
