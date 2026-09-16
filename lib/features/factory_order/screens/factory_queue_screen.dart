// lib/features/factory_order/screens/factory_queue_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/models/factory_order.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/sync_status_indicator.dart';
import '../../reports/widgets/daily_report_modal.dart';

final factoryQueueProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  final response = await supabase.from('factory_orders').select('''
        *,
        sales_pipelines(
          id,
          customers(customer_name, contact_person),
          products(name, category)
        )
      ''').inFilter('status', [
    'pending',
    'in_production'
  ]).order('created_at', ascending: true);

  return List<Map<String, dynamic>>.from(response as List);
});

class FactoryQueueScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(factoryQueueProvider);
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(factoryQueueProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: const Color(0xFF1E1B4B),
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
                              AppColors.primary.withValues(alpha: 0.25),
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
                              const Color(0xFF06B6D4).withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Content
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
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    (profile?.fullName ?? 'F')[0].toUpperCase(),
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
                                        color: Colors.white.withValues(alpha: 0.6),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      profile?.fullName ?? 'Factory Staff',
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
                          const SizedBox(height: 12),
                          // Responsive stat pills wrap
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
                                profile?.primaryRole.name.toUpperCase() ?? 'FACTORY',
                                Icons.badge_outlined,
                              ),
                              _buildHeaderStat(
                                'Status',
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
                  onPressed: () => ref.invalidate(factoryQueueProvider),
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
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: InkWell(
                  onTap: () => DailyReportModal.show(context, ref),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.summarize_outlined, color: Color(0xFF6366F1), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Download Daily Report',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Export or download your activities for today (PDF / Excel)',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download, size: 14, color: Color(0xFF6366F1)),
                              SizedBox(width: 4),
                              Text(
                                'Report',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            queueAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.factory_outlined,
                              size: 64, color: AppColors.textSecondary),
                          SizedBox(height: 16),
                          Text(
                            'Queue is Clear',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No pending factory orders.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final order = orders[index];
                        final pipeline =
                            order['sales_pipelines'] as Map<String, dynamic>?;
                        final customer =
                            pipeline?['customers'] as Map<String, dynamic>?;
                        final product = pipeline?['products'] as Map<String, dynamic>?;
                        final status =
                            FactoryOrderStatus.fromString(order['status'] as String);
                        final createdAt = DateTime.parse(order['created_at'] as String);
                        final expectedDate = order['expected_completion_date'] != null
                            ? DateTime.parse(
                                order['expected_completion_date'] as String)
                            : null;
                        final isOverdue = expectedDate != null &&
                            expectedDate.isBefore(DateTime.now()) &&
                            status != FactoryOrderStatus.completed;

                        return GestureDetector(
                          onTap: () => context.push(
                            AppRoutes.factoryOrderForm
                                .replaceAll(':id', pipeline?['id'] as String? ?? ''),
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isOverdue ? AppColors.error : AppColors.border,
                                width: isOverdue ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: status == FactoryOrderStatus.inProduction
                                            ? AppColors.infoLight
                                            : AppColors.warningLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        status == FactoryOrderStatus.inProduction
                                            ? Icons.settings_outlined
                                            : Icons.pending_outlined,
                                        color: status == FactoryOrderStatus.inProduction
                                            ? AppColors.info
                                            : AppColors.warning,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            customer?['customer_name'] as String? ?? customer?['company_name'] as String? ?? '',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            product?['name'] as String? ?? '',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _StatusBadge(status: status),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined,
                                        size: 12, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Created ${DateFormat('dd MMM').format(createdAt)}',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (expectedDate != null) ...[
                                      const SizedBox(width: 12),
                                      Icon(
                                        isOverdue
                                            ? Icons.warning_outlined
                                            : Icons.schedule,
                                        size: 12,
                                        color: isOverdue
                                            ? AppColors.error
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isOverdue
                                            ? 'OVERDUE — ${DateFormat('dd MMM').format(expectedDate)}'
                                            : 'Due ${DateFormat('dd MMM').format(expectedDate)}',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          fontWeight: isOverdue
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isOverdue
                                              ? AppColors.error
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    const Icon(Icons.chevron_right,
                                        color: AppColors.textDisabled, size: 16),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: orders.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  static Widget _buildHeaderStat(
    String label,
    String value,
    IconData icon, {
    Color iconColor = Colors.white,
    double iconSize = 13,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: iconSize),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final FactoryOrderStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bg;
    switch (status) {
      case FactoryOrderStatus.pending:
        color = AppColors.warning;
        bg = AppColors.warningLight;
        break;
      case FactoryOrderStatus.inProduction:
        color = AppColors.info;
        bg = AppColors.infoLight;
        break;
      case FactoryOrderStatus.completed:
        color = AppColors.success;
        bg = AppColors.successLight;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
