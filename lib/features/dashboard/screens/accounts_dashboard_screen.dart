// lib/features/dashboard/screens/accounts_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../reports/widgets/daily_report_modal.dart';
import '../../../core/widgets/network_status_chip.dart';

final accountsDashboardDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  final userId = profile?.id;

  int activeDealsCount = 0;
  try {
    final res = await supabase
        .from('sales_pipelines')
        .select('id')
        .neq('status', 'cancelled')
        .neq('status', 'suspended')
        .isFilter('deleted_at', null);
    activeDealsCount = (res as List).length;
  } catch (_) {}

  int completedDealsCount = 0;
  try {
    final res = await supabase
        .from('sales_pipelines')
        .select('id')
        .eq('status', 'completed')
        .isFilter('deleted_at', null);
    completedDealsCount = (res as List).length;
  } catch (_) {}

  int customersCount = 0;
  try {
    final res =
        await supabase.from('customers').select('id').isFilter('deleted_at', null);
    customersCount = (res as List).length;
  } catch (_) {}

  int todayProspectsCount = 0;
  if (userId != null) {
    try {
      final now = DateTime.now();
      final start =
          DateTime(now.year, now.month, now.day).toIso8601String();
      final end =
          DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
      final pRes = await supabase
          .from('crm_prospects')
          .select('id')
          .gte('created_at', start)
          .lte('created_at', end);
      todayProspectsCount = (pRes as List).length;
    } catch (_) {}
  }

  List<Map<String, dynamic>> recentDeals = [];
  try {
    final response = await supabase
        .from('sales_pipelines')
        .select(
            'id, current_step, status, updated_at, customers(customer_name, company_name), products(name)')
        .neq('status', 'cancelled')
        .isFilter('deleted_at', null)
        .order('updated_at', ascending: false)
        .limit(8);
    recentDeals = List<Map<String, dynamic>>.from(response as List);
  } catch (_) {}

  return {
    'activeDealsCount': activeDealsCount,
    'completedDealsCount': completedDealsCount,
    'customersCount': customersCount,
    'todayProspectsCount': todayProspectsCount,
    'recentDeals': recentDeals,
  };
});

class AccountsDashboardScreen extends ConsumerWidget {
  const AccountsDashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final dataAsync = ref.watch(accountsDashboardDataProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fullName = profile?.fullName ?? '';
    final displayName = fullName.isNotEmpty ? fullName.split(' ').first : 'Accounts';
    final avatarInitial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          // === Hero AppBar ===
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF1E1B4B),
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF1E1B4B),
                      Color(0xFF312E81)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white30, width: 2),
                            ),
                            child: Center(
                              child: Text(avatarInitial,
                                  style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                          ),
                          const Positioned(
                            bottom: 0,
                            right: 0,
                            child: NetworkAvatarDot(
                                size: 14, borderColor: Colors.white),
                          ),
                        ]),
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
                                    color: Colors.white.withValues(alpha: 0.75)),
                              ),
                              const SizedBox(height: 2),
                              Text(displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5)),
                              const SizedBox(height: 3),
                              Text(
                                DateFormat('EEEE, dd MMMM').format(DateTime.now()),
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('ACCOUNTS',
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    letterSpacing: 0.8)),
                            const SizedBox(height: 6),
                            const NetworkStatusChip(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => ref.refresh(accountsDashboardDataProvider),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Sign out of your account?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref.read(authControllerProvider.notifier).signOut();
                  }
                },
              ),
              const SizedBox(width: 4),
            ],
          ),

          // === Body ===
          SliverToBoxAdapter(
            child: dataAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))),
              error: (err, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text('Error: '))),
              data: (data) {
                final activeDeals = data['activeDealsCount'] as int;
                final completedDeals = data['completedDealsCount'] as int;
                final customers = data['customersCount'] as int;
                final prospectsToday = data['todayProspectsCount'] as int;
                final recentDeals =
                    data['recentDeals'] as List<Map<String, dynamic>>;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- KPI CARDS ---
                      Builder(builder: (ctx) {
                        final w = MediaQuery.of(ctx).size.width;
                        return GridView.count(
                          crossAxisCount: w >= 600 ? 4 : 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: w >= 600 ? 1.6 : 1.34,
                          children: [
                            _kpiCard('Active\nProjects', '$activeDeals',
                                Icons.alt_route, const Color(0xFF4F46E5),
                                () => context.go(AppRoutes.pipelines)),
                            _kpiCard('Total\nCustomers', '$customers',
                                Icons.people_outline, const Color(0xFF0891B2),
                                () => context.go(AppRoutes.customers)),
                            _kpiCard('Completed\nDeals', '$completedDeals',
                                Icons.check_circle_outline, const Color(0xFF10B981),
                                () => context.go(AppRoutes.pipelines)),
                            _kpiCard('Prospects\nToday', '$prospectsToday',
                                Icons.person_add_alt_1_outlined, const Color(0xFF8B5CF6),
                                () => context.go('/crm/prospects')),
                          ],
                        );
                      }),

                      const SizedBox(height: 24),

                      // --- QUICK ACTIONS ---
                      const Text('Quick Actions',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      _actionRow([
                        _actionBtn(context, 'Assigned Work',
                            Icons.calendar_month_outlined,
                            const Color(0xFF4F46E5), isDark,
                            () => context.push(AppRoutes.assignedWork)),
                        _actionBtn(context, 'Deals & Pipelines',
                            Icons.work_outline,
                            const Color(0xFF2563EB), isDark,
                            () => context.go(AppRoutes.pipelines)),
                      ]),
                      const SizedBox(height: 12),
                      _actionRow([
                        _actionBtn(context, 'Daily Tasks',
                            Icons.fact_check_outlined,
                            const Color(0xFF8B5CF6), isDark,
                            () => context.push(AppRoutes.dailyTasks)),
                        _actionBtn(context, 'Project Manager',
                            Icons.dashboard_outlined,
                            const Color(0xFF0D9488), isDark,
                            () => context.go(AppRoutes.projectManager)),
                      ]),
                      const SizedBox(height: 12),
                      _actionRow([
                        _actionBtn(context, 'Customers',
                            Icons.people_outlined,
                            const Color(0xFFD97706), isDark,
                            () => context.go(AppRoutes.customers)),
                        _actionBtn(context, 'Daily Report',
                            Icons.summarize_outlined,
                            const Color(0xFF0284C7), isDark,
                            () => DailyReportModal.show(context, ref)),
                      ]),

                      const SizedBox(height: 24),

                      // --- RECENT DEALS ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Active Deals',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          TextButton(
                              onPressed: () => context.go(AppRoutes.pipelines),
                              child: const Text('View All ->'))
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (recentDeals.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: Colors.grey.shade200)),
                          child: Column(children: [
                            Icon(Icons.check_circle_outline,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text('No active deals',
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                          ]),
                        )
                      else
                        ...recentDeals.map((deal) => _dealCard(context, deal)),

                      const SizedBox(height: 36),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String count, IconData icon, Color color,
      VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200, width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                    width: 42,
                    height: 42,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Icon(icon, color: Colors.white, size: 22)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                            height: 1.2),
                        maxLines: 2)),
              ]),
              const SizedBox(height: 10),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(count,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionRow(List<Widget> children) {
    return Row(children: [
      Expanded(child: children[0]),
      if (children.length > 1) ...[
        const SizedBox(width: 12),
        Expanded(child: children[1])
      ],
    ]);
  }

  Widget _actionBtn(BuildContext context, String title, IconData icon,
      Color color, bool isDark, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : Colors.grey.shade200,
                  width: 1.2),
              boxShadow: [
                BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]),
          child: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
  }

  Widget _dealCard(BuildContext context, Map<String, dynamic> deal) {
    final customer = deal['customers'];
    final product = deal['products'];
    final customerName = customer?['company_name'] ??
        customer?['customer_name'] ??
        'Unknown';
    final productName = product?['name'] ?? 'Standard System';
    final step = deal['current_step'] ?? 'quotation';
    final stepLabel = {
          'quotation': 'Quotation',
          'sales_order': 'Sales Order',
          'boq': 'BOQ',
          'factory_order': 'Factory',
          'purchase_order': 'Purchase',
          'completed': 'Completed'
        }[step] ??
        step;
    Color stepColor = const Color(0xFF4F46E5);
    if (step == 'completed') stepColor = const Color(0xFF10B981);
    if (step == 'boq' ||
        step == 'factory_order' ||
        step == 'purchase_order') {
      stepColor = const Color(0xFFD97706);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final dealId = deal['id']?.toString() ?? '';
            if (dealId.isNotEmpty) {
              context.push('/pipelines/$dealId');
            } else {
              context.push('/pipelines');
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: stepColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: Icon(Icons.work_outline,
                      color: stepColor, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(customerName,
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(productName,
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ])),
              Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: stepColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: stepColor.withValues(alpha: 0.3))),
                  child: Text(stepLabel,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: stepColor))),
            ]),
          ),
        ),
      ),
    );
  }
}
