// lib/core/widgets/pipeline_card.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/pipeline.dart';
import '../models/customer.dart';
import '../theme/app_theme.dart';
import '../router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../models/user_role.dart';
import '../models/quotation.dart';
import 'step_tracker.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final isSalesHead = profile?.primaryRole == UserRole.salesHead || profile?.primaryRole == UserRole.admin;
    final bool requiresApproval = isSalesHead &&
        pipeline.currentStep == PipelineStep.quotation &&
        pipeline.quotation?.status == QuotationStatus.pendingApproval;

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.pipelineDetail.replaceAll(':id', pipeline.id),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: requiresApproval ? const Color(0xFFFFFDF5) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: requiresApproval ? Colors.amber.shade700 : AppColors.border,
            width: requiresApproval ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: requiresApproval
                  ? Colors.amber.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: requiresApproval ? 12 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (_) {
                            final custName = pipeline.customer?.customerName ?? pipeline.customer?.companyName ?? pipeline.customer?.contactPerson;
                            if (showCustomer && custName != null && custName.isNotEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  custName,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        Text(
                          pipeline.product?.name ?? 'Unknown Product',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (showSalesperson && pipeline.createdByProfile != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            pipeline.createdByProfile!.fullName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (requiresApproval) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade800, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pending_actions, size: 12, color: Colors.amber.shade900),
                          const SizedBox(width: 4),
                          Text(
                            'Needs Approval',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Status badge
                  _StatusBadge(status: pipeline.status),
                ],
              ),
            ),
            // Divider
            const Divider(height: 1, thickness: 1, color: AppColors.divider),
            // Step tracker
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: StepTrackerWidget(
                productId: pipeline.productId,
                currentStep: pipeline.currentStep,
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: AppColors.textSecondary.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy').format(pipeline.createdAt),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.textDisabled,
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

class _StatusBadge extends StatelessWidget {
  final PipelineStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = _getColors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
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
