// lib/features/quotation_generator/data/qg_settings_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for module-owned settings, catalog, templates and text blocks.
/// Replaces legacy reads/writes to `pdf_templates`. All data is stored in `qg_*` tables.
class QgSettingsRepository {
  final SupabaseClient _supabase;

  // In-memory cache for offline resiliency
  final Map<String, dynamic> _cache = {};

  QgSettingsRepository(this._supabase);

  // --------------------------------------------------------------------------
  // Settings (Company, Bank, Defaults, Presets)
  // --------------------------------------------------------------------------

  Future<Map<String, dynamic>> getSetting(String key, {Map<String, dynamic>? fallback}) async {
    if (_cache.containsKey('setting_$key')) {
      return Map<String, dynamic>.from(_cache['setting_$key'] as Map);
    }
    try {
      final res = await _supabase
          .from('qg_settings')
          .select('value')
          .eq('key', key)
          .maybeSingle();

      if (res != null && res['value'] is Map) {
        final val = Map<String, dynamic>.from(res['value'] as Map);
        _cache['setting_$key'] = val;
        return val;
      }
    } catch (e) {
      debugPrint('QgSettingsRepository.getSetting("$key") error: $e');
    }
    return fallback ?? {};
  }

  Future<void> saveSetting(String key, Map<String, dynamic> value) async {
    _cache['setting_$key'] = value;
    try {
      await _supabase.from('qg_settings').upsert({
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('QgSettingsRepository.saveSetting("$key") error: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // Categories & Spec Templates
  // --------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final res = await _supabase
          .from('qg_categories')
          .select()
          .order('sort_order', ascending: true);
      return res.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('QgSettingsRepository.getCategories error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSpecTemplate(String categoryId) async {
    try {
      final res = await _supabase
          .from('qg_spec_templates')
          .select()
          .eq('category_id', categoryId)
          .maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint('QgSettingsRepository.getSpecTemplate error: $e');
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // Catalog Items
  // --------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getCatalogItems({String? kind}) async {
    try {
      var query = _supabase.from('qg_catalog').select().eq('is_active', true);
      if (kind != null) {
        query = query.eq('kind', kind);
      }
      final res = await query.order('kw', ascending: true);
      return res.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('QgSettingsRepository.getCatalogItems error: $e');
      return [];
    }
  }

  // --------------------------------------------------------------------------
  // Text Blocks & Aliases
  // --------------------------------------------------------------------------

  Future<Map<String, String>> getTextBlocks() async {
    try {
      final res = await _supabase.from('qg_text_blocks').select('key, text_content');
      final Map<String, String> map = {};
      for (final r in res) {
        final k = r['key'] as String?;
        final v = r['text_content'] as String?;
        if (k != null && v != null) map[k] = v;
      }
      return map;
    } catch (e) {
      debugPrint('QgSettingsRepository.getTextBlocks error: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getItemAliases() async {
    try {
      final res = await _supabase.from('qg_item_aliases').select();
      return res.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('QgSettingsRepository.getItemAliases error: $e');
      return [];
    }
  }
}
