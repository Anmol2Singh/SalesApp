// lib/features/dashboard/screens/sales_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/user_role.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pipelines/providers/pipelines_provider.dart';
import '../../../core/models/customer.dart';
import '../../crm/providers/crm_providers.dart';
import '../../../core/widgets/dashboard_switcher_button.dart';
import '../../../core/widgets/network_status_chip.dart';

class SalesDashboardScreen extends ConsumerWidget {
  const SalesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final pipelinesAsync = ref.watch(pipelinesNotifierProvider);

    final leadsAsync = ref.watch(leadsProvider);
    final activeLeadsCount = leadsAsync.valueOrNull
            ?.where((l) =>
                l.status.toLowerCase() != 'won' &&
                l.status.toLowerCase() != 'lost')
            .length ??
        0;

    final rawName = profile?.fullName.trim() ?? '';
    final displayName = rawName.isNotEmpty ? rawName : (profile?.primaryRole.displayName ?? 'Sales Executive');
    final avatarInitial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 154,
            pinned: true,
            backgroundColor: const Color(0xFF1E1B4B),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            automaticallyImplyLeading: false,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
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
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    width: 2,
                                  ),
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                child: Center(
                                  child: Text(
                                    avatarInitial,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const Positioned(
                                bottom: 1,
                                right: 1,
                                child: NetworkAvatarDot(
                                  size: 14,
                                  borderColor: Color(0xFF1E1B4B),
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
                                    color: Colors.white.withValues(alpha: 0.8),
                                    letterSpacing: 0.3,
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
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
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
                                (profile?.primaryRole.displayName ?? 'SALES')
                                    .toUpperCase(),
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
                  ref.read(pipelinesNotifierProvider.notifier).refresh();
                  ref.invalidate(leadsProvider);
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
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error),
                          child: const Text('Logout',
                              style: TextStyle(color: Colors.white)),
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
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 2x2 Metric KPI Cards (Unified Dashboard Style)
                pipelinesAsync.when(
                  data: (pipelines) {
                    final total = pipelines.length;
                    final inProgress = pipelines
                        .where((p) => p.status == PipelineStatus.inProgress)
                        .length;
                    final completed = pipelines
                        .where((p) => p.status == PipelineStatus.completed)
                        .length;

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth >= 900
                            ? 4
                            : constraints.maxWidth >= 550
                                ? 4
                                : 2;
                        final childAspectRatio = constraints.maxWidth >= 900
                            ? 2.3
                            : constraints.maxWidth >= 550
                                ? 2.0
                                : 1.85;

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: childAspectRatio,
                          children: [
                            _SalesStatCard(
                              title: 'Active\nDeals',
                              value: '$inProgress',
                              icon: Icons.alt_route,
                              color: const Color(0xFF2563EB),
                              onTap: () => context.go(AppRoutes.pipelines),
                            ),
                            _SalesStatCard(
                              title: 'Completed\nDeals',
                              value: '$completed',
                              icon: Icons.verified_outlined,
                              color: const Color(0xFF10B981),
                              onTap: () => context.go(AppRoutes.pipelines),
                            ),
                            _SalesStatCard(
                              title: 'Customer\nLeads',
                              value: '$activeLeadsCount',
                              icon: Icons.person,
                              color: const Color(0xFF06B6D4),
                              onTap: () => context.push('/crm/prospects'),
                            ),
                            _SalesStatCard(
                              title: 'Total\nDeals',
                              value: '$total',
                              icon: Icons.handshake_outlined,
                              color: const Color(0xFF8B5CF6),
                              onTap: () => context.go(AppRoutes.pipelines),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 10),

                // Quick actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final roles = profile?.roles ?? [];
                    final isHeadOrAdmin = profile?.primaryRole == UserRole.admin ||
                        profile?.primaryRole == UserRole.manager ||
                        profile?.primaryRole == UserRole.salesHead ||
                        roles.contains(UserRole.admin) ||
                        roles.contains(UserRole.salesHead);

                    final actionCards = <_ActionCard>[];

                    // Requirement 4: Exclude "New Customer" & "View Deals" for sales person & sales head as already in nav bar
                    final isSalesRole = profile?.primaryRole == UserRole.sales ||
                        profile?.primaryRole == UserRole.salesHead ||
                        roles.contains(UserRole.sales) ||
                        roles.contains(UserRole.salesHead);

                    if (!isSalesRole && (profile?.primaryRole.canCreateCustomers ?? false)) {
                      actionCards.add(
                        _ActionCard(
                          icon: Icons.business_outlined,
                          label: 'New Customer',
                          color: AppColors.primary,
                          onTap: () => context.push(AppRoutes.createCustomer),
                        ),
                      );
                    }

                    if (!isSalesRole) {
                      actionCards.add(
                        _ActionCard(
                          icon: Icons.alt_route_outlined,
                          label: 'View Deals',
                          color: const Color(0xFF6366F1),
                          onTap: () => context.go(AppRoutes.pipelines),
                        ),
                      );
                    }

                    actionCards.add(
                      _ActionCard(
                        icon: Icons.inventory_2_outlined,
                        label: 'View Products',
                        color: Colors.teal,
                        onTap: () => context.push('/products'),
                      ),
                    );

                    // Multi-role direct Quick Action: Complaints (serviceHead / admin)
                    if (roles.contains(UserRole.serviceHead) || isHeadOrAdmin) {
                      actionCards.add(
                        _ActionCard(
                          icon: Icons.support_agent_outlined,
                          label: 'Complaints',
                          color: const Color(0xFF8B5CF6),
                          onTap: () => context.push('/complaints/dashboard'),
                        ),
                      );
                    }

                    // Multi-role direct Quick Action: Installations (installation / serviceHead / admin)
                    if (roles.contains(UserRole.installation) || roles.contains(UserRole.serviceHead) || isHeadOrAdmin) {
                      actionCards.add(
                        _ActionCard(
                          icon: Icons.build_circle_outlined,
                          label: 'Installations',
                          color: const Color(0xFF0284C7),
                          onTap: () => context.push('/installations/dashboard'),
                        ),
                      );
                    }

                    // Multi-role direct Quick Action: Manage BOQ Items (boq / admin)
                    if (roles.contains(UserRole.boq) || isHeadOrAdmin) {
                      actionCards.add(
                        _ActionCard(
                          icon: Icons.format_list_bulleted_outlined,
                          label: 'BOQ Items',
                          color: const Color(0xFFEC4899),
                          onTap: () => context.push(AppRoutes.manageBoqItems),
                        ),
                      );
                    }

                    // Multi-role direct Quick Action: Factory Queue (factory)
                    if (roles.contains(UserRole.factory)) {
                      actionCards.add(
                        _ActionCard(
                          icon: Icons.precision_manufacturing_outlined,
                          label: 'Factory Queue',
                          color: const Color(0xFFEA580C),
                          onTap: () => context.push(AppRoutes.factoryQueue),
                        ),
                      );
                    }

                    // Multi-role direct Quick Action: Material Queue (purchase)
                    if (roles.contains(UserRole.purchase)) {
                      actionCards.add(
                        _ActionCard(
                          icon: Icons.shopping_cart_outlined,
                          label: 'Material Queue',
                          color: const Color(0xFF10B981),
                          onTap: () => context.push(AppRoutes.purchaseQueue),
                        ),
                      );
                    }

                    actionCards.add(
                      _ActionCard(
                        icon: Icons.download_outlined,
                        label: "Today's Report",
                        color: AppColors.success,
                        onTap: () => context.push('/reports/activity'),
                      ),
                    );

                    actionCards.add(
                      _ActionCard(
                        icon: Icons.contact_page_outlined,
                        label: 'Customer 360',
                        color: const Color(0xFFF59E0B),
                        onTap: () => context.push('/reports/customer'),
                      ),
                    );

                    actionCards.add(
                      _ActionCard(
                        icon: Icons.people_alt_outlined,
                        label: 'CRM',
                        color: Colors.blueAccent,
                        onTap: () => context.push('/crm/dashboard'),
                      ),
                    );

                    actionCards.add(
                      _ActionCard(
                        icon: Icons.fact_check_outlined,
                        label: 'Daily Tasks',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => context.push(AppRoutes.dailyTasks),
                      ),
                    );

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth > 550 ? 4 : 3;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: actionCards.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.15,
                          ),
                          itemBuilder: (context, idx) => actionCards[idx],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Recent activity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My Recent Deals',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.pipelines),
                      child: const Text('See All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                pipelinesAsync.when(
                  data: (pipelines) {
                    if (pipelines.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(Icons.alt_route_outlined,
                                  size: 48, color: AppColors.textSecondary),
                              const SizedBox(height: 12),
                              const Text(
                                'No deals yet',
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () =>
                                    context.push(AppRoutes.createCustomer),
                                child: const Text('Start First Deal'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: pipelines.take(5).map((p) {
                        return GestureDetector(
                          onTap: () => context.push(
                            AppRoutes.pipelineDetail.replaceAll(':id', p.id),
                          ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.customer?.companyName ?? '',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        p.product?.name ?? '',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Builder(
                                  builder: (context) {
                                    final badgeColor = _getDealBadgeColor(p.currentStep, p.status);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: badgeColor.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        p.status == PipelineStatus.completed ? 'Completed' : p.currentStep.displayName,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: badgeColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (e, _) => Center(child: Text('$e')),
                ),
                const SizedBox(height: 110),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

Color _getDealBadgeColor(PipelineStep step, PipelineStatus status) {
  if (status == PipelineStatus.completed) return const Color(0xFF10B981);
  if (status == PipelineStatus.suspended || status == PipelineStatus.cancelled) return Colors.red;
  
  switch (step) {
    case PipelineStep.quotation:
      return Colors.amber.shade700;
    case PipelineStep.salesOrder:
      return Colors.blue;
    case PipelineStep.boq:
      return Colors.purple;
    case PipelineStep.factoryOrder:
      return Colors.orange;
    case PipelineStep.purchaseOrder:
      return Colors.teal;
    default:
      return AppColors.primary;
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionCard({
    required this.icon,
    required this.label,
    this.color = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SalesStatCard({
    required this.title,
    required this.value,
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
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade300
                            : const Color(0xFF1E293B),
                        height: 1.15,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
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
