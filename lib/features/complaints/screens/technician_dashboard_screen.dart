import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../providers/complaints_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'complaints_leaderboard_screen.dart';
import '../data/models/complaint_model.dart';
import '../../../features/installations/providers/installations_provider.dart';
import '../../../features/installations/data/models/installation_model.dart';
import '../../../core/widgets/network_status_chip.dart';

class TechnicianDashboardScreen extends ConsumerWidget {
  const TechnicianDashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Future<void> _launchMaps(BuildContext context, String address) async {
    final query = Uri.encodeComponent(address);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final complaints = ref.watch(complaintsProvider);
    final profile = ref.watch(currentProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter assigned complaints for this technician (Robust matching by ID, Name, Email, Phone, and Notes)
    final assignedComplaints = complaints.where((c) {
      if (profile == null) return true;
      final pName = profile.fullName.trim().toLowerCase();
      final pEmail = profile.email.trim().toLowerCase();
      final pPhone = (profile.phone ?? '').trim().replaceAll(RegExp(r'[^\d+]'), '');
      final tName = (c.technicianName ?? '').trim().toLowerCase();
      final tId = (c.technicianId ?? '').trim();
      final notes = (c.notes ?? '').toLowerCase();
      
      final matchesId = tId.isNotEmpty && (tId == profile.id);
      final matchesName = tName.isNotEmpty && (tName == pName || tName.contains(pName) || pName.contains(tName));
      final matchesEmail = pEmail.isNotEmpty && (tName.contains(pEmail) || notes.contains(pEmail));
      final matchesNotes = pName.isNotEmpty && notes.contains(pName);
      final matchesPhone = pPhone.isNotEmpty && (notes.contains(pPhone) || (c.customerPhone.isNotEmpty && notes.contains(pPhone)));
      
      return matchesId || matchesName || matchesEmail || matchesNotes || matchesPhone;
    }).toList();

    final myActiveTasks = assignedComplaints.where((c) => c.status == 'assigned' || c.status == 'in_progress').toList();
    final activeTask = myActiveTasks.isNotEmpty ? myActiveTasks.first : null;
    final recentComplaints = assignedComplaints.take(5).toList();

    final installations = ref.watch(installationsProvider);
    final assignedInstallations = installations.where((i) {
      if (profile == null) return true;
      final pName = profile.fullName.trim().toLowerCase();
      final pEmail = profile.email.trim().toLowerCase();
      final pPhone = (profile.phone ?? '').trim().replaceAll(RegExp(r'[^\d+]'), '');
      final tName = (i.technicianName ?? '').trim().toLowerCase();
      final tId = (i.technicianId ?? '').trim();
      final notes = (i.notes ?? '').toLowerCase();
      
      final matchesId = tId.isNotEmpty && (tId == profile.id);
      final matchesName = tName.isNotEmpty && (tName == pName || tName.contains(pName) || pName.contains(tName));
      final matchesEmail = pEmail.isNotEmpty && (tName.contains(pEmail) || notes.contains(pEmail));
      final matchesNotes = pName.isNotEmpty && notes.contains(pName);
      final matchesPhone = pPhone.isNotEmpty && (notes.contains(pPhone) || (i.customerPhone.isNotEmpty && notes.contains(pPhone)));
      
      return matchesId || matchesName || matchesEmail || matchesNotes || matchesPhone;
    }).toList();
    
    final myActiveInstallations = assignedInstallations.where((i) => i.status == 'assigned' || i.status == 'in_progress' || i.status == 'pending' || i.status == 'scheduled').toList();
    final recentInstallations = assignedInstallations.take(5).toList();

    final isWide = MediaQuery.of(context).size.width >= 800;

    final rawName = profile?.fullName.trim() ?? '';
    final displayName = rawName.isNotEmpty ? rawName : 'Technician';
    final avatarInitial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.background,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 74),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/complaints/book'),
          backgroundColor: const Color(0xFF0F172A),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'New Complaint',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(complaintsProvider.notifier).load(refresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 154,
              pinned: true,
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              automaticallyImplyLeading: false,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
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
                                  'TECHNICIAN',
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
                  onPressed: () {
                    ref.read(complaintsProvider.notifier).load(refresh: true);
                    ref.read(installationsProvider.notifier).load(refresh: true);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Sign Out',
                  onPressed: () => _showLogoutDialog(context, ref),
                ),
                const SizedBox(width: 4),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.all(isWide ? 32.0 : 16.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Quick Actions Section (Leaderboard, View Products, Installations)
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Quick Action 1: Daily Tasks
                      Expanded(
                        child: _buildQuickActionButton(
                          context,
                          title: 'Daily Tasks',
                          subtitle: 'Tasks completed',
                          icon: Icons.fact_check_outlined,
                          gradientColors: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          onTap: () => context.push(AppRoutes.dailyTasks),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Quick Action 2: Leaderboard
                      Expanded(
                        child: _buildQuickActionButton(
                          context,
                          title: 'Leaderboard',
                          subtitle: 'Rankings & points',
                          icon: Icons.emoji_events_outlined,
                          gradientColors: const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => const ComplaintsLeaderboardScreen(isEmbedded: false),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Quick Action 3: View Products
                      Expanded(
                        child: _buildQuickActionButton(
                          context,
                          title: 'View Products',
                          subtitle: 'Catalog & specs',
                          icon: Icons.inventory_2_outlined,
                          gradientColors: const [Color(0xFF0D9488), Color(0xFF10B981)],
                          onTap: () => context.push('/products'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Quick Action 4: Installations
                      Expanded(
                        child: _buildQuickActionButton(
                          context,
                          title: 'Installations',
                          subtitle: '${assignedInstallations.length} assigned',
                          icon: Icons.build_circle_outlined,
                          gradientColors: const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                          onTap: () => context.push('${AppRoutes.technicianTasks}?tab=installations'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2. 2x2 Bento Metric Cards Grid
                  GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: isWide ? 2.0 : 1.82,
                    children: [
                      _buildTechStatCard(
                        title: 'Active\nComplaints',
                        value: '${assignedComplaints.where((c) => c.status == "assigned" || c.status == "in_progress").length}',
                        icon: Icons.support_agent_outlined,
                        color: const Color(0xFF2563EB),
                        isDark: isDark,
                      ),
                      _buildTechStatCard(
                        title: 'Active\nInstallations',
                        value: '${myActiveInstallations.length}',
                        icon: Icons.build_circle_outlined,
                        color: const Color(0xFF0D9488),
                        isDark: isDark,
                      ),
                      _buildTechStatCard(
                        title: 'Pending\nApproval',
                        value: '${assignedComplaints.where((c) => c.status == "pending_approval").length + assignedInstallations.where((i) => i.status == "pending_approval").length}',
                        icon: Icons.hourglass_top,
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                      _buildTechStatCard(
                        title: 'Completed\nJobs',
                        value: '${assignedComplaints.where((c) => c.status == "closed" || c.status == "resolved").length + assignedInstallations.where((i) => i.status == "closed" || i.status == "resolved" || i.status == "completed").length}',
                        icon: Icons.check_circle_outline,
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Active Task Banner Card (If active job in progress)
                  if (activeTask != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4C1D95).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'CURRENT ACTIVE JOB',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                activeTask.ticketNumber,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            activeTask.title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Customer: ${activeTask.customerName}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white38),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.navigation_outlined, size: 14),
                                  label: const Text('Navigate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () => _launchMaps(context, activeTask.customerAddress),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.info_outline, color: Colors.white, size: 14),
                                  label: const Text('View Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: () => context.push('/complaints/details/${activeTask.id}'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 3. Section: My Assigned Complaints (Recent 5 only)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Assigned Complaints',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.technicianTasks),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFF6D28D9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View All (${assignedComplaints.length})',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_forward_ios, size: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (assignedComplaints.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, size: 36, color: Colors.grey),
                          SizedBox(height: 6),
                          Text(
                            'No Complaints Assigned',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'You currently have no complaints assigned to your roster.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Recent 5 list
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentComplaints.length,
                      itemBuilder: (context, idx) {
                        final c = recentComplaints[idx];
                        return _buildComplaintTile(context, c, isDark);
                      },
                    ),

                    if (assignedComplaints.length > 5) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go(AppRoutes.technicianTasks),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: const Color(0xFF6D28D9).withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          icon: const Icon(Icons.list_alt, size: 16, color: Color(0xFF6D28D9)),
                          label: Text(
                            'See all ${assignedComplaints.length} tasks in My Tasks',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFF6D28D9),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  
                  // --- INSTALLATIONS SECTION ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Installations',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('${AppRoutes.technicianTasks}?tab=installations'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFF2563EB),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View All (${assignedInstallations.length})',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_forward_ios, size: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (assignedInstallations.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.handyman, size: 36, color: Colors.grey),
                          SizedBox(height: 6),
                          Text(
                            'No Installations Assigned',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'You currently have no installations assigned to your roster.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentInstallations.length,
                      itemBuilder: (context, idx) {
                        final i = recentInstallations[idx];
                        return _buildInstallationTile(context, i, isDark);
                      },
                    ),
                  ],
                  const SizedBox(height: 140),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTechStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isDark = false,
  }) {
    return Material(
      color: Colors.transparent,
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
              offset: const Offset(0, 3),
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
                      color: isDark ? Colors.grey.shade300 : const Color(0xFF1E293B),
                      height: 1.15,
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
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
    );
  }

  Widget _buildComplaintTile(BuildContext context, Complaint c, bool isDark) {
    Color statusColor = const Color(0xFF6D28D9);
    if (c.status == 'closed' || c.status == 'resolved') statusColor = const Color(0xFF10B981);
    if (c.status == 'pending_approval') statusColor = Colors.amber.shade800;
    if (c.status == 'in_progress') statusColor = const Color(0xFF0284C7);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/complaints/details/${c.id}'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(Icons.handyman_outlined, color: statusColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            c.ticketNumber,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (c.priority.toLowerCase().contains('high')) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'HIGH',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Customer: ${c.customerName}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    c.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstallationTile(BuildContext context, Installation i, bool isDark) {
    Color statusColor = const Color(0xFF2563EB);
    if (i.status == 'closed' || i.status == 'resolved') statusColor = const Color(0xFF10B981);
    if (i.status == 'in_progress') statusColor = const Color(0xFF0284C7);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/installations/details/${i.id}'), 
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(Icons.solar_power, color: statusColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            i.ticketNumber,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (i.priority.toLowerCase().contains('high')) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'HIGH',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        i.title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Customer: ${i.customerName}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    i.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
