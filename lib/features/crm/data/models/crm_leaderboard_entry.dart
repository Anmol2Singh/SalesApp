// lib/features/crm/data/models/crm_leaderboard_entry.dart

class CrmLeaderboardEntry {
  final String userId;
  final String userName;
  final String? userEmail;
  final int totalLeads;
  final int wonDeals;
  final int activeLeads;
  final double totalRevenue;
  final double conversionRate;

  const CrmLeaderboardEntry({
    required this.userId,
    required this.userName,
    this.userEmail,
    required this.totalLeads,
    required this.wonDeals,
    required this.activeLeads,
    required this.totalRevenue,
    required this.conversionRate,
  });

  factory CrmLeaderboardEntry.fromMap(Map<String, dynamic> map) {
    final total = (map['total_leads'] as num?)?.toInt() ?? 0;
    final won = (map['won_deals'] as num?)?.toInt() ?? 0;
    final active = (map['active_leads'] as num?)?.toInt() ?? 0;
    final rev = (map['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final rate = total > 0 ? (won / total) * 100.0 : 0.0;

    return CrmLeaderboardEntry(
      userId: map['id'] as String? ?? map['user_id'] as String? ?? '',
      userName: map['full_name'] as String? ?? map['user_name'] as String? ?? 'Sales Representative',
      userEmail: map['email'] as String?,
      totalLeads: total,
      wonDeals: won,
      activeLeads: active,
      totalRevenue: rev,
      conversionRate: rate,
    );
  }
}
