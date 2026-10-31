import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pm_daily_transaction.dart';
import '../models/pm_transaction_purpose.dart';

class PmDailyTransactionsRepository {
  final SupabaseClient _supabase;

  PmDailyTransactionsRepository(this._supabase);

  /// Fetch daily transactions for a company, ordered by date desc, sr_no desc
  Future<List<PmDailyTransaction>> getDailyTransactions({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
    String? firmName,
    String? partyName,
    String? paymentMode,
    String? transactionName,
    String? entryNature,
    String? flowType,
  }) async {
    var query = _supabase
        .from('pm_daily_transactions')
        .select('*')
        .eq('company_id', companyId);

    if (startDate != null) {
      query = query.gte('date', startDate.toIso8601String().split('T').first);
    }
    if (endDate != null) {
      query = query.lte('date', endDate.toIso8601String().split('T').first);
    }
    if (firmName != null && firmName != 'ALL') {
      query = query.eq('firm_name', firmName);
    }
    if (partyName != null && partyName != 'ALL') {
      query = query.eq('party_name', partyName);
    }
    if (paymentMode != null && paymentMode != 'ALL') {
      query = query.eq('payment_mode', paymentMode);
    }
    if (transactionName != null && transactionName != 'ALL') {
      query = query.eq('transaction_name', transactionName);
    }
    if (entryNature != null && entryNature != 'ALL') {
      query = query.eq('entry_nature', entryNature);
    }
    if (flowType != null && flowType != 'ALL') {
      query = query.eq('type', flowType);
    }

    final res = await query
        .order('date', ascending: false)
        .order('sr_no', ascending: false);

    return (res as List<dynamic>).map((e) => PmDailyTransaction.fromJson(e)).toList();
  }

  /// Create a transaction entry
  Future<PmDailyTransaction> createTransaction(Map<String, dynamic> data) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null && !data.containsKey('created_by')) {
      data['created_by'] = userId;
    }
    final res = await _supabase.from('pm_daily_transactions').insert(data).select().single();
    return PmDailyTransaction.fromJson(res);
  }

  /// Update an entry
  Future<PmDailyTransaction> updateTransaction(String id, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    final res = await _supabase.from('pm_daily_transactions').update(data).eq('id', id).select().single();
    return PmDailyTransaction.fromJson(res);
  }

  /// Delete an entry
  Future<void> deleteTransaction(String id) async {
    await _supabase.from('pm_daily_transactions').delete().eq('id', id);
  }

  /// Bulk delete entries
  Future<void> bulkDeleteTransactions(List<String> ids) async {
    if (ids.isEmpty) return;
    await _supabase.from('pm_daily_transactions').delete().inFilter('id', ids);
  }

  /// Next Sr No for date
  Future<int> getNextSrNo(String companyId, DateTime date) async {
    try {
      final res = await _supabase
          .from('pm_daily_transactions')
          .select('sr_no')
          .eq('company_id', companyId)
          .eq('date', date.toIso8601String().split('T').first)
          .order('sr_no', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null && res['sr_no'] != null) {
        return (res['sr_no'] as num).toInt() + 1;
      }
    } catch (_) {}
    return 1;
  }

  static const List<PmTransactionPurpose> defaultPurposes = [
    PmTransactionPurpose(id: '1', name: 'Advance Payment', sortOrder: 1),
    PmTransactionPurpose(id: '2', name: 'Final Payment', sortOrder: 2),
    PmTransactionPurpose(id: '3', name: 'Material Purchase', sortOrder: 3),
    PmTransactionPurpose(id: '4', name: 'Transport / Freight', sortOrder: 4),
    PmTransactionPurpose(id: '5', name: 'Labour / Installation', sortOrder: 5),
    PmTransactionPurpose(id: '6', name: 'Site Expenses', sortOrder: 6),
    PmTransactionPurpose(id: '7', name: 'Office Expense', sortOrder: 7),
    PmTransactionPurpose(id: '8', name: 'Salary / Wages', sortOrder: 8),
    PmTransactionPurpose(id: '9', name: 'Vendor Payment', sortOrder: 9),
    PmTransactionPurpose(id: '10', name: 'Customer Receipt', sortOrder: 10),
    PmTransactionPurpose(id: '11', name: 'Refund', sortOrder: 11),
    PmTransactionPurpose(id: '12', name: 'Miscellaneous', sortOrder: 12),
  ];

  /// Get transaction purposes
  Future<List<PmTransactionPurpose>> getTransactionPurposes() async {
    try {
      final res = await _supabase
          .from('pm_transaction_purposes')
          .select('*')
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);
      final list = (res as List<dynamic>).map((e) => PmTransactionPurpose.fromJson(e)).toList();
      if (list.isNotEmpty) return list;
    } catch (_) {
      // Fall through to defaults if table not yet migrated or offline
    }
    return defaultPurposes;
  }

  /// Create purpose
  Future<PmTransactionPurpose> createTransactionPurpose(String name) async {
    final trimmed = name.trim();
    final res = await _supabase
        .from('pm_transaction_purposes')
        .insert({'name': trimmed})
        .select()
        .single();
    return PmTransactionPurpose.fromJson(res);
  }

  /// Update purpose
  Future<PmTransactionPurpose> updateTransactionPurpose(String id, String newName) async {
    final trimmed = newName.trim();
    final res = await _supabase
        .from('pm_transaction_purposes')
        .update({'name': trimmed, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return PmTransactionPurpose.fromJson(res);
  }

  /// Delete purpose
  Future<void> deleteTransactionPurpose(String id) async {
    await _supabase.from('pm_transaction_purposes').delete().eq('id', id);
  }
}
