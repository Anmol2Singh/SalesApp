// lib/features/quotation_generator/services/tank_item_parser.dart

class TankItemInfo {
  final String material;
  final int capacityLitres;
  final bool isPressurized;

  const TankItemInfo({
    required this.material,
    required this.capacityLitres,
    required this.isPressurized,
  });
}

class TankItemParser {
  /// Extracts tank specifications (material, capacity, pressurization) directly
  /// from the tank line item description / name, e.g. "GI pressurised Tank 1000Ltr".
  static TankItemInfo parse(String text) {
    final lower = text.toLowerCase();

    // Material detection
    String material = 'GI';
    if (lower.contains('enamel')) {
      material = 'Enamel';
    } else if (RegExp(r'\bms\b|mild\s*steel').hasMatch(lower)) {
      material = 'MS';
    } else if (RegExp(r'\bss\b|stainless|\bss\s*304\b|\bss\s*316\b').hasMatch(lower)) {
      material = 'SS';
    } else if (RegExp(r'\bgi\b|galvanized').hasMatch(lower)) {
      material = 'GI';
    }

    // Pressurization detection
    bool isPressurized = true;
    if (lower.contains('non-pressuri') ||
        lower.contains('non pressuri') ||
        lower.contains('nonpressuri') ||
        lower.contains('unpressuri') ||
        lower.contains('un-pressuri') ||
        lower.contains('atmospheric') ||
        lower.contains('gravity')) {
      isPressurized = false;
    } else if (lower.contains('pressuri')) {
      isPressurized = true;
    }

    // Capacity detection
    int capacity = 500;
    final match = RegExp(r'(\d+)\s*(?:ltr|lpd|l\b|liter|litres)', caseSensitive: false).firstMatch(text);
    if (match != null) {
      capacity = int.tryParse(match.group(1)!) ?? 500;
    } else {
      final bareMatch = RegExp(r'(\d+)\s*tank', caseSensitive: false).firstMatch(text);
      if (bareMatch != null) {
        capacity = int.tryParse(bareMatch.group(1)!) ?? 500;
      }
    }

    return TankItemInfo(
      material: material,
      capacityLitres: capacity,
      isPressurized: isPressurized,
    );
  }
}

