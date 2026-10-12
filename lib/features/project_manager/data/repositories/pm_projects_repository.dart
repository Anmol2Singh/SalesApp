import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pm_project.dart';

class PmProjectsRepository {
  final SupabaseClient _supabase;

  PmProjectsRepository(this._supabase);

  /// Fetch all projects for a company, joining customer details
  Future<List<PmProject>> getProjects({
    required String companyId,
    String? searchQuery,
  }) async {
    // 1. Fetch projects with joined customer
    final response = await _supabase
        .from('pm_projects')
        .select('''
          *,
          customers!inner (
            id, customer_name, company_name, contact_person, phone, email, address, gst_number, created_by, created_at, updated_at
          )
        ''')
        .eq('company_id', companyId)
        .order('id_no', ascending: false);

    final rawList = response as List<dynamic>;
    if (rawList.isEmpty) return [];

    final projectIds = rawList.map((e) => e['id'] as String).toList();

    // 2. Fetch latest calling record dates and remarks for these projects
    final callDateMap = <String, DateTime>{};
    final callRemarkMap = <String, String>{};

    try {
      final callRecordsRes = await _supabase
          .from('pm_calling_records')
          .select('project_id, date, description')
          .inFilter('project_id', projectIds)
          .order('date', ascending: false);

      for (final rec in (callRecordsRes as List<dynamic>)) {
        final pid = rec['project_id'] as String?;
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
      return PmProject.fromJson(map);
    }).toList();
  }

  /// Fetch a single project with its joined customer
  Future<PmProject?> getProjectById(String id) async {
    final response = await _supabase
        .from('pm_projects')
        .select('''
          *,
          customers!inner (
            id, customer_name, company_name, contact_person, phone, email, address, gst_number, created_by, created_at, updated_at
          )
        ''')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return PmProject.fromJson(Map<String, dynamic>.from(response));
  }

  /// Create a new project linked to an existing customer
  Future<PmProject> createProject(Map<String, dynamic> data) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null && !data.containsKey('created_by')) {
      data['created_by'] = userId;
    }

    final response = await _supabase
        .from('pm_projects')
        .insert(data)
        .select('''
          *,
          customers!inner (
            id, customer_name, company_name, contact_person, phone, email, address, gst_number, created_by, created_at, updated_at
          )
        ''')
        .single();

    return PmProject.fromJson(Map<String, dynamic>.from(response));
  }

  /// Update an existing project
  Future<PmProject> updateProject(String id, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    final response = await _supabase
        .from('pm_projects')
        .update(data)
        .eq('id', id)
        .select('''
          *,
          customers!inner (
            id, customer_name, company_name, contact_person, phone, email, address, gst_number, created_by, created_at, updated_at
          )
        ''')
        .single();

    return PmProject.fromJson(Map<String, dynamic>.from(response));
  }

  /// Delete a project
  Future<void> deleteProject(String id) async {
    await _supabase.from('pm_projects').delete().eq('id', id);
  }

  /// Bulk delete projects
  Future<void> bulkDeleteProjects(List<String> ids) async {
    if (ids.isEmpty) return;
    await _supabase.from('pm_projects').delete().inFilter('id', ids);
  }

  /// Get the next available ID number
  Future<int> getNextIdNo() async {
    try {
      final res = await _supabase
          .from('pm_projects')
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

  /// Recalculate and synchronize project financial totals from its ledger entries
  Future<void> syncProjectTotals(String projectId) async {
    final entriesRes = await _supabase
        .from('pm_ledger_entries')
        .select('*')
        .eq('project_id', projectId)
        .order('sr_no', ascending: true);

    final entries = (entriesRes as List<dynamic>);
    if (entries.isEmpty) return;

    double totalSalesM = 0;
    double totalMOutward = 0;
    double totalOrder = 0;
    double totalExtraWork = 0;
    double totalPaymentReceived = 0;

    for (final e in entries) {
      totalSalesM += (e['sales_m_value'] as num?)?.toDouble() ?? 0;
      totalMOutward += (e['m_outward_value'] as num?)?.toDouble() ?? 0;
      totalOrder += (e['order_value'] as num?)?.toDouble() ?? 0;
      totalExtraWork += (e['extra_work_value'] as num?)?.toDouble() ?? 0;
      totalPaymentReceived += (e['payment_received'] as num?)?.toDouble() ?? 0;
    }

    final existing = await _supabase
        .from('pm_projects')
        .select('order_value')
        .eq('id', projectId)
        .maybeSingle();

    final finalOrder = totalOrder > 0
        ? totalOrder
        : ((existing?['order_value'] as num?)?.toDouble() ?? 0);

    await _supabase.from('pm_projects').update({
      'sales_m_value': totalSalesM,
      'm_outward_value': totalMOutward,
      'm_balance': totalSalesM - totalMOutward,
      'order_value': finalOrder,
      'extra_work_value': totalExtraWork,
      'payment_received': totalPaymentReceived,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', projectId);
  }
}
