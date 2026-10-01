// lib/features/pipelines/screens/pipeline_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/quotation.dart';
import '../../../core/models/user_role.dart';
import '../../../core/widgets/pipeline_card.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/sync_status_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/pipelines_provider.dart';
import '../../../core/services/excel_service.dart';

class PipelineListScreen extends ConsumerStatefulWidget {
  final String initialStep;
  final String initialStatus;
  const PipelineListScreen({
    super.key,
    this.initialStep = '',
    this.initialStatus = '',
  });

  @override
  ConsumerState<PipelineListScreen> createState() => _PipelineListScreenState();
}

class _PipelineListScreenState extends ConsumerState<PipelineListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStep = '';
  String _selectedStatus = '';

  // 0: Needs Action, 1: Active, 2: Completed
  int _selectedTabIndex = 1;
  String _quickFilter = 'all'; // 'all', 'needs_approval', 'quotation', 'boq', 'factory_order'

  @override
  void initState() {
    super.initState();
    _selectedStep = widget.initialStep;
    _selectedStatus = widget.initialStatus;
    if (_selectedStatus == 'completed') {
      _selectedTabIndex = 2;
    } else if (_selectedStatus == 'needs_approval' || widget.initialStep == 'quotation_approval') {
      _selectedTabIndex = 0;
      _quickFilter = 'needs_approval';
    }
    _scrollController.addListener(_onScroll);
    if (_selectedStep.isNotEmpty || _selectedStatus.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pipelinesNotifierProvider.notifier).setFilters(
              step: _selectedStep,
              status: _selectedStatus,
            );
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(pipelinesNotifierProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dealsStreamProvider);
    final pipelinesAsync = ref.watch(pipelinesNotifierProvider);
    final profile = ref.watch(currentProfileProvider);
    final canViewAll = profile?.primaryRole == UserRole.admin ||
        profile?.primaryRole == UserRole.manager ||
        profile?.primaryRole == UserRole.salesHead ||
        profile?.roles.contains(UserRole.admin) == true ||
        profile?.roles.contains(UserRole.salesHead) == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRoutes.adminDashboard);
            }
          },
        ),
        title: Text(canViewAll ? 'All Deals' : 'My Deals'),
        actions: [
          const SyncStatusIndicator(),
          Consumer(
            builder: (context, ref, _) {
              final hasActive = _selectedStep.isNotEmpty || _selectedStatus.isNotEmpty;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    tooltip: 'Filter Deals',
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
          if (canViewAll)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export to Excel',
              onPressed: () => _exportExcel(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(pipelinesNotifierProvider.notifier).refresh(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (val) async {
              if (val == 'export') {
                _exportExcel(context, ref);
              } else if (val == 'logout') {
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go(AppRoutes.login);
                  }
                }
              }
            },
            itemBuilder: (ctx) => [
              if (canViewAll)
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download_outlined, color: AppColors.primary, size: 18),
                      SizedBox(width: 10),
                      Text('Export to Excel'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.error, size: 18),
                    SizedBox(width: 10),
                    Text('Logout', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(pipelinesNotifierProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Segmented Control Tabs & Quick Filter Chips
            pipelinesAsync.maybeWhen(
              data: (allPipelines) {
                final needsActionCount = allPipelines
                    .where((p) =>
                        p.quotation?.status == QuotationStatus.pendingApproval)
                    .length;
                final activeCount = allPipelines
                    .where((p) => p.status != PipelineStatus.completed)
                    .length;
                final completedCount = allPipelines
                    .where((p) => p.status == PipelineStatus.completed)
                    .length;

                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Bar at Top
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim().toLowerCase();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search by customer, product, quote #...',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                              prefixIcon: const Icon(Icons.search,
                                  size: 20, color: AppColors.textSecondary),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear,
                                          size: 18,
                                          color: AppColors.textSecondary),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),

                        // Segmented Control Tabs: Needs Action (#) | Active (#) | Completed (#)
                        Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // 1. Needs Action
                              _buildSegmentedTab(
                                index: 0,
                                label: 'Needs Action ($needsActionCount)',
                                icon: Icons.warning_amber_rounded,
                                activeBg: const Color(0xFFFEF3C7),
                                activeFg: const Color(0xFFB45309),
                              ),
                              const SizedBox(width: 4),
                              // 2. Active
                              _buildSegmentedTab(
                                index: 1,
                                label: 'Active ($activeCount)',
                                icon: Icons.alt_route_outlined,
                                activeBg: AppColors.primary,
                                activeFg: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              // 3. Completed
                              _buildSegmentedTab(
                                index: 2,
                                label: 'Completed ($completedCount)',
                                icon: Icons.check_circle_outline,
                                activeBg: const Color(0xFF10B981),
                                activeFg: Colors.white,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Horizontally scrollable quick filter chips row
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildQuickChip('All', 'all'),
                              const SizedBox(width: 6),
                              _buildQuickChip(
                                '⚠️ Needs Approval ($needsActionCount)',
                                'needs_approval',
                                isAlert: true,
                              ),
                              const SizedBox(width: 6),
                              _buildQuickChip('Quotation', 'quotation'),
                              const SizedBox(width: 6),
                              _buildQuickChip('BOQ', 'boq'),
                              const SizedBox(width: 6),
                              _buildQuickChip('Factory Order', 'factory_order'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              orElse: () => const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ),

            if (_selectedStep.isNotEmpty || _selectedStatus.isNotEmpty)
              SliverToBoxAdapter(
                child: _FilterChipsRow(
                  step: _selectedStep,
                  status: _selectedStatus,
                  onClearStep: () {
                    setState(() => _selectedStep = '');
                    ref
                        .read(pipelinesNotifierProvider.notifier)
                        .setFilters(step: '', status: _selectedStatus);
                  },
                  onClearStatus: () {
                    setState(() => _selectedStatus = '');
                    ref
                        .read(pipelinesNotifierProvider.notifier)
                        .setFilters(step: _selectedStep, status: '');
                  },
                ),
              ),

            pipelinesAsync.when(
              data: (allPipelines) {
                final pipelines = allPipelines.where((p) {
                  // Tab selection
                  if (_selectedTabIndex == 0) {
                    if (p.quotation?.status != QuotationStatus.pendingApproval) {
                      return false;
                    }
                  } else if (_selectedTabIndex == 1) {
                    if (p.status == PipelineStatus.completed) return false;
                  } else if (_selectedTabIndex == 2) {
                    if (p.status != PipelineStatus.completed) return false;
                  }

                  // Quick filter chips
                  if (_quickFilter == 'needs_approval') {
                    if (p.quotation?.status != QuotationStatus.pendingApproval) {
                      return false;
                    }
                  } else if (_quickFilter == 'quotation') {
                    if (p.currentStep != PipelineStep.quotation) return false;
                  } else if (_quickFilter == 'boq') {
                    if (p.currentStep != PipelineStep.boq) return false;
                  } else if (_quickFilter == 'factory_order') {
                    if (p.currentStep != PipelineStep.factoryOrder) return false;
                  }

                  // Search query filter
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery;
                    final custName = (p.customer?.customerName ?? '').toLowerCase();
                    final compName = (p.customer?.companyName ?? '').toLowerCase();
                    final phone = (p.customer?.phone ?? '').toLowerCase();
                    final prod = (p.product?.name ?? '').toLowerCase();
                    final salesman = (p.createdByProfile?.fullName ?? p.quotation?.salesman ?? '').toLowerCase();
                    final quoteNo = (p.quotation?.quotationNumber ?? '').toLowerCase();

                    final matches = custName.contains(q) ||
                        compName.contains(q) ||
                        phone.contains(q) ||
                        prod.contains(q) ||
                        salesman.contains(q) ||
                        quoteNo.contains(q);

                    if (!matches) return false;
                  }

                  return true;
                }).toList();

                if (pipelines.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedTabIndex == 0
                                  ? Icons.verified_outlined
                                  : (_selectedTabIndex == 2
                                      ? Icons.check_circle_outline
                                      : Icons.search_off_outlined),
                              size: 46,
                              color: _selectedTabIndex == 0
                                  ? const Color(0xFF10B981)
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedTabIndex == 0
                                  ? 'No deals requiring approval'
                                  : (_selectedTabIndex == 2
                                      ? 'No completed deals yet'
                                      : 'No deals match this filter'),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedTabIndex == 0
                                  ? 'All quotations have been approved or reviewed.'
                                  : 'Try adjusting your filters or search terms.',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // List of compact deal cards with responsive centering and FAB padding
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 88),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 850),
                            child: PipelineCard(
                              pipeline: pipelines[index],
                              showCustomer: true,
                              showSalesperson: canViewAll,
                            ),
                          ),
                        );
                      },
                      childCount: pipelines.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: ShimmerListLoader(),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      const Text(
                        'Failed to load deals',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(pipelinesNotifierProvider.notifier)
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
      ),
      floatingActionButton: profile?.primaryRole.canCreateCustomers == true
          ? FloatingActionButton.extended(
              heroTag: 'new_deal_fab',
              onPressed: () => context.push(AppRoutes.customers),
              icon: const Icon(Icons.add),
              label: const Text(
                'New Deal',
                style:
                    TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  Widget _buildSegmentedTab({
    required int index,
    required String label,
    required IconData icon,
    required Color activeBg,
    required Color activeFg,
  }) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
            _quickFilter = 'all';
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeFg : Colors.grey.shade600,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 11.5,
                    color: isSelected ? activeFg : Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, String value, {bool isAlert = false}) {
    final isSelected = _quickFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _quickFilter = value;
          if (value == 'needs_approval') {
            _selectedTabIndex = 0;
          }
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isAlert ? const Color(0xFFFEF3C7) : AppColors.primary)
              : (isAlert
                  ? const Color(0xFFFFFBEB)
                  : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isAlert ? const Color(0xFFF59E0B) : AppColors.primary)
                : (isAlert ? const Color(0xFFFDE68A) : Colors.grey.shade300),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isAlert ? const Color(0xFFB45309) : Colors.white)
                : (isAlert ? const Color(0xFFD97706) : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterSheet(
        selectedStep: _selectedStep,
        selectedStatus: _selectedStatus,
        onApply: (step, status) {
          setState(() {
            _selectedStep = step;
            _selectedStatus = status;
          });
          ref
              .read(pipelinesNotifierProvider.notifier)
              .setFilters(step: step, status: status);
        },
      ),
    );
  }

  void _exportExcel(BuildContext context, WidgetRef ref) async {
    final pipelines = ref.read(pipelinesNotifierProvider).value ?? [];
    if (pipelines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    try {
      await ExcelService.exportPipelines(context, pipelines);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}

class _FilterChipsRow extends StatelessWidget {
  final String step;
  final String status;
  final VoidCallback onClearStep;
  final VoidCallback onClearStatus;

  const _FilterChipsRow({
    required this.step,
    required this.status,
    required this.onClearStep,
    required this.onClearStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (step.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(
                  PipelineStep.fromString(step).displayName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
                deleteIcon:
                    const Icon(Icons.close, size: 14, color: AppColors.primary),
                onDeleted: onClearStep,
                backgroundColor: AppColors.primarySurface,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          if (status.isNotEmpty)
            Chip(
              label: Text(
                PipelineStatus.fromString(status).displayName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
              deleteIcon:
                  const Icon(Icons.close, size: 14, color: AppColors.primary),
              onDeleted: onClearStatus,
              backgroundColor: AppColors.primarySurface,
              side: const BorderSide(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final String selectedStep;
  final String selectedStatus;
  final Function(String step, String status) onApply;

  const _FilterSheet({
    required this.selectedStep,
    required this.selectedStatus,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _step;
  late String _status;

  @override
  void initState() {
    super.initState();
    _step = widget.selectedStep;
    _status = widget.selectedStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Deals',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Step',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              '',
              'quotation',
              'boq',
              'factory_order',
              'purchase_order',
              'completed',
            ].map((step) {
              final label = step.isEmpty
                  ? 'All'
                  : PipelineStep.fromString(step).displayName;
              return ChoiceChip(
                label: Text(label,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: _step == step
                            ? AppColors.primary
                            : AppColors.textPrimary)),
                selected: _step == step,
                onSelected: (_) => setState(() => _step = step),
                selectedColor: AppColors.primarySurface,
                side: BorderSide(
                  color: _step == step ? AppColors.primary : AppColors.border,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Status',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['', 'in_progress', 'completed', 'on_hold', 'cancelled']
                .map((status) {
              final label = status.isEmpty
                  ? 'All'
                  : PipelineStatus.fromString(status).displayName;
              return ChoiceChip(
                label: Text(label,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: _status == status
                            ? AppColors.primary
                            : AppColors.textPrimary)),
                selected: _status == status,
                onSelected: (_) => setState(() => _status = status),
                selectedColor: AppColors.primarySurface,
                side: BorderSide(
                  color:
                      _status == status ? AppColors.primary : AppColors.border,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _step = '';
                      _status = '';
                    });
                    widget.onApply('', '');
                    Navigator.pop(context);
                  },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_step, _status);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
