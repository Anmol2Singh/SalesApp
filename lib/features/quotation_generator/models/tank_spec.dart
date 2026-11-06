// lib/features/quotation_generator/models/tank_spec.dart

class TankSpec {
  final int capacityLitres;
  final bool isPressurized;
  final int shellThicknessMm;
  final int dishThicknessMm;
  final String capacityAndThickness;
  final String operatingPressure;
  final String testingPressure;
  final String hotWaterInletOutlet;
  final String heatPumpCirculation;
  final String outerTankInsulation;
  final String temperatureDrop;
  final String innerAndOuterTank;
  final String tankDirection;
  final String other;

  const TankSpec({
    this.capacityLitres = 500,
    this.isPressurized = true,
    this.shellThicknessMm = 3,
    this.dishThicknessMm = 3,
    String? capacityAndThickness,
    this.operatingPressure = 'Up to 5 Bar',
    this.testingPressure = '7 bar pressure',
    this.hotWaterInletOutlet = '2 Inch,',
    this.heatPumpCirculation = '1 Inch,',
    this.outerTankInsulation = 'PUF',
    this.temperatureDrop = '3° C / 8 hour',
    this.innerAndOuterTank = 'GI',
    this.tankDirection = 'Horizontal / Vertical',
    this.other = 'Solar Provision Additional Heat Pump Provision',
  }) : capacityAndThickness = capacityAndThickness ?? '$capacityLitres ltr, ${shellThicknessMm}mm Shell, ${dishThicknessMm}mm Dish.';

  String get innerTankMaterial => innerAndOuterTank.isNotEmpty ? innerAndOuterTank : 'GI';
  String get innerTankThickness => '${shellThicknessMm}mm';
  String get outerCladdingMaterial => innerAndOuterTank.isNotEmpty ? innerAndOuterTank : 'GI';
  String get outerCladdingThickness => '${dishThicknessMm}mm';
  String get insulationMaterial {
    final lower = outerTankInsulation.toLowerCase();
    if (lower.contains('puff') || lower.contains('puf')) return 'PUF';
    if (lower.contains('rockwool')) return 'Rockwool';
    final cleaned = outerTankInsulation
        .replaceAll(RegExp(r'^\s*50\s*mm\s*with\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*Insulation\s*$', caseSensitive: false), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : 'PUF';
  }

  String get tankTitle =>
      '$capacityLitres Ltr HOT WATER STORAGE $innerTankMaterial ${isPressurized ? "Pressurized" : "Non-Pressurized"} TANK';

  String get priceRowDescription {
    final shell = innerTankThickness.isNotEmpty ? innerTankThickness : '${shellThicknessMm}mm';
    final dish = outerCladdingThickness.isNotEmpty ? outerCladdingThickness : '${dishThicknessMm}mm';
    final ins = (outerTankInsulation.toLowerCase().contains('puff') || outerTankInsulation.toLowerCase().contains('puf'))
        ? '50 mm with PUF Insulation'
        : (outerTankInsulation.toLowerCase().contains('insulation')
            ? outerTankInsulation
            : '50 mm with $outerTankInsulation Insulation');
    return '$capacityLitres LTR Capacity, $innerTankMaterial ${isPressurized ? "Pressurized" : "Non-Pressurized"} Tank, $shell Shell, and $dish Dish, $ins.';
  }

  static String generateSubjectLine({
    double? hpKw,
    double? kw,
    int hpQty = 1,
    int? litres,
    int? tankLitres,
    int tankQty = 1,
    String innerMaterial = 'GI',
    required bool isPressurized,
  }) {
    final effectiveKw = hpKw ?? kw ?? 4.0;
    final effectiveLitres = litres ?? tankLitres ?? 500;
    final kwStr = effectiveKw.truncateToDouble() == effectiveKw
        ? effectiveKw.toInt().toString()
        : effectiveKw.toString();
    return 'Proposal For air Source Heat Pump Water Heating System ${kwStr}KWx$hpQty, ${effectiveLitres}LTRx$tankQty for your Project.';
  }

  static String generateMultiTankSubjectLine(double hpKw, List<TankSpec> tanks, {int hpQty = 1}) {
    final kwStr = hpKw.truncateToDouble() == hpKw ? hpKw.toInt().toString() : hpKw.toString();
    final tankDescs = tanks.map((t) => '${t.capacityLitres}LTRx1').join(', ');
    return 'Proposal For air Source Heat Pump Water Heating System ${kwStr}KWx$hpQty, $tankDescs for your Project.';
  }

  factory TankSpec.defaultFor({
    required int capacityLitres,
    required bool isPressurized,
  }) {
    return TankSpec(
      capacityLitres: capacityLitres,
      isPressurized: isPressurized,
      capacityAndThickness: '$capacityLitres ltr, 3mm Shell, 3mm Dish.',
      operatingPressure: isPressurized ? 'Up to 5 Bar' : 'Gravity / 0.5 Bar',
      testingPressure: isPressurized ? '7 bar pressure' : 'Up to 3 bar',
      hotWaterInletOutlet: '2 Inch,',
      heatPumpCirculation: '1 Inch,',
      outerTankInsulation: '50 mm with Puff Insulation',
      temperatureDrop: '3° C / 8 hour',
      innerAndOuterTank: 'GI',
      tankDirection: 'Horizontal / Vertical',
      other: 'Other Solar Provision Additional Heat Pump Provision',
    );
  }

  factory TankSpec.fromJson(Map<String, dynamic> json) {
    final cap = (json['capacityLitres'] as num? ?? 500).toInt();
    final shell = (json['shellThicknessMm'] as num? ?? 3).toInt();
    final dish = (json['dishThicknessMm'] as num? ?? 3).toInt();
    return TankSpec(
      capacityLitres: cap,
      isPressurized: json['isPressurized'] as bool? ?? true,
      shellThicknessMm: shell,
      dishThicknessMm: dish,
      capacityAndThickness: json['capacityAndThickness'] as String? ?? '$cap ltr, ${shell}mm Shell, ${dish}mm Dish.',
      operatingPressure: json['operatingPressure'] as String? ?? 'Up to 5 Bar',
      testingPressure: json['testingPressure'] as String? ?? '7 bar pressure',
      hotWaterInletOutlet: json['hotWaterInletOutlet'] as String? ?? '2 Inch,',
      heatPumpCirculation: json['heatPumpCirculation'] as String? ?? '1 Inch,',
      outerTankInsulation: json['outerTankInsulation'] as String? ?? 'PUF',
      temperatureDrop: json['temperatureDrop'] as String? ?? '3° C / 8 hour',
      innerAndOuterTank: json['innerAndOuterTank'] as String? ?? 'GI',
      tankDirection: json['tankDirection'] as String? ?? 'Horizontal / Vertical',
      other: json['other'] as String? ?? 'Other Solar Provision Additional Heat Pump Provision',
    );
  }

  Map<String, dynamic> toJson() => {
    'capacityLitres': capacityLitres,
    'isPressurized': isPressurized,
    'shellThicknessMm': shellThicknessMm,
    'dishThicknessMm': dishThicknessMm,
    'capacityAndThickness': capacityAndThickness,
    'operatingPressure': operatingPressure,
    'testingPressure': testingPressure,
    'hotWaterInletOutlet': hotWaterInletOutlet,
    'heatPumpCirculation': heatPumpCirculation,
    'outerTankInsulation': outerTankInsulation,
    'temperatureDrop': temperatureDrop,
    'innerAndOuterTank': innerAndOuterTank,
    'tankDirection': tankDirection,
    'other': other,
  };
}
