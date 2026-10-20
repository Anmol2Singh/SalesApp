// lib/features/quotation_generator/models/pool_heat_pump_model.dart

class PoolHeatPumpModel {
  final String id;
  final String modelName;
  final double capacityKw;
  final String description;
  final String defaultImagePath;
  final Map<String, String> specs;

  const PoolHeatPumpModel({
    required this.id,
    required this.modelName,
    required this.capacityKw,
    required this.description,
    this.defaultImagePath = '',
    required this.specs,
  });

  String get heatingCapacity => specs['Heating Capacity'] ?? '25.5~6.4 kW';
  String get powerInput => specs['Power Input'] ?? '5.2~0.84 kW';
  String get powerSupply => specs['Power Supply'] ?? '415V - 3Phase';
  String get maxPowerInput => specs['Max. Power Input'] ?? '4.76kw';
  String get maxCurrent => specs['Max. Current'] ?? '30A';
  String get waterFlowRate => specs['Water Flow Volume'] ?? '12000 L/h';
  String get noise => specs['Noise Level (10m)'] ?? '<=59 dB(A)';
  String get heatExchanger => specs['Heat Exchanger'] ?? 'Titanium';
  String get refrigerant => specs['Refrigerant'] ?? 'R32';
  String get workingTempRange => specs['Working Temp Range'] ?? '-15~43°C';

  Map<String, dynamic> toJson() => {
        'id': id,
        'modelName': modelName,
        'capacityKw': capacityKw,
        'description': description,
        'defaultImagePath': defaultImagePath,
        'specs': specs,
      };

  factory PoolHeatPumpModel.fromJson(Map<String, dynamic> json) => PoolHeatPumpModel(
        id: json['id'] as String? ?? 'IZ-35SP',
        modelName: json['modelName'] as String? ?? 'IZ-35SP',
        capacityKw: (json['capacityKw'] as num?)?.toDouble() ?? 35.0,
        description: json['description'] as String? ?? '',
        defaultImagePath: json['defaultImagePath'] as String? ?? '',
        specs: (json['specs'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            {},
      );

  PoolHeatPumpModel copyWith({
    String? id,
    String? modelName,
    double? capacityKw,
    String? description,
    String? defaultImagePath,
    Map<String, String>? specs,
  }) {
    return PoolHeatPumpModel(
      id: id ?? this.id,
      modelName: modelName ?? this.modelName,
      capacityKw: capacityKw ?? this.capacityKw,
      description: description ?? this.description,
      defaultImagePath: defaultImagePath ?? this.defaultImagePath,
      specs: specs ?? this.specs,
    );
  }

  static PoolHeatPumpModel defaultModel() => const PoolHeatPumpModel(
        id: 'IZ-35SP',
        modelName: 'IZ-35SP',
        capacityKw: 35.0,
        description: 'Air Source Heat Pump 35KW for Swimming Pool. Make: IZYHEAT Heat Pump Model: IZ-35SP',
        defaultImagePath: '',
        specs: {
          'Capacity in kW': '35KW',
          'Product Dimensions': '1084x399x737mm',
          'Power Supply': '415V - 3Phase',
          'Max. Power Input': '4.76kw',
          'Max. Current': '30A',
          'Water Flow Volume': '12000 L/h',
          'Noise Level (10m)': '<=59 dB(A)',
          'Heating Capacity': '25.5~6.4 kW (TODO_CONFIRM)',
          'Power Input': '5.2~0.84 kW (TODO_CONFIRM)',
          'Refrigerant': 'R32',
          'Heat Exchanger': 'Titanium',
          'Working Temp Range': '-15~43°C',
        },
      );
}
