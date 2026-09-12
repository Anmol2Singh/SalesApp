// lib/features/crm/screens/crm_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';
import '../providers/crm_providers.dart';
import '../providers/crm_leaderboard_provider.dart';
import '../data/models/crm_leaderboard_entry.dart';
import '../data/models/lead_model.dart';
import '../data/models/prospect_model.dart';

class CrmDashboardScreen extends ConsumerStatefulWidget {
  const CrmDashboardScreen({super.key});

  @override
  ConsumerState<CrmDashboardScreen> createState() => _CrmDashboardScreenState();
}

class _CrmDashboardScreenState extends ConsumerState<CrmDashboardScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _lastCanManageSources = false;
  String _dateFilter = 'All Time'; // 'All Time', 'This Year', 'This Month', 'This Week'
  String _leaderboardSort = 'Won Deals'; // 'Won Deals', 'Revenue', 'Conversion Rate'
  bool _isRefreshing = false;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _initTabController(bool canManageSources) {
    if (_tabController == null || _lastCanManageSources != canManageSources) {
      _tabController?.dispose();
      _tabController = TabController(length: canManageSources ? 3 : 2, vsync: this);
      _lastCanManageSources = canManageSources;
    }
  }

  Future<void> _refreshAll() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await Future.wait([
        ref.read(prospectsProvider.notifier).load(refresh: false),
        ref.read(leadsProvider.notifier).load(refresh: false),
        ref.read(crmSourcesProvider.notifier).load(refresh: false),
      ]);
      ref.invalidate(crmLeaderboardProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('✓ Analytics updated'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final isCrmStaff = profile?.primaryRole == UserRole.crmStaff;
    final isAdmin = profile?.primaryRole == UserRole.admin || profile?.roles.contains(UserRole.admin) == true;
    final canManageSources = isCrmStaff || isAdmin;
    _initTabController(canManageSources);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'CRM Intelligence & Analytics',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: isCrmStaff
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (isAdmin) {
                    context.go('/admin/dashboard');
                  } else if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Analytics',
            onPressed: _isRefreshing ? null : _refreshAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController!,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            const Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
            const Tab(icon: Icon(Icons.emoji_events_outlined, size: 18), text: 'Leaderboard'),
            if (canManageSources)
              const Tab(icon: Icon(Icons.tune_outlined, size: 18), text: 'Lead Sources'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isRefreshing) const LinearProgressIndicator(minHeight: 2.5),
          Expanded(
            child: TabBarView(
              controller: _tabController!,
              children: [
                _buildOverviewTab(),
                _buildLeaderboardTab(),
                if (canManageSources) _buildSourcesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: OVERVIEW (STRUCTURE PER REFERENCE)
  // ==========================================
  Widget _buildOverviewTab() {
    final prospectsAsync = ref.watch(prospectsProvider);
    final leadsAsync = ref.watch(leadsProvider);

    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Pills Row
            _buildDateFilterRow(),
            const SizedBox(height: 16),

            // Top 4 KPI Metrics Bento Grid
            _buildKpiSection(prospectsAsync, leadsAsync),
            const SizedBox(height: 24),

            // Monthly Trend Chart Card
            _buildTrendChartCard(leadsAsync),
            const SizedBox(height: 24),

            // Pipeline & Status Distribution
            _buildDistributionSection(leadsAsync, prospectsAsync),
            const SizedBox(height: 24),

            // Recent Leads / Follow-up list
            _buildRecentLeadsSection(leadsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterRow() {
    final filters = ['All Time', 'This Year', 'This Month', 'This Week'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _dateFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(
                f,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              onSelected: (_) => setState(() => _dateFilter = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isWithinDateFilter(DateTime date) {
    final now = DateTime.now();
    switch (_dateFilter) {
      case 'This Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return date.isAfter(weekAgo);
      case 'This Month':
        final monthAgo = DateTime(now.year, now.month, 1);
        return date.isAfter(monthAgo);
      case 'This Year':
        final yearAgo = DateTime(now.year, 1, 1);
        return date.isAfter(yearAgo);
      case 'All Time':
      default:
        return true;
    }
  }

  Widget _buildKpiSection(
    AsyncValue<List<Prospect>> prospectsAsync,
    AsyncValue<List<Lead>> leadsAsync,
  ) {
    final currencyFormat = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');

    final prospects = (prospectsAsync.value ?? [])
        .where((p) => _isWithinDateFilter(p.createdAt))
        .toList();
    final leads = (leadsAsync.value ?? [])
        .where((l) => _isWithinDateFilter(l.createdAt))
        .toList();

    final activeLeads = leads.where((l) => l.status != 'Won' && l.status != 'Lost').toList();
    final wonLeads = leads.where((l) => l.status == 'Won' || l.convertedToCustomerId != null).toList();

    double pipelineRevenue = 0.0;
    for (final l in activeLeads) {
      pipelineRevenue += l.estimatedValue;
    }

    double wonRevenue = 0.0;
    for (final l in wonLeads) {
      wonRevenue += l.estimatedValue;
    }

    final convRate = leads.isNotEmpty ? ((wonLeads.length / leads.length) * 100).toStringAsFixed(1) : '0.0';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final count = isWide ? 4 : 2;

        return GridView.count(
          crossAxisCount: count,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 1.5 : 1.15,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildKpiCard(
              title: 'Active Prospects',
              value: '${prospects.where((p) => p.convertedToLeadId == null || !leads.any((l) => l.id == p.convertedToLeadId)).length}',
              badge: '${prospects.where((p) => p.convertedToLeadId != null && leads.any((l) => l.id == p.convertedToLeadId)).length} converted',
              isBadgePositive: true,
              icon: Icons.people_alt_outlined,
              color: const Color(0xFF3B82F6),
              onTap: () => context.go('/crm/prospects'),
            ),
            _buildKpiCard(
              title: 'Active Leads',
              value: '${activeLeads.length}',
              badge: currencyFormat.format(pipelineRevenue),
              isBadgePositive: true,
              icon: Icons.trending_up,
              color: const Color(0xFFF59E0B),
              onTap: () => context.go('/crm/leads'),
            ),
            _buildKpiCard(
              title: 'Won Deals',
              value: '${wonLeads.length}',
              badge: '$convRate% win rate',
              isBadgePositive: true,
              icon: Icons.check_circle_outline,
              color: const Color(0xFF10B981),
              onTap: () => context.go('/crm/customers'),
            ),
            _buildKpiCard(
              title: 'Won Revenue',
              value: currencyFormat.format(wonRevenue),
              badge: '${wonLeads.length} deals closed',
              isBadgePositive: true,
              icon: Icons.currency_rupee,
              color: const Color(0xFF8B5CF6),
              onTap: () => context.go('/crm/customers'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String badge,
    required bool isBadgePositive,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Monthly Leads Trend Chart ---
  Widget _buildTrendChartCard(AsyncValue<List<Lead>> leadsAsync) {
    final leads = leadsAsync.value ?? [];

    // Calculate last 6 months counts
    final now = DateTime.now();
    final months = <DateTime>[];
    for (int i = 5; i >= 0; i--) {
      months.add(DateTime(now.year, now.month - i, 1));
    }

    final monthNames = months.map((m) => DateFormat('MMM').format(m)).toList();
    final leadCounts = <double>[];
    final wonCounts = <double>[];

    for (final m in months) {
      final nextMonth = DateTime(m.year, m.month + 1, 1);
      final count = leads.where((l) => l.createdAt.isAfter(m) && l.createdAt.isBefore(nextMonth)).length.toDouble();
      final won = leads.where((l) => l.status == 'Won' && l.createdAt.isAfter(m) && l.createdAt.isBefore(nextMonth)).length.toDouble();
      leadCounts.add(count);
      wonCounts.add(won);
    }

    final maxVal = ([...leadCounts, ...wonCounts, 5.0].reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lead Velocity Trend',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'New Leads vs Converted Deals (6M)',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendIndicator(const Color(0xFF6366F1), 'Leads'),
                  const SizedBox(width: 10),
                  _buildLegendIndicator(const Color(0xFF10B981), 'Won'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxVal / 4).clamp(1.0, 100.0),
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: AppColors.border.withOpacity(0.6),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (maxVal / 4).clamp(1.0, 100.0),
                      getTitlesWidget: (val, meta) => Text(
                        val.toInt().toString(),
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < monthNames.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              monthNames[idx],
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 5,
                minY: 0,
                maxY: maxVal,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      leadCounts.length,
                      (i) => FlSpot(i.toDouble(), leadCounts[i]),
                    ),
                    isCurved: true,
                    color: const Color(0xFF6366F1),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF6366F1).withOpacity(0.08),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(
                      wonCounts.length,
                      (i) => FlSpot(i.toDouble(), wonCounts[i]),
                    ),
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF10B981).withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendIndicator(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  // --- Distribution Section: Products and Lead Sources ---
  Widget _buildDistributionSection(
    AsyncValue<List<Lead>> leadsAsync,
    AsyncValue<List<Prospect>> prospectsAsync,
  ) {
    final leads = leadsAsync.value ?? [];
    final prospects = prospectsAsync.value ?? [];

    // Group leads by product
    final productCounts = <String, int>{};
    for (final l in leads) {
      final p = l.productName.trim().isEmpty ? 'General Solar' : l.productName.trim();
      productCounts[p] = (productCounts[p] ?? 0) + 1;
    }

    // Group prospects by source
    final sourceCounts = <String, int>{};
    for (final p in prospects) {
      final s = p.source.trim().isEmpty ? 'Manual' : p.source.trim();
      sourceCounts[s] = (sourceCounts[s] ?? 0) + 1;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildBreakdownCard('Product Breakdown', productCounts, const Color(0xFF3B82F6))),
              const SizedBox(width: 16),
              Expanded(child: _buildBreakdownCard('Lead Source Attribution', sourceCounts, const Color(0xFF8B5CF6))),
            ],
          );
        } else {
          return Column(
            children: [
              _buildBreakdownCard('Product Breakdown', productCounts, const Color(0xFF3B82F6)),
              const SizedBox(height: 16),
              _buildBreakdownCard('Lead Source Attribution', sourceCounts, const Color(0xFF8B5CF6)),
            ],
          );
        }
      },
    );
  }

  Widget _buildBreakdownCard(String title, Map<String, int> counts, Color accentColor) {
    final total = counts.values.fold(0, (a, b) => a + b);
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topItems = sorted.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (topItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No distribution data yet', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            )
          else
            ...topItems.map((entry) {
              final pct = total > 0 ? (entry.value / total) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        Text(
                          '${entry.value} (${(pct * 100).toStringAsFixed(0)}%)',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: AppColors.border.withOpacity(0.5),
                        valueColor: AlwaysStoppedAnimation(accentColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentLeadsSection(AsyncValue<List<Lead>> leadsAsync) {
    final leads = leadsAsync.value ?? [];
    // User requested: "for recent pipeline deals, don't show won deals"
    final openDeals = leads.where((l) => l.status != 'Won' && l.status != 'Lost').toList();
    final recent = openDeals.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Pipeline Deals',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/crm/leads'),
                child: const Text('View All', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 16),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text('No active deals found in pipeline.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final lead = recent[index];
                final isWon = lead.status == 'Won';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  onTap: () => context.push('/crm/leads/${lead.id}'),
                  leading: CircleAvatar(
                    backgroundColor: isWon ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                    child: Icon(
                      isWon ? Icons.check_circle : Icons.trending_up,
                      color: isWon ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    lead.prospectName ?? 'Lead #${lead.id.substring(0, 6)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${lead.productName} • ${DateFormat('dd MMM yyyy').format(lead.createdAt)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${NumberFormat('#,##,##0').format(lead.estimatedValue)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lead.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isWon ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: COMPETITIVE LEADERBOARD (TASK 4.4)
  // ==========================================
  Widget _buildLeaderboardTab() {
    final leaderboardAsync = ref.watch(crmLeaderboardProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(crmLeaderboardProvider),
      child: leaderboardAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No sales performance data available yet.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            );
          }

          // Sort based on chosen metric
          final sorted = List<CrmLeaderboardEntry>.from(entries);
          if (_leaderboardSort == 'Revenue') {
            sorted.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
          } else if (_leaderboardSort == 'Conversion Rate') {
            sorted.sort((a, b) => b.conversionRate.compareTo(a.conversionRate));
          } else {
            sorted.sort((a, b) => b.wonDeals.compareTo(a.wonDeals));
          }

          final topThree = sorted.take(3).toList();

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Metric Sort Segmented Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sales Leaderboard',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    DropdownButton<String>(
                      value: _leaderboardSort,
                      underline: const SizedBox.shrink(),
                      items: ['Won Deals', 'Revenue', 'Conversion Rate']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _leaderboardSort = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Top 3 Podium
                _buildTopThreePodium(topThree),
                const SizedBox(height: 24),

                // Ranked List of All Reps
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: const [
                            SizedBox(width: 32, child: Text('Rank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                            Expanded(child: Text('Sales Representative', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                            SizedBox(width: 80, child: Text('Deals Won', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                            SizedBox(width: 90, child: Text('Revenue', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sorted.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final rep = sorted[index];
                          final rank = index + 1;

                          Color rankColor = AppColors.textSecondary;
                          if (rank == 1) rankColor = const Color(0xFFD97706);
                          if (rank == 2) rankColor = const Color(0xFF6B7280);
                          if (rank == 3) rankColor = const Color(0xFFB45309);

                          return ListTile(
                            leading: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: rank <= 3 ? rankColor.withOpacity(0.15) : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '#$rank',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: rankColor,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              rep.userName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            subtitle: Text(
                              '${rep.activeLeads} active leads • ${rep.conversionRate.toStringAsFixed(0)}% conv',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    '${rep.wonDeals}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981)),
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    '₹${NumberFormat.compactCurrency(locale: 'en_IN', symbol: '').format(rep.totalRevenue)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading leaderboard: $e')),
      ),
    );
  }

  Widget _buildTopThreePodium(List<CrmLeaderboardEntry> topThree) {
    if (topThree.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1B4B),
            Color(0xFF312E81),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Rank 2 (Silver)
          if (topThree.length > 1)
            _buildPodiumStep(
              entry: topThree[1],
              rank: 2,
              medalColor: const Color(0xFF94A3B8),
              avatarSize: 52,
              height: 120,
            )
          else
            const SizedBox(width: 80),

          // Rank 1 (Gold)
          _buildPodiumStep(
            entry: topThree[0],
            rank: 1,
            medalColor: const Color(0xFFFBBF24),
            avatarSize: 64,
            height: 150,
          ),

          // Rank 3 (Bronze)
          if (topThree.length > 2)
            _buildPodiumStep(
              entry: topThree[2],
              rank: 3,
              medalColor: const Color(0xFFD97706),
              avatarSize: 48,
              height: 100,
            )
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildPodiumStep({
    required CrmLeaderboardEntry entry,
    required int rank,
    required Color medalColor,
    required double avatarSize,
    required double height,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: avatarSize / 2,
              backgroundColor: medalColor.withOpacity(0.3),
              child: Text(
                entry.userName.isNotEmpty ? entry.userName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: avatarSize * 0.4,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: medalColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 85,
          child: Text(
            entry.userName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${entry.wonDeals} Won',
          style: const TextStyle(
            color: Color(0xFF34D399),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        Text(
          '₹${NumberFormat.compactCurrency(locale: 'en_IN', symbol: '').format(entry.totalRevenue)}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: CRM SETTINGS & LEAD SOURCES (TASK 4.2)
  // ==========================================
  Widget _buildSourcesTab() {
    final sourcesAsync = ref.watch(crmSourcesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.read(crmSourcesProvider.notifier).load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lead Sources',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage prospect intake channels',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showAddSourceDialog(context),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('Add Source', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            sourcesAsync.when(
              data: (sources) {
                if (sources.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: const Text('No sources found. Click "+ Add Source" to create one.'),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sources.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final src = sources[index];

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.campaign_outlined, color: AppColors.primary, size: 20),
                        ),
                        title: Text(
                          src,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                              tooltip: 'Edit Name',
                              onPressed: () => _showEditSourceDialog(context, src),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                              tooltip: 'Delete Source',
                              onPressed: () => _confirmDeleteSource(context, src),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading sources: $e')),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSourceDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Lead Source', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Source Name *',
            hintText: 'e.g. Instagram Ad, Trade Expo, Partner',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              await ref.read(crmSourcesProvider.notifier).addSource(text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lead source added successfully!'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Save Source', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditSourceDialog(BuildContext context, String sourceName) {
    final controller = TextEditingController(text: sourceName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Lead Source', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Source Name *',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              await ref.read(crmSourcesProvider.notifier).updateSource(sourceName, text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lead source updated!'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSource(BuildContext context, String sourceName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Source', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$sourceName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(crmSourcesProvider.notifier).deleteSource(sourceName);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Source deleted.'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
