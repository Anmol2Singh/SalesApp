// lib/features/quotation_generator/services/tank_spec_options_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TankSpecOptionsService {
  static const String categoryMaterial = 'tank_material';
  static const String categoryInsulation = 'insulation_type';
  static const String categoryShellThickness = 'shell_thickness';
  static const String categoryDishThickness = 'dish_thickness';

  static const Map<String, List<String>> defaultOptions = {
    categoryMaterial: ['GI', 'MS', 'Enamel', 'SS'],
    categoryInsulation: ['Puff', 'Rockwool', 'Custom'],
    categoryShellThickness: ['2mm', '3mm', '4mm', '5mm', '6mm'],
    categoryDishThickness: ['2mm', '3mm', '4mm', '5mm', '6mm'],
  };

  static List<String> getDefaults(String category) {
    return List<String>.from(defaultOptions[category] ?? []);
  }

  static final Map<String, List<String>> _cache = {};

  static SupabaseClient get _supabase => Supabase.instance.client;

  /// Loads options from database, with fallback to in-memory cache and defaults.
  static Future<List<String>> getOptions(String category, {SupabaseClient? client}) async {
    try {
      final supabase = client ?? _supabase;
      final rows = await supabase
          .from('tank_spec_dropdown_options')
          .select('label')
          .eq('category', category)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);

      if (rows.isNotEmpty) {
        final list = rows
            .map((r) => r['label']?.toString().trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (list.isNotEmpty) {
          _cache[category] = list;
          return list;
        }
      }
    } catch (e) {
      debugPrint('TankSpecOptionsService.getOptions("$category") error: $e');
    }

    if (_cache.containsKey(category) && _cache[category]!.isNotEmpty) {
      return List<String>.from(_cache[category]!);
    }
    return List<String>.from(defaultOptions[category] ?? []);
  }

  /// Adds a new option to the database for the given category.
  static Future<List<String>> addOption(String category, String label, {SupabaseClient? client}) async {
    final clean = label.trim();
    if (clean.isEmpty) return getOptions(category, client: client);

    try {
      final supabase = client ?? _supabase;
      final current = await getOptions(category, client: client);
      if (current.any((it) => it.toLowerCase() == clean.toLowerCase())) {
        return current;
      }

      final nextSort = current.length + 1;
      await supabase.from('tank_spec_dropdown_options').insert({
        'category': category,
        'label': clean,
        'sort_order': nextSort,
      });

      current.add(clean);
      _cache[category] = current;
      return current;
    } catch (e) {
      debugPrint('TankSpecOptionsService.addOption error: $e');
      rethrow;
    }
  }

  /// Deletes an option from the database for the given category.
  static Future<List<String>> deleteOption(String category, String label, {SupabaseClient? client}) async {
    final clean = label.trim();
    try {
      final supabase = client ?? _supabase;
      await supabase
          .from('tank_spec_dropdown_options')
          .delete()
          .eq('category', category)
          .eq('label', clean);

      final current = await getOptions(category, client: client);
      current.removeWhere((it) => it.toLowerCase() == clean.toLowerCase());
      _cache[category] = current;
      return current;
    } catch (e) {
      debugPrint('TankSpecOptionsService.deleteOption error: $e');
      rethrow;
    }
  }
}
