// lib/features/installations/screens/installations_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/installations_provider.dart';
import '../data/models/installation_model.dart';

class InstallationsListScreen extends ConsumerStatefulWidget {
  const InstallationsListScreen({super.key});

  @override
  ConsumerState<InstallationsListScreen> createState() =>
      _InstallationsListScreenState();
}

class _InstallationsListScreenState
    extends ConsumerState<InstallationsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all'; // 'all', 'pending', 'active', 'closed'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || !_tabController.animation!.isAnimating) {
        if (_searchQuery.isNotEmpty || _searchController.text.isNotEmpty) {
          setState(() {
            _searchController.clear();
            _searchQuery = '';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final installations = ref.watch(installationsProvider);
    final isLoading = ref.watch(installationsLoadingProvider);

    final pendingCount =
        installations.where((c) => c.status == 'pending').length;
    final activeCount = installations
        .where((c) => c.status == 'assigned' || c.status == 'in_progress')
        .length;
    final closedCount = installations
        .where((c) => c.status == 'closed' || c.status == 'resolved')
        .length;

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
              context.go('/installations/dashboard');
            }
          },
        ),
        title: const Text(
          'Installations',
          style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(installationsProvider.notifier).load(refresh: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
              fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'All (${installations.length})'),
            Tab(
                text:
                    'Staff (${installations.where((c) => c.source == 'staff').length})'),
            Tab(
                text:
                    'Customer (${installations.where((c) => c.source == 'customer').length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search ticket, customer, technician...',
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF0284C7)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Status', 'all', installations.length),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending', 'pending', pendingCount,
                          color: const Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      _buildFilterChip('Active', 'active', activeCount,
                          color: const Color(0xFF3B82F6)),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed', 'closed', closedCount,
                          color: const Color(0xFF10B981)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(installations, isLoading),
                _buildList(
                    installations.where((c) => c.source == 'staff').toList(),
                    isLoading),
                _buildList(
                    installations.where((c) => c.source == 'customer').toList(),
                    isLoading),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        icon: const Icon(Icons.add, color: Colors.white),
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

  Widget _buildFilterChip(String label, String value, int count,
      {Color color = const Color(0xFF0284C7)}) {
    final isSelected = _selectedStatus == value;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedStatus = value);
      },
      selectedColor: color.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? color : Colors.grey.shade700,
      ),
      backgroundColor: Colors.transparent,
      side: BorderSide(
        color: isSelected ? color : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildList(List<Installation> list, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    var filtered = list;

    if (_selectedStatus == 'pending') {
      filtered = filtered.where((c) => c.status == 'pending').toList();
    } else if (_selectedStatus == 'active') {
      filtered = filtered
          .where((c) => c.status == 'assigned' || c.status == 'in_progress')
          .toList();
    } else if (_selectedStatus == 'closed') {
      filtered = filtered
          .where((c) => c.status == 'closed' || c.status == 'resolved')
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((c) {
        return c.ticketNumber.toLowerCase().contains(_searchQuery) ||
            c.customerName.toLowerCase().contains(_searchQuery) ||
            c.title.toLowerCase().contains(_searchQuery) ||
            (c.technicianName?.toLowerCase().contains(_searchQuery) ?? false) ||
            (c.productName?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No installations found',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return _buildInstallationCard(item);
      },
    );
  }

  Widget _buildInstallationCard(Installation item) {
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/installations/details/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                      color: Color(0xFF0F172A),
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
              const SizedBox(height: 6),
              Text(
                item.title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.customerName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
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
                        item.technicianName ?? 'Not Assigned',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
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
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
