// lib/features/complaints/screens/complaints_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../providers/complaints_provider.dart';
import '../data/models/complaint_model.dart';

class ComplaintsListScreen extends ConsumerStatefulWidget {
  const ComplaintsListScreen({super.key});

  @override
  ConsumerState<ComplaintsListScreen> createState() => _ComplaintsListScreenState();
}

class _ComplaintsListScreenState extends ConsumerState<ComplaintsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all'; // 'all', 'pending', 'active', 'closed'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final complaints = ref.watch(complaintsProvider);
    final isLoading = ref.watch(complaintsLoadingProvider);

    // Counts for status filters
    final pendingCount = complaints.where((c) => c.status == 'pending').length;
    final activeCount = complaints.where((c) => c.status == 'assigned' || c.status == 'in_progress').length;
    final closedCount = complaints.where((c) => c.status == 'closed' || c.status == 'resolved').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go(AppRoutes.complaintsDashboard);
            }
          },
        ),
        title: const Text(
          'Complaints',
          style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () => ref.read(complaintsProvider.notifier).load(refresh: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'All (${complaints.length})'),
            Tab(text: 'Staff Intake (${complaints.where((c) => c.source == 'staff').length})'),
            Tab(text: 'Customer App (${complaints.where((c) => c.source == 'customer').length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6D28D9),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Book Complaint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => context.push('/complaints/book'),
      ),
      body: Column(
        children: [
          // Search Bar & Status Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by ticket #, customer, phone, product, error...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF6D28D9)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('All Statuses', 'all', null),
                      const SizedBox(width: 8),
                      _buildStatusChip('Pending ($pendingCount)', 'pending', const Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      _buildStatusChip('Active ($activeCount)', 'active', const Color(0xFF3B82F6)),
                      const SizedBox(width: 8),
                      _buildStatusChip('Closed ($closedCount)', 'closed', const Color(0xFF10B981)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List of Complaints for each Tab Section
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildComplaintsList(complaints, null),
                      _buildComplaintsList(complaints, 'staff'),
                      _buildComplaintsList(complaints, 'customer'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String key, Color? color) {
    final isSelected = _selectedStatus == key;
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
      onSelected: (_) => setState(() => _selectedStatus = key),
    );
  }

  Widget _buildComplaintsList(List<Complaint> allComplaints, String? sectionSource) {
    // 1. Filter by section source
    var list = sectionSource == null
        ? allComplaints
        : allComplaints.where((c) => c.source == sectionSource).toList();

    // 2. Filter by status
    if (_selectedStatus == 'pending') {
      list = list.where((c) => c.status == 'pending').toList();
    } else if (_selectedStatus == 'active') {
      list = list.where((c) => c.status == 'assigned' || c.status == 'in_progress').toList();
    } else if (_selectedStatus == 'closed') {
      list = list.where((c) => c.status == 'closed' || c.status == 'resolved').toList();
    }

    // 3. Filter by search query
    if (_searchQuery.isNotEmpty) {
      list = list.where((c) {
        final matchTicket = c.ticketNumber.toLowerCase().contains(_searchQuery);
        final matchName = c.customerName.toLowerCase().contains(_searchQuery);
        final matchPhone = c.customerPhone.toLowerCase().contains(_searchQuery);
        final matchProduct = (c.productName ?? '').toLowerCase().contains(_searchQuery);
        final matchTitle = c.title.toLowerCase().contains(_searchQuery);
        final matchError = (c.errorCode ?? '').toLowerCase().contains(_searchQuery);
        return matchTicket || matchName || matchPhone || matchProduct || matchTitle || matchError;
      }).toList();
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_late_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No complaints found',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching with different keywords.'
                  : 'No tickets registered in this section.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = list[index];
        return _buildComplaintCard(context, item);
      },
    );
  }

  Widget _buildComplaintCard(BuildContext context, Complaint item) {
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

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/complaints/details/${item.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                            fontSize: 13,
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
                          child: Text(
                            isStaff ? 'Staff Intake' : 'Customer App',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isStaff ? const Color(0xFF4F46E5) : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (item.status != 'closed' && item.status != 'resolved') ...[
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6D28D9)),
                            tooltip: 'Edit Complaint',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => context.push('/complaints/edit/${item.id}'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Customer: ${item.customerName} • ${item.customerPhone}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'Address: ${item.customerAddress}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.errorCode != null && item.errorCode!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      'Error: ${item.errorCode}${item.errorDescription != null ? " - ${item.errorDescription}" : ""}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (item.productName != null && item.productName!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.productName!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (item.technicianName != null && item.technicianName!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.person_pin, size: 14, color: Color(0xFF6D28D9)),
                          const SizedBox(width: 4),
                          Text(
                            item.technicianName!,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                          ),
                        ],
                      )
                    else
                      const Text('Not Assigned', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500)),
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
