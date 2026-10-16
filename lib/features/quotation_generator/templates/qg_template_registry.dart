// lib/features/quotation_generator/templates/qg_template_registry.dart

import 'heat_pump_template.dart';
import 'boom_barrier_template.dart';
import 'qg_product_template.dart';

/// Central registry of product proposal templates in quotation_generator module.
class QgTemplateRegistry {
  static const List<QgProductTemplate> _templates = [
    HeatPumpTemplate(),
    BoomBarrierTemplate(),
  ];

  /// Returns all registered product templates.
  static List<QgProductTemplate> get allTemplates => List.unmodifiable(_templates);

  /// Resolves a template by product name (e.g. "Heat Pump", "Boom Barrier").
  static QgProductTemplate? findTemplateForProduct(String productName) {
    if (productName.trim().isEmpty) return null;
    for (final t in _templates) {
      if (t.matchesProduct(productName)) {
        return t;
      }
    }
    return null;
  }

  /// Resolves a template by its key (e.g. 'heat_pump_proposal', 'boom_barrier_quotation').
  static QgProductTemplate? findTemplateByKey(String key) {
    for (final t in _templates) {
      if (t.key == key) {
        return t;
      }
    }
    return null;
  }

  /// Default union of product name search terms across all registered templates.
  static const List<String> defaultProductFilter = [
    'Heat Pump',
    'Heatpump',
    'Boom Barrier',
    'Boom barrier',
    'boom barrier',
    'BoomBarrier',
    'Barrier',
  ];
}
