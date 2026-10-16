// lib/features/installations/screens/installation_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../providers/installations_provider.dart';
import '../data/models/installation_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/dashboard_switcher_button.dart';

class InstallationDashboardScreen extends ConsumerStatefulWidget {
  const InstallationDashboardScreen({super.key});

  @override
  ConsumerState<InstallationDashboardScreen> createState() =>
      _InstallationDashboardScreenState();
}

class _InstallationDashboardScreenState
    extends ConsumerState<InstallationDashboardScreen> {
  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content:
            const Text('Are you sure you want to sign out of Installation Portal?'),
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
    final installations = ref.watch(installationsProvider);
    final isLoading = ref.watch(installationsLoadingProvider);
    final profile = ref.watch(currentProfileProvider);
    final isAdmin = profile?.primaryRole == UserRole.admin ||
        profile?.primaryRole == UserRole.manager ||
        profile?.roles.contains(UserRole.admin) == true;

    final rawName = profile?.fullName.trim() ?? '';
    final displayName = rawName.isNotEmpty
        ? rawName
        : (profile?.primaryRole.displayName ?? 'Installation Coordinator');
    final avatarInitial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'I';

    if (isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.navBarColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Back',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else if (context.canPop()) {
                context.pop();
              } else {
                final profile = ref.read(currentProfileProvider);
                context.go(profile != null ? getRoleHome(profile.primaryRole) : AppRoutes.login);
              }
            },
          ),
          title: const Text(
            'Installation Dashboard',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          actions: [
            const DashboardSwitcherButton(),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
              tooltip: 'Refresh',
              onPressed: () =>
                  ref.read(installationsProvider.notifier).load(refresh: true),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: _buildOperationsView(installations, isLoading, isAdmin: true),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.navBarColor,
          icon: const Icon(Icons.build_circle_outlined, color: Colors.white),
          label: const Text(
            'New Installation',
            style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          onPressed: () => context.push('/installations/book'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.navBarColor,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            automaticallyImplyLeading: false,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
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
                          Color(0xFF1E3A8A),
                          Color(0xFF0284C7),
                          Color(0xFF0D9488),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, $displayName',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Installation Management Portal',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
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
                icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                tooltip: 'Refresh',
                onPressed: () =>
                    ref.read(installationsProvider.notifier).load(refresh: true),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                tooltip: 'Sign Out',
                onPressed: () => _showLogoutDialog(context, ref),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ],
        body: _buildOperationsView(installations, isLoading, isAdmin: false),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        icon: const Icon(Icons.build_circle_outlined, color: Colors.white),
        label: const Text(
          'New Installation',
          style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        onPressed: () => context.push('/installations/book'),
      ),
    );
  }

  Widget _buildOperationsView(List<Installation> installations, bool isLoading,
      {bool isAdmin = false}) {
    final pendingCount =
        installations.where((c) => c.status == 'pending').length;
    final inProgressCount = installations
        .where((c) => c.status == 'in_progress' || c.status == 'assigned')
        .length;
    final closedCount = installations
        .where((c) => c.status == 'closed' || c.status == 'resolved')
        .length;
    final totalCount = installations.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 80.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operations Overview',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 800;
              final crossAxisCount = isWide ? 4 : 2;
              final childAspectRatio = isWide ? 1.6 : 1.34;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
                children: [
                  _buildKpiCard(
                    title: 'Total\nInstallations',
                    value: '$totalCount',
                    badgeColor: const Color(0xFF2563EB),
                    icon: Icons.assignment_outlined,
                  ),
                  _buildKpiCard(
                    title: 'Pending\nAllocation',
                    value: '$pendingCount',
                    badgeColor: const Color(0xFFEF4444),
                    icon: Icons.hourglass_empty_rounded,
                  ),
                  _buildKpiCard(
                    title: 'In\nProgress',
                    value: '$inProgressCount',
                    badgeColor: const Color(0xFF06B6D4),
                    icon: Icons.engineering_outlined,
                  ),
                  _buildKpiCard(
                    title: 'Completed\nInstalls',
                    value: '$closedCount',
                    badgeColor: const Color(0xFF10B981),
                    icon: Icons.check_circle_outline,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),

          // Action navigation shortcuts
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  title: 'All Installations',
                  subtitle: 'List & Filter ($totalCount)',
                  icon: Icons.list_alt_outlined,
                  color: const Color(0xFF2563EB),
                  onTap: () => context.push('/installations'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionBtn(
                  title: 'Assign Techs',
                  subtitle: 'Pending ($pendingCount)',
                  icon: Icons.person_add_alt_1_outlined,
                  color: const Color(0xFFD97706),
                  onTap: () => context.push('/installations/assign'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  title: 'History',
                  subtitle: 'Closed ($closedCount)',
                  icon: Icons.history_rounded,
                  color: const Color(0xFF0D9488),
                  onTap: () => context.push('/installations/history'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionBtn(
                  title: 'Technicians',
                  subtitle: 'Manage Roster',
                  icon: Icons.engineering_outlined,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => context.push('/complaints/technicians'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Recently Added Installations
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Installations',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (installations.isNotEmpty)
                TextButton(
                  onPressed: () => context.push('/installations'),
                  child: const Text('View All'),
                ),
            ],
          ),
          const SizedBox(height: 6),

          if (isLoading) ...[
            const ShimmerListLoader(),
          ] else if (installations.isEmpty) ...[
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
                  Icon(Icons.build_circle_outlined,
                      size: 52, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    'No Installations Found',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "New Installation" below to schedule an installation job.',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.grey.shade600,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: installations.take(5).length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = installations.take(5).toList()[index];
                return _buildInstallationTile(context, item);
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
    required Color badgeColor,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
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
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
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
                    color: badgeColor,
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
                      color: isDark ? Colors.grey.shade300 : const Color(0xFF1E293B),
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
                value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
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
                  color: color.withValues(alpha: 0.1),
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
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstallationTile(BuildContext context, Installation item) {
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
        statusText = 'COMPLETED';
        break;
      default:
        statusColor = Colors.grey;
        statusText = item.status.toUpperCase();
    }

    return InkWell(
      onTap: () => context.push('/installations/details/${item.id}'),
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
                Text(
                  item.ticketNumber,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textSecondary),
                ),
                if (item.productName != null &&
                    item.productName!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('•', style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(width: 8),
                  const Icon(Icons.solar_power_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      item.productName!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textSecondary),
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
                      item.technicianName != null
                          ? Icons.engineering
                          : Icons.person_off_outlined,
                      size: 14,
                      color: item.technicianName != null
                          ? const Color(0xFF0284C7)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.technicianName != null
                          ? item.technicianName!
                          : 'Not Assigned',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: item.technicianName != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: item.technicianName != null
                            ? const Color(0xFF0284C7)
                            : Colors.grey,
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
}
