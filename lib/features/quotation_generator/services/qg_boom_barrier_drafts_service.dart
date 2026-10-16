// lib/features/quotation_generator/services/qg_boom_barrier_drafts_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/boom_barrier_proposal_draft.dart';

/// Manages local offline persistence of Boom Barrier proposal drafts in Hive.
/// Box name is strictly prefixed with `qg_` per module isolation rules.
class QgBoomBarrierDraftsService {
  static const String _boxName = 'qg_boom_barrier_drafts';
  static Box<dynamic>? _box;

  static Future<Box<dynamic>?> _getBox() async {
    try {
      if (_box != null && _box!.isOpen) {
        return _box!;
      }
      _box = await Hive.openBox(_boxName);
      return _box!;
    } catch (e) {
      debugPrint('QgBoomBarrierDraftsService._getBox error: $e');
      return null;
    }
  }

  /// Saves a Boom Barrier draft locally to Hive.
  static Future<void> saveDraft(BoomBarrierProposalDraft draft) async {
    try {
      final box = await _getBox();
      if (box == null) return;
      final key = 'qg_bb_draft_${draft.quotationId}';
      draft.draftUpdatedAt = DateTime.now();
      await box.put(key, draft.toJson());
      debugPrint('QgBoomBarrierDraftsService: Saved local draft for quotation ${draft.quotationId}');
    } catch (e) {
      debugPrint('QgBoomBarrierDraftsService.saveDraft error: $e');
    }
  }

  /// Loads an existing draft for a quotation if one exists.
  static Future<BoomBarrierProposalDraft?> loadDraft(String quotationId) async {
    try {
      final box = await _getBox();
      if (box == null) return null;
      final key = 'qg_bb_draft_$quotationId';
      final data = box.get(key);
      if (data == null) return null;
      if (data is Map) {
        return BoomBarrierProposalDraft.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      debugPrint('QgBoomBarrierDraftsService.loadDraft error: $e');
      return null;
    }
  }

  /// Checks whether a local draft exists for the given quotation.
  static Future<bool> hasDraft(String quotationId) async {
    try {
      final box = await _getBox();
      if (box == null) return false;
      final key = 'qg_bb_draft_$quotationId';
      return box.containsKey(key);
    } catch (e) {
      return false;
    }
  }

  /// Removes a local draft after finalization.
  static Future<void> deleteDraft(String quotationId) async {
    try {
      final box = await _getBox();
      final key = 'qg_bb_draft_$quotationId';
      await box?.delete(key);
    } catch (e) {
      debugPrint('QgBoomBarrierDraftsService.deleteDraft error: $e');
    }
  }
}
