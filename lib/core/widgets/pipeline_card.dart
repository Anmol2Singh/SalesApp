// lib/core/widgets/pipeline_card.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../models/pipeline.dart';
import '../theme/app_theme.dart';
import '../router/app_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../models/user_role.dart';
import '../models/quotation.dart';
import '../../features/pipelines/providers/pipelines_provider.dart';
import '../providers/supabase_provider.dart';

class PipelineCard extends ConsumerWidget {
  final SalesPipeline pipeline;
  final bool showCustomer;
  final bool showSalesperson;

  const PipelineCard({
    super.key,
    required this.pipeline,
    this.showCustomer = true,
    this.showSalesperson = false,
  });

  String _getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'DE';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _getDisplayProductName(SalesPipeline pipeline) {
    if (pipeline.quotation != null && pipeline.quotation!.lineItems.isNotEmpty) {
      final desc = pipeline.quotation!.lineItems.first.description.trim();
      if (desc.isNotEmpty) {
        return desc.replaceAll(' - ', ' • ');
      }
    }
    return pipeline.product?.name ?? 'Heat Pump';
  }

  String _formatDealValue(double? amount) {
    if (amount == null || amount <= 0) return '';
    if (amount >= 10000000) {
      final cr = amount / 10000000;
      final str = cr.toStringAsFixed(cr.truncateToDouble() == cr ? 1 : 2);
      return '₹$str Cr';
    } else if (amount >= 100000) {
      final l = amount / 100000;
      final str = l.toStringAsFixed(l.truncateToDouble() == l ? 1 : 2);
      return '₹$str L';
    } else {
      return '₹${NumberFormat('#,##,##0', 'en_IN').format(amount)}';
    }
  }

  int _getStepNumber(SalesPipeline p) {
    if (p.status == PipelineStatus.completed) return 5;
    switch (p.currentStep) {
      case PipelineStep.quotation:
        return 1;
      case PipelineStep.salesOrder:
        return 2;
      case PipelineStep.boq:
        return 3;
      case PipelineStep.factoryOrder:
        return 4;
      case PipelineStep.purchaseOrder:
      case PipelineStep.completed:
        return 5;
    }
  }

  String _getStepName(SalesPipeline p) {
    if (p.status == PipelineStatus.completed) return 'Completed';
    switch (p.currentStep) {
      case PipelineStep.quotation:
        return 'Quotation';
      case PipelineStep.salesOrder:
        return 'Sales Order';
      case PipelineStep.boq:
        return 'BOQ';
      case PipelineStep.factoryOrder:
        return 'Factory Order';
      case PipelineStep.purchaseOrder:
        return 'Purchase Order';
      case PipelineStep.completed:
        return 'Completed';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final isApproverRole = profile?.primaryRole == UserRole.admin ||
        profile?.primaryRole == UserRole.manager ||
        profile?.primaryRole == UserRole.salesHead ||
        profile?.roles.contains(UserRole.admin) == true ||
        profile?.roles.contains(UserRole.salesHead) == true;

    final isSalesExecutive = profile?.primaryRole == UserRole.sales && !isApproverRole;

    final bool requiresApproval =
        pipeline.quotation?.status == QuotationStatus.pendingApproval;

    final custName = pipeline.customer?.customerName ??
        pipeline.customer?.companyName ??
        pipeline.customer?.contactPerson ??
        'Customer';

    final initials = _getInitials(custName);
    final productName = _getDisplayProductName(pipeline);
    final salespersonName = pipeline.createdByProfile?.fullName ?? '';
    final dealValue = _formatDealValue(pipeline.quotation?.grandTotal);
    final currentStepNum = _getStepNumber(pipeline);
    final currentStepName = _getStepName(pipeline);
    final isCompleted = pipeline.status == PipelineStatus.completed;
    final progressFraction = isCompleted ? 1.0 : (currentStepNum / 5.0);

    return InkWell(
      onTap: () => context.push(
        AppRoutes.pipelineDetail.replaceAll(':id', pipeline.id),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: requiresApproval ? const Color(0xFFFFFDF8) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: requiresApproval ? const Color(0xFFFDE68A) : AppColors.border,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: requiresApproval
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 4px-6px vertical accent bar on left edge for Needs Approval
                if (requiresApproval)
                  Container(
                    width: 5,
                    color: const Color(0xFFF59E0B),
                  ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- ROW 1: Header (Avatar, Customer Info, Value & Status) ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Compact initials avatar
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: requiresApproval
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: requiresApproval
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Customer name & Subtitle row
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    custName,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    children: [
                                      Text(
                                        productName,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (salespersonName.isNotEmpty) ...[
                                        Text(
                                          '•',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              size: 13,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              salespersonName,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 11.5,
                                                color: Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Deal value and Status badge top-right
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (dealValue.isNotEmpty)
                                  Text(
                                    dealValue,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                const SizedBox(height: 3),
                                if (requiresApproval)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                          color: const Color(0xFFF59E0B),
                                          width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.warning_amber_rounded,
                                            size: 11, color: Color(0xFFD97706)),
                                        SizedBox(width: 3),
                                        Text(
                                          'Needs Approval',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFD97706),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (dealValue.isEmpty)
                                  _StatusBadge(status: pipeline.status),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // --- ROW 2: Stepper / Linear Progress Bar (Critical Redesign) ---
                        _buildCompactProgressSection(
                          currentStepNum: currentStepNum,
                          currentStepName: currentStepName,
                          requiresApproval: requiresApproval,
                          progressFraction: progressFraction,
                          isCompleted: isCompleted,
                        ),

                        const SizedBox(height: 8),

                        // --- ROW 3: Footer (Date & Direct Quick Action) ---
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM yyyy').format(pipeline.createdAt),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Spacer(),

                            // Quick Action Button in Card Footer
                            if (requiresApproval) ...[
                              if (isApproverRole)
                                ElevatedButton.icon(
                                  onPressed: () => _showReviewAndApproveSheet(
                                      context, ref, pipeline),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    minimumSize: const Size(0, 30),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6)),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.rate_review_outlined,
                                      size: 13),
                                  label: const Text(
                                    'Review & Approve',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else if (isSalesExecutive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.hourglass_empty,
                                          size: 11, color: Color(0xFFD97706)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Waiting for Admin Approval',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                _buildViewButton(context),
                            ] else ...[
                              _buildViewButton(context),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewButton(BuildContext context) {
    return InkWell(
      onTap: () => context.push(
        AppRoutes.pipelineDetail.replaceAll(':id', pipeline.id),
      ),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'View',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 3),
            Icon(Icons.arrow_forward_ios, size: 9, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Color _getStepColor(int stepNum) {
    switch (stepNum) {
      case 1:
        return const Color(0xFFD97706); // Quotation (Amber)
      case 2:
        return const Color(0xFF2563EB); // Sales Order (Royal Blue)
      case 3:
        return const Color(0xFF0D9488); // BOQ (Teal)
      case 4:
        return const Color(0xFF7C3AED); // Factory Order (Purple)
      case 5:
        return const Color(0xFF059669); // Material Requisition (Emerald)
      default:
        return const Color(0xFF10B981); // Completed (Green)
    }
  }

  Widget _buildCompactProgressSection({
    required int currentStepNum,
    required String currentStepName,
    required bool requiresApproval,
    required double progressFraction,
    required bool isCompleted,
  }) {
    final stepColor = isCompleted ? const Color(0xFF10B981) : _getStepColor(currentStepNum);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: 5 compact connecting nodes + Percentage shifted to the line matching step dots
        Row(
          children: [
            Expanded(
              child: Row(
                children: List.generate(5, (index) {
                  final nodeIndex = index + 1;
                  final isDone = isCompleted || nodeIndex < currentStepNum;
                  final isActive = !isCompleted && nodeIndex == currentStepNum;

                  final Color dotColor;
                  if (isDone) {
                    dotColor = const Color(0xFF10B981);
                  } else if (isActive) {
                    dotColor = requiresApproval
                        ? const Color(0xFFF59E0B)
                        : _getStepColor(nodeIndex);
                  } else {
                    dotColor = Colors.grey.shade300;
                  }

                  return Expanded(
                    child: Row(
                      children: [
                        if (isActive && requiresApproval)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFF59E0B), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hourglass_top,
                                    size: 10, color: Color(0xFFD97706)),
                                const SizedBox(width: 2),
                                Text(
                                  currentStepName,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: dotColor.withValues(alpha: 0.4),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        if (index < 4)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: isDone
                                  ? const Color(0xFF10B981)
                                  : Colors.grey.shade200,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 10),
            // Percentage shifted to step dots line
            Text(
              '${(progressFraction * 100).toInt()}%',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isCompleted ? const Color(0xFF10B981) : stepColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // Row 2: Stage name highlighted with the distinct color of each step
        Row(
          children: [
            Text(
              'Current Stage: ',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            if (isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Completed (5 of 5)',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: stepColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  currentStepName,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: stepColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($currentStepNum of 5)',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _fetchLiveQuotationInfo(
      WidgetRef ref, SalesPipeline pipeline) async {
    if (pipeline.quotation != null &&
        pipeline.quotation!.grandTotal > 0 &&
        pipeline.product != null) {
      return {
        'product_name': pipeline.product!.name,
        'quotation_number': pipeline.quotation!.quotationNumber,
        'grand_total': pipeline.quotation!.grandTotal,
        'salesman': pipeline.quotation!.salesman ??
            pipeline.createdByProfile?.fullName ??
            'Sales Executive',
      };
    }

    try {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase
          .from('quotations')
          .select('quotation_number, grand_total, salesman, products(name)')
          .eq('pipeline_id', pipeline.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        String? prodName;
        if (res['products'] is Map) {
          prodName = res['products']['name'] as String?;
        }
        return {
          'product_name':
              prodName ?? pipeline.product?.name ?? 'Standard System',
          'quotation_number': res['quotation_number']?.toString() ??
              pipeline.quotation?.quotationNumber ??
              '-',
          'grand_total': (res['grand_total'] as num?)?.toDouble() ??
              pipeline.quotation?.grandTotal ??
              0.0,
          'salesman': res['salesman']?.toString() ??
              pipeline.createdByProfile?.fullName ??
              'Sales Executive',
        };
      }
    } catch (_) {}

    return {
      'product_name': pipeline.product?.name ?? 'Standard System',
      'quotation_number': pipeline.quotation?.quotationNumber ?? '-',
      'grand_total': pipeline.quotation?.grandTotal ?? 0.0,
      'salesman': pipeline.createdByProfile?.fullName ?? 'Sales Executive',
    };
  }

  void _showReviewAndApproveSheet(
      BuildContext context, WidgetRef ref, SalesPipeline pipeline) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cust = pipeline.customer?.companyName ??
            pipeline.customer?.customerName ??
            'Customer';

        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.rate_review_outlined,
                            size: 20, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Review Quotation',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              FutureBuilder<Map<String, dynamic>>(
                future: _fetchLiveQuotationInfo(ref, pipeline),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final prodName = data?['product_name'] ??
                      _getDisplayProductName(pipeline);
                  final qNum = data?['quotation_number'] ??
                      pipeline.quotation?.quotationNumber ??
                      '-';
                  final grandTotal = (data?['grand_total'] as num?)?.toDouble() ??
                      pipeline.quotation?.grandTotal ??
                      0.0;
                  final totalStr =
                      '₹${NumberFormat('#,##,##0.00', 'en_IN').format(grandTotal)}';
                  final salesman = data?['salesman'] ??
                      pipeline.createdByProfile?.fullName ??
                      'Sales Executive';

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDF8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      children: [
                        _buildModalDetailRow('Customer', cust),
                        const SizedBox(height: 6),
                        _buildModalDetailRow('Product', prodName),
                        const SizedBox(height: 6),
                        _buildModalDetailRow('Quotation #', qNum),
                        const SizedBox(height: 6),
                        _buildModalDetailRow('Grand Total', totalStr, isBold: true),
                        const SizedBox(height: 6),
                        _buildModalDetailRow('Salesperson', salesman),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              // Action buttons: Details, Reject, Approve
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push(
                        AppRoutes.pipelineDetail.replaceAll(':id', pipeline.id),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('View Details'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleReject(ctx, ref, pipeline),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleApprove(ctx, ref, pipeline),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalDetailRow(String label, String value,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? const Color(0xFF0F172A) : Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<void> _handleApprove(
      BuildContext ctx, WidgetRef ref, SalesPipeline pipeline) async {
    Navigator.pop(ctx);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final profile = ref.read(currentProfileProvider);
      final currentUserId = supabase.auth.currentUser!.id;

      String? quotationId = pipeline.quotation?.id;
      if (quotationId == null) {
        final qRes = await supabase
            .from('quotations')
            .select('id')
            .eq('pipeline_id', pipeline.id)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        quotationId = qRes?['id'] as String?;
      }

      if (quotationId != null) {
        await supabase.from('quotations').update({
          'status': 'confirmed',
          'approved_by': currentUserId,
          'approved_at': DateTime.now().toIso8601String(),
          'confirmed_by': currentUserId,
          'confirmed_at': DateTime.now().toIso8601String(),
        }).eq('id', quotationId);
      }

      await supabase.from('sales_pipelines').update({
        'current_step': 'sales_order',
        'status': 'in_progress',
        'notes':
            'Quotation approved by ${profile?.fullName ?? "Sales Head / Admin"}.',
      }).eq('id', pipeline.id);

      ref.read(pipelinesNotifierProvider.notifier).load(refresh: true);
      ref.invalidate(pipelineDetailProvider(pipeline.id));

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('✓ Quotation approved! Next stage unlocked.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
              content: Text('Approval failed: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleReject(
      BuildContext ctx, WidgetRef ref, SalesPipeline pipeline) async {
    final controller = TextEditingController();
    final proceed = await showDialog<bool>(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reject Quotation',
            style:
                TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the reason/remarks for rejection. The sales executive will see this and will be able to edit and resubmit:',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Reason / Remarks',
                hintText: 'e.g. Price adjustment requested',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(dlgCtx).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a rejection reason.')),
                );
                return;
              }
              Navigator.pop(dlgCtx, true);
            },
            child: const Text('Confirm Rejection',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (proceed != true) return;
    Navigator.pop(ctx);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final currentUserId = supabase.auth.currentUser!.id;
      final remark = controller.text.trim();

      String? quotationId = pipeline.quotation?.id;
      if (quotationId == null) {
        final qRes = await supabase
            .from('quotations')
            .select('id')
            .eq('pipeline_id', pipeline.id)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        quotationId = qRes?['id'] as String?;
      }

      if (quotationId != null) {
        await supabase.from('quotations').update({
          'status': 'rejected',
          'approved_by': currentUserId,
          'approved_at': DateTime.now().toIso8601String(),
        }).eq('id', quotationId);
      }

      await supabase.from('sales_pipelines').update({
        'status': 'in_progress',
        'notes': 'Changes requested: $remark',
      }).eq('id', pipeline.id);

      ref.read(pipelinesNotifierProvider.notifier).load(refresh: true);
      ref.invalidate(pipelineDetailProvider(pipeline.id));

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Quotation rejected and feedback saved.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
              content: Text('Rejection failed: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final PipelineStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = _getColors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  (Color, Color) _getColors() {
    switch (status) {
      case PipelineStatus.inProgress:
        return (AppColors.statusInProgress, AppColors.infoLight);
      case PipelineStatus.completed:
        return (AppColors.statusCompleted, AppColors.successLight);
      case PipelineStatus.onHold:
        return (AppColors.statusOnHold, AppColors.warningLight);
      case PipelineStatus.cancelled:
        return (AppColors.statusCancelled, AppColors.errorLight);
      case PipelineStatus.suspended:
        return (AppColors.error, AppColors.errorLight);
    }
  }
}
