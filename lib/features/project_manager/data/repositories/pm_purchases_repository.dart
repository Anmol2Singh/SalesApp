import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pm_purchase.dart';

class PmPurchasesRepository {
  final SupabaseClient _supabase;

  PmPurchasesRepository(this._supabase);

  /// Fetch all purchases/vendors for a company
  Future<List<PmPurchase>> getPurchases({
    required String companyId,
  }) async {
    final response = await _supabase
        .from('pm_purchases')
        .select('*')
        .eq('company_id', companyId)
        .order('id_no', ascending: false);

    final rawList = response as List<dynamic>;
    if (rawList.isEmpty) return [];

    final purchaseIds = rawList.map((e) => e['id'] as String).toList();
    final callDateMap = <String, DateTime>{};
    final callRemarkMap = <String, String>{};

    try {
      final callRecordsRes = await _supabase
          .from('pm_calling_records')
          .select('purchase_id, date, description')
          .inFilter('purchase_id', purchaseIds)
          .order('date', ascending: false);

      for (final rec in (callRecordsRes as List<dynamic>)) {
        final pid = rec['purchase_id'] as String?;
        final dStr = rec['date'] as String?;
        if (pid == null || dStr == null) continue;
        final d = DateTime.tryParse(dStr);
        if (d != null) {
          if (!callDateMap.containsKey(pid) || d.isAfter(callDateMap[pid]!)) {
            callDateMap[pid] = d;
          }
        }
        if (!callRemarkMap.containsKey(pid) && rec['description'] != null) {
          callRemarkMap[pid] = rec['description'] as String;
        }
      }
    } catch (_) {}

    return rawList.map((json) {
      final map = Map<String, dynamic>.from(json);
      final id = map['id'] as String;
      if (callDateMap.containsKey(id)) {
        map['reminder_date'] = callDateMap[id]!.toIso8601String();
      }
      if (callRemarkMap.containsKey(id)) {
        map['last_call_remark'] = callRemarkMap[id];
      }
      return PmPurchase.fromJson(map);
    }).toList();
  }

  /// Fetch a single vendor by id
  Future<PmPurchase?> getPurchaseById(String id) async {
    final response = await _supabase
        .from('pm_purchases')
        .select('*')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return PmPurchase.fromJson(Map<String, dynamic>.from(response));
  }

  /// Create a new vendor record
  Future<PmPurchase> createPurchase(Map<String, dynamic> data) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null && !data.containsKey('created_by')) {
      data['created_by'] = userId;
    }

    final response = await _supabase
        .from('pm_purchases')
        .insert(data)
        .select('*')
        .single();

    return PmPurchase.fromJson(Map<String, dynamic>.from(response));
  }

  /// Update an existing vendor
  Future<PmPurchase> updatePurchase(String id, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    final response = await _supabase
        .from('pm_purchases')
        .update(data)
        .eq('id', id)
        .select('*')
        .single();

    return PmPurchase.fromJson(Map<String, dynamic>.from(response));
  }

  /// Delete a vendor
  Future<void> deletePurchase(String id) async {
    await _supabase.from('pm_purchases').delete().eq('id', id);
  }

  /// Bulk delete vendors
  Future<void> bulkDeletePurchases(List<String> ids) async {
    if (ids.isEmpty) return;
    await _supabase.from('pm_purchases').delete().inFilter('id', ids);
  }

  /// Get next ID number for vendor
  Future<int> getNextIdNo() async {
    try {
      final res = await _supabase
          .from('pm_purchases')
          .select('id_no')
          .order('id_no', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null && res['id_no'] != null) {
        return (res['id_no'] as num).toInt() + 1;
      }
    } catch (_) {}
    return 1001;
  }

  /// Recalculate totals from purchase ledger entries
  Future<void> syncPurchaseTotals(String purchaseId) async {
    final entriesRes = await _supabase
        .from('pm_purchase_ledger_entries')
        .select('*')
        .eq('purchase_id', purchaseId)
        .order('sr_no', ascending: true);

    final entries = (entriesRes as List<dynamic>);

    double totalQuotation = 0;
    double totalPaid = 0;

    for (final e in entries) {
      totalQuotation += (e['quotation_value'] ?? e['order_value'] as num?)?.toDouble() ?? 0;
      totalPaid += (e['payment_paid'] ?? e['payment_received'] as num?)?.toDouble() ?? 0;
    }

    final existing = await _supabase
        .from('pm_purchases')
        .select('quotation_value, order_value')
        .eq('id', purchaseId)
        .maybeSingle();

    final initialQuot = (existing?['quotation_value'] ?? existing?['order_value'] as num?)?.toDouble() ?? 0;
    final finalQuot = totalQuotation > 0 ? totalQuotation : initialQuot;
    final balance = finalQuot - totalPaid;

    await _supabase.from('pm_purchases').update({
      'quotation_value': finalQuot,
      'order_value': finalQuot,
      'payment_paid': totalPaid,
      'payment_received': totalPaid,
      'balance': balance,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', purchaseId);
  }
}
