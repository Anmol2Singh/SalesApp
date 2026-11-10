// lib/features/dashboard/screens/unified_dashboard_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/pipeline.dart';
import '../../../core/models/user_role.dart';
import '../../../core/auth/role_access.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dashboard_switcher_button.dart';
import '../../../core/widgets/network_status_chip.dart';
import '../../../core/widgets/logout_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../../crm/providers/crm_providers.dart';
import '../../daily_tasks/providers/daily_tasks_provider.dart';
import '../../pipelines/providers/pipelines_provider.dart';
import '../../reports/widgets/daily_report_modal.dart';
import 'admin_dashboard_screen.dart' show dashboardStatsProvider;

/// Unified data provider calculating role-restricted active deals, pending steps, and prospects
final unifiedDashboardDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  final userId = profile?.id;
  final roles = profile?.roles ?? [];

  final isAdminOrManagerOrSalesHead = roles.contains(UserRole.admin) ||
      roles.contains(UserRole.manager) ||
      roles.contains(UserRole.salesHead);
  final isSales = roles.contains(UserRole.sales);
  final hasBoq = roles.contains(UserRole.boq) ||
      roles.contains(UserRole.serviceHead) ||
      roles.contains(UserRole.installation) ||
      roles.contains(UserRole.complaints);
  final hasFactory = roles.contains(UserRole.factory);
  final hasPurchase = roles.contains(UserRole.purchase);

  // 1. Fetch pending deals targeted to this role's steps
  List<Map<String, dynamic>> pendingDeals = [];
  try {
    List<String> targetSteps = [];
    if (hasBoq) targetSteps.add('boq');
    if (hasFactory) targetSteps.add('factory_order');
    if (hasPurchase) targetSteps.add('purchase_order');
    if (targetSteps.isEmpty) {
      if (isSales) {
        targetSteps.add('quotation');
      } else {
        targetSteps.add('boq');
      }
    }

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
        .inFilter('current_step', targetSteps)
        .neq('status', 'cancelled')
        .neq('status', 'suspended')
        .neq('status', 'completed')
        .isFilter('deleted_at', null)
        .order('updated_at', ascending: false)
        .limit(10);
    pendingDeals = List<Map<String, dynamic>>.from(response as List);
  } catch (e) {
    debugPrint('Error fetching pending deals: $e');
  }

  // 2. Fetch role-specific active deals count (only active deals seen by respective role)
  int activeDealsCount = 0;
  try {
    if (isAdminOrManagerOrSalesHead) {
      final res = await supabase
          .from('sales_pipelines')
          .select('id')
          .neq('status', 'cancelled')
          .neq('status', 'suspended')
          .neq('status', 'completed')
          .neq('current_step', 'completed')
          .isFilter('deleted_at', null);
      activeDealsCount = (res as List).length;
    } else if (isSales && !hasBoq && !hasFactory && !hasPurchase) {
      List<String> assignedCustomerIds = [];
      if (userId != null) {
        try {
          final custRes = await supabase
              .from('customers')
              .select('id')
              .eq('assigned_to', userId);
          assignedCustomerIds = (custRes as List)
              .map((c) => c['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
        } catch (_) {}
      }

      var query = supabase
          .from('sales_pipelines')
          .select('id')
          .neq('status', 'cancelled')
          .neq('status', 'suspended')
          .neq('status', 'completed')
          .neq('current_step', 'completed')
          .isFilter('deleted_at', null);

      if (userId != null) {
        if (assignedCustomerIds.isNotEmpty) {
          final idList = assignedCustomerIds.join(',');
          query = query.or('created_by.eq.$userId,customer_id.in.($idList)');
        } else {
          query = query.eq('created_by', userId);
        }
      }
      final res = await query;
      activeDealsCount = (res as List).length;
    } else if (hasBoq || hasFactory || hasPurchase) {
      final List<String> visibleSteps = [];
      if (hasBoq) {
        visibleSteps.addAll(['boq', 'factory_order', 'purchase_order']);
      }
      if (hasFactory) {
        visibleSteps.addAll(['factory_order', 'purchase_order']);
      }
      if (hasPurchase) {
        visibleSteps.add('purchase_order');
      }

      final uniqueVisibleSteps = visibleSteps.toSet().toList();

      final res = await supabase
          .from('sales_pipelines')
          .select('id')
          .inFilter('current_step', uniqueVisibleSteps)
          .neq('status', 'cancelled')
          .neq('status', 'suspended')
          .neq('status', 'completed')
          .neq('current_step', 'completed')
          .isFilter('deleted_at', null);
      activeDealsCount = (res as List).length;
    } else {
      activeDealsCount = 0;
    }
  } catch (e) {
    debugPrint('Error fetching activeDealsCount: $e');
  }

  // 3. Fetch prospects added by the user
  int prospectsAddedCount = 0;
  if (userId != null) {
    try {
      final pRes = await supabase
          .from('crm_prospects')
          .select('id')
          .eq('created_by', userId);
      prospectsAddedCount = (pRes as List).length;
    } catch (_) {}
  }

  // 4. Fetch daily tasks count for today
  int todayTasksCount = 0;
  if (userId != null) {
    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final tRes = await supabase
          .from('daily_tasks')
          .select('id')
          .eq('user_id', userId)
          .eq('task_date', todayStr);
      todayTasksCount = (tRes as List).length;
    } catch (_) {}
  }

  // 5. Fetch projects count (for Accounts/Finance)
  int projectsCount = 0;
  try {
    final prRes = await supabase
        .from('pm_projects')
        .select('id')
        .isFilter('deleted_at', null);
    projectsCount = (prRes as List).length;
  } catch (_) {}

  // 6. Fetch Day-Book entries count (for Accounts/Finance)
  int dayBookEntriesCount = 0;
  try {
    final txRes = await supabase
        .from('pm_daily_transactions')
        .select('id')
        .isFilter('deleted_at', null);
    dayBookEntriesCount = (txRes as List).length;
  } catch (_) {}

  return {
    'pendingDeals': pendingDeals,
    'activeDealsCount': activeDealsCount,
    'prospectsAddedCount': prospectsAddedCount,
    'todayTasksCount': todayTasksCount,
    'projectsCount': projectsCount,
    'dayBookEntriesCount': dayBookEntriesCount,
  };
});

class UnifiedDashboardScreen extends ConsumerWidget {
  const UnifiedDashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF38BDF8),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Logging out...',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final roles = profile.roles;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pipelinesAsync = ref.watch(pipelinesNotifierProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final unifiedDataAsync = ref.watch(unifiedDashboardDataProvider);
    final leads = ref.watch(leadsProvider).value ?? [];
    final prospects = ref.watch(prospectsProvider).value ?? [];
    final todayTasks = ref.watch(dailyTasksProvider).value ?? [];

    final bool hasService = roles.contains(UserRole.serviceHead) ||
        roles.contains(UserRole.complaints) ||
        roles.contains(UserRole.installation);
    final bool hasOperations = roles.contains(UserRole.boq) ||
        roles.contains(UserRole.factory) ||
        roles.contains(UserRole.purchase);
    final bool hasSales = roles.contains(UserRole.sales);
    final bool hasAccounts = roles.contains(UserRole.accounts);
    final bool isPureAccounts = hasAccounts &&
        !hasOperations &&
        !hasSales &&
        !hasService &&
        !roles.contains(UserRole.admin) &&
        !roles.contains(UserRole.manager);
    final bool hasDealsAccess = (hasOperations || hasSales) && !isPureAccounts;

    // Build user display name and avatar initial
    final rawName = profile?.fullName.trim() ?? '';
    final displayName = rawName.isNotEmpty
        ? rawName
        : (profile?.primaryRole.displayName ?? 'Staff User');
    final avatarInitial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    // Compute display role label
    final List<String> roleNames = [];
    if (roles.contains(UserRole.serviceHead)) roleNames.add('Service Head');
    if (roles.contains(UserRole.complaints)) roleNames.add('Complaints');
    if (roles.contains(UserRole.installation)) roleNames.add('Installation');
    if (roles.contains(UserRole.purchase)) roleNames.add('Purchase');
    if (roles.contains(UserRole.factory)) roleNames.add('Factory');
    if (roles.contains(UserRole.boq)) roleNames.add('BOQ');
    if (roles.contains(UserRole.sales)) roleNames.add('Sales');
    if (roles.contains(UserRole.accounts)) roleNames.add('Finance');
    if (roles.contains(UserRole.crmStaff)) roleNames.add('CRM');
    if (roles.contains(UserRole.technician)) roleNames.add('Technician');

    final headerRoleLabel = roleNames.isNotEmpty
        ? roleNames.take(2).join(' · ').toUpperCase()
        : (profile?.primaryRole.displayName.toUpperCase() ?? 'STAFF');

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(unifiedDashboardDataProvider);
          ref.read(leadsProvider.notifier).load(refresh: true);
          ref.read(prospectsProvider.notifier).load(refresh: true);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Exact Gradient Header matching screenshot & BOQ Dashboard
            SliverAppBar(
              expandedHeight: 154,
              pinned: true,
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              automaticallyImplyLeading: false,
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  children: [
                    // Unified purple-violet gradient matching Admin & screenshot
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
                                      color:
                                          Colors.white.withValues(alpha: 0.25),
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
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
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
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
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
                const DashboardSwitcherButton(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh',
                  onPressed: () {
                    ref.invalidate(dashboardStatsProvider);
                    ref.invalidate(unifiedDashboardDataProvider);
                    ref.read(leadsProvider.notifier).load(refresh: true);
                    ref.read(prospectsProvider.notifier).load(refresh: true);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Logout',
                  onPressed: () => confirmAndSignOut(context, ref),
                ),
                const SizedBox(width: 4),
              ],
            ),

            // Body Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Role-Adaptive KPI Cards Grid matching exact screenshot 1 design
                    _buildUnifiedStatsGrid(
                      context: context,
                      roles: roles,
                      hasService: hasService,
                      hasOperations: hasOperations,
                      hasSales: hasSales,
                      statsAsync: statsAsync,
                      unifiedDataAsync: unifiedDataAsync,
                      leadsCount: leads.length,
                      prospectsCount: prospects.length,
                      tasksCount: todayTasks.length,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 16),

                    // 2. Quick Actions Section
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
                    _UnifiedQuickActionsGrid(roles: roles),
                    const SizedBox(height: 16),

                    // 3. Recent Deals (if Deals access)
                    if (hasDealsAccess) ...[
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
                            child: const Text(
                              'View All',
                              style: TextStyle(fontFamily: 'Inter'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      pipelinesAsync.when(
                        data: (pipelines) {
                          final visiblePipelines = pipelines
                              .where((p) => RoleAccess.isDealVisibleForUser(p, profile))
                              .toList();
                          final activeDeals = visiblePipelines.where((p) =>
                              p.status != PipelineStatus.completed &&
                              p.currentStep != PipelineStep.completed &&
                              p.status != PipelineStatus.cancelled).toList();
                          final recent = (activeDeals
                                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
                              .take(5)
                              .toList();
                          if (recent.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No active leads',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: recent.map((p) {
                              return _UnifiedRecentPipelineTile(pipeline: p);
                            }).toList(),
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (e, _) => Center(child: Text('$e')),
                      ),
                    ],

                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedStatsGrid({
    required BuildContext context,
    required List<UserRole> roles,
    required bool hasService,
    required bool hasOperations,
    required bool hasSales,
    required AsyncValue<Map<String, dynamic>> statsAsync,
    required AsyncValue<Map<String, dynamic>> unifiedDataAsync,
    required int leadsCount,
    required int prospectsCount,
    required int tasksCount,
    required bool isDark,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final crossAxisCount = screenWidth >= 800 ? 4 : 2;
        final childAspectRatio = screenWidth >= 800 ? 1.6 : 1.34;

        List<Widget> cards = [];

        final dashData = unifiedDataAsync.value ?? {};
        final activeCount = dashData['activeDealsCount'] ?? 0;
        final prospectsAddedCount = dashData['prospectsAddedCount'] ?? 0;
        final opTasksCount = dashData['todayTasksCount'] ?? tasksCount;

        final isAccountsOnly = roles.contains(UserRole.accounts) &&
            !hasOperations &&
            !hasSales &&
            !hasService &&
            !roles.contains(UserRole.admin) &&
            !roles.contains(UserRole.manager);

        if (isAccountsOnly) {
          final projectsCount = dashData['projectsCount'] ?? 0;
          final dayBookEntriesCount = dashData['dayBookEntriesCount'] ?? 0;

          cards = [
            _UnifiedStatCard(
              title: 'Project\nManager',
              count: '$projectsCount',
              icon: Icons.solar_power_outlined,
              color: const Color(0xFF005CE6),
              onTap: () => context.go(AppRoutes.projectManager),
            ),
            _UnifiedStatCard(
              title: 'Prospects\nAdded',
              count: '$prospectsAddedCount',
              icon: Icons.person_search_outlined,
              color: const Color(0xFF10B981),
              onTap: () => context.push('/crm/prospects'),
            ),
            _UnifiedStatCard(
              title: 'Today\'s\nTasks',
              count: '$opTasksCount',
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () => context.push(AppRoutes.dailyTasks),
            ),
            _UnifiedStatCard(
              title: 'Day-Book\nEntries',
              count: '$dayBookEntriesCount',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFF0284C7),
              onTap: () => context.push(AppRoutes.pmDailyTransactions),
            ),
          ];
        } else if (hasOperations) {
          // Operations roles (BOQ, Factory, Purchase) match screenshot 1 perfectly
          final pendingDeals = (dashData['pendingDeals'] as List?) ?? [];

          final hasBoq = roles.contains(UserRole.boq);
          final hasFactory = roles.contains(UserRole.factory);
          final hasPurchase = roles.contains(UserRole.purchase);

          final pendingLabel = [
            if (hasBoq) 'BOQ',
            if (hasFactory) 'Factory',
            if (hasPurchase) 'Purchase',
          ].join('/');

          cards = [
            _UnifiedStatCard(
              title: 'Active\nDeals',
              count: '$activeCount',
              icon: Icons.alt_route,
              color: const Color(0xFF2563EB),
              onTap: () => context.go(AppRoutes.pipelines),
            ),
            _UnifiedStatCard(
              title:
                  'Pending\n${pendingLabel.isEmpty ? "Actions" : pendingLabel}',
              count: '${pendingDeals.length}',
              icon: Icons.assignment_outlined,
              color: const Color(0xFFF59E0B),
              onTap: () => context.go(AppRoutes.pipelines),
            ),
            _UnifiedStatCard(
              title: 'Prospects\nAdded',
              count: '$prospectsAddedCount',
              icon: Icons.person_search_outlined,
              color: const Color(0xFF10B981),
              onTap: () => context.push('/crm/prospects'),
            ),
            _UnifiedStatCard(
              title: 'Today\'s\nTasks',
              count: '$opTasksCount',
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () => context.push(AppRoutes.dailyTasks),
            ),
          ];
        } else if (hasService) {
          final stats = statsAsync.value ?? {};
          final complaintsCount = stats['active_complaints_count'] ??
              stats['complaints_count'] ??
              0;
          final installationsCount = stats['active_installations_count'] ??
              stats['installations_count'] ??
              0;
          final pendingApproval = stats['pending_approval_count'] ?? 0;

          cards = [
            _UnifiedStatCard(
              title: 'Active\nComplaints',
              count: '$complaintsCount',
              icon: Icons.support_agent_outlined,
              color: const Color(0xFF2563EB),
              onTap: () => context.go('/complaints/dashboard'),
            ),
            _UnifiedStatCard(
              title: 'Active\nInstallations',
              count: '$installationsCount',
              icon: Icons.build_circle_outlined,
              color: const Color(0xFF0D9488),
              onTap: () => context.go('/installations/dashboard'),
            ),
            _UnifiedStatCard(
              title: 'Prospects\nAdded',
              count: '$prospectsAddedCount',
              icon: Icons.person_search_outlined,
              color: const Color(0xFF10B981),
              onTap: () => context.push('/crm/prospects'),
            ),
            _UnifiedStatCard(
              title: 'Today\'s\nTasks',
              count: '$tasksCount',
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () => context.push(AppRoutes.dailyTasks),
            ),
          ];
        } else if (hasSales) {
          cards = [
            _UnifiedStatCard(
              title: 'Active\nDeals',
              count: '$activeCount',
              icon: Icons.alt_route,
              color: const Color(0xFF2563EB),
              onTap: () => context.go(AppRoutes.pipelines),
            ),
            _UnifiedStatCard(
              title: 'Total\nLeads',
              count: '$leadsCount',
              icon: Icons.trending_up,
              color: const Color(0xFF0284C7),
              onTap: () => context.push('/crm/leads'),
            ),
            _UnifiedStatCard(
              title: 'Prospects\nAdded',
              count: '$prospectsAddedCount',
              icon: Icons.person_search_outlined,
              color: const Color(0xFF10B981),
              onTap: () => context.push('/crm/prospects'),
            ),
            _UnifiedStatCard(
              title: 'Today\'s\nTasks',
              count: '$opTasksCount',
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () => context.push(AppRoutes.dailyTasks),
            ),
          ];
        } else {
          cards = [
            _UnifiedStatCard(
              title: 'Active\nDeals',
              count: '$activeCount',
              icon: Icons.alt_route,
              color: const Color(0xFF2563EB),
              onTap: () => context.go(AppRoutes.pipelines),
            ),
            _UnifiedStatCard(
              title: 'Total\nLeads',
              count: '$leadsCount',
              icon: Icons.trending_up,
              color: const Color(0xFF0284C7),
              onTap: () => context.push('/crm/leads'),
            ),
            _UnifiedStatCard(
              title: 'Prospects\nAdded',
              count: '$prospectsAddedCount',
              icon: Icons.person_search_outlined,
              color: const Color(0xFF10B981),
              onTap: () => context.push('/crm/prospects'),
            ),
            _UnifiedStatCard(
              title: 'Today\'s\nTasks',
              count: '$opTasksCount',
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () => context.push(AppRoutes.dailyTasks),
            ),
          ];
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
          children: cards,
        );
      },
    );
  }
}

/// Exact KPI Card matching screenshot 1
class _UnifiedStatCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _UnifiedStatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
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
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
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
}

class _UnifiedQuickActionsGrid extends ConsumerWidget {
  final List<UserRole> roles;

  const _UnifiedQuickActionsGrid({required this.roles});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isAccountsOnly = roles.contains(UserRole.accounts) &&
        !roles.contains(UserRole.admin) &&
        !roles.contains(UserRole.manager) &&
        !roles.contains(UserRole.salesHead) &&
        !roles.contains(UserRole.sales);

    final categories = <_QuickActionCategory>[];

    if (isAccountsOnly) {
      categories.addAll([
        _QuickActionCategory(
          title: 'Finance & Projects',
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF005CE6),
          actions: [
            _QuickActionBtn(
              label: 'Project Manager',
              icon: Icons.solar_power_outlined,
              color: const Color(0xFF005CE6),
              onTap: () => context.go(AppRoutes.projectManager),
            ),
            _QuickActionBtn(
              label: 'Prospect',
              icon: Icons.person_search_outlined,
              color: const Color(0xFF10B981),
              onTap: () => context.push('/crm/prospects'),
            ),
          ],
        ),
        _QuickActionCategory(
          title: 'Work & Tasks',
          icon: Icons.calendar_month_outlined,
          color: const Color(0xFF4F46E5),
          actions: [
            _QuickActionBtn(
              label: 'Daily Tasks',
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () => context.push(AppRoutes.dailyTasks),
            ),
            _QuickActionBtn(
              label: 'Assigned Work',
              icon: Icons.calendar_month_outlined,
              color: const Color(0xFF4F46E5),
              onTap: () => context.push(AppRoutes.assignedWork),
            ),
          ],
        ),
        _QuickActionCategory(
          title: 'Catalog & Reports',
          icon: Icons.inventory_2_outlined,
          color: const Color(0xFF0D9488),
          actions: [
            _QuickActionBtn(
              label: 'View Products',
              icon: Icons.grid_view_outlined,
              color: const Color(0xFF0D9488),
              onTap: () => context.push('/products'),
            ),
            _QuickActionBtn(
              label: 'Daily Report',
              icon: Icons.summarize_outlined,
              color: const Color(0xFF2563EB),
              onTap: () => DailyReportModal.show(context, ref),
            ),
          ],
        ),
      ]);
    } else {
      final hasCrmStaff = roles.contains(UserRole.crmStaff);
      final hasBoq =
          roles.contains(UserRole.boq) || roles.contains(UserRole.serviceHead);
      final hasFactory = roles.contains(UserRole.factory);
      final hasPurchase = roles.contains(UserRole.purchase);
      final hasSales = roles.contains(UserRole.sales);
      final hasDeals = hasBoq || hasFactory || hasPurchase || hasSales;
      final hasAccounts = roles.contains(UserRole.accounts);
      final hasInstallation = roles.contains(UserRole.installation) ||
          roles.contains(UserRole.serviceHead);
      final hasComplaints = roles.contains(UserRole.complaints) ||
          roles.contains(UserRole.serviceHead);

      final bool isSalesOrAdminRole = roles.contains(UserRole.admin) ||
          roles.contains(UserRole.sales) ||
          roles.contains(UserRole.salesHead) ||
          roles.contains(UserRole.manager);
      final bool canShowProspectUnderSales = !isSalesOrAdminRole;

      categories.addAll([
        // 1. CRM
        if (hasCrmStaff || hasSales)
          _QuickActionCategory(
            title: 'CRM',
            icon: Icons.people_alt_outlined,
            color: const Color(0xFF3B82F6),
            actions: [
              _QuickActionBtn(
                label: 'CRM',
                icon: Icons.people_alt_outlined,
                color: const Color(0xFF3B82F6),
                onTap: () => context.push('/crm/dashboard'),
              ),
            ],
          ),

        // 2. Sales
        if (hasDeals || hasSales || canShowProspectUnderSales)
          _QuickActionCategory(
            title: 'Sales',
            icon: Icons.trending_up,
            color: const Color(0xFF6366F1),
            actions: [
              if (hasDeals)
                _QuickActionBtn(
                  label: 'Deals',
                  icon: Icons.currency_rupee,
                  color: const Color(0xFF6366F1),
                  onTap: () => context.go(AppRoutes.pipelines),
                ),
              if (hasSales)
                _QuickActionBtn(
                  label: 'Quotation Generator',
                  icon: Icons.request_quote_outlined,
                  color: const Color(0xFF0284C7),
                  onTap: () => context.push(AppRoutes.heatPumpQuotationHub),
                ),
              if (canShowProspectUnderSales)
                _QuickActionBtn(
                  label: 'Prospects',
                  icon: Icons.person_search_outlined,
                  color: const Color(0xFF10B981),
                  onTap: () => context.push('/crm/prospects'),
                ),
            ],
          ),

        // 3. Work & Tasks (All roles)
        _QuickActionCategory(
          title: 'Work & Tasks',
          icon: Icons.calendar_month_outlined,
          color: const Color(0xFF4F46E5),
          actions: [
            _QuickActionBtn(
              label: 'Assigned Work',
              icon: Icons.calendar_month_outlined,
              color: const Color(0xFF4F46E5),
              onTap: () => context.push(AppRoutes.assignedWork),
            ),
            _QuickActionBtn(
              label: 'Daily Tasks',
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF8B5CF6),
              onTap: () => context.push(AppRoutes.dailyTasks),
            ),
          ],
        ),

        // 4. Finance
        if (hasAccounts)
          _QuickActionCategory(
            title: 'Finance',
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF005CE6),
            actions: [
              _QuickActionBtn(
                label: 'Project Manager',
                icon: Icons.solar_power_outlined,
                color: const Color(0xFF005CE6),
                onTap: () => context.go(AppRoutes.projectManager),
              ),
            ],
          ),

        // 5. Field Operations & Service
        if (hasInstallation || hasComplaints)
          _QuickActionCategory(
            title: 'Field Operations & Service',
            icon: Icons.engineering_outlined,
            color: const Color(0xFF0284C7),
            actions: [
              if (hasInstallation)
                _QuickActionBtn(
                  label: 'Installations',
                  icon: Icons.build_circle_outlined,
                  color: const Color(0xFF0284C7),
                  onTap: () => context.go('/installations/dashboard'),
                ),
              if (hasComplaints)
                _QuickActionBtn(
                  label: 'Complaints',
                  icon: Icons.build_outlined,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => context.go('/complaints/dashboard'),
                ),
            ],
          ),

        // 6. Reports & Analytics (Today's Report for all roles, Customer 360 for sales)
        _QuickActionCategory(
          title: 'Reports & Analytics',
          icon: Icons.analytics_outlined,
          color: const Color(0xFF10B981),
          actions: [
            _QuickActionBtn(
              label: "Today's Report",
              icon: Icons.bar_chart_outlined,
              color: const Color(0xFF10B981),
              onTap: () => context.push('/reports/activity'),
            ),
            if (hasSales)
              _QuickActionBtn(
                label: 'Customer 360',
                icon: Icons.contact_page_outlined,
                color: const Color(0xFFF59E0B),
                onTap: () => context.push('/reports/customer'),
              ),
          ],
        ),

        // 7. Catalog & Inventory (View Products default for all, BOQ Items for boq role)
        _QuickActionCategory(
          title: 'Catalog & Inventory',
          icon: Icons.inventory_2_outlined,
          color: const Color(0xFFEC4899),
          actions: [
            _QuickActionBtn(
              label: 'View Products',
              icon: Icons.grid_view_outlined,
              color: const Color(0xFF0D9488),
              onTap: () => context.push('/products'),
            ),
            if (hasBoq)
              _QuickActionBtn(
                label: 'Manage BOQ Items',
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFFEC4899),
                onTap: () => context.push(AppRoutes.manageBoqItems),
              ),
          ],
        ),
      ]);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: categories.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 2),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(cat.icon, size: 13, color: cat.color),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cat.title.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: isDark
                                ? Colors.grey.shade400
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActionGrid(cat.actions, constraints, isDark),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildActionGrid(
      List<_QuickActionBtn> actions, BoxConstraints constraints, bool isDark) {
    final crossAxisCount = constraints.maxWidth >= 700 ? 4 : 2;
    final rows = <Widget>[];

    for (int i = 0; i < actions.length; i += crossAxisCount) {
      final rowChildren = <Widget>[];
      for (int j = 0; j < crossAxisCount; j++) {
        if (i + j < actions.length) {
          final a = actions[i + j];
          rowChildren.add(
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: a.onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : Colors.grey.shade200,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.02),
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
                            color: a.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(a.icon, color: a.color, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            a.label,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          rowChildren.add(const Expanded(child: SizedBox.shrink()));
        }
        if (j < crossAxisCount - 1) {
          rowChildren.add(const SizedBox(width: 8));
        }
      }
      rows.add(Row(children: rowChildren));
      if (i + crossAxisCount < actions.length) {
        rows.add(const SizedBox(height: 8));
      }
    }

    return Column(children: rows);
  }
}

class _QuickActionCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<_QuickActionBtn> actions;

  const _QuickActionCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.actions,
  });
}

class _QuickActionBtn {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _UnifiedRecentPipelineTile extends StatelessWidget {
  final SalesPipeline pipeline;

  const _UnifiedRecentPipelineTile({required this.pipeline});

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
    final stepValue = pipeline.currentStep.dbValue;
    final statusValue = pipeline.status.dbValue;
    final stepName = pipeline.currentStep.displayName;
    final companyName = pipeline.customer?.customerName ??
        pipeline.customer?.companyName ??
        pipeline.customer?.contactPerson ??
        '';
    final productName = pipeline.product?.name ?? '';
    final badgeColor = _getBadgeColor(stepValue, statusValue);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push('/pipelines/${pipeline.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : AppColors.border,
          ),
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
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    productName.isNotEmpty
                        ? productName
                        : 'Deal #${pipeline.id.substring(0, min(6, pipeline.id.length))}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: companyName.isNotEmpty ? 12 : 14,
                      fontWeight: companyName.isNotEmpty
                          ? FontWeight.normal
                          : FontWeight.w600,
                      color: companyName.isNotEmpty
                          ? (isDark
                              ? Colors.grey.shade400
                              : AppColors.textSecondary)
                          : (isDark ? Colors.white : AppColors.textPrimary),
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
