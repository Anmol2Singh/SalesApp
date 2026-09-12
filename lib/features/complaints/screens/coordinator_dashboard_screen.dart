// lib/features/complaints/screens/coordinator_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../providers/complaints_provider.dart';
import '../data/models/complaint_model.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';
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
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedSource = 'all'; // 'all', 'staff', 'customer'
  String _selectedStatus = 'all'; // 'all', 'pending', 'in_progress', 'closed'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
    final profile = ref.watch(currentProfileProvider);
    final isAdminOrManager =
        profile?.primaryRole == UserRole.admin || profile?.primaryRole == UserRole.manager;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: isAdminOrManager
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Back to Admin Panel',
                onPressed: () => context.go(AppRoutes.adminDashboard),
              )
            : null,
        title: const Text(
          'Service & Complaints Operations',
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
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Tickets',
            onPressed: () => ref.read(complaintsProvider.notifier).load(refresh: true),
          ),
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

    final staffIntakeCount = complaints.where((c) => c.source == 'staff').length;
    final customerIntakeCount = complaints.where((c) => c.source == 'customer').length;

    // Filter complaints based on search query, source, and status
    final filtered = complaints.where((c) {
      // Source filter
      if (_selectedSource == 'staff' && c.source != 'staff') return false;
      if (_selectedSource == 'customer' && c.source != 'customer') return false;

      // Status filter
      if (_selectedStatus == 'pending' && c.status != 'pending') return false;
      if (_selectedStatus == 'in_progress' && (c.status != 'in_progress' && c.status != 'assigned')) return false;
      if (_selectedStatus == 'closed' && (c.status != 'closed' && c.status != 'resolved')) return false;

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTicket = c.ticketNumber.toLowerCase().contains(q);
        final matchName = c.customerName.toLowerCase().contains(q);
        final matchPhone = c.customerPhone.toLowerCase().contains(q);
        final matchProduct = (c.productName ?? '').toLowerCase().contains(q);
        final matchTitle = c.title.toLowerCase().contains(q);
        return matchTicket || matchName || matchPhone || matchProduct || matchTitle;
      }
      return true;
    }).toList();

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

          // Staff vs Customer Intake Filter Chips
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.filter_list, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Intake Channel Filter',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'All Channels ($totalCount)',
                      isSelected: _selectedSource == 'all',
                      onSelected: () => setState(() => _selectedSource = 'all'),
                    ),
                    _buildFilterChip(
                      label: 'Staff Intake ($staffIntakeCount)',
                      isSelected: _selectedSource == 'staff',
                      onSelected: () => setState(() => _selectedSource = 'staff'),
                      icon: Icons.badge_outlined,
                    ),
                    _buildFilterChip(
                      label: 'Customer App ($customerIntakeCount)',
                      isSelected: _selectedSource == 'customer',
                      onSelected: () => setState(() => _selectedSource = 'customer'),
                      icon: Icons.phone_android_outlined,
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Status Filter Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusFilterChip('All Statuses', 'all'),
                    _buildStatusFilterChip('Pending ($pendingCount)', 'pending', color: const Color(0xFFEF4444)),
                    _buildStatusFilterChip('Active ($inProgressCount)', 'in_progress', color: const Color(0xFF3B82F6)),
                    _buildStatusFilterChip('Closed ($closedCount)', 'closed', color: const Color(0xFF10B981)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by ticket #, customer, phone, product...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),

          const SizedBox(height: 16),

          // Service Requests Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Complaints (${filtered.length})',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                label: const Text('Assign Technicians'),
                onPressed: () => context.push('/complaints/assign'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (isLoading) ...[
            const ShimmerListLoader(),
          ] else if (filtered.isEmpty) ...[
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
                    _searchQuery.isNotEmpty
                        ? 'No tickets match your search filters.'
                        : 'Tap "Book Complaint" below to log a new service ticket.',
                    style: TextStyle(fontFamily: 'Inter', color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _buildComplaintTile(context, item);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    IconData? icon,
  }) {
    return ChoiceChip(
      avatar: icon != null ? Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary) : null,
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF1E1B4B),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildStatusFilterChip(String label, String statusKey, {Color? color}) {
    final isSelected = _selectedStatus == statusKey;
    final chipColor = color ?? const Color(0xFF1E1B4B);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: chipColor,
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      onSelected: (_) => setState(() => _selectedStatus = statusKey),
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
            color: Colors.black.withOpacity(0.02),
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
                  color: badgeColor.withOpacity(0.12),
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
              color: Colors.black.withOpacity(0.02),
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
                    color: statusColor.withOpacity(0.12),
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
}
