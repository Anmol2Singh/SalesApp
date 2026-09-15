// lib/features/dashboard/screens/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/models/customer.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pipelines/providers/pipelines_provider.dart';

import '../../../core/widgets/sync_status_indicator.dart';
import '../../../core/widgets/global_search_delegate.dart';

final dashboardTimeFilterProvider = StateProvider<String>((ref) => 'month');

final dashboardStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final timeFilter = ref.watch(dashboardTimeFilterProvider);

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  if (supabaseUrl.contains('your-project-ref')) {
    return {
      'active_deals': 12,
      'revenue_in_pipeline': 845000.0,
      'amc_needs_attention': 4,
      'awaiting_fulfillment': 3,
      'trend': [
        {'date': 'Day 1', 'created': 2.0, 'completed': 1.0},
        {'date': 'Day 2', 'created': 4.0, 'completed': 2.0},
        {'date': 'Day 3', 'created': 3.0, 'completed': 1.0},
        {'date': 'Day 4', 'created': 7.0, 'completed': 4.0},
        {'date': 'Day 5', 'created': 5.0, 'completed': 3.0},
        {'date': 'Day 6', 'created': 8.0, 'completed': 5.0},
        {'date': 'Day 7', 'created': 6.0, 'completed': 4.0},
      ]
    };
  }

  try {
    final result = await supabase.rpc('get_dashboard_stats', params: {'time_filter': timeFilter});
    return Map<String, dynamic>.from(result as Map);
  } catch (e) {
    final result = await supabase.rpc('get_dashboard_stats');
    return Map<String, dynamic>.from(result as Map);
  }
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final pipelinesAsync = ref.watch(pipelinesNotifierProvider);
    final currentFilter = ref.watch(dashboardTimeFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF1E1B4B),
            clipBehavior: Clip.antiAlias,
            automaticallyImplyLeading: false,
            title: const Text(
              'Dashboard',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Deep indigo → violet gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1E1B4B),
                          Color(0xFF4C1D95),
                          Color(0xFF6D28D9),
                        ],
                      ),
                    ),
                  ),
                  // Radial glow top-right
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Radial glow bottom-left
                  Positioned(
                    bottom: -20,
                    left: -40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF06B6D4).withOpacity(0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  (profile?.fullName ?? 'A')[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Good ${_getGreeting()}',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.6),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    profile?.fullName ?? 'Admin',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Mini stat pills row
                        Row(
                          children: [
                            _buildHeaderStat(
                              'Today',
                              DateFormat('dd MMM').format(DateTime.now()),
                              Icons.calendar_today_outlined,
                            ),
                            const SizedBox(width: 12),
                            _buildHeaderStat(
                              'Role',
                              profile?.primaryRole.name.toUpperCase() ?? 'ADMIN',
                              Icons.admin_panel_settings_outlined,
                            ),
                            const SizedBox(width: 12),
                            _buildHeaderStat(
                              'Status',
                              'ONLINE',
                              Icons.circle,
                              iconColor: const Color(0xFF10B981),
                              iconSize: 10,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              const SyncStatusIndicator(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  ref.invalidate(dashboardStatsProvider);
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Logout',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                          child: const Text('Logout', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(authControllerProvider.notifier).signOut();
                  }
                },
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Date Range Filters
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Today',
                          selected: currentFilter == 'today',
                          onSelected: () => ref.read(dashboardTimeFilterProvider.notifier).state = 'today',
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'This Week',
                          selected: currentFilter == 'week',
                          onSelected: () => ref.read(dashboardTimeFilterProvider.notifier).state = 'week',
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'This Month',
                          selected: currentFilter == 'month',
                          onSelected: () => ref.read(dashboardTimeFilterProvider.notifier).state = 'month',
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'This Year',
                          selected: currentFilter == 'year',
                          onSelected: () => ref.read(dashboardTimeFilterProvider.notifier).state = 'year',
                        ),
                      ],
                    ),
                  ),
                ),

                // Stats Cards and Trend Chart loaded together
                statsAsync.when(
                  data: (stats) {
                    final trendList = stats['trend'] as List<dynamic>? ?? [];
                    final created = trendList.map((t) => (t['created'] as num? ?? 0.0).toDouble()).toList();
                    final completed = trendList.map((t) => (t['completed'] as num? ?? 0.0).toDouble()).toList();
                    
                    while (created.length < 7) created.add(0.0);
                    while (completed.length < 7) completed.add(0.0);

                    final trendMap = {
                      'created': created,
                      'completed': completed,
                      'revenue': (stats['revenue_in_pipeline'] as num? ?? 0.0).toDouble(),
                    };

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatsGrid(stats: stats),
                        const SizedBox(height: 20),
                        _TrendChartCard(data: trendMap),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                  error: (e, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Failed to load stats: $e'),
                  ),
                ),
                const SizedBox(height: 20),

                // Quick Actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: _QuickActionCard(
                          icon: Icons.shield_outlined,
                          label: 'AMC',
                          color: AppColors.primary,
                          onTap: () => context.push('/amc'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 140,
                        child: _QuickActionCard(
                          icon: Icons.people_alt_outlined,
                          label: 'CRM',
                          color: Colors.blueAccent,
                          onTap: () => context.push('/crm/dashboard'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 140,
                        child: _QuickActionCard(
                          icon: Icons.report_problem_outlined,
                          label: 'Complaints',
                          color: const Color(0xFF6D28D9),
                          onTap: () => context.go('/complaints/dashboard'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 140,
                        child: _QuickActionCard(
                          icon: Icons.inventory_2_outlined,
                          label: 'Inventory',
                          color: AppColors.accent,
                          onTap: () => context.push(AppRoutes.inventory),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 140,
                        child: _QuickActionCard(
                          icon: Icons.local_mall_outlined,
                          label: 'View Products',
                          color: Colors.teal,
                          onTap: () => context.push('/products'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 140,
                        child: _QuickActionCard(
                          icon: Icons.download_outlined,
                          label: "Today's Report",
                          color: AppColors.success,
                          onTap: () => context.push('/reports/activity'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 140,
                        child: _QuickActionCard(
                          icon: Icons.picture_as_pdf_outlined,
                          label: 'Search PDF',
                          color: Colors.deepOrange,
                          onTap: () => context.push(AppRoutes.searchPdf),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Recent Pipelines
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Deals',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.pipelines),
                      child: const Text('View All',
                          style: TextStyle(fontFamily: 'Inter')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                pipelinesAsync.when(
                  data: (pipelines) {
                    final recent = pipelines.take(5).toList();
                    if (recent.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No deals yet',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: recent.map((p) {
                        return _RecentPipelineTile(pipeline: p);
                      }).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                  error: (e, _) => Center(child: Text('$e')),
                ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning,';
    if (hour < 17) return 'Afternoon,';
    return 'Evening,';
  }

  static Widget _buildHeaderStat(
    String label,
    String value,
    IconData icon, {
    Color iconColor = Colors.white,
    double iconSize = 14,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: iconSize),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##,##0', 'en_IN');
    final revenue = (stats['revenue_in_pipeline'] as num? ?? 0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 800 ? 4 : 2;
        final childAspectRatio = constraints.maxWidth >= 800 ? 1.6 : 2.1;
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
      children: [
        _StatCard(
          title: 'Active Deals',
          value: '${stats['active_deals'] ?? 0}',
          icon: Icons.alt_route,
          color: AppColors.primary,
          onTap: () => context.go(AppRoutes.pipelines),
        ),
        _StatCard(
          title: 'Revenue in Pipeline',
          value: '₹${currencyFormat.format(revenue)}',
          icon: Icons.currency_rupee,
          color: AppColors.success,
          onTap: () => context.go(AppRoutes.pipelines),
        ),
        _StatCard(
          title: 'AMC Needs Attention',
          value: '${stats['amc_needs_attention'] ?? 0}',
          icon: Icons.warning_amber_outlined,
          color: AppColors.warning,
          onTap: () => context.push('/amc'),
        ),
        _StatCard(
          title: 'Awaiting Fulfillment',
          value: '${stats['awaiting_fulfillment'] ?? 0}',
          icon: Icons.factory_outlined,
          color: AppColors.error,
          onTap: () => context.go('${AppRoutes.pipelines}?step=factory_order'),
        ),
      ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPipelineTile extends StatelessWidget {
  final dynamic pipeline;

  const _RecentPipelineTile({required this.pipeline});

  Color _getBadgeColor(String step, String status) {
    if (status == 'completed') return Colors.green;
    if (status == 'suspended' || status == 'cancelled') return Colors.red;
    
    switch (step) {
      case 'quotation':
        return Colors.amber;
      case 'sales_order':
      case 'salesOrder':
        return Colors.blue;
      case 'boq':
        return Colors.purple;
      case 'factory_order':
      case 'factoryOrder':
        return Colors.orange;
      case 'purchase_order':
      case 'purchaseOrder':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (pipeline == null) return const SizedBox.shrink();

    String stepValue = 'quotation';
    String statusValue = 'in_progress';
    String stepName = 'Quotation';
    String companyName = '';
    String productName = '';
    String pipelineId = '';

    if (pipeline is Map) {
      pipelineId = pipeline['id'] as String? ?? '';
      stepValue = pipeline['current_step'] as String? ?? 'quotation';
      statusValue = pipeline['status'] as String? ?? 'in_progress';
      stepName = PipelineStep.fromString(stepValue).displayName;
      
      final cust = pipeline['customers'];
      if (cust is Map) {
        companyName = cust['customer_name'] as String? ?? cust['company_name'] as String? ?? cust['contact_person'] as String? ?? '';
      }
      final prod = pipeline['products'];
      if (prod is Map) {
        productName = prod['name'] as String? ?? '';
      }
    } else {
      // SalesPipeline object
      try {
        pipelineId = pipeline.id;
        stepValue = pipeline.currentStep.dbValue;
        statusValue = pipeline.status.dbValue;
        stepName = pipeline.currentStep.displayName;
        companyName = pipeline.customer?.customerName ?? pipeline.customer?.companyName ?? pipeline.customer?.contactPerson ?? '';
        productName = pipeline.product?.name ?? '';
      } catch (_) {}
    }

    final badgeColor = _getBadgeColor(stepValue, statusValue);

    return GestureDetector(
      onTap: () {
        if (pipelineId.isNotEmpty) {
          context.push(
            AppRoutes.pipelineDetail.replaceAll(':id', pipelineId),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.alt_route_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (companyName.isNotEmpty) ...[
                    Text(
                      companyName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    productName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: companyName.isNotEmpty ? 12 : 14,
                      fontWeight: companyName.isNotEmpty ? FontWeight.normal : FontWeight.w600,
                      color: companyName.isNotEmpty ? AppColors.textSecondary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withOpacity(0.3)),
              ),
              child: Text(
                stepName,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _TrendChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final List<double> created = List<double>.from(data['created']);
    final List<double> completed = List<double>.from(data['completed']);
    final double revenue = (data['revenue'] as num? ?? 0).toDouble();
    final currencyFormat = NumberFormat('#,##,##0', 'en_IN');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deals Trend (Last 7 Days)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Created vs. Completed',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Pipeline Value',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '₹${currencyFormat.format(revenue)}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(7, (i) => FlSpot(i.toDouble(), created[i])),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(7, (i) => FlSpot(i.toDouble(), completed[i])),
                    isCurved: true,
                    color: AppColors.success,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.success.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text('Created', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 20),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text('Completed', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
