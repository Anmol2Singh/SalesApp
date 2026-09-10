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
        title: const Text('Customers'),
        actions: [
          const SyncStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
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
          // Active filter chips
          Consumer(
            builder: (context, ref, _) {
              final notifier = ref.watch(customersNotifierProvider.notifier);
              final currentFilter = notifier.filterBy;
              final currentSort = notifier.sortBy;
              if (currentFilter.isEmpty && currentSort == 'recent') {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (currentFilter.isNotEmpty) ...[
                        Chip(
                          label: Text(
                            currentFilter == 'active_deal' ? 'Active Deal' : 'Active AMC',
                            style: const TextStyle(fontSize: 12),
                          ),
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
                          label: const Text(
                            'Alphabetical',
                            style: TextStyle(fontSize: 12),
                          ),
                          onDeleted: () {
                            ref.read(customersNotifierProvider.notifier).setFilterAndSort(
                              filter: currentFilter,
                              sort: 'recent',
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          // Search bar
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final notifier = ref.read(customersNotifierProvider.notifier);
            final currentFilter = notifier.filterBy;
            final currentSort = notifier.sortBy;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter & Sort Customers',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Filter By',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: Text('All', style: TextStyle(color: currentFilter == '' ? AppColors.primary : AppColors.textPrimary)),
                        selected: currentFilter == '',
                        onSelected: (_) {
                          notifier.setFilterAndSort(filter: '', sort: currentSort);
                          Navigator.pop(context);
                        },
                      ),
                      FilterChip(
                        label: Text('Has Active Deal', style: TextStyle(color: currentFilter == 'active_deal' ? AppColors.primary : AppColors.textPrimary)),
                        selected: currentFilter == 'active_deal',
                        onSelected: (_) {
                          notifier.setFilterAndSort(filter: 'active_deal', sort: currentSort);
                          Navigator.pop(context);
                        },
                      ),
                      FilterChip(
                        label: Text('Has Active AMC', style: TextStyle(color: currentFilter == 'active_amc' ? AppColors.primary : AppColors.textPrimary)),
                        selected: currentFilter == 'active_amc',
                        onSelected: (_) {
                          notifier.setFilterAndSort(filter: 'active_amc', sort: currentSort);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sort By',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('Recently Added', style: TextStyle(color: currentSort == 'recent' ? AppColors.primary : AppColors.textPrimary)),
                        selected: currentSort == 'recent',
                        onSelected: (_) {
                          notifier.setFilterAndSort(filter: currentFilter, sort: 'recent');
                          Navigator.pop(context);
                        },
                      ),
                      ChoiceChip(
                        label: Text('Alphabetical', style: TextStyle(color: currentSort == 'alphabetical' ? AppColors.primary : AppColors.textPrimary)),
                        selected: currentSort == 'alphabetical',
                        onSelected: (_) {
                          notifier.setFilterAndSort(filter: currentFilter, sort: 'alphabetical');
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
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
