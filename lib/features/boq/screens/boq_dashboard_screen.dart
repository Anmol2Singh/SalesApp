// lib/features/boq/screens/boq_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_role.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../reports/widgets/daily_report_modal.dart';
import '../../../core/widgets/network_status_chip.dart';

final boqDashboardDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  final userId = profile?.id;

  // 1. Fetch deals needing BOQ (current_step == 'boq')
  List<Map<String, dynamic>> pendingBoqDeals = [];
  try {
    final query = supabase
        .from('sales_pipelines')
        .select('''
          id,
          current_step,
          status,
          created_at,
          updated_at,
          customers(customer_name, company_name, phone),
          products(name, category)
        ''');
        
    List<String> targetSteps = [];
    if (profile?.roles.contains(UserRole.boq) == true) targetSteps.add('boq');
    if (profile?.roles.contains(UserRole.factory) == true) targetSteps.add('factory_order');
    if (profile?.roles.contains(UserRole.purchase) == true) targetSteps.add('purchase_order');
    if (targetSteps.isEmpty) targetSteps.add('boq');

    final response = await query
        .inFilter('current_step', targetSteps)
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
        .neq('status', 'cancelled')
        .neq('status', 'suspended')
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

    final rawName = profile?.fullName.trim() ?? '';
    final displayName = rawName.isNotEmpty ? rawName : (profile?.primaryRole.displayName ?? 'Operations Staff');
    final avatarInitial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'O';

    // Build header role label
    final headerRoleLabels = [
      if (profile?.roles.contains(UserRole.boq) == true) 'BOQ',
      if (profile?.roles.contains(UserRole.factory) == true) 'Factory',
      if (profile?.roles.contains(UserRole.purchase) == true) 'Purchase',
    ];
    final headerRoleLabel = headerRoleLabels.isEmpty ? 'OPERATIONS' : headerRoleLabels.join(' · ').toUpperCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              automaticallyImplyLeading: false,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  children: [
                    // Unified purple-violet gradient matching Admin
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0F172A),
                            Color(0xFF2E1065),
                            Color(0xFF6B21A8),
                            Color(0xFF4F46E5),
                            Color(0xFF2563EB),
                          ],
                        ),
                      ),
                    ),
                    // Ambient light glow
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
                              Colors.white.withValues(alpha: 0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Header Content
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      avatarInitial,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: NetworkAvatarDot(
                                    size: 14,
                                    borderColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Good ${_getGreeting()},',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.75),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Today ${DateFormat('dd MMM').format(DateTime.now())}',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  headerRoleLabel,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const NetworkStatusChip(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
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
                const SizedBox(width: 4),
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
                  final roles = profile?.roles ?? [];
                  final hasBoqRole = roles.contains(UserRole.boq);
                  final hasFactoryRole = roles.contains(UserRole.factory);
                  final hasPurchaseRole = roles.contains(UserRole.purchase);

                  // Build pending action label
                  final pendingLabel = [
                    if (hasBoqRole) 'BOQ',
                    if (hasFactoryRole) 'Factory Orders',
                    if (hasPurchaseRole) 'Purchase',
                  ].join('/');

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Responsive KPI Metric Cards Grid
                        Builder(
                          builder: (context) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            final int kpiCols = screenWidth >= 1000 ? 4 : (screenWidth >= 600 ? 4 : 2);
                            final double kpiRatio = screenWidth >= 1200
                                ? 2.3
                                : (screenWidth >= 1000
                                    ? 2.0
                                    : (screenWidth >= 600 ? 1.6 : 1.34));
                            return GridView.count(
                              crossAxisCount: kpiCols,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: kpiRatio,
                              children: [
                                _buildMetricCard(
                                  title: 'Active\nDeals',
                                  count: activeDealsCount.toString(),
                                  icon: Icons.alt_route,
                                  color: const Color(0xFF2563EB),
                                  onTap: () => context.go(AppRoutes.pipelines),
                                ),
                                _buildMetricCard(
                                  title: 'Pending\n${pendingLabel.isEmpty ? "Actions" : pendingLabel}',
                                  count: pendingBoqDeals.length.toString(),
                                  icon: Icons.pending_actions_outlined,
                                  color: const Color(0xFFF59E0B),
                                  onTap: () => context.go(AppRoutes.pipelines),
                                ),
                                _buildMetricCard(
                                  title: 'Configured\nItems',
                                  count: totalBoqItems.toString(),
                                  icon: Icons.inventory_2_outlined,
                                  color: const Color(0xFF10B981),
                                  onTap: () => context.push('/boq/manage-items'),
                                ),
                                _buildMetricCard(
                                  title: 'Prospects\nToday',
                                  count: todayProspectsCount.toString(),
                                  icon: Icons.person_add_alt_1_outlined,
                                  color: const Color(0xFF8B5CF6),
                                  onTap: () => context.go('/crm/prospects'),
                                ),
                              ],
                            );
                          },
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

                        Builder(
                          builder: (context) {
                            final buttons = <Widget>[
                              _buildQuickActionButton(
                                context,
                                title: 'Assigned Work',
                                subtitle: 'Task calendar & roster',
                                icon: Icons.calendar_month_outlined,
                                color: const Color(0xFF4F46E5),
                                isDark: isDark,
                                onTap: () => context.push(AppRoutes.assignedWork),
                              ),
                              _buildQuickActionButton(
                                context,
                                title: 'Deals & Pipelines',
                                subtitle: pendingBoqDeals.isNotEmpty
                                    ? '${pendingBoqDeals.length} Action Required'
                                    : 'View customer deals',
                                icon: Icons.work_outline,
                                color: const Color(0xFF2563EB),
                                isDark: isDark,
                                onTap: () => context.go(AppRoutes.pipelines),
                              ),
                              if (hasBoqRole)
                                _buildQuickActionButton(
                                  context,
                                  title: 'Configure BOQ',
                                  subtitle: '$totalBoqItems BOM items',
                                  icon: Icons.format_list_bulleted,
                                  color: const Color(0xFFD97706),
                                  isDark: isDark,
                                  onTap: () => context.push('/boq/manage-items'),
                                ),
                              if (hasFactoryRole)
                                _buildQuickActionButton(
                                  context,
                                  title: 'Factory Queue',
                                  subtitle: 'View factory orders',
                                  icon: Icons.precision_manufacturing_outlined,
                                  color: const Color(0xFFEA580C),
                                  isDark: isDark,
                                  onTap: () => context.push(AppRoutes.factoryQueue),
                                ),
                              if (hasPurchaseRole)
                                _buildQuickActionButton(
                                  context,
                                  title: 'Material Queue',
                                  subtitle: 'Purchase & requisitions',
                                  icon: Icons.shopping_cart_outlined,
                                  color: const Color(0xFF059669),
                                  isDark: isDark,
                                  onTap: () => context.push(AppRoutes.purchaseQueue),
                                ),
                              _buildQuickActionButton(
                                context,
                                title: 'Daily Tasks',
                                subtitle: 'Tasks completed',
                                icon: Icons.fact_check_outlined,
                                color: const Color(0xFF8B5CF6),
                                isDark: isDark,
                                onTap: () => context.push(AppRoutes.dailyTasks),
                              ),
                              _buildQuickActionButton(
                                context,
                                title: 'View Products',
                                subtitle: 'Catalog & specs',
                                icon: Icons.inventory_2_outlined,
                                color: const Color(0xFF0D9488),
                                isDark: isDark,
                                onTap: () => context.push('/products'),
                              ),
                              _buildQuickActionButton(
                                context,
                                title: 'Daily Report',
                                subtitle: 'PDF / Excel summary',
                                icon: Icons.summarize_outlined,
                                color: const Color(0xFF0284C7),
                                isDark: isDark,
                                onTap: () => DailyReportModal.show(context, ref),
                              ),
                              _buildQuickActionButton(
                                context,
                                title: 'Customer Prospects',
                                subtitle: 'Track prospects',
                                icon: Icons.person_search_outlined,
                                color: const Color(0xFF6366F1),
                                isDark: isDark,
                                onTap: () => context.go('/crm/prospects'),
                              ),
                            ];

                            return Column(
                              children: [
                                for (int i = 0; i < buttons.length; i += 2) ...[
                                  if (i > 0) const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: buttons[i]),
                                      const SizedBox(width: 12),
                                      if (i + 1 < buttons.length)
                                        Expanded(child: buttons[i + 1])
                                      else
                                        const Expanded(child: SizedBox.shrink()),
                                    ],
                                  ),
                                ],
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // Section: Operations Deals
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pending Deals',
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
                                  'No deals currently waiting for operations',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'All pipeline deals have their operations processed. You can view all deals or configure items.',
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
                                                    'Action Pending',
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
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        height: 1.2,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  count,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isDark = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          color: isDark ? Colors.grey.shade400 : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
