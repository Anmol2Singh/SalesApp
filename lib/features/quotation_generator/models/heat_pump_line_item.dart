// lib/features/quotation_generator/models/heat_pump_line_item.dart

import 'heat_pump_model.dart';

class HeatPumpLineItem {
  final String id;
  final String modelName;
  final double kw;
  final int qty;
  final int rate;
  final int amount;
  final String description;
  final HeatPumpModel? model;
  final Map<String, String> specs;

  const HeatPumpLineItem({
    required this.id,
    required this.modelName,
    required this.kw,
    this.qty = 1,
    this.rate = 0,
    int? amount,
    this.description = '',
    this.model,
    this.specs = const {},
  }) : amount = amount ?? (rate * qty);

  HeatPumpLineItem copyWith({
    String? id,
    String? modelName,
    double? kw,
    int? qty,
    int? rate,
    int? amount,
    String? description,
    HeatPumpModel? model,
    Map<String, String>? specs,
  }) {
    return HeatPumpLineItem(
      id: id ?? this.id,
      modelName: modelName ?? this.modelName,
      kw: kw ?? this.kw,
      qty: qty ?? this.qty,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      model: model ?? this.model,
      specs: specs ?? this.specs,
    );
  }

  String get kwDisplay => (kw == kw.toInt()) ? '${kw.toInt()}' : '$kw';

  HeatPumpModel toModel() {
    if (model != null) return model!;
    final kwStr = kwDisplay;
    return HeatPumpModel(
      id: modelName,
      modelName: modelName,
      displayCapacityKw: kw,
      ratedHeatingCapacity: '${kwStr}kw',
      descriptionLine: 'Air Source Heat pump ${kwStr}kw',
      makeModelLine: 'Make: IZYHEAT Heat Pump Model: $modelName ${kwStr}kw',
      specs: specs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'modelName': modelName,
    'kw': kw,
    'qty': qty,
    'rate': rate,
    'amount': amount,
    'description': description,
    'specs': specs,
  };

  factory HeatPumpLineItem.fromJson(Map<String, dynamic> json) => HeatPumpLineItem(
    id: json['id'] as String? ?? 'hp',
    modelName: json['modelName'] as String? ?? 'IZ-4C',
    kw: (json['kw'] as num?)?.toDouble() ?? 4.0,
    qty: (json['qty'] as num?)?.toInt() ?? 1,
    rate: (json['rate'] as num?)?.toInt() ?? 0,
    amount: (json['amount'] as num?)?.toInt(),
    description: json['description'] as String? ?? '',
    specs: (json['specs'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())),
  );
}
