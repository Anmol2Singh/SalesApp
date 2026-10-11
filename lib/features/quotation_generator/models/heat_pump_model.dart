// lib/features/quotation_generator/models/heat_pump_model.dart

class HeatPumpModel {
  final String id;
  final String modelName;
  final double displayCapacityKw;
  final String ratedHeatingCapacity;
  final String descriptionLine;
  final String makeModelLine;
  final String powerInputText;
  final String defaultImagePath;
  final Map<String, String> specs;

  const HeatPumpModel({
    required this.id,
    required this.modelName,
    required this.displayCapacityKw,
    this.ratedHeatingCapacity = '3.6kw',
    this.descriptionLine = 'Air Source Heat pump 3.6kw',
    this.makeModelLine = 'Make: IZYHEAT Heat Pump Model: IZ-4C 3.6kw',
    this.powerInputText = 'Power Input 0.86kw, output 3.6kw, 220V - 1Phase, 50Hz With Auto Defrost.',
    this.defaultImagePath = 'assets/images/model_iz_4c.png',
    this.specs = const {},
  });

  String get powerSupply =>
      specs['Power Supply'] ??
      (powerInputText.contains('3Phase') || powerInputText.contains('3 Phase') || powerInputText.contains('415V')
          ? '415V - 3Phase'
          : '220V - 1Phase');

  factory HeatPumpModel.fromJson(Map<String, dynamic> json) {
    return HeatPumpModel(
      id: json['id'] as String? ?? json['modelName'] as String? ?? 'IZ-4C',
      modelName: json['modelName'] as String? ?? 'IZ-4C',
      displayCapacityKw: (json['displayCapacityKw'] as num? ?? 4.0).toDouble(),
      ratedHeatingCapacity: json['ratedHeatingCapacity'] as String? ?? '3.6kw',
      descriptionLine: json['descriptionLine'] as String? ?? 'Air Source Heat pump 3.6kw',
      makeModelLine: json['makeModelLine'] as String? ?? 'Make: IZYHEAT Heat Pump Model: IZ-4C 3.6kw',
      powerInputText: json['powerInputText'] as String? ?? 'Power Input 0.86kw, output 3.6kw, 220V - 1Phase, 50Hz With Auto Defrost.',
      defaultImagePath: json['defaultImagePath'] as String? ?? 'assets/images/model_iz_4c.png',
      specs: Map<String, String>.from(json['specs'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'modelName': modelName,
    'displayCapacityKw': displayCapacityKw,
    'ratedHeatingCapacity': ratedHeatingCapacity,
    'descriptionLine': descriptionLine,
    'makeModelLine': makeModelLine,
    'powerInputText': powerInputText,
    'defaultImagePath': defaultImagePath,
    'specs': specs,
  };

  HeatPumpModel copyWith({
    String? id,
    String? modelName,
    double? displayCapacityKw,
    String? ratedHeatingCapacity,
    String? descriptionLine,
    String? makeModelLine,
    String? powerInputText,
    String? defaultImagePath,
    Map<String, String>? specs,
  }) {
    return HeatPumpModel(
      id: id ?? this.id,
      modelName: modelName ?? this.modelName,
      displayCapacityKw: displayCapacityKw ?? this.displayCapacityKw,
      ratedHeatingCapacity: ratedHeatingCapacity ?? this.ratedHeatingCapacity,
      descriptionLine: descriptionLine ?? this.descriptionLine,
      makeModelLine: makeModelLine ?? this.makeModelLine,
      powerInputText: powerInputText ?? this.powerInputText,
      defaultImagePath: defaultImagePath ?? this.defaultImagePath,
      specs: specs ?? this.specs,
    );
  }
}
