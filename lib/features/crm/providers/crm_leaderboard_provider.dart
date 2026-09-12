// lib/features/crm/providers/crm_leaderboard_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/models/crm_leaderboard_entry.dart';

// CRM Leaderboard provider - Completely independent from complaints leaderboard
final crmLeaderboardProvider = FutureProvider<List<CrmLeaderboardEntry>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  try {
    // Primary: Call SECURITY DEFINER RPC to get company-wide global leaderboard
    final rpcResponse = await supabase.rpc('get_crm_leaderboard');
    if (rpcResponse is List && rpcResponse.isNotEmpty) {
      final entries = rpcResponse.map((row) {
        final r = row as Map<String, dynamic>;
        return CrmLeaderboardEntry(
          userId: r['user_id'] as String? ?? '',
          userName: r['user_name'] as String? ?? 'Sales Representative',
          userEmail: r['user_email'] as String?,
          totalLeads: (r['total_leads'] as num?)?.toInt() ?? 0,
          wonDeals: (r['won_deals'] as num?)?.toInt() ?? 0,
          activeLeads: (r['active_leads'] as num?)?.toInt() ?? 0,
          totalRevenue: (r['total_revenue'] as num?)?.toDouble() ?? 0.0,
          conversionRate: (r['conversion_rate'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

      entries.sort((a, b) {
        if (b.wonDeals != a.wonDeals) {
          return b.wonDeals.compareTo(a.wonDeals);
        }
        return b.totalRevenue.compareTo(a.totalRevenue);
      });

      return entries;
    }
  } catch (_) {
    // Fall back to client query if RPC is not accessible
  }

  try {
    // 1. Fetch sales profiles (role = sales or roles contains sales, or admin/manager)
    final profilesResponse = await supabase
        .from('profiles')
        .select('id, full_name, email, role, roles')
        .or('role.eq.sales,roles.cs.{"sales"},role.eq.admin,role.eq.manager');

    final profiles = List<Map<String, dynamic>>.from(profilesResponse as List);

    // 2. Fetch all leads
    final leadsResponse = await supabase
        .from('crm_leads')
        .select('id, status, estimated_value, assigned_to, created_by');

    final leads = List<Map<String, dynamic>>.from(leadsResponse as List);

    // 3. Aggregate performance per sales rep
    final List<CrmLeaderboardEntry> entries = [];

    for (final profile in profiles) {
      final userId = profile['id'] as String;
      final userName = profile['full_name'] as String? ?? 'Sales Representative';
      final email = profile['email'] as String?;

      final userLeads = leads.where((l) {
        final assigned = l['assigned_to'] as String?;
        final creator = l['created_by'] as String?;
        return assigned == userId || (assigned == null && creator == userId);
      }).toList();

      final totalLeads = userLeads.length;
      final wonLeads = userLeads.where((l) => l['status'] == 'Won').toList();
      final wonDeals = wonLeads.length;
      final activeLeads = userLeads.where((l) => l['status'] != 'Won' && l['status'] != 'Lost').length;

      double totalRevenue = 0.0;
      for (final l in wonLeads) {
        final val = l['estimated_value'];
        if (val is num) {
          totalRevenue += val.toDouble();
        } else if (val != null) {
          totalRevenue += double.tryParse(val.toString()) ?? 0.0;
        }
      }

      final conversionRate = totalLeads > 0 ? (wonDeals / totalLeads) * 100.0 : 0.0;

      entries.add(CrmLeaderboardEntry(
        userId: userId,
        userName: userName,
        userEmail: email,
        totalLeads: totalLeads,
        wonDeals: wonDeals,
        activeLeads: activeLeads,
        totalRevenue: totalRevenue,
        conversionRate: conversionRate,
      ));
    }

    entries.sort((a, b) {
      if (b.wonDeals != a.wonDeals) {
        return b.wonDeals.compareTo(a.wonDeals);
      }
      return b.totalRevenue.compareTo(a.totalRevenue);
    });

    return entries;
  } catch (_) {
    return [];
  }
});
