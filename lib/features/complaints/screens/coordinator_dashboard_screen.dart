// lib/features/complaints/screens/coordinator_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../providers/complaints_provider.dart';
import '../data/models/complaint_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';
import 'complaints_leaderboard_screen.dart';

class CoordinatorDashboardScreen extends ConsumerStatefulWidget {
  const CoordinatorDashboardScreen({super.key});

  @override
  ConsumerState<CoordinatorDashboardScreen> createState() => _CoordinatorDashboardScreenState();
}

class _CoordinatorDashboardScreenState extends ConsumerState<CoordinatorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of Service Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authControllerProvider.notifier).signOut();
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final complaints = ref.watch(complaintsProvider);
    final isLoading = ref.watch(complaintsLoadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to Main Dashboard',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go(AppRoutes.adminDashboard);
            }
          },
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Complaints Dashboard',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Tickets',
            onPressed: () => ref.read(complaintsProvider.notifier).load(refresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'Error Code Settings',
            onPressed: () => context.push('/complaints/error-codes'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sign Out',
            onPressed: () => _showLogoutDialog(context, ref),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Tickets & Operations'),
            Tab(icon: Icon(Icons.emoji_events_outlined, size: 18), text: 'Technicians Leaderboard'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E1B4B),
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text(
          'Book Complaint',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        onPressed: () => context.push('/complaints/book'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOperationsTab(complaints, isLoading),
          const ComplaintsLeaderboardScreen(isEmbedded: true),
        ],
      ),
    );
  }

  Widget _buildOperationsTab(List<Complaint> complaints, bool isLoading) {
    final pendingCount = complaints.where((c) => c.status == 'pending').length;
    final inProgressCount = complaints.where((c) => c.status == 'in_progress' || c.status == 'assigned').length;
    final closedCount = complaints.where((c) => c.status == 'closed' || c.status == 'resolved').length;
    final totalCount = complaints.length;


    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 96.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Bento KPI Cards
          const Text(
            'Operations Overview',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 800;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 1.6 : 1.35,
                children: [
                  _buildKpiCard(
                    title: 'Total Tickets',
                    value: '$totalCount',
                    subtitle: 'Lifetime tickets',
                    badgeColor: const Color(0xFF6366F1),
                    icon: Icons.confirmation_number_outlined,
                  ),
                  _buildKpiCard(
                    title: 'Pending Dispatch',
                    value: '$pendingCount',
                    subtitle: '$pendingCount need tech',
                    badgeColor: const Color(0xFFEF4444),
                    icon: Icons.hourglass_empty_rounded,
                  ),
                  _buildKpiCard(
                    title: 'In Field / Active',
                    value: '$inProgressCount',
                    subtitle: '$inProgressCount dispatched',
                    badgeColor: const Color(0xFF3B82F6),
                    icon: Icons.local_shipping_outlined,
                  ),
                  _buildKpiCard(
                    title: 'Closed / Resolved',
                    value: '$closedCount',
                    subtitle: '$closedCount completed',
                    badgeColor: const Color(0xFF10B981),
                    icon: Icons.check_circle_outline,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Product Complaints Frequency Chart
          _buildProductComplaintsChart(complaints),

          const SizedBox(height: 20),

          // Recently Added Complaints Header
          const Text(
            'Recently Added Complaints',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          if (isLoading) ...[
            const ShimmerListLoader(),
          ] else if (complaints.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 52, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'No Complaints Found',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Book Complaint" below to log a new service ticket.',
                    style: TextStyle(fontFamily: 'Inter', color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: complaints.take(5).length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = complaints.take(5).toList()[index];
                return _buildComplaintTile(context, item);
              },
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color badgeColor,
    required IconData icon,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: badgeColor, size: 18),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintTile(BuildContext context, Complaint item) {
    Color statusColor;
    String statusText;
    switch (item.status) {
      case 'pending':
        statusColor = const Color(0xFFEF4444);
        statusText = 'PENDING';
        break;
      case 'assigned':
      case 'in_progress':
        statusColor = const Color(0xFF3B82F6);
        statusText = 'ACTIVE';
        break;
      case 'closed':
      case 'resolved':
        statusColor = const Color(0xFF10B981);
        statusText = 'CLOSED';
        break;
      default:
        statusColor = Colors.grey;
        statusText = item.status.toUpperCase();
    }

    final isStaff = item.source == 'staff';

    return InkWell(
      onTap: () => context.push('/complaints/details/${item.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      item.ticketNumber,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E1B4B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isStaff ? const Color(0xFFEEF2FF) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isStaff ? const Color(0xFFC7D2FE) : const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isStaff ? Icons.badge_outlined : Icons.phone_android_outlined,
                            size: 11,
                            color: isStaff ? const Color(0xFF4F46E5) : const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isStaff ? 'Staff' : 'Customer',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isStaff ? const Color(0xFF4F46E5) : const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  item.customerName,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
                ),
                if (item.productName != null && item.productName!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('•', style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(width: 8),
                  const Icon(Icons.solar_power_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      item.productName!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      item.technicianName != null ? Icons.engineering : Icons.person_off_outlined,
                      size: 14,
                      color: item.technicianName != null ? const Color(0xFF6366F1) : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.technicianName != null ? item.technicianName! : 'Not Assigned',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: item.technicianName != null ? FontWeight.w600 : FontWeight.normal,
                        color: item.technicianName != null ? const Color(0xFF6366F1) : Colors.grey,
                      ),
                    ),
                  ],
                ),
                Text(
                  item.tatRemaining,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductComplaintsChart(List<Complaint> complaints) {
    if (complaints.isEmpty) return const SizedBox.shrink();

    // Group complaints by product
    final Map<String, int> productCounts = {};
    for (var c in complaints) {
      final p = (c.productName != null && c.productName!.isNotEmpty) ? c.productName! : 'Other Products';
      productCounts[p] = (productCounts[p] ?? 0) + 1;
    }

    final sortedEntries = productCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sortedEntries.isNotEmpty ? sortedEntries.first.value : 1;

    final palette = [
      const Color(0xFF6D28D9),
      const Color(0xFF3B82F6),
      const Color(0xFF0D9488),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
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
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 20, color: Color(0xFF6D28D9)),
                  SizedBox(width: 8),
                  Text(
                    'Most Reported Products',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D28D9).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${sortedEntries.length} Products Tracked',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Distribution of complaints by product line',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ...sortedEntries.take(5).toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final pName = entry.value.key;
            final count = entry.value.value;
            final pct = (count / complaints.length) * 100;
            final fill = count / maxVal;
            final color = palette[idx % palette.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                pName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$count ticket${count > 1 ? "s" : ""} (${pct.toStringAsFixed(1)}%)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: fill,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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
}
