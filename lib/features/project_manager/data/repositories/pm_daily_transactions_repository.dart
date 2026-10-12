import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pm_daily_transaction.dart';

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
}
