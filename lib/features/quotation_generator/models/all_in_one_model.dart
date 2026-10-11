// lib/features/quotation_generator/models/all_in_one_model.dart

class AllInOneModel {
  final String id;
  final String modelName;
  final String mountType; // 'floor' or 'wall'
  final int tankVolumeLitres;
  final String description;
  final Map<String, String> specs;

  const AllInOneModel({
    required this.id,
    required this.modelName,
    required this.mountType,
    required this.tankVolumeLitres,
    required this.description,
    required this.specs,
  });

  bool get isWallMounted => mountType.toLowerCase() == 'wall';
  int get tankVolumeLtr => tankVolumeLitres;

  String get productDimension => specs['Product Dimension'] ?? '570x1810mm';
  String get powerSupply => specs['Power Supply'] ?? '220V-240V/50Hz';
  String get waterYield => specs['Heating Rate'] ?? specs['Heating Rate / Water Yield'] ?? '42 L/h';
  double get cop => double.tryParse(specs['COP'] ?? '4.76') ?? 4.76;
  String get compressor => specs['Compressor'] ?? 'PANASONIC';
  String get refrigerant => specs['Refrigerant'] ?? 'R134a';
  String get maxOutletWaterTemp => specs['Max Outlet Water Temp'] ?? '65°C';
  String get ambientTemperature => specs['Ambient Temperature'] ?? '-7~45°C';
  String get waterTankMaterial => specs['Water Tank'] ?? specs['Water Tank Material'] ?? 'Tank with enamel coating';
  String get netWeight => specs['Net Weight'] ?? '93 KG';

  Map<String, dynamic> toJson() => {
        'id': id,
        'modelName': modelName,
        'mountType': mountType,
        'tankVolumeLitres': tankVolumeLitres,
        'description': description,
        'specs': specs,
      };

  factory AllInOneModel.fromJson(Map<String, dynamic> json) => AllInOneModel(
        id: json['id'] as String? ?? '',
        modelName: json['modelName'] as String? ?? '',
        mountType: json['mountType'] as String? ?? 'floor',
        tankVolumeLitres: (json['tankVolumeLitres'] as num?)?.toInt() ?? 200,
        description: json['description'] as String? ?? '',
        specs: (json['specs'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            {},
      );

  static AllInOneModel defaultFloor() => const AllInOneModel(
        id: 'IZ-200A',
        modelName: 'IZ-200A',
        mountType: 'floor',
        tankVolumeLitres: 200,
        description: 'ALL IN ONE HEAT PUMP (TOP Blow) Make: IZYHEAT Heat Pump Model: IZ-200A',
        specs: {
          'Product Dimension': '570x1810mm',
          'Tank Volume': '200 Ltr',
          'Power Supply': '220V-240V/50Hz',
          'Heating Rate': '42 L/h',
          'COP': '4.76',
          'Compressor': 'PANASONIC',
          'Refrigerant': 'R134a',
          'Max Outlet Water Temp': '65°C',
          'Ambient Temperature': '-7~45°C',
          'Water Tank': 'Tank with enamel coating',
          'Net Weight': '93 KG',
        },
      );

  static AllInOneModel defaultWall() => const AllInOneModel(
        id: 'IZ-100V',
        modelName: 'IZ-100V',
        mountType: 'wall',
        tankVolumeLitres: 100,
        description: 'ALL IN ONE WALL MOUNTED HEAT PUMP (TOP Blow) Make: IZYHEAT Heat Pump Model: IZ-100V',
        specs: {
          'Product Dimension': '470x1282mm',
          'Tank Volume': '100 Ltr',
          'Power Supply': '220V-240V/50Hz',
          'Heating Rate': '12 L/h',
          'COP': '3.5',
          'Compressor': 'GMCC/PANASONIC',
          'Refrigerant': 'R134a',
          'Max Outlet Water Temp': '75°C',
          'Ambient Temperature': '-7~45°C',
          'Water Tank': 'Tank with enamel coating',
          'Net Weight': '45 kg',
        },
      );

  static AllInOneModel defaultFloorModel() => defaultFloor();
  static AllInOneModel defaultWallModel() => defaultWall();
}
