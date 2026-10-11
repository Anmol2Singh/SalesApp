// lib/features/quotation_generator/config/quote_type.dart

import 'package:flutter/material.dart';

enum QuoteType {
  hpWithTank,
  hpOnly,
  tankOnly,
  partsOnly,
  swimmingPool,
  allInOneFloor,
  allInOneWall,
}

extension QuoteTypeX on QuoteType {
  String get id => name;
  String get label => displayName;
  Color get accentColor => color;

  String get displayName {
    switch (this) {
      case QuoteType.hpWithTank:
        return 'Heat Pump + Tank';
      case QuoteType.hpOnly:
        return 'Heat Pump Only';
      case QuoteType.tankOnly:
        return 'Storage Tank Only';
      case QuoteType.partsOnly:
        return 'Parts & Accessories';
      case QuoteType.swimmingPool:
        return 'Swimming Pool Heat Pump';
      case QuoteType.allInOneFloor:
        return 'All In One (Floor Mounted)';
      case QuoteType.allInOneWall:
        return 'All In One (Wall Mounted)';
    }
  }

  String get shortCode {
    switch (this) {
      case QuoteType.hpWithTank:
        return 'HP+Tank';
      case QuoteType.hpOnly:
        return 'HP Only';
      case QuoteType.tankOnly:
        return 'Tank';
      case QuoteType.partsOnly:
        return 'Parts';
      case QuoteType.swimmingPool:
        return 'Pool';
      case QuoteType.allInOneFloor:
        return 'AIO Floor';
      case QuoteType.allInOneWall:
        return 'AIO Wall';
    }
  }

  String get description {
    switch (this) {
      case QuoteType.hpWithTank:
        return 'Air source heat pump combined with pressurized or non-pressurized storage tank (GI/MS/Enamel).';
      case QuoteType.hpOnly:
        return 'Commercial & domestic air source heat pump unit with stand (standalone machine).';
      case QuoteType.tankOnly:
        return 'Hot water storage or solar water heater tank with puff/rockwool insulation.';
      case QuoteType.partsOnly:
        return 'Spare parts, return line circulation pumps, electrical controllers and accessories.';
      case QuoteType.swimmingPool:
        return 'Dedicated pool heating system with titanium heat exchanger and weather protection.';
      case QuoteType.allInOneFloor:
        return 'Integrated compact top-blow unit with internal 200L enamel coated tank.';
      case QuoteType.allInOneWall:
        return 'Space-saving wall mounted top-blow unit with internal 100L enamel tank.';
    }
  }

  IconData get icon {
    switch (this) {
      case QuoteType.hpWithTank:
        return Icons.water_damage_outlined;
      case QuoteType.hpOnly:
        return Icons.hvac_outlined;
      case QuoteType.tankOnly:
        return Icons.storage_outlined;
      case QuoteType.partsOnly:
        return Icons.settings_suggest_outlined;
      case QuoteType.swimmingPool:
        return Icons.pool_outlined;
      case QuoteType.allInOneFloor:
        return Icons.kitchen_outlined;
      case QuoteType.allInOneWall:
        return Icons.view_sidebar_outlined;
    }
  }

  Color get color {
    switch (this) {
      case QuoteType.hpWithTank:
        return const Color(0xFF0284C7);
      case QuoteType.hpOnly:
        return const Color(0xFF2563EB);
      case QuoteType.tankOnly:
        return const Color(0xFF0D9488);
      case QuoteType.partsOnly:
        return const Color(0xFFD97706);
      case QuoteType.swimmingPool:
        return const Color(0xFF0891B2);
      case QuoteType.allInOneFloor:
        return const Color(0xFF7C3AED);
      case QuoteType.allInOneWall:
        return const Color(0xFF4F46E5);
    }
  }
}

class QuoteTypeExtension {
  static QuoteType fromId(String? id) {
    if (id == null) return QuoteType.hpWithTank;
    final clean = id.trim().toLowerCase().replaceAll('_', '');
    for (final v in QuoteType.values) {
      if (v.name.toLowerCase() == clean) return v;
    }
    return QuoteType.hpWithTank;
  }
}
