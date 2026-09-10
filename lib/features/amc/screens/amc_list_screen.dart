// lib/features/amc/screens/amc_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/amc_contract.dart';
import '../providers/amc_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/excel_service.dart';

class AmcListScreen extends ConsumerStatefulWidget {
  const AmcListScreen({super.key});

  @override
  ConsumerState<AmcListScreen> createState() => _AmcListScreenState();
}

class _AmcListScreenState extends ConsumerState<AmcListScreen> {
  String _selectedFilter = '';

  final _filterOptions = const [
    {'label': 'All', 'value': ''},
    {'label': 'Active', 'value': 'active'},
    {'label': 'Expiring Soon', 'value': 'expiring_soon'},
    {'label': 'Expired', 'value': 'expired'},
    {'label': 'Interested', 'value': 'interested'},
    {'label': 'Pending', 'value': 'pending_setup'},
  ];

  @override
  Widget build(BuildContext context) {
    final amcAsync = ref.watch(amcNotifierProvider);
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AMC Contracts'),
        actions: [
          if (profile?.primaryRole.canExportAll == true)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export AMC',
              onPressed: () => _exportAmcContracts(amcAsync),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(amcNotifierProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filterOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final option = _filterOptions[index];
                final isSelected = _selectedFilter == option['value'];
                return FilterChip(
                  label: Text(
                    option['label']!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedFilter = option['value']!);
                    ref
                        .read(amcNotifierProvider.notifier)
                        .setStatusFilter(option['value']!);
                  },
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primary,
                  side: BorderSide(
                    color:
                        isSelected ? AppColors.primary : AppColors.border,
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),

          // List
          Expanded(
            child: amcAsync.when(
              data: (contracts) {
                if (contracts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.build_circle_outlined,
                            size: 64, color: AppColors.textDisabled),
                        const SizedBox(height: 12),
                        const Text(
                          'No AMC contracts found',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'AMC contracts will appear here when created\nfrom quotations or completed pipelines.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(amcNotifierProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: contracts.length,
                    itemBuilder: (context, index) {
                      return _AmcContractCard(
                        contract: contracts[index],
                        onTap: () => context.push(
                          AppRoutes.amcDetail
                              .replaceAll(':id', contracts[index].id),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text('Error: $e'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(amcNotifierProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _exportAmcContracts(AsyncValue<List<AmcContract>> amcAsync) {
    final contracts = amcAsync.value;
    if (contracts == null || contracts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No AMC contracts to export'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    ExcelService.exportAmcContracts(context, contracts);
  }
}

class _AmcContractCard extends StatelessWidget {
  final AmcContract contract;
  final VoidCallback onTap;

  const _AmcContractCard({required this.contract, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: contract.isExpiringSoon
                ? AppColors.warning.withOpacity(0.4)
                : AppColors.border,
          ),
          boxShadow: contract.isExpiringSoon
              ? [
                  BoxShadow(
                    color: AppColors.warning.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: customer + status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    contract.customer?.companyName ?? 'Unknown Customer',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: contract.status),
              ],
            ),
            const SizedBox(height: 6),

            // Product + AMC number
            Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    contract.product?.name ?? 'Unknown Product',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  contract.amcNumber,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Dates + visits progress
            if (contract.startDate != null || contract.endDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (contract.startDate != null) ...[
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${dateFormat.format(contract.startDate!)} — ${contract.endDate != null ? dateFormat.format(contract.endDate!) : '?'}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (contract.serviceVisits != null &&
                      contract.serviceVisits!.isNotEmpty) ...[
                    Icon(Icons.engineering_outlined,
                        size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      contract.visitsProgressText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AmcContractStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: status.color,
        ),
      ),
    );
  }
}
