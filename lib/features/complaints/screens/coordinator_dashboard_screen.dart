// lib/features/complaints/screens/coordinator_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/shimmer_loader.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/complaints_provider.dart';
import '../data/models/complaint_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';
import '../../../core/router/app_router.dart';

class CoordinatorDashboardScreen extends ConsumerWidget {
  const CoordinatorDashboardScreen({super.key});

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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final complaints = ref.watch(complaintsProvider);
    final profile = ref.watch(currentProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdminOrManager = profile?.primaryRole == UserRole.admin || profile?.primaryRole == UserRole.manager;

    final pendingCount = complaints.where((c) => c.status == 'pending').length;
    final inProgressCount = complaints.where((c) => c.status == 'in_progress' || c.status == 'assigned').length;
    final closedCount = complaints.where((c) => c.status == 'closed').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        
        return Scaffold(
          backgroundColor: isWide ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: isAdminOrManager
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Back to Admin Panel',
                onPressed: () => context.go(AppRoutes.adminDashboard),
              )
            : null,
        title: const Text(
          'Complaints Dashboard',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined, color: Colors.white),
            tooltip: 'Service History',
            onPressed: () => context.push('/complaints/history'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sign Out',
            onPressed: () => _showLogoutDialog(context, ref),
          ),
        ],
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Bento Grid KPIs
            const Text(
              'Performance Overview',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
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
                  childAspectRatio: isWide ? 1.6 : 1.4,
                  children: [
                _buildKpiCard(
                  title: 'Pending Approval',
                  value: '$pendingCount',
                  subtitle: '$pendingCount pending',
                  badgeColor: const Color(0xFFEF4444),
                  icon: Icons.hourglass_empty_rounded,
                ),
                _buildKpiCard(
                  title: 'Active / Forwarded',
                  value: '$inProgressCount',
                  subtitle: 'In field resolution',
                  badgeColor: const Color(0xFF3B82F6),
                  icon: Icons.local_shipping_outlined,
                ),
                _buildKpiCard(
                  title: 'Complaints Closed',
                  value: '$closedCount',
                  subtitle: '$closedCount resolved',
                  badgeColor: const Color(0xFF10B981),
                  icon: Icons.check_circle_outline,
                ),
                _buildKpiCard(
                  title: 'Repeat Issues',
                  value: '00',
                  subtitle: '0 repeat issues',
                  badgeColor: const Color(0xFFF59E0B),
                  icon: Icons.replay_circle_filled_rounded,
                ),
              ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Recent Closed & SLA Complaints
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Service Requests',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/complaints/history'),
                  child: const Text('View All History'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (ref.watch(complaintsLoadingProvider)) ...[
              const ShimmerListLoader(),
            ] else if (complaints.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No Complaints Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    SizedBox(height: 4),
                    Text('Tap "Book Complaint" below to create a new service ticket.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ] else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: complaints.length,
                itemBuilder: (context, index) {
                  final item = complaints[index];
                  return _buildComplaintTile(context, item);
                },
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
      },
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              Icon(icon, size: 20, color: badgeColor),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: badgeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintTile(BuildContext context, Complaint item) {
    Color statusColor;
    if (item.status == 'closed') {
      statusColor = const Color(0xFF10B981);
    } else if (item.status == 'in_progress' || item.status == 'assigned') {
      statusColor = const Color(0xFF3B82F6);
    } else {
      statusColor = const Color(0xFFF59E0B);
    }

    return InkWell(
      onTap: () => context.push('/complaints/details/${item.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D28D9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.ticketNumber,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6D28D9),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
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
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                item.customerName,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                item.tatRemaining,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          if (item.technicianName != null) ...[
            const Divider(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: item.technicianAvatarUrl != null
                      ? NetworkImage(item.technicianAvatarUrl!)
                      : null,
                  child: item.technicianAvatarUrl == null
                      ? const Icon(Icons.person, size: 14)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  'Assigned Tech: ${item.technicianName}',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ]
        ],
      ),
    ),
  );
}
}
