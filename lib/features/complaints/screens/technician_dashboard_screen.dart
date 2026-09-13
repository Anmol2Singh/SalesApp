import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/complaints_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'complaints_leaderboard_screen.dart';

class TechnicianDashboardScreen extends ConsumerWidget {
  const TechnicianDashboardScreen({super.key});

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

    // Filter assigned complaints for this technician (Robust matching by ID, Name, and Email)
    final assignedComplaints = complaints.where((c) {
      if (profile == null) return true;
      final pName = profile.fullName.trim().toLowerCase();
      final pEmail = profile.email.trim().toLowerCase();
      final tName = (c.technicianName ?? '').trim().toLowerCase();
      final tId = (c.technicianId ?? '').trim();
      
      final matchesId = tId.isNotEmpty && (tId == profile.id);
      final matchesName = tName.isNotEmpty && (tName == pName || tName.contains(pName) || pName.contains(tName));
      final matchesEmail = pEmail.isNotEmpty && (tName.contains(pEmail) || (c.notes?.toLowerCase().contains(pEmail) ?? false));
      
      return matchesId || matchesName || matchesEmail;
    }).toList();

    final myActiveTasks = assignedComplaints.where((c) => c.status == 'assigned' || c.status == 'in_progress').toList();
    final activeTask = myActiveTasks.isNotEmpty ? myActiveTasks.first : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        
        return Scaffold(
          backgroundColor: isWide ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)) : const Color(0xFFF8FAFC),
      appBar: isWide ? null : AppBar(
        title: Text(
          'Technician: ${profile?.fullName ?? "Staff Tech"}',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined, color: Colors.white),
            tooltip: 'Technician Leaderboard',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => const ComplaintsLeaderboardScreen(isEmbedded: false),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () => ref.read(complaintsProvider.notifier).load(refresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.history_outlined, color: Colors.white),
            tooltip: 'My Completed Jobs',
            onPressed: () => context.push('/complaints/history'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _showLogoutDialog(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/complaints/book'),
        backgroundColor: const Color(0xFF6D28D9),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Complaint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(complaintsProvider.notifier).load(refresh: true),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWide ? 32.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            if (isWide)
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Row(
                  children: [
                    Text(
                      'Technician: ${profile?.fullName ?? "Staff Tech"}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.leaderboard_outlined),
                      tooltip: 'Technician Leaderboard',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const ComplaintsLeaderboardScreen(isEmbedded: false),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.history_outlined),
                      tooltip: 'My Completed Jobs',
                      onPressed: () => context.push('/complaints/history'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => _showLogoutDialog(context, ref),
                    ),
                  ],
                ),
              ),
            // Compact Active Task Banner Card
            if (activeTask != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4C1D95).withOpacity(0.2),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ACTIVE JOB',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          activeTask.ticketNumber,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activeTask.title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.navigation_outlined, size: 14),
                            label: const Text('Start Navigation', style: TextStyle(fontSize: 12)),
                            onPressed: () => _launchMaps(context, activeTask.customerAddress),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6D28D9),
                              padding: const EdgeInsets.symmetric(vertical: 6),
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
              const SizedBox(height: 16),
            ],

            // Daily Performance & Task Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Active',
                    '${assignedComplaints.where((c) => c.status == "assigned" || c.status == "in_progress").length}',
                    Icons.directions_run,
                    const Color(0xFF6D28D9),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    'Pending Appr.',
                    '${assignedComplaints.where((c) => c.status == "pending_approval").length}',
                    Icons.hourglass_top,
                    Colors.amber.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    'Completed',
                    '${assignedComplaints.where((c) => c.status == "closed").length}',
                    Icons.check_circle_outline,
                    const Color(0xFF10B981),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Assigned Tasks Queue Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Assigned Complaints',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${assignedComplaints.length} Total',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (assignedComplaints.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.assignment_turned_in_outlined, size: 44, color: Colors.grey),
                    SizedBox(height: 10),
                    Text(
                      'No Complaints Assigned',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You currently have no complaints assigned to your roster.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: assignedComplaints.length,
                itemBuilder: (context, idx) {
                  final c = assignedComplaints[idx];
                  Color statusColor = const Color(0xFF6D28D9);
                  if (c.status == 'closed') statusColor = const Color(0xFF10B981);
                  if (c.status == 'pending_approval') statusColor = Colors.amber.shade700;

                  return InkWell(
                    onTap: () => context.push('/complaints/details/${c.id}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: statusColor.withOpacity(0.1),
                            child: Icon(Icons.handyman_outlined, color: statusColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.ticketNumber, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('Customer: ${c.customerName}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c.status.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
      },
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
