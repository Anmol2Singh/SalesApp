// lib/features/boq/screens/boq_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/widgets/sync_status_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../reports/widgets/daily_report_modal.dart';

final boqDashboardDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  final userId = profile?.id;

  // 1. Fetch deals needing BOQ (current_step == 'boq')
  List<Map<String, dynamic>> pendingBoqDeals = [];
  try {
    final response = await supabase
        .from('sales_pipelines')
        .select('''
          id,
          current_step,
          status,
          created_at,
          updated_at,
          customers(customer_name, company_name, phone),
          products(name, category)
        ''')
        .eq('current_step', 'boq')
        .isFilter('deleted_at', null)
        .order('updated_at', ascending: false)
        .limit(10);
    pendingBoqDeals = List<Map<String, dynamic>>.from(response as List);
  } catch (e) {
    debugPrint('Error fetching pending BOQ deals: $e');
  }

  // 2. Fetch total active deals
  int activeDealsCount = 0;
  try {
    final activeRes = await supabase
        .from('sales_pipelines')
        .select('id')
        .neq('status', 'won')
        .neq('status', 'lost')
        .isFilter('deleted_at', null);
    activeDealsCount = (activeRes as List).length;
  } catch (_) {}

  // 3. Fetch total configured BOQ items
  int totalBoqItems = 0;
  try {
    final boqRes = await supabase.from('product_boq_items').select('id');
    totalBoqItems = (boqRes as List).length;
  } catch (_) {}

  // 4. Fetch prospects created today by this user
  int todayProspectsCount = 0;
  if (userId != null) {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0).toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

      final pRes = await supabase
          .from('crm_prospects')
          .select('id')
          .eq('created_by', userId)
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay);
      todayProspectsCount = (pRes as List).length;
    } catch (_) {}
  }

  return {
    'pendingBoqDeals': pendingBoqDeals,
    'activeDealsCount': activeDealsCount,
    'totalBoqItems': totalBoqItems,
    'todayProspectsCount': todayProspectsCount,
  };
});

class BoqDashboardScreen extends ConsumerWidget {
  const BoqDashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final dataAsync = ref.watch(boqDashboardDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.refresh(boqDashboardDataProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Gradient Header with User Info & Actions
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: const Color(0xFF1E1B4B),
              clipBehavior: Clip.antiAlias,
              automaticallyImplyLeading: false,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
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
                    // Ambient glow top-right
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
                              const Color(0xFFF59E0B).withValues(alpha: 0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Header Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 42, 20, 16),
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
                                    color: Colors.white.withValues(alpha: 0.35),
                                    width: 2,
                                  ),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    (profile?.fullName ?? 'B')[0].toUpperCase(),
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
                                        color: Colors.white.withValues(alpha: 0.65),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      profile?.fullName ?? 'BOQ Specialist',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 20,
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
                          const SizedBox(height: 12),
                          // Responsive stat pills wrap (never overflows)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildHeaderStat(
                                'Today',
                                DateFormat('dd MMM').format(DateTime.now()),
                                Icons.calendar_today_outlined,
                              ),
                              _buildHeaderStat(
                                'Role',
                                'BOQ',
                                Icons.badge_outlined,
                              ),
                              _buildHeaderStat(
                                '',
                                'ONLINE',
                                Icons.circle,
                                iconColor: const Color(0xFF10B981),
                                iconSize: 8,
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
                  icon: const Icon(Icons.summarize_outlined, color: Colors.white),
                  tooltip: 'Daily Report',
                  onPressed: () => DailyReportModal.show(context, ref),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh',
                  onPressed: () => ref.refresh(boqDashboardDataProvider),
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Logout'),
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

            // Body Content
            SliverToBoxAdapter(
              child: dataAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text('Error loading dashboard: $err')),
                ),
                data: (data) {
                  final pendingBoqDeals = data['pendingBoqDeals'] as List<Map<String, dynamic>>;
                  final activeDealsCount = data['activeDealsCount'] as int;
                  final totalBoqItems = data['totalBoqItems'] as int;
                  final todayProspectsCount = data['todayProspectsCount'] as int;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KPI Metric Cards Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Active Deals',
                                count: activeDealsCount.toString(),
                                icon: Icons.work_outline,
                                color: const Color(0xFF6366F1),
                                onTap: () => context.go(AppRoutes.pipelines),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Pending BOQ',
                                count: pendingBoqDeals.length.toString(),
                                icon: Icons.pending_actions_outlined,
                                color: const Color(0xFFF59E0B),
                                isUrgent: pendingBoqDeals.isNotEmpty,
                                onTap: () => context.go(AppRoutes.pipelines),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                title: 'BOQ Items Configured',
                                count: totalBoqItems.toString(),
                                icon: Icons.format_list_bulleted_outlined,
                                color: const Color(0xFF10B981),
                                onTap: () => context.push('/boq/manage-items'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Prospects Today',
                                count: todayProspectsCount.toString(),
                                icon: Icons.person_add_alt_1_outlined,
                                color: const Color(0xFF06B6D4),
                                onTap: () => context.go('/crm/prospects'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Section: Quick Actions
                        const Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Quick Action 1: Deals & Pipelines
                        _buildActionCard(
                          title: 'Go to Deals & Pipelines',
                          subtitle: 'View, filter, and process all customer deals and BOQs',
                          icon: Icons.work_outline,
                          iconColor: const Color(0xFF6366F1),
                          badge: '${pendingBoqDeals.length} Needs BOQ',
                          badgeColor: pendingBoqDeals.isNotEmpty
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF6366F1),
                          onTap: () => context.go(AppRoutes.pipelines),
                        ),
                        const SizedBox(height: 10),

                        // Quick Action 2: Manage BOQ Items
                        _buildActionCard(
                          title: 'Configure BOQ Items',
                          subtitle: 'Set up bill of materials items per product catalog',
                          icon: Icons.format_list_bulleted,
                          iconColor: const Color(0xFFF59E0B),
                          badge: '$totalBoqItems Items',
                          badgeColor: const Color(0xFFF59E0B),
                          onTap: () => context.push('/boq/manage-items'),
                        ),
                        const SizedBox(height: 10),

                        // Quick Action 3: Take Daily Report
                        _buildActionCard(
                          title: 'Take Daily Activity Report',
                          subtitle: 'Download or share your today’s activity report (PDF / Excel)',
                          icon: Icons.summarize_outlined,
                          iconColor: const Color(0xFF10B981),
                          badge: 'PDF / Excel',
                          badgeColor: const Color(0xFF10B981),
                          onTap: () => DailyReportModal.show(context, ref),
                        ),
                        const SizedBox(height: 10),

                        // Quick Action 4: Add / View Prospects
                        _buildActionCard(
                          title: 'Customer Prospects',
                          subtitle: 'Add new prospects or track existing ones',
                          icon: Icons.person_search_outlined,
                          iconColor: const Color(0xFF06B6D4),
                          badge: 'Add +',
                          badgeColor: const Color(0xFF06B6D4),
                          onTap: () => context.go('/crm/prospects'),
                        ),

                        const SizedBox(height: 24),

                        // Section: Deals Pending BOQ
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Deals Requiring BOQ',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go(AppRoutes.pipelines),
                              child: const Text('View All Deals →'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (pendingBoqDeals.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'No deals currently waiting for BOQ',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'All pipeline deals have their BOQ processed. You can view all deals or configure items.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => context.go(AppRoutes.pipelines),
                                  icon: const Icon(Icons.work_outline, size: 16),
                                  label: const Text('Go to All Deals'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pendingBoqDeals.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final deal = pendingBoqDeals[index];
                              final customer = deal['customers'] as Map<String, dynamic>?;
                              final product = deal['products'] as Map<String, dynamic>?;
                              final customerName = customer?['customer_name'] ?? 'Unknown Customer';
                              final companyName = customer?['company_name'];
                              final productName = product?['name'] ?? 'Product';
                              final dealId = deal['id']?.toString() ?? '';

                              return InkWell(
                                onTap: () => context.push('/pipelines/$dealId'),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.assignment_outlined,
                                          color: Color(0xFFD97706),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customerName,
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            if (companyName != null && companyName.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                companyName,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    productName,
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'BOQ Pending',
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFFB45309),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isUrgent = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUrgent ? color.withValues(alpha: 0.5) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (isUrgent)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              count,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isUrgent ? color : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(
    String label,
    String value,
    IconData icon, {
    Color? iconColor,
    double iconSize = 12,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: iconColor ?? Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 5),
          if (label.isNotEmpty)
            Text(
              '$label: ',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
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
          ),
        ],
      ),
    );
  }
}
