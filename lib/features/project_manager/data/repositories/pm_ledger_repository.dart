import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pm_ledger_entry.dart';
import '../models/pm_payment_term.dart';
import '../models/pm_expense.dart';
import '../models/pm_calling_record.dart';
import '../models/pm_checklist_item.dart';
import '../models/pm_work_remark.dart';

class PmLedgerRepository {
  final SupabaseClient _supabase;

  PmLedgerRepository(this._supabase);

  // ---------------------------------------------------------------------------
  // 1. Financial Ledger Entries
  // ---------------------------------------------------------------------------
  Future<List<PmLedgerEntry>> getLedgerEntries(String recordId, {bool isPurchase = false}) async {
    final table = isPurchase ? 'pm_purchase_ledger_entries' : 'pm_ledger_entries';
    final fk = isPurchase ? 'purchase_id' : 'project_id';

    final res = await _supabase
        .from(table)
        .select('*')
        .eq(fk, recordId)
        .order('sr_no', ascending: true);

    return (res as List<dynamic>).map((e) => PmLedgerEntry.fromJson(e)).toList();
  }

  Future<PmLedgerEntry> addLedgerEntry(Map<String, dynamic> data, {bool isPurchase = false}) async {
    final table = isPurchase ? 'pm_purchase_ledger_entries' : 'pm_ledger_entries';
    final res = await _supabase.from(table).insert(data).select().single();
    return PmLedgerEntry.fromJson(res);
  }

  Future<PmLedgerEntry> updateLedgerEntry(String id, Map<String, dynamic> data, {bool isPurchase = false}) async {
    final table = isPurchase ? 'pm_purchase_ledger_entries' : 'pm_ledger_entries';
    data['updated_at'] = DateTime.now().toIso8601String();
    final res = await _supabase.from(table).update(data).eq('id', id).select().single();
    return PmLedgerEntry.fromJson(res);
  }

  Future<void> deleteLedgerEntry(String id, {bool isPurchase = false}) async {
    final table = isPurchase ? 'pm_purchase_ledger_entries' : 'pm_ledger_entries';
    await _supabase.from(table).delete().eq('id', id);
  }

  // ---------------------------------------------------------------------------
  // 2. Payment Terms (Sales mode only)
  // ---------------------------------------------------------------------------
  Future<List<PmPaymentTerm>> getPaymentTerms(String projectId) async {
    final res = await _supabase
        .from('pm_payment_terms')
        .select('*')
        .eq('project_id', projectId)
        .order('created_at', ascending: true);

    return (res as List<dynamic>).map((e) => PmPaymentTerm.fromJson(e)).toList();
  }

  Future<PmPaymentTerm> addPaymentTerm(Map<String, dynamic> data) async {
    final res = await _supabase.from('pm_payment_terms').insert(data).select().single();
    return PmPaymentTerm.fromJson(res);
  }

  Future<PmPaymentTerm> updatePaymentTerm(String id, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    final res = await _supabase.from('pm_payment_terms').update(data).eq('id', id).select().single();
    return PmPaymentTerm.fromJson(res);
  }

  Future<void> deletePaymentTerm(String id) async {
    await _supabase.from('pm_payment_terms').delete().eq('id', id);
  }

  // ---------------------------------------------------------------------------
  // 3. Project Expenses (Sales mode only)
  // ---------------------------------------------------------------------------
  Future<List<PmExpense>> getExpenses(String projectId) async {
    final res = await _supabase
        .from('pm_expenses')
        .select('*')
        .eq('project_id', projectId)
        .order('sr_no', ascending: true);

    return (res as List<dynamic>).map((e) => PmExpense.fromJson(e)).toList();
  }

  Future<PmExpense> addExpense(Map<String, dynamic> data) async {
    final res = await _supabase.from('pm_expenses').insert(data).select().single();
    return PmExpense.fromJson(res);
  }

  Future<PmExpense> updateExpense(String id, Map<String, dynamic> data) async {
    final res = await _supabase.from('pm_expenses').update(data).eq('id', id).select().single();
    return PmExpense.fromJson(res);
  }

  Future<void> deleteExpense(String id) async {
    await _supabase.from('pm_expenses').delete().eq('id', id);
  }

  // ---------------------------------------------------------------------------
  // 4. Calling Records (Sales & Purchase mode)
  // ---------------------------------------------------------------------------
  Future<List<PmCallingRecord>> getCallingRecords(String recordId, {bool isPurchase = false}) async {
    final fk = isPurchase ? 'purchase_id' : 'project_id';
    final res = await _supabase
        .from('pm_calling_records')
        .select('*')
        .eq(fk, recordId)
        .order('date', ascending: false);

    return (res as List<dynamic>).map((e) => PmCallingRecord.fromJson(e)).toList();
  }

  Future<PmCallingRecord> addCallingRecord(Map<String, dynamic> data) async {
    final res = await _supabase.from('pm_calling_records').insert(data).select().single();
    return PmCallingRecord.fromJson(res);
  }

  Future<PmCallingRecord> updateCallingRecord(String id, Map<String, dynamic> data) async {
    final res = await _supabase.from('pm_calling_records').update(data).eq('id', id).select().single();
    return PmCallingRecord.fromJson(res);
  }

  Future<void> deleteCallingRecord(String id) async {
    await _supabase.from('pm_calling_records').delete().eq('id', id);
  }

  // ---------------------------------------------------------------------------
  // 5. SWH Technical Checklist (Sales mode only)
  // ---------------------------------------------------------------------------
  Future<List<PmChecklistItem>> getChecklistItems(String projectId) async {
    final res = await _supabase
        .from('pm_swh_checklist')
        .select('*')
        .eq('project_id', projectId)
        .order('sr_no', ascending: true);

    return (res as List<dynamic>).map((e) => PmChecklistItem.fromJson(e)).toList();
  }

  Future<PmChecklistItem> addChecklistItem(Map<String, dynamic> data) async {
    final res = await _supabase.from('pm_swh_checklist').insert(data).select().single();
    return PmChecklistItem.fromJson(res);
  }

  Future<PmChecklistItem> updateChecklistItem(String id, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    final res = await _supabase.from('pm_swh_checklist').update(data).eq('id', id).select().single();
    return PmChecklistItem.fromJson(res);
  }

  Future<void> deleteChecklistItem(String id) async {
    await _supabase.from('pm_swh_checklist').delete().eq('id', id);
  }

  // ---------------------------------------------------------------------------
  // 6. Work Remarks (Sales mode only)
  // ---------------------------------------------------------------------------
  Future<List<PmWorkRemark>> getWorkRemarks(String projectId) async {
    final res = await _supabase
        .from('pm_work_remarks')
        .select('*')
        .eq('project_id', projectId)
        .order('date', ascending: false);

    return (res as List<dynamic>).map((e) => PmWorkRemark.fromJson(e)).toList();
  }

  Future<PmWorkRemark> addWorkRemark(Map<String, dynamic> data) async {
    final res = await _supabase.from('pm_work_remarks').insert(data).select().single();
    return PmWorkRemark.fromJson(res);
  }

  Future<PmWorkRemark> updateWorkRemark(String id, Map<String, dynamic> data) async {
    final res = await _supabase.from('pm_work_remarks').update(data).eq('id', id).select().single();
    return PmWorkRemark.fromJson(res);
  }

  Future<void> deleteWorkRemark(String id) async {
    await _supabase.from('pm_work_remarks').delete().eq('id', id);
  }
}
