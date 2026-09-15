// lib/features/customers/screens/customer_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/sync_status_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/customers_provider.dart';
import '../../../core/models/customer.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  final String initialSearch;
  final String initialFilter;
  const CustomerListScreen({
    super.key,
    this.initialSearch = '',
    this.initialFilter = '',
  });

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearch;
    _scrollController.addListener(_onScroll);
    if (widget.initialSearch.isNotEmpty || widget.initialFilter.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(customersNotifierProvider.notifier);
        if (widget.initialSearch.isNotEmpty) {
          notifier.search(widget.initialSearch);
        }
        if (widget.initialFilter.isNotEmpty) {
          notifier.setFilterAndSort(
            filter: widget.initialFilter,
            sort: notifier.sortBy,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0 &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      ref.read(customersNotifierProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersNotifierProvider);
    final profile = ref.watch(currentProfileProvider);
    final canCreate = profile?.primaryRole.canCreateCustomers ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.adminDashboard),
        ),
        title: const Text('Customers'),
        actions: [
          const SyncStatusIndicator(),
          Consumer(
            builder: (context, ref, _) {
              final notifier = ref.watch(customersNotifierProvider.notifier);
              final hasActive = notifier.filterBy.isNotEmpty || notifier.sortBy != 'recent';
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    tooltip: 'Filter & Sort',
                    onPressed: _showFilterSheet,
                  ),
                  if (hasActive)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(customersNotifierProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
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
      body: Column(
        children: [
          // Search bar (seamless extension of AppBar)
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      ref.read(customersNotifierProvider.notifier).search(value),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by customer name, phone, email...',
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(customersNotifierProvider.notifier)
                                  .search('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Active filter chips (cleanly placed below search bar)
          Consumer(
            builder: (context, ref, _) {
              final notifier = ref.watch(customersNotifierProvider.notifier);
              final currentFilter = notifier.filterBy;
              final currentSort = notifier.sortBy;
              if (currentFilter.isEmpty && currentSort == 'recent') {
                return const SizedBox.shrink();
              }
              return Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (currentFilter.isNotEmpty) ...[
                        Chip(
                          backgroundColor: const Color(0xFFEFF6FF),
                          side: const BorderSide(color: Color(0xFF3B82F6), width: 1),
                          label: Text(
                            currentFilter == 'active_deal' ? 'Active Deal' : 'Active AMC',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF1D4ED8)),
                          onDeleted: () {
                            ref.read(customersNotifierProvider.notifier).setFilterAndSort(
                              filter: '',
                              sort: currentSort,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (currentSort != 'recent') ...[
                        Chip(
                          backgroundColor: const Color(0xFFEFF6FF),
                          side: const BorderSide(color: Color(0xFF3B82F6), width: 1),
                          label: const Text(
                            'Alphabetical (A-Z)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF1D4ED8)),
                          onDeleted: () {
                            ref.read(customersNotifierProvider.notifier).setFilterAndSort(
                              filter: currentFilter,
                              sort: 'recent',
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      TextButton.icon(
                        onPressed: () {
                          ref.read(customersNotifierProvider.notifier).setFilterAndSort(
                            filter: '',
                            sort: 'recent',
                          );
                        },
                        icon: const Icon(Icons.clear_all, size: 16, color: AppColors.textSecondary),
                        label: const Text('Clear All', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // List
          Expanded(
            child: customersAsync.when(
              data: (customers) {
                if (customers.isEmpty) {
                  return _EmptyState(
                      onAdd: canCreate ? _navigateToCreate : null);
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () =>
                      ref.read(customersNotifierProvider.notifier).refresh(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: customers.length + 1,
                        itemBuilder: (context, index) {
                      if (index == customers.length) {
                        final hasMore = ref
                            .read(customersNotifierProvider.notifier)
                            .hasMore;
                        if (hasMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        } else {
                          return const SizedBox(
                              height: 80); // Bottom padding for FAB
                        }
                      }
                      return _CustomerTile(customer: customers[index]);
                    },
                  ),
                    ),
                  ),
                );
              },
              loading: () => const ShimmerListLoader(),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load customers',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(customersNotifierProvider.notifier)
                          .refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _navigateToCreate,
              icon: const Icon(Icons.add),
              label: const Text(
                'New Customer',
                style:
                    TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  void _navigateToCreate() => context.push(AppRoutes.createCustomer);

  void _showFilterSheet() {
    final notifier = ref.read(customersNotifierProvider.notifier);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _CustomerFilterSheet(
          currentFilter: notifier.filterBy,
          currentSort: notifier.sortBy,
          onApply: (filter, sort) {
            notifier.setFilterAndSort(filter: filter, sort: sort);
          },
        );
      },
    );
  }
}

class _CustomerFilterSheet extends StatefulWidget {
  final String currentFilter;
  final String currentSort;
  final Function(String filter, String sort) onApply;

  const _CustomerFilterSheet({
    required this.currentFilter,
    required this.currentSort,
    required this.onApply,
  });

  @override
  State<_CustomerFilterSheet> createState() => _CustomerFilterSheetState();
}

class _CustomerFilterSheetState extends State<_CustomerFilterSheet> {
  late String _filter;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _filter = widget.currentFilter;
    _sort = widget.currentSort;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Filter & Sort Customers',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 20),

          // Filter By
          const Text(
            'FILTER BY STATUS / DEALS',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildOption(
                label: 'All Customers',
                icon: Icons.people_outline,
                selected: _filter.isEmpty,
                onTap: () => setState(() => _filter = ''),
              ),
              _buildOption(
                label: 'Has Active Deal',
                icon: Icons.trending_up,
                selected: _filter == 'active_deal',
                onTap: () => setState(() => _filter = 'active_deal'),
              ),
              _buildOption(
                label: 'Has Active AMC',
                icon: Icons.verified_user_outlined,
                selected: _filter == 'active_amc',
                onTap: () => setState(() => _filter = 'active_amc'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sort By
          const Text(
            'SORT BY',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildOption(
                label: 'Recently Added',
                icon: Icons.access_time,
                selected: _sort == 'recent',
                onTap: () => setState(() => _sort = 'recent'),
              ),
              _buildOption(
                label: 'Alphabetical (A - Z)',
                icon: Icons.sort_by_alpha,
                selected: _sort == 'alphabetical',
                onTap: () => setState(() => _sort = 'alphabetical'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    setState(() {
                      _filter = '';
                      _sort = 'recent';
                    });
                    widget.onApply('', 'recent');
                    Navigator.pop(context);
                  },
                  child: const Text('Reset All', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    widget.onApply(_filter, _sort);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerTile extends ConsumerWidget {
  final Customer customer;

  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDuplicate = ref.watch(customerDuplicateCandidateProvider(customer)).value ?? false;

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.customerDetail.replaceAll(':id', customer.id),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  customer.companyName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customer.companyName,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasDuplicate) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning, size: 10, color: AppColors.warning),
                              SizedBox(width: 2),
                              Text(
                                'Duplicate',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (customer.contactPerson != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      customer.contactPerson!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (customer.phone != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          customer.phone!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (customer.assignedToName != null && customer.assignedToName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline, size: 11, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Assigned: ${customer.assignedToName}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (customer.reassignmentRequested) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 11, color: AppColors.warning),
                          SizedBox(width: 4),
                          Text(
                            'Reassign Requested',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (customer.phone != null && customer.phone!.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.phone_outlined, size: 20, color: AppColors.primary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => launchUrlString('tel:${customer.phone}'),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.green),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  final cleanPhone = customer.phone!.replaceAll(RegExp(r'\D'), '');
                  final formattedPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
                  launchUrlString('https://wa.me/$formattedPhone');
                },
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onAdd;

  const _EmptyState({this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Customers Yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first customer to start\nmanaging the sales pipeline.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add Customer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
