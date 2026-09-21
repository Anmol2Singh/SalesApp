// lib/features/dashboard/screens/recent_deals_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/factory_order.dart';
import '../../factory_order/screens/factory_queue_screen.dart';
import '../../purchase_order/screens/purchase_queue_screen.dart';

enum RecentDealsType {
  factory,
  purchase,
}

class RecentDealsScreen extends ConsumerStatefulWidget {
  final RecentDealsType type;
  final String? title;

  const RecentDealsScreen({
    super.key,
    required this.type,
    this.title,
  });

  @override
  ConsumerState<RecentDealsScreen> createState() => _RecentDealsScreenState();
}

class _RecentDealsScreenState extends ConsumerState<RecentDealsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFactory = widget.type == RecentDealsType.factory;
    final asyncData = isFactory
        ? ref.watch(factoryQueueProvider)
        : ref.watch(purchaseQueueProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.title ?? 'Recent Deals',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              if (isFactory) {
                ref.invalidate(factoryQueueProvider);
              } else {
                ref.invalidate(purchaseQueueProvider);
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          if (isFactory) {
            ref.invalidate(factoryQueueProvider);
          } else {
            ref.invalidate(purchaseQueueProvider);
          }
        },
        child: Column(
          children: [
            // Search field
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search by customer, product, or deal...',
                  hintStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: asyncData.when(
                data: (orders) {
                  final filtered = orders.where((order) {
                    if (_searchQuery.isEmpty) return true;
                    final pipeline = order['sales_pipelines'] as Map<String, dynamic>?;
                    final customer = pipeline?['customers'] as Map<String, dynamic>?;
                    final product = pipeline?['products'] as Map<String, dynamic>?;
                    final custName = (customer?['customer_name'] as String? ?? customer?['company_name'] as String? ?? '').toLowerCase();
                    final prodName = (product?['name'] as String? ?? '').toLowerCase();
                    final statusStr = (order['status'] as String? ?? '').toLowerCase();
                    return custName.contains(_searchQuery) ||
                        prodName.contains(_searchQuery) ||
                        statusStr.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFactory ? Icons.factory_outlined : Icons.shopping_cart_outlined,
                            size: 56,
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty ? 'No Deals Available' : 'No Deals Match Search',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _searchQuery.isEmpty
                                ? 'All orders and requisitions have been processed.'
                                : 'Try searching with a different term.',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final order = filtered[index];
                      if (isFactory) {
                        return _buildFactoryDealCard(context, order);
                      } else {
                        return _buildPurchaseDealCard(context, order);
                      }
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactoryDealCard(BuildContext context, Map<String, dynamic> order) {
    final pipeline = order['sales_pipelines'] as Map<String, dynamic>?;
    final customer = pipeline?['customers'] as Map<String, dynamic>?;
    final product = pipeline?['products'] as Map<String, dynamic>?;
    final status = FactoryOrderStatus.fromString(order['status'] as String? ?? 'pending');
    final createdAt = DateTime.tryParse(order['created_at'] as String? ?? '') ?? DateTime.now();
    final expectedDate = order['expected_completion_date'] != null
        ? DateTime.tryParse(order['expected_completion_date'] as String)
        : null;
    final isOverdue = expectedDate != null &&
        expectedDate.isBefore(DateTime.now()) &&
        status != FactoryOrderStatus.completed;

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.factoryOrderForm
            .replaceAll(':id', pipeline?['id'] as String? ?? ''),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? AppColors.error : AppColors.border,
            width: isOverdue ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: status == FactoryOrderStatus.inProduction
                        ? AppColors.infoLight
                        : AppColors.warningLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    status == FactoryOrderStatus.inProduction
                        ? Icons.settings_outlined
                        : Icons.pending_outlined,
                    color: status == FactoryOrderStatus.inProduction
                        ? AppColors.info
                        : AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer?['customer_name'] as String? ??
                            customer?['company_name'] as String? ??
                            'Unknown Customer',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        product?['name'] as String? ?? '',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                FactoryStatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Created ${DateFormat('dd MMM yyyy').format(createdAt)}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (expectedDate != null) ...[
                  const SizedBox(width: 12),
                  Icon(
                    isOverdue ? Icons.warning_outlined : Icons.schedule,
                    size: 12,
                    color: isOverdue ? AppColors.error : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOverdue
                        ? 'OVERDUE — ${DateFormat('dd MMM').format(expectedDate)}'
                        : 'Due ${DateFormat('dd MMM').format(expectedDate)}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
                      color: isOverdue ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ],
                const Spacer(),
                const Icon(Icons.chevron_right,
                    color: AppColors.textDisabled, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseDealCard(BuildContext context, Map<String, dynamic> order) {
    final pipeline = order['sales_pipelines'] as Map<String, dynamic>?;
    final customer = pipeline?['customers'] as Map<String, dynamic>?;
    final product = pipeline?['products'] as Map<String, dynamic>?;
    final createdAt = DateTime.tryParse(order['created_at'] as String? ?? '') ?? DateTime.now();

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.purchaseOrderForm
            .replaceAll(':id', pipeline?['id'] as String? ?? ''),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer?['customer_name'] as String? ??
                        customer?['company_name'] as String? ??
                        'Unknown Customer',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    product?['name'] as String? ?? '',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Added ${DateFormat('dd MMM yyyy').format(createdAt)}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}
