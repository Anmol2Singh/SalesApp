// lib/features/quotation_generator/services/qg_drafts_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/qg_proposal_draft.dart';

/// Manages local offline persistence of proposal drafts in Hive.
/// Box is prefixed with `qg_` per isolation rules.
class QgDraftsService {
  static const String _boxName = 'qg_drafts';
  static Box<dynamic>? _box;

  static Future<Box<dynamic>> _getBox() async {
    if (_box != null && _box!.isOpen) {
      return _box!;
    }
    _box = await Hive.openBox(_boxName);
    return _box!;
  }

  /// Saves a draft locally to Hive.
  static Future<void> saveDraft(QgProposalDraft draft) async {
    try {
      final box = await _getBox();
      final key = 'qg_draft_${draft.quotationId}';
      draft.draftUpdatedAt = DateTime.now();
      await box.put(key, draft.toJson());
      debugPrint('QgDraftsService: Saved local draft for quotation ${draft.quotationId}');
    } catch (e) {
      debugPrint('QgDraftsService.saveDraft error: $e');
    }
  }

  /// Loads an existing draft for a quotation if one exists.
  static Future<QgProposalDraft?> loadDraft(String quotationId) async {
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
      debugPrint('QgDraftsService.loadDraft error: $e');
      return null;
    }
  }

  /// Checks whether a local draft exists for the given quotation.
  static Future<bool> hasDraft(String quotationId) async {
    try {
      final box = await _getBox();
      final key = 'qg_draft_$quotationId';
      return box.containsKey(key);
    } catch (e) {
      return false;
    }
  }

  /// Deletes a local draft (e.g. when user clicks 'Reset to Deal Quotation' or after finalization).
  static Future<void> deleteDraft(String quotationId) async {
    try {
      final box = await _getBox();
      final key = 'qg_draft_$quotationId';
      await box.delete(key);
      debugPrint('QgDraftsService: Deleted local draft for quotation $quotationId');
    } catch (e) {
      debugPrint('QgDraftsService.deleteDraft error: $e');
    }
  }
}
