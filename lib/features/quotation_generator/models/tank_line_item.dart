// lib/features/quotation_generator/models/tank_line_item.dart

import 'tank_spec.dart';

class TankLineItem {
  final String id;
  final int capacityLitres;
  final int qty;
  final int rate; // Amount or rate per unit
  final String material; // 'GI', 'MS', 'Enamel'
  final bool isPressurized;
  final int shellThicknessMm;
  final int dishThicknessMm;
  final String insulation;
  final bool hasManhole;
  final bool hasStandProvisions;
  final bool isWifiEnabled;
  final String? extraNote; // e.g. "Extra", "(Sr.No 01 Included with it)"
  final bool isIncludedInHp; // If true, rate shows 'Included'

  const TankLineItem({
    required this.id,
    this.capacityLitres = 500,
    this.qty = 1,
    this.rate = 120000,
    String? material,
    String? innerTankMaterial,
    String? outerCladdingMaterial,
    this.isPressurized = true,
    int? shellThicknessMm,
    String? innerTankThickness,
    int? dishThicknessMm,
    String? outerCladdingThickness,
    String? insulation,
    String? insulationMaterial,
    String? insulationThickness,
    this.hasManhole = false,
    this.hasStandProvisions = false,
    this.isWifiEnabled = false,
    this.extraNote,
    this.isIncludedInHp = false,
  })  : material = innerTankMaterial ?? material ?? outerCladdingMaterial ?? 'GI',
        shellThicknessMm = shellThicknessMm ?? (innerTankThickness != null ? 3 : 3),
        dishThicknessMm = dishThicknessMm ?? (outerCladdingThickness != null ? 3 : 3),
        insulation = insulation ?? (insulationMaterial != null ? '$insulationThickness $insulationMaterial' : '50 mm with Puff Insulation');

  String get innerTankMaterial => material;
  String get innerTankThickness => '${shellThicknessMm}mm';
  String get outerCladdingThickness => '${dishThicknessMm}mm';
  String get outerCladdingMaterial => material;
  String get insulationMaterial => insulation.contains('Rockwool') ? 'Rockwool' : 'PUF';
  String get insulationThickness => '50mm';

  /// Generates clean description without stray commas or empty parentheses
  String get generatedDescription {
    final pressureStr = isPressurized ? 'Pressurized' : 'Non-Pressurized';
    final parts = <String>[];

    // Tank line summary
    parts.add(
        '$capacityLitres LTR Capacity, $material $pressureStr Tank, ${shellThicknessMm}mm Shell, and ${dishThicknessMm}mm Dish Thickness');

    if (insulation.isNotEmpty) {
      parts.add(insulation);
    }
    if (hasManhole && !insulation.contains('Manhole')) {
      parts.add('With 450 mm Manhole');
    }
    if (hasStandProvisions && !insulation.contains('Provisions for stand')) {
      parts.add('Other Provisions for stand');
    }
    if (isWifiEnabled) {
      parts.add('Wifi Enable System');
    }

    var desc = parts.join(', ');
    if (extraNote != null && extraNote!.trim().isNotEmpty) {
      desc = '$desc ${extraNote!.trim()}';
    }
    return desc.replaceAll(RegExp(r',\s*,'), ',').trim();
  }

  /// Converts this line into a full TankSpec for Annexure II Technical Specification table
  TankSpec toTankSpec() {
    final insulationFull = insulation.isNotEmpty ? insulation : '50 mm with Puff Insulation';

    return TankSpec(
      capacityLitres: capacityLitres,
      isPressurized: isPressurized,
      capacityAndThickness: '$capacityLitres ltr, ${shellThicknessMm}mm Shell, ${dishThicknessMm}mm Dish.',
      operatingPressure: isPressurized ? 'Up to 5 Bar' : 'Gravity / Non-Pressurized',
      testingPressure: isPressurized ? '7 bar pressure' : 'Up to 3 bar',
      hotWaterInletOutlet: '2 Inch,',
      heatPumpCirculation: '1 Inch,',
      outerTankInsulation: insulationFull,
      temperatureDrop: '3° C / 8 hour',
      innerAndOuterTank: material,
      tankDirection: 'Horizontal / Vertical',
      other: isWifiEnabled
          ? 'Additional Heat Pump Provision & Wifi Enabled System'
          : 'Other Solar Provision Additional Heat Pump Provision',
    );
  }

  TankLineItem copyWith({
    String? id,
    int? capacityLitres,
    int? qty,
    int? rate,
    String? material,
    String? innerTankMaterial,
    bool? isPressurized,
    int? shellThicknessMm,
    String? innerTankThickness,
    int? dishThicknessMm,
    String? outerCladdingThickness,
    String? insulation,
    String? insulationMaterial,
    String? insulationThickness,
    bool? hasManhole,
    bool? hasStandProvisions,
    bool? isWifiEnabled,
    String? extraNote,
    bool? isIncludedInHp,
  }) {
    return TankLineItem(
      id: id ?? this.id,
      capacityLitres: capacityLitres ?? this.capacityLitres,
      qty: qty ?? this.qty,
      rate: rate ?? this.rate,
      material: material ?? innerTankMaterial ?? this.material,
      isPressurized: isPressurized ?? this.isPressurized,
      shellThicknessMm: shellThicknessMm ?? this.shellThicknessMm,
      dishThicknessMm: dishThicknessMm ?? this.dishThicknessMm,
      insulation: insulation ?? this.insulation,
      hasManhole: hasManhole ?? this.hasManhole,
      hasStandProvisions: hasStandProvisions ?? this.hasStandProvisions,
      isWifiEnabled: isWifiEnabled ?? this.isWifiEnabled,
      extraNote: extraNote ?? this.extraNote,
      isIncludedInHp: isIncludedInHp ?? this.isIncludedInHp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'capacityLitres': capacityLitres,
        'qty': qty,
        'rate': rate,
        'material': material,
        'isPressurized': isPressurized,
        'shellThicknessMm': shellThicknessMm,
        'dishThicknessMm': dishThicknessMm,
        'insulation': insulation,
        'hasManhole': hasManhole,
        'hasStandProvisions': hasStandProvisions,
        'isWifiEnabled': isWifiEnabled,
        'extraNote': extraNote,
        'isIncludedInHp': isIncludedInHp,
      };

  factory TankLineItem.fromJson(Map<String, dynamic> json) => TankLineItem(
        id: json['id'] as String? ?? 'tank_1',
        capacityLitres: (json['capacityLitres'] as num?)?.toInt() ?? 500,
        qty: (json['qty'] as num?)?.toInt() ?? 1,
        rate: (json['rate'] as num?)?.toInt() ?? 0,
        material: json['material'] as String? ?? json['innerTankMaterial'] as String? ?? 'GI',
        isPressurized: json['isPressurized'] as bool? ?? true,
        shellThicknessMm: (json['shellThicknessMm'] as num?)?.toInt() ?? 3,
        dishThicknessMm: (json['dishThicknessMm'] as num?)?.toInt() ?? 3,
        insulation: json['insulation'] as String? ?? '50 mm with Puff Insulation',
        hasManhole: json['hasManhole'] as bool? ?? false,
        hasStandProvisions: json['hasStandProvisions'] as bool? ?? false,
        isWifiEnabled: json['isWifiEnabled'] as bool? ?? false,
        extraNote: json['extraNote'] as String?,
        isIncludedInHp: json['isIncludedInHp'] as bool? ?? false,
      );
}
