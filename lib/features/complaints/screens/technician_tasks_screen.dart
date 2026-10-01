// lib/features/complaints/screens/technician_tasks_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/complaints_provider.dart';
import '../data/models/complaint_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/installations/providers/installations_provider.dart';
import '../../../features/installations/data/models/installation_model.dart';

class TechnicianTasksScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const TechnicianTasksScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<TechnicianTasksScreen> createState() => _TechnicianTasksScreenState();
}

class _TechnicianTasksScreenState extends ConsumerState<TechnicianTasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _callCustomer(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;
    final url = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(complaintsProvider.notifier).load(refresh: true),
      ref.read(installationsProvider.notifier).load(refresh: true),
    ]);
  }

  void _showLogoutDialog(BuildContext context) {
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return const Color(0xFF6366F1);
      case 'in_progress':
        return const Color(0xFF0284C7);
      case 'pending_approval':
        return Colors.amber.shade800;
      case 'closed':
      case 'resolved':
        return const Color(0xFF10B981);
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'IN PROGRESS';
      case 'pending_approval':
        return 'PENDING APPR.';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaints = ref.watch(complaintsProvider);
    final profile = ref.watch(currentProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter assigned complaints for this technician
    final assignedComplaints = complaints.where((c) {
      if (profile == null) return true;
      final pName = profile.fullName.trim().toLowerCase();
      final pEmail = profile.email.trim().toLowerCase();
      final pPhone = (profile.phone ?? '').trim().replaceAll(RegExp(r'[^\d]'), '');
      final tName = (c.technicianName ?? '').trim().toLowerCase();
      final tId = (c.technicianId ?? '').trim();

      final matchesId = tId.isNotEmpty && (tId == profile.id);
      final matchesName = tName.isNotEmpty && (tName == pName || tName.contains(pName) || pName.contains(tName));
      final matchesEmail = pEmail.isNotEmpty && (tName.contains(pEmail) || (c.notes?.toLowerCase().contains(pEmail) ?? false));
      final matchesPhone = pPhone.isNotEmpty && ((c.notes?.replaceAll(RegExp(r'[^\d]'), '').contains(pPhone) ?? false));

      return matchesId || matchesName || matchesEmail || matchesPhone;
    }).toList();

    // Fetch and filter installations
    final installations = ref.watch(installationsProvider);
    final assignedInstallations = installations.where((i) {
      if (profile == null) return true;
      final pName = profile.fullName.trim().toLowerCase();
      final pEmail = profile.email.trim().toLowerCase();
      final pPhone = (profile.phone ?? '').trim().replaceAll(RegExp(r'[^\d]'), '');
      final tName = (i.technicianName ?? '').trim().toLowerCase();
      final tId = (i.technicianId ?? '').trim();

      final matchesId = tId.isNotEmpty && (tId == profile.id);
      final matchesName = tName.isNotEmpty && (tName == pName || tName.contains(pName) || pName.contains(tName));
      final matchesEmail = pEmail.isNotEmpty && (tName.contains(pEmail) || (i.notes?.toLowerCase().contains(pEmail) ?? false));
      final matchesPhone = pPhone.isNotEmpty && ((i.notes?.replaceAll(RegExp(r'[^\d]'), '').contains(pPhone) ?? false));
      final matchesSupporter = pName.isNotEmpty && (i.notes?.toLowerCase().contains(pName) ?? false);

      return matchesId || matchesName || matchesEmail || matchesPhone || matchesSupporter;
    }).toList();

    // Use current tab list
    final List<dynamic> currentList = _selectedTab == 0 ? assignedComplaints : assignedInstallations;

    // Compute status counts for filter chips
    final activeCount = currentList.where((c) {
      final s = c.status.toLowerCase();
      return s == 'assigned' || s == 'pending' || s == 'scheduled' || s == 'open';
    }).length;
    final inProgressCount = currentList.where((c) => c.status.toLowerCase() == 'in_progress').length;
    final pendingApprCount = currentList.where((c) => c.status.toLowerCase() == 'pending_approval').length;
    final completedCount = currentList.where((c) {
      final s = c.status.toLowerCase();
      return s == 'closed' || s == 'resolved' || s == 'completed';
    }).length;

    // Filter by status pill
    var filtered = currentList.where((c) {
      final s = c.status.toLowerCase();
      if (_selectedFilter == 'Active') return s == 'assigned' || s == 'pending' || s == 'scheduled' || s == 'open';
      if (_selectedFilter == 'In Progress') return s == 'in_progress';
      if (_selectedFilter == 'Pending Appr.') return s == 'pending_approval';
      if (_selectedFilter == 'Completed') return s == 'closed' || s == 'resolved' || s == 'completed';
      return true; // 'All'
    }).toList();

    // Filter by search query
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((c) {
        return c.ticketNumber.toLowerCase().contains(query) ||
            c.title.toLowerCase().contains(query) ||
            c.customerName.toLowerCase().contains(query) ||
            c.customerAddress.toLowerCase().contains(query) ||
            (c.productName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'My Tasks',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${currentList.length}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sign Out',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(_selectedTab == 0 ? '/complaints/book' : '/installations/book'),
        backgroundColor: _selectedTab == 0 ? const Color(0xFF6D28D9) : const Color(0xFF2563EB),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _selectedTab == 0 ? 'New Complaint' : 'New Installation',
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            // Search Box
            Container(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search tasks by ticket, customer, address...',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade500),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Tab Toggle
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedTab = 0;
                        _selectedFilter = 'All'; // reset filter on tab switch
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedTab == 0
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Complaints',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w500,
                            color: _selectedTab == 0 ? (isDark ? Colors.white : Colors.black) : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedTab = 1;
                        _selectedFilter = 'All'; // reset filter on tab switch
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedTab == 1
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Installations',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w500,
                            color: _selectedTab == 1 ? (isDark ? Colors.white : Colors.black) : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Status Filter Chips
            Container(
              width: double.infinity,
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', currentList.length),
                    const SizedBox(width: 8),
                    _buildFilterChip('Active', activeCount, color: const Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    _buildFilterChip('In Progress', inProgressCount, color: const Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending Appr.', pendingApprCount, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    _buildFilterChip('Completed', completedCount, color: const Color(0xFF10B981)),
                  ],
                ),
              ),
            ),

            // Task List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_turned_in_outlined,
                              size: 56,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No matching tasks'
                                  : (_selectedFilter == 'All'
                                      ? 'No ${_selectedTab == 0 ? 'Complaints' : 'Installations'} Assigned'
                                      : 'No $_selectedFilter tasks'),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Try changing your search keywords or filter'
                                  : 'Assigned jobs will appear here in real-time.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final c = filtered[idx];
                        if (_selectedTab == 0) {
                          return _buildTaskCard(c as Complaint, isDark);
                        } else {
                          return _buildInstallationCard(c as Installation, isDark);
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, {Color? color}) {
    final isSelected = _selectedFilter == label;
    final chipColor = color ?? const Color(0xFF6D28D9);

    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Complaint c, bool isDark) {
    final statusColor = _getStatusColor(c.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.status == 'assigned' || c.status == 'in_progress'
              ? statusColor.withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: c.status == 'assigned' || c.status == 'in_progress' ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/complaints/details/${c.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Ticket & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c.ticketNumber,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (c.priority.toLowerCase().contains('high')) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.priority_high, size: 10, color: Colors.red.shade700),
                                Text(
                                  'HIGH',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatStatusLabel(c.status),
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

                // Title
                Text(
                  c.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Customer info
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 15, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        c.customerName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (c.customerPhone.isNotEmpty)
                      InkWell(
                        onTap: () => _callCustomer(c.customerPhone),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone, size: 12, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text(
                                'Call',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Address
                if (c.customerAddress.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on_outlined, size: 15, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.customerAddress,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Action Bar
                const Divider(height: 16),
                Row(
                  children: [
                    if (c.customerAddress.isNotEmpty) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.navigation_outlined, size: 13),
                        label: const Text(
                          'Navigate',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => _launchMaps(context, c.customerAddress),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF6D28D9),
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      label: const Text(
                        'Details',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => context.push('/complaints/details/${c.id}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstallationCard(Installation i, bool isDark) {
    final statusColor = _getStatusColor(i.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: i.status == 'assigned' || i.status == 'in_progress'
              ? statusColor.withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: i.status == 'assigned' || i.status == 'in_progress' ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/installations/details/${i.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Ticket & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            i.ticketNumber,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (i.priority.toLowerCase().contains('high')) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.priority_high, size: 10, color: Colors.red.shade700),
                                Text(
                                  'HIGH',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatStatusLabel(i.status),
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

                // Title
                Text(
                  i.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Customer info
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 15, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        i.customerName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (i.customerPhone.isNotEmpty)
                      InkWell(
                        onTap: () => _callCustomer(i.customerPhone),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone, size: 12, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text(
                                'Call',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Address
                if (i.customerAddress.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on_outlined, size: 15, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          i.customerAddress,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Action Bar
                const Divider(height: 16),
                Row(
                  children: [
                    if (i.customerAddress.isNotEmpty) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.navigation_outlined, size: 13),
                        label: const Text(
                          'Navigate',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => _launchMaps(context, i.customerAddress),
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.info_outline, size: 13),
                      label: const Text(
                        'Details',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => context.push('/installations/details/${i.id}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
