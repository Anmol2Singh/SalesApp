// lib/core/widgets/step_tracker.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../theme/app_theme.dart';
import '../../features/pipelines/providers/pipelines_provider.dart';

class StepTrackerWidget extends ConsumerWidget {
  final String productId;
  final PipelineStep currentStep;
  final Function(PipelineStep step)? onStepTap;
  final Map<PipelineStep, String?>? pdfUrls;
  final bool compact;
  final List<Map<String, dynamic>>? stepsConfig;

  const StepTrackerWidget({
    super.key,
    required this.productId,
    required this.currentStep,
    this.onStepTap,
    this.pdfUrls,
    this.compact = false,
    this.stepsConfig,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stepsConfig != null && stepsConfig!.isNotEmpty) {
      if (compact) return _buildCompact(stepsConfig!);
      return _buildFull(stepsConfig!);
    }

    final stepsAsync = ref.watch(workflowStepsProvider(productId));

    return stepsAsync.when(
      data: (steps) {
        if (compact) return _buildCompact(steps);
        return _buildFull(steps);
      },
      loading: () => const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => _buildFull([
        {'id': 'quotation', 'name': 'Quotation'},
        {'id': 'sales_order', 'name': 'Sales Order'},
        {'id': 'boq', 'name': 'BOQ'},
        {'id': 'factory_order', 'name': 'Factory Order'},
        {'id': 'purchase_order', 'name': 'Purchase Order'},
      ]),
    );
  }

  Widget _buildFull(List<Map<String, dynamic>> steps) {
    final currentStepId = currentStep.dbValue;
    int currentIndex = steps.indexWhere((s) => (s['id'] ?? s['key']) == currentStepId);
    if (currentIndex == -1) {
      currentIndex = currentStep == PipelineStep.completed ? steps.length : 0;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            Expanded(child: _buildStep(steps[i], i, currentIndex)),
            if (i < steps.length - 1) _buildConnector(i, currentIndex),
          ],
        ],
      ),
    );
  }

  Widget _buildCompact(List<Map<String, dynamic>> steps) {
    final currentStepId = currentStep.dbValue;
    int currentIndex = steps.indexWhere((s) => (s['id'] ?? s['key']) == currentStepId);
    if (currentIndex == -1) {
      currentIndex = currentStep == PipelineStep.completed ? steps.length : 0;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < currentIndex
                  ? AppColors.stepCompleted
                  : i == currentIndex
                      ? AppColors.stepActive
                      : AppColors.stepPending,
            ),
          ),
          if (i < steps.length - 1)
            Container(
              width: 12,
              height: 2,
              color: i < currentIndex
                  ? AppColors.stepCompleted
                  : AppColors.stepPending,
            ),
        ],
      ],
    );
  }

  Widget _buildStep(Map<String, dynamic> step, int index, int currentIndex) {
    final isCompleted = index < currentIndex;
    final isActive = index == currentIndex;
    
    final stepId = step['id'] ?? step['key'] ?? '';
    final stepName = step['name'] ?? '';
    final stepEnum = _mapToEnum(stepId);
    final hasPdf = stepEnum != null && pdfUrls?[stepEnum] != null;

    Color circleColor;
    Color textColor;
    Widget icon;

    if (isCompleted) {
      circleColor = AppColors.stepCompleted;
      textColor = AppColors.stepCompleted;
      icon = const Icon(Icons.check, color: Colors.white, size: 14);
    } else if (isActive) {
      circleColor = AppColors.stepActive;
      textColor = AppColors.stepActive;
      icon = Text(
        '${index + 1}',
        style: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    } else {
      circleColor = AppColors.stepPending;
      textColor = AppColors.textDisabled;
      icon = Text(
        '${index + 1}',
        style: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return GestureDetector(
      onTap: stepEnum != null && (isCompleted || isActive) && onStepTap != null
          ? () => onStepTap!(stepEnum)
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: circleColor.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Center(child: icon),
              ),
              if (isCompleted && hasPdf)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.info,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.white,
                      size: 8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            stepName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: textColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(int index, int currentIndex) {
    final isCompleted = index < currentIndex;

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 22),
        color: isCompleted ? AppColors.stepCompleted : AppColors.stepPending,
      ),
    );
  }

  PipelineStep? _mapToEnum(String id) {
    switch (id) {
      case 'quotation':
        return PipelineStep.quotation;
      case 'sales_order':
      case 'salesOrder':
        return PipelineStep.salesOrder;
      case 'boq':
        return PipelineStep.boq;
      case 'factory_order':
      case 'factoryOrder':
        return PipelineStep.factoryOrder;
      case 'purchase_order':
      case 'purchaseOrder':
        return PipelineStep.purchaseOrder;
      default:
        return null;
    }
  }
}
