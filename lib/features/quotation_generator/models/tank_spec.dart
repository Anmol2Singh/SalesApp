// lib/features/quotation_generator/models/tank_spec.dart

class TankSpec {
  final int capacityLitres;
  final bool isPressurized;
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
    this.capacityAndThickness = '500 ltr, 3mm Shell, 3mm Dish.',
    this.operatingPressure = 'Up to 5 Bar',
    this.testingPressure = '7 bar pressure',
    this.hotWaterInletOutlet = '2 Inch,',
    this.heatPumpCirculation = '1 Inch,',
    this.outerTankInsulation = 'PUF',
    this.temperatureDrop = '3° C / 8 hour',
    this.innerAndOuterTank = 'GI',
    this.tankDirection = 'Horizontal / Vertical',
    this.other = 'Solar Provision Additional Heat Pump Provision',
  });

  String get innerTankMaterial => innerAndOuterTank.isNotEmpty ? innerAndOuterTank : 'GI';
  String get innerTankThickness => '3mm';
  String get outerCladdingMaterial => innerAndOuterTank.isNotEmpty ? innerAndOuterTank : 'GI';
  String get outerCladdingThickness => '3mm';
  String get insulationMaterial => outerTankInsulation.contains('Puff') || outerTankInsulation.contains('PUF') ? 'PUF' : 'Rockwool';

  String get tankTitle =>
      '$capacityLitres Ltr HOT WATER STORAGE $innerTankMaterial ${isPressurized ? "Pressurized" : "Non-Pressurized"} TANK';

  String get priceRowDescription =>
      '$capacityLitres LTR Capacity, $innerTankMaterial ${isPressurized ? "Pressurized" : "Non-Pressurized"} Tank, 3mm Shell, and 3mm Dish Thickness, 50 mm with Puff Insulation.';

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
    return TankSpec(
      capacityLitres: (json['capacityLitres'] as num? ?? 500).toInt(),
      isPressurized: json['isPressurized'] as bool? ?? true,
      capacityAndThickness: json['capacityAndThickness'] as String? ?? '500 ltr, 3mm Shell, 3mm Dish.',
      operatingPressure: json['operatingPressure'] as String? ?? 'Up to 5 Bar',
      testingPressure: json['testingPressure'] as String? ?? '7 bar pressure',
      hotWaterInletOutlet: json['hotWaterInletOutlet'] as String? ?? '2 Inch,',
      heatPumpCirculation: json['heatPumpCirculation'] as String? ?? '1 Inch,',
      outerTankInsulation: json['outerTankInsulation'] as String? ?? '50 mm with Puff Insulation',
      temperatureDrop: json['temperatureDrop'] as String? ?? '3° C / 8 hour',
      innerAndOuterTank: json['innerAndOuterTank'] as String? ?? 'GI',
      tankDirection: json['tankDirection'] as String? ?? 'Horizontal / Vertical',
      other: json['other'] as String? ?? 'Other Solar Provision Additional Heat Pump Provision',
    );
  }

  Map<String, dynamic> toJson() => {
    'capacityLitres': capacityLitres,
    'isPressurized': isPressurized,
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
