// lib/features/quotation_generator/services/qg_drafts_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/qg_proposal_draft.dart';

/// Manages persistence of proposal drafts in Supabase database and local fallback.
/// Strictly persists over database so all devices and Web can access synced drafts.
class QgDraftsService {
  static const String _boxName = 'qg_drafts';
  static Box<dynamic>? _box;

  static SupabaseClient get _supabase => Supabase.instance.client;

  static Future<Box<dynamic>> _getBox() async {
    if (_box != null && _box!.isOpen) {
      return _box!;
    }
    _box = await Hive.openBox(_boxName);
    return _box!;
  }

  /// Saves a draft directly over database (quotations.product_specs) and locally.
  static Future<void> saveDraft(QgProposalDraft draft, {SupabaseClient? client}) async {
    draft.draftUpdatedAt = DateTime.now();

    // 1. Save over database
    try {
      final supabase = client ?? _supabase;
      Map<String, dynamic> existingSpecs = {};

      try {
        final row = await supabase
            .from('quotations')
            .select('product_specs')
            .eq('id', draft.quotationId)
            .maybeSingle();

        if (row != null && row['product_specs'] is Map) {
          existingSpecs = Map<String, dynamic>.from(row['product_specs'] as Map);
        }
      } catch (e) {
        debugPrint('QgDraftsService.saveDraft DB read error: $e');
      }

      existingSpecs['qg_proposal_draft'] = draft.toJson();
      if (draft.hasTank) {
        existingSpecs['tank_spec'] = {
          'material': draft.tankMaterial,
          'capacity': draft.tankCapacityLitres,
          'shell_thickness': draft.tankShellThickness,
          'dish_thickness': draft.tankDishThickness,
          'insulation': draft.tankInsulation,
          'is_pressurized': draft.isTankPressurized,
          'specs_table': draft.tankSpecs,
        };
      }

      await supabase
          .from('quotations')
          .update({'product_specs': existingSpecs})
          .eq('id', draft.quotationId);

      debugPrint('QgDraftsService: Saved draft to database for quotation ${draft.quotationId}');
    } catch (e) {
      debugPrint('QgDraftsService.saveDraft DB update error: $e');
    }

    // 2. Also keep local fallback
    try {
      final box = await _getBox();
      final key = 'qg_draft_${draft.quotationId}';
      await box.put(key, draft.toJson());
    } catch (e) {
      debugPrint('QgDraftsService.saveDraft local box error: $e');
    }
  }

  /// Loads an existing draft from database first, falling back to local storage.
  static Future<QgProposalDraft?> loadDraft(String quotationId, {SupabaseClient? client}) async {
    // 1. Fetch from database first
    try {
      final supabase = client ?? _supabase;
      final row = await supabase
          .from('quotations')
          .select('product_specs')
          .eq('id', quotationId)
          .maybeSingle();

      if (row != null && row['product_specs'] is Map) {
        final specs = Map<String, dynamic>.from(row['product_specs'] as Map);
        if (specs['qg_proposal_draft'] is Map) {
          debugPrint('QgDraftsService: Loaded draft from database for quotation $quotationId');
          return QgProposalDraft.fromJson(Map<String, dynamic>.from(specs['qg_proposal_draft'] as Map));
        }
      }
    } catch (e) {
      debugPrint('QgDraftsService.loadDraft DB error: $e');
    }

    // 2. Fallback to local box
    try {
      final box = await _getBox();
      final key = 'qg_draft_$quotationId';
      final data = box.get(key);
      if (data == null) return null;
      if (data is Map) {
        return QgProposalDraft.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      debugPrint('QgDraftsService.loadDraft local error: $e');
      return null;
    }
  }

  /// Checks whether a draft exists for the given quotation.
  static Future<bool> hasDraft(String quotationId, {SupabaseClient? client}) async {
    final d = await loadDraft(quotationId, client: client);
    return d != null;
  }

  /// Deletes draft from database and local storage.
  static Future<void> deleteDraft(String quotationId, {SupabaseClient? client}) async {
    try {
      final supabase = client ?? _supabase;
      final row = await supabase
          .from('quotations')
          .select('product_specs')
          .eq('id', quotationId)
          .maybeSingle();

      if (row != null && row['product_specs'] is Map) {
        final specs = Map<String, dynamic>.from(row['product_specs'] as Map);
        specs.remove('qg_proposal_draft');
        await supabase
            .from('quotations')
            .update({'product_specs': specs})
            .eq('id', quotationId);
      }
      debugPrint('QgDraftsService: Deleted database draft for quotation $quotationId');
    } catch (e) {
      debugPrint('QgDraftsService.deleteDraft DB error: $e');
    }

    try {
      final box = await _getBox();
      final key = 'qg_draft_$quotationId';
      await box.delete(key);
    } catch (e) {
      debugPrint('QgDraftsService.deleteDraft local error: $e');
    }
  }
}
