// lib/features/pipelines/screens/pipeline_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/customer.dart';
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
  String _selectedStep = '';
  String _selectedStatus = '';

  bool _showCompletedDeals = false;

  @override
  void initState() {
    super.initState();
    _selectedStep = widget.initialStep;
    _selectedStatus = widget.initialStatus;
    if (_selectedStatus == 'completed') {
      _showCompletedDeals = true;
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
    final pipelinesAsync = ref.watch(pipelinesNotifierProvider);
    final profile = ref.watch(currentProfileProvider);
    final isAdmin = profile?.primaryRole == UserRole.admin;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(pipelinesNotifierProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 185,
              pinned: true,
              backgroundColor: const Color(0xFF1E1B4B),
              clipBehavior: Clip.antiAlias,
              title: Text(
                isAdmin ? 'All Deals' : 'My Deals',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  children: [
                    // Deep indigo → violet gradient
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1E1B4B),
                            Color(0xFF4C1D95),
                            Color(0xFF6D28D9),
                          ],
                        ),
                      ),
                    ),
                    // Radial glow top-right
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
                              AppColors.primary.withOpacity(0.25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Radial glow bottom-left
                    Positioned(
                      bottom: -20,
                      left: -40,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF06B6D4).withOpacity(0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 68, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  gradient: LinearGradient(
                                    colors: profile?.primaryRole.gradientColors ??
                                        [const Color(0xFF8B5CF6), const Color(0xFF06B6D4)],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    (profile?.fullName ?? 'S')[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Good ${_getGreeting()}',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.6),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      profile?.fullName ?? 'Representative',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Mini stat pills row
                          Row(
                            children: [
                              _buildHeaderStat(
                                'Today',
                                DateFormat('dd MMM').format(DateTime.now()),
                                Icons.calendar_today_outlined,
                              ),
                              const SizedBox(width: 12),
                              _buildHeaderStat(
                                'Role',
                                profile?.primaryRole.name.toUpperCase() ?? 'STAFF',
                                Icons.badge_outlined,
                                iconColor: profile?.primaryRole.roleColor ?? Colors.white,
                                accentColor: profile?.primaryRole.roleColor,
                              ),
                              const SizedBox(width: 12),
                              _buildHeaderStat(
                                'Status',
                                'ONLINE',
                                Icons.circle,
                                iconColor: const Color(0xFF10B981),
                                iconSize: 10,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                const SyncStatusIndicator(),
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.white),
                  onPressed: _showFilterSheet,
                ),
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.download_outlined, color: Colors.white),
                    onPressed: () => _exportExcel(context, ref),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => ref.read(pipelinesNotifierProvider.notifier).refresh(),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
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

            // Toggle Bar: Active Deals vs Completed Deals
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _showCompletedDeals = false);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_showCompletedDeals ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.alt_route_outlined,
                                  size: 16,
                                  color: !_showCompletedDeals ? Colors.white : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Active Deals',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: !_showCompletedDeals ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _showCompletedDeals = true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _showCompletedDeals ? const Color(0xFF10B981) : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color: _showCompletedDeals ? Colors.white : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Completed Deals',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _showCompletedDeals ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                  if (_showCompletedDeals) {
                    return p.status == PipelineStatus.completed;
                  } else {
                    return p.status != PipelineStatus.completed;
                  }
                }).toList();

                if (pipelines.isEmpty) {
                  return SliverFillRemaining(
                    child: _showCompletedDeals
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF10B981)),
                                  SizedBox(height: 12),
                                  Text(
                                    'No completed deals yet.',
                                    style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _EmptyPipelinesState(
                            onAdd: profile?.primaryRole.canCreateCustomers == true
                                ? () => context.go(AppRoutes.customers)
                                : null,
                          ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == pipelines.length) {
                          return const SizedBox(height: 80);
                        }
                        return PipelineCard(
                          pipeline: pipelines[index],
                          showCustomer: true,
                          showSalesperson: isAdmin,
                        );
                      },
                      childCount: pipelines.length + 1,
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  static Widget _buildHeaderStat(
    String label,
    String value,
    IconData icon, {
    Color iconColor = Colors.white,
    double iconSize = 14,
    Color? accentColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accentColor != null ? accentColor.withOpacity(0.18) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accentColor != null ? accentColor.withOpacity(0.45) : Colors.white.withOpacity(0.1),
            width: accentColor != null ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: iconSize),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

class _EmptyPipelinesState extends StatelessWidget {
  final VoidCallback? onAdd;

  const _EmptyPipelinesState({this.onAdd});

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
              child: const Icon(Icons.handshake_outlined,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Deals Yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a customer and start a new deal to begin tracking the sales lifecycle.',
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
                label: const Text('Go to Customers'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
