// lib/features/quotation_generator/ui/screens/quotation_history_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/deal_quotation_item.dart';
import '../../providers/quotation_generator_providers.dart';
import 'quotation_settings_screen.dart';
import 'proposal_builder_screen.dart';

/// Automated Deal Hub listing all deal quotations created for the Heat Pump product.
/// Strictly read-only against existing deal quotations.
class QuotationHistoryScreen extends ConsumerStatefulWidget {
  const QuotationHistoryScreen({super.key});

  @override
  ConsumerState<QuotationHistoryScreen> createState() =>
      _QuotationHistoryScreenState();
}

class _QuotationHistoryScreenState extends ConsumerState<QuotationHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _selectedStatusFilter = 'All'; // All, Draft, Pending, Confirmed, Rejected
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    // 30-second automated polling timer for live deal synchronization
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.invalidate(dealQuotationsProvider);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _navigateBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    final profile = ref.read(currentProfileProvider);
    final home = profile != null ? getRoleHome(profile.primaryRole) : AppRoutes.adminDashboard;
    context.go(home);
  }

  Future<void> _refresh() async {
    ref.invalidate(dealQuotationsProvider);
    await ref.read(dealQuotationsProvider.future);
  }

  Color _getStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'confirmed':
        return AppColors.success;
      case 'pending':
      case 'pending_approval':
      case 'pending approval':
        return AppColors.warning;
      case 'rejected':
        return AppColors.error;
      case 'draft':
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: _navigateBack,
          ),
          title: const Text(
            'Proposal PDF Generator (Heat Pump Hub)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Sync Deals',
              onPressed: _refresh,
            ),
          ],
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.accent,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(icon: Icon(Icons.folder_shared_outlined), text: 'Deal Quotations Queue'),
              Tab(icon: Icon(Icons.settings_outlined), text: 'Module Settings'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDealQuotationsQueueTab(),
            const QuotationSettingsScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildDealQuotationsQueueTab() {
    final quotesAsync = ref.watch(dealQuotationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return quotesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Failed to load deal quotations: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (quotes) {
        // Filter by search query
        final query = _searchCtrl.text.trim().toLowerCase();
        final filteredBySearch = quotes.where((q) {
          if (query.isEmpty) return true;
          return q.customerName.toLowerCase().contains(query) ||
              q.quotationNumber.toLowerCase().contains(query) ||
              q.salesmanName.toLowerCase().contains(query);
        }).toList();

        // Filter by status chip
        final filtered = filteredBySearch.where((q) {
          if (_selectedStatusFilter == 'All') return true;
          final s = q.status.trim().toLowerCase();
          if (_selectedStatusFilter == 'Confirmed') return s == 'confirmed';
          if (_selectedStatusFilter == 'Pending') return s.contains('pending');
          if (_selectedStatusFilter == 'Draft') return s == 'draft';
          if (_selectedStatusFilter == 'Rejected') return s == 'rejected';
          return true;
        }).toList();

        // Calculate KPI summaries
        final totalCount = quotes.length;
        final confirmedCount = quotes.where((q) => q.isConfirmed).length;
        final finalizedCount = quotes.where((q) => q.hasFinalizedProposal).length;

        return Column(
          children: [
            // KPI Summary Row
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  _buildKpiChip('Total Deals', '$totalCount', AppColors.primary, isDark),
                  const SizedBox(width: 8),
                  _buildKpiChip('Approved', '$confirmedCount', AppColors.success, isDark),
                  const SizedBox(width: 8),
                  _buildKpiChip('Finalized PDF', '$finalizedCount', const Color(0xFF8B5CF6), isDark),
                ],
              ),
            ),

            // Search Bar & Filters
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by customer, quotation number, or salesperson...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _searchCtrl.clear()),
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in ['All', 'Confirmed', 'Pending', 'Draft', 'Rejected'])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(
                                filter,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedStatusFilter == filter ? FontWeight.w600 : FontWeight.w500,
                                  color: _selectedStatusFilter == filter
                                      ? AppColors.primary
                                      : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
                                ),
                              ),
                              selected: _selectedStatusFilter == filter,
                              onSelected: (_) => setState(() => _selectedStatusFilter = filter),
                              selectedColor: AppColors.primary.withAlpha(40),
                              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              checkmarkColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: BorderSide(
                                color: _selectedStatusFilter == filter
                                    ? AppColors.primary
                                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Quotations List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Column(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textSecondary),
                                SizedBox(height: 12),
                                Text(
                                  'No deal quotations match criteria.',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Quotations created in Heat Pump deals automatically appear here.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _buildDealQuotationCard(item, isDark);
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiChip(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(isDark ? 30 : 15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDealQuotationCard(DealQuotationItem q, bool isDark) {
    final statusColor = _getStatusColor(q.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: q.hasFinalizedProposal
              ? AppColors.success.withAlpha(80)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          width: q.hasFinalizedProposal ? 1.5 : 1,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openProposalDetails(q),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Customer + Status Chip
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.customerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Quote Ref: ${q.quotationNumber} • Rev ${q.revision}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withAlpha(80)),
                        ),
                        child: Text(
                          q.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (q.hasFinalizedProposal) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 10, color: AppColors.success),
                              SizedBox(width: 4),
                              Text('PDF Finalized', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Items breakdown summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < q.lineItems.length && i < 2; i++) ...[
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 6, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              q.lineItems[i]['description']?.toString() ?? '',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (i < q.lineItems.length - 1) const SizedBox(height: 4),
                    ],
                    if (q.lineItems.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          '+ ${q.lineItems.length - 2} more items',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Bottom Info: Date, Salesman, Grand Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(q.formattedDate, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(width: 12),
                          const Icon(Icons.person_outline, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            q.salesmanName,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    q.formattedGrandTotal,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
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

  void _openProposalDetails(DealQuotationItem q) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ProposalBuilderScreen(
          quotationId: q.id,
          initialDealQuotation: q,
        ),
      ),
    ).then((_) {
      if (mounted) ref.invalidate(dealQuotationsProvider);
    });
  }
}

