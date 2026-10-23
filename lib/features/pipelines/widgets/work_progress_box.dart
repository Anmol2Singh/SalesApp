// lib/features/pipelines/widgets/work_progress_box.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/user_role.dart';
import '../../../core/models/pipeline.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/factory_order.dart';
import '../../../core/models/purchase_order.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../providers/pipelines_provider.dart';
import '../../sales_order/widgets/delivery_challan_modal.dart';
import '../../quotation_generator/data/qg_noc_repository.dart';
import '../../quotation_generator/models/qg_noc_document.dart';
import '../../quotation_generator/models/qg_noc_builder_state.dart';
import '../../quotation_generator/services/pdf_noc_builder.dart';
import '../../quotation_generator/services/qg_noc_extractor.dart';

/// Helper service for Work Progress metadata persistence & live evaluations.
class WorkProgressService {
  static const String _wpTagPrefix = '[WORK_PROGRESS:';
  static const String _wpTagSuffix = ']';

  /// Extracts work progress metadata from pipeline notes or steps_config.
  static Map<String, dynamic> parseProgressMeta(SalesPipeline pipeline) {
    final notes = pipeline.notes;
    if (notes != null && notes.contains(_wpTagPrefix)) {
      final start = notes.indexOf(_wpTagPrefix) + _wpTagPrefix.length;
      final end = notes.indexOf(_wpTagSuffix, start);
      if (end != -1) {
        try {
          final jsonStr = notes.substring(start, end);
          final parsed = jsonDecode(jsonStr);
          if (parsed is Map) {
            return Map<String, dynamic>.from(parsed);
          }
        } catch (_) {}
      }
    }

    if (pipeline.stepsConfig != null) {
      for (final s in pipeline.stepsConfig!) {
        if (s['id'] == '_work_progress' || s['work_progress'] != null) {
          final raw = s['work_progress'] ?? s;
          if (raw is Map) return Map<String, dynamic>.from(raw);
        }
      }
    }
    return {};
  }

  /// Updates work progress metadata in sales_pipelines notes.
  static Future<void> updateProgressMeta(
    SupabaseClient supabase,
    String pipelineId, {
    bool? dispatchReady,
    bool? challanGenerated,
    bool? dispatched,
  }) async {
    final res = await supabase
        .from('sales_pipelines')
        .select('notes')
        .eq('id', pipelineId)
        .maybeSingle();

    final currentNotes = res?['notes']?.toString() ?? '';
    Map<String, dynamic> currentMeta = {};
    if (currentNotes.contains(_wpTagPrefix)) {
      final start = currentNotes.indexOf(_wpTagPrefix) + _wpTagPrefix.length;
      final end = currentNotes.indexOf(_wpTagSuffix, start);
      if (end != -1) {
        try {
          final jsonStr = currentNotes.substring(start, end);
          currentMeta = Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
        } catch (_) {}
      }
    }

    if (dispatchReady != null) currentMeta['dispatch_ready'] = dispatchReady;
    if (challanGenerated != null) currentMeta['challan_generated'] = challanGenerated;
    if (dispatched != null) currentMeta['dispatched'] = dispatched;

    final newTag = '$_wpTagPrefix${jsonEncode(currentMeta)}$_wpTagSuffix';
    String newNotes;
    if (currentNotes.contains(_wpTagPrefix)) {
      newNotes = currentNotes.replaceAll(RegExp(r'\[WORK_PROGRESS:.*?\]'), newTag);
    } else {
      newNotes = currentNotes.trim().isEmpty ? newTag : '${currentNotes.trim()} $newTag';
    }

    await supabase.from('sales_pipelines').update({
      'notes': newNotes,
    }).eq('id', pipelineId);
  }

  /// Checks whether an installation ticket for this customer & pipeline is completed (resolved or closed).
  static Future<bool> isInstallationComplete(
    SupabaseClient supabase,
    String customerId,
    String pipelineId,
  ) async {
    try {
      final instList = await supabase
          .from('installations')
          .select('id, status, notes, customer_id')
          .or('customer_id.eq.$customerId,notes.ilike.%Deal ID: $pipelineId%');

      if (instList.isNotEmpty) {
        for (final item in instList) {
          final m = Map<String, dynamic>.from(item as Map);
          final s = (m['status']?.toString() ?? '').toLowerCase();
          if (s == 'resolved' || s == 'closed') {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }
}

/// Dynamic Work Progress Tracker displaying the 10 real workflow steps:
/// Quotation -> Sales Order -> Dispatch Ready -> Dispatched -> Factory BOQ ->
/// Site BOQ -> Factory Manufacture -> PO -> Installation -> NOC.
class WorkProgressBox extends ConsumerStatefulWidget {
  final SalesPipeline pipeline;

  const WorkProgressBox({super.key, required this.pipeline});

  @override
  ConsumerState<WorkProgressBox> createState() => _WorkProgressBoxState();
}

class _WorkProgressBoxState extends ConsumerState<WorkProgressBox> {
  bool _loadingAux = true;
  bool _isInstallationCreated = false;
  bool _isInstallationCompleted = false;
  String? _installationTicketNumber;
  String _installationStatus = 'none';

  QgNocDocument? _nocDoc;
  bool _isNocCompleted = false;

  @override
  void initState() {
    super.initState();
    _fetchAuxData();
  }

  @override
  void didUpdateWidget(covariant WorkProgressBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pipeline.id != widget.pipeline.id ||
        oldWidget.pipeline.notes != widget.pipeline.notes ||
        oldWidget.pipeline.updatedAt != widget.pipeline.updatedAt) {
      _fetchAuxData();
    }
  }

  Future<void> _fetchAuxData() async {
    try {
      final supabase = ref.read(supabaseClientProvider);

      // 1. Fetch real customer installation tickets
      final instList = await supabase
          .from('installations')
          .select('id, ticket_number, status, notes, created_at, customer_id')
          .or('customer_id.eq.${widget.pipeline.customerId},notes.ilike.%Deal ID: ${widget.pipeline.id}%')
          .order('created_at', ascending: false);

      bool foundCreated = false;
      bool foundResolved = false;
      String? ticketNo;
      String rawStatus = 'none';

      if (instList.isNotEmpty) {
        foundCreated = true;
        for (final item in instList) {
          final m = Map<String, dynamic>.from(item as Map);
          final s = (m['status']?.toString() ?? '').toLowerCase();
          ticketNo ??= m['ticket_number']?.toString();
          rawStatus = s;
          if (s == 'resolved' || s == 'closed') {
            foundResolved = true;
            ticketNo = m['ticket_number']?.toString();
            rawStatus = s;
            break;
          }
        }
      }

      // 2. Fetch real NOC documents for this deal
      QgNocDocument? noc;
      try {
        final docs = await QgNocRepository.listNocs(dealId: widget.pipeline.id);
        if (docs.isNotEmpty) {
          noc = docs.first;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isInstallationCreated = foundCreated;
          _isInstallationCompleted = foundResolved;
          _installationTicketNumber = ticketNo;
          _installationStatus = rawStatus;
          _nocDoc = noc;
          _isNocCompleted = noc != null;
          _loadingAux = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingAux = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pipeline = widget.pipeline;
    final meta = WorkProgressService.parseProgressMeta(pipeline);

    // Dynamic Step Status calculations
    final bool step1QuotationDone = pipeline.quotation != null;
    final bool step2SalesOrderDone = pipeline.salesOrder != null;

    final bool step3DispatchReady = meta['dispatch_ready'] == true;

    final bool isChallanGenerated = meta['challan_generated'] == true;
    final bool step4DispatchedDone = meta['dispatched'] == true;
    final bool step4CanCheck = isChallanGenerated && !step4DispatchedDone;

    final bool step5FactoryBoqDone = pipeline.boq != null &&
        (pipeline.boq!.items.any((i) => i.scope == 'company') ||
            pipeline.boq!.isSubmitted ||
            pipeline.boq!.items.isNotEmpty);

    final bool step6SiteBoqDone = pipeline.boq != null &&
        (pipeline.boq!.items.any((i) => i.scope == 'customer') ||
            pipeline.boq!.extraFields.isNotEmpty ||
            pipeline.boq!.isSubmitted);

    final bool step7FactoryMfgDone = pipeline.factoryOrder != null &&
        pipeline.factoryOrder!.status == FactoryOrderStatus.completed;
    final bool step7FactoryMfgInProgress = pipeline.factoryOrder != null &&
        pipeline.factoryOrder!.status == FactoryOrderStatus.inProduction;

    final bool step8PoDone = pipeline.purchaseOrder != null &&
        (pipeline.purchaseOrder!.status == PurchaseOrderStatus.received ||
            pipeline.purchaseOrder!.status == PurchaseOrderStatus.ordered ||
            pipeline.purchaseOrder!.items.isNotEmpty);

    final bool step9InstallationDone = _isInstallationCompleted;

    // NOC is strictly activated only AFTER Installation is created & completed
    final bool step10NocActivated = step9InstallationDone;
    final bool step10NocDone = _isNocCompleted;

    // Count completed steps
    final stepsCompleted = [
      step1QuotationDone,
      step2SalesOrderDone,
      step3DispatchReady,
      step4DispatchedDone,
      step5FactoryBoqDone,
      step6SiteBoqDone,
      step7FactoryMfgDone,
      step8PoDone,
      step9InstallationDone,
      step10NocDone,
    ].where((c) => c).length;

    final double progressFraction = stepsCompleted / 10.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_tree_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Work Progress',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (_loadingAux) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Live order fulfillment & commissioning pipeline',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Progress percentage pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: progressFraction == 1.0
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : progressFraction >= 0.5
                          ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: progressFraction == 1.0
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : progressFraction >= 0.5
                            ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$stepsCompleted / 10',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: progressFraction == 1.0
                            ? const Color(0xFF059669)
                            : progressFraction >= 0.5
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${(progressFraction * 100).toInt()}%)',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: progressFraction == 1.0
                            ? const Color(0xFF059669)
                            : progressFraction >= 0.5
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Sleek gradient progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: progressFraction,
                backgroundColor: AppColors.border.withValues(alpha: 0.6),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressFraction == 1.0
                      ? const Color(0xFF10B981)
                      : const Color(0xFF2563EB),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Horizontal scrollable step line
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: Quotation
                  _buildStepItem(
                    stepNum: 1,
                    title: 'Quotation',
                    isCompleted: step1QuotationDone,
                    isActive: !step1QuotationDone,
                    badgeText: step1QuotationDone ? 'Done' : 'Pending',
                    badgeColor: step1QuotationDone ? AppColors.success : AppColors.textDisabled,
                    onTap: () => _handleStepTap(1, step1QuotationDone),
                  ),
                  _buildConnector(isCompleted: step1QuotationDone),

                  // Step 2: Sales Order
                  _buildStepItem(
                    stepNum: 2,
                    title: 'Sales\nOrder',
                    isCompleted: step2SalesOrderDone,
                    isActive: step1QuotationDone && !step2SalesOrderDone,
                    badgeText: step2SalesOrderDone ? 'Done' : 'Pending',
                    badgeColor: step2SalesOrderDone ? AppColors.success : AppColors.textDisabled,
                    onTap: () => _handleStepTap(2, step2SalesOrderDone),
                  ),
                  _buildConnector(isCompleted: step2SalesOrderDone),

                  // Step 3: Dispatch Ready (clicking pops up confirmation)
                  _buildStepItem(
                    stepNum: 3,
                    title: 'Dispatch\nReady',
                    isCompleted: step3DispatchReady,
                    isActive: step2SalesOrderDone && !step3DispatchReady,
                    badgeText: step3DispatchReady ? 'Ready ✓' : 'Check',
                    badgeColor: step3DispatchReady ? AppColors.success : const Color(0xFF2563EB),
                    hasActionIndicator: !step3DispatchReady,
                    onTap: _showDispatchReadyDialog,
                  ),
                  _buildConnector(isCompleted: step3DispatchReady),

                  // Step 4: Dispatched (activated after delivery challan generated)
                  _buildStepItem(
                    stepNum: 4,
                    title: 'Dispatched',
                    isCompleted: step4DispatchedDone,
                    isActive: step4CanCheck,
                    isDeactivated: !isChallanGenerated && !step4DispatchedDone,
                    badgeText: step4DispatchedDone
                        ? 'Dispatched ✓'
                        : isChallanGenerated
                            ? 'Check Dispatched'
                            : 'Challan Req.',
                    badgeColor: step4DispatchedDone
                        ? AppColors.success
                        : isChallanGenerated
                            ? const Color(0xFF059669)
                            : AppColors.textDisabled,
                    hasActionIndicator: step4CanCheck,
                    customActionWidget: step4CanCheck
                        ? Container(
                            margin: const EdgeInsets.only(top: 4),
                            child: InkWell(
                              onTap: _showConfirmDispatchedDialog,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF059669).withValues(alpha: 0.35),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 11, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text(
                                      'Check',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      if (!isChallanGenerated && !step4DispatchedDone) {
                        _showChallanRequiredDialog();
                      } else {
                        _showConfirmDispatchedDialog();
                      }
                    },
                  ),
                  _buildConnector(isCompleted: step4DispatchedDone),

                  // Step 5: Factory BOQ
                  _buildStepItem(
                    stepNum: 5,
                    title: 'Factory\nBOQ',
                    isCompleted: step5FactoryBoqDone,
                    isActive: step4DispatchedDone && !step5FactoryBoqDone,
                    badgeText: step5FactoryBoqDone ? 'Done' : 'Pending',
                    badgeColor: step5FactoryBoqDone ? AppColors.success : AppColors.textDisabled,
                    onTap: () => _handleStepTap(5, step5FactoryBoqDone),
                  ),
                  _buildConnector(isCompleted: step5FactoryBoqDone),

                  // Step 6: Site BOQ
                  _buildStepItem(
                    stepNum: 6,
                    title: 'Site\nBOQ',
                    isCompleted: step6SiteBoqDone,
                    isActive: step5FactoryBoqDone && !step6SiteBoqDone,
                    badgeText: step6SiteBoqDone ? 'Done' : 'Pending',
                    badgeColor: step6SiteBoqDone ? AppColors.success : AppColors.textDisabled,
                    onTap: () => _handleStepTap(6, step6SiteBoqDone),
                  ),
                  _buildConnector(isCompleted: step6SiteBoqDone),

                  // Step 7: Factory Manufacture
                  _buildStepItem(
                    stepNum: 7,
                    title: 'Factory\nMfg',
                    isCompleted: step7FactoryMfgDone,
                    isActive: step7FactoryMfgInProgress || (step6SiteBoqDone && !step7FactoryMfgDone),
                    badgeText: step7FactoryMfgDone
                        ? 'Done'
                        : step7FactoryMfgInProgress
                            ? 'In Prod'
                            : 'Pending',
                    badgeColor: step7FactoryMfgDone
                        ? AppColors.success
                        : step7FactoryMfgInProgress
                            ? const Color(0xFF7C3AED)
                            : AppColors.textDisabled,
                    onTap: () => _handleStepTap(7, step7FactoryMfgDone),
                  ),
                  _buildConnector(isCompleted: step7FactoryMfgDone),

                  // Step 8: PO (Purchase Order)
                  _buildStepItem(
                    stepNum: 8,
                    title: 'PO',
                    isCompleted: step8PoDone,
                    isActive: step7FactoryMfgDone && !step8PoDone,
                    badgeText: step8PoDone ? 'Done' : 'Pending',
                    badgeColor: step8PoDone ? AppColors.success : AppColors.textDisabled,
                    onTap: () => _handleStepTap(8, step8PoDone),
                  ),
                  _buildConnector(isCompleted: step8PoDone),

                  // Step 9: Installation (requires created & completed customer installation)
                  _buildStepItem(
                    stepNum: 9,
                    title: 'Installation',
                    isCompleted: step9InstallationDone,
                    isActive: _isInstallationCreated && !_isInstallationCompleted,
                    badgeText: step9InstallationDone
                        ? 'Done ✓'
                        : _isInstallationCreated
                            ? 'In Progress'
                            : 'Pending',
                    badgeColor: step9InstallationDone
                        ? AppColors.success
                        : _isInstallationCreated
                            ? const Color(0xFFD97706)
                            : AppColors.textDisabled,
                    onTap: _showInstallationDialog,
                  ),
                  _buildConnector(isCompleted: step9InstallationDone),

                  // Step 10: NOC (activated only AFTER installation completed)
                  _buildStepItem(
                    stepNum: 10,
                    title: 'NOC',
                    isCompleted: step10NocDone,
                    isActive: step10NocActivated && !step10NocDone,
                    isDeactivated: !step10NocActivated,
                    badgeText: step10NocDone
                        ? 'Issued ✓'
                        : step10NocActivated
                            ? 'Generate'
                            : 'Locked',
                    badgeColor: step10NocDone
                        ? const Color(0xFF286B37)
                        : step10NocActivated
                            ? const Color(0xFF059669)
                            : AppColors.textDisabled,
                    hasActionIndicator: step10NocActivated && !step10NocDone,
                    onTap: _handleNocStepTap,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required int stepNum,
    required String title,
    required bool isCompleted,
    required bool isActive,
    bool isDeactivated = false,
    required String badgeText,
    required Color badgeColor,
    bool hasActionIndicator = false,
    Widget? customActionWidget,
    required VoidCallback onTap,
  }) {
    Color circleBg;
    Widget centerIcon;
    List<BoxShadow>? shadows;

    if (isCompleted) {
      circleBg = const Color(0xFF10B981);
      centerIcon = const Icon(Icons.check, size: 15, color: Colors.white);
    } else if (isDeactivated) {
      circleBg = const Color(0xFFF1F5F9);
      centerIcon = const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF94A3B8));
    } else if (isActive) {
      circleBg = hasActionIndicator ? const Color(0xFF2563EB) : const Color(0xFF3B82F6);
      shadows = [
        BoxShadow(
          color: circleBg.withValues(alpha: 0.35),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
      centerIcon = Text(
        '$stepNum',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    } else {
      circleBg = const Color(0xFFE2E8F0);
      centerIcon = Text(
        '$stepNum',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 70, maxWidth: 84),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
                border: isDeactivated
                    ? Border.all(color: const Color(0xFFCBD5E1), width: 1.2)
                    : null,
                boxShadow: shadows,
              ),
              child: Center(child: centerIcon),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: (isActive || isCompleted) ? FontWeight.w700 : FontWeight.w500,
                color: isDeactivated
                    ? AppColors.textDisabled
                    : (isCompleted || isActive)
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (customActionWidget != null)
              customActionWidget
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnector({required bool isCompleted}) {
    return Container(
      width: 22,
      height: 2,
      margin: const EdgeInsets.only(top: 15),
      color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
    );
  }

  // Step 3 dialog: Dispatch ready popup
  void _showDispatchReadyDialog() {
    final meta = WorkProgressService.parseProgressMeta(widget.pipeline);
    final isReady = meta['dispatch_ready'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.verified_outlined, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Dispatch Readiness Check',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isReady
                  ? 'This order is currently marked as verified and READY for dispatch.'
                  : 'Are all goods and components inspected, verified, and ready for dispatch?',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    isReady ? Icons.check_circle : Icons.info_outline,
                    size: 16,
                    color: isReady ? AppColors.success : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isReady ? 'Status: Ready for Dispatch' : 'Status: Pending Verification',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isReady ? AppColors.success : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isReady ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final supabase = ref.read(supabaseClientProvider);
              await WorkProgressService.updateProgressMeta(
                supabase,
                widget.pipeline.id,
                dispatchReady: !isReady,
              );
              ref.invalidate(pipelineDetailProvider(widget.pipeline.id));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      !isReady
                          ? '✓ Order marked as Ready for Dispatch.'
                          : 'Order dispatch ready status reset.',
                    ),
                    backgroundColor: !isReady ? AppColors.success : AppColors.warning,
                  ),
                );
              }
            },
            child: Text(isReady ? 'Mark as Not Ready' : 'Confirm Dispatch Ready'),
          ),
        ],
      ),
    );
  }

  // Step 4 dialog: Delivery Challan required
  void _showChallanRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.warning, size: 22),
            SizedBox(width: 10),
            Text('Delivery Challan Required', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Before checking this order as Dispatched, a Delivery Challan must be generated for this customer.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (widget.pipeline.salesOrder != null && widget.pipeline.customer != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                DeliveryChallanModal.show(
                  context,
                  pipelineId: widget.pipeline.id,
                  customer: widget.pipeline.customer!,
                );
              },
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text('Generate Delivery Challan'),
            ),
        ],
      ),
    );
  }

  // Step 4 dialog: Confirm Dispatched
  void _showConfirmDispatchedDialog() {
    final meta = WorkProgressService.parseProgressMeta(widget.pipeline);
    final isDispatched = meta['dispatched'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_shipping, color: Color(0xFF059669), size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              isDispatched ? 'Dispatched Status' : 'Confirm Dispatch',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDispatched
                  ? 'This order has been verified and recorded as Dispatched.'
                  : 'Delivery Challan has been generated. Would you like to check and mark this deal as officially Dispatched?',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Delivery Challan: Generated & Verified ✓',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDispatched ? const Color(0xFFDC2626) : const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final supabase = ref.read(supabaseClientProvider);
              await WorkProgressService.updateProgressMeta(
                supabase,
                widget.pipeline.id,
                dispatched: !isDispatched,
              );
              ref.invalidate(pipelineDetailProvider(widget.pipeline.id));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      !isDispatched
                          ? '✓ Shipment successfully marked as Dispatched!'
                          : 'Dispatched status reverted.',
                    ),
                    backgroundColor: !isDispatched ? AppColors.success : AppColors.warning,
                  ),
                );
              }
            },
            child: Text(isDispatched ? 'Revert Dispatch' : 'Check as Dispatched'),
          ),
        ],
      ),
    );
  }

  // Step 9 dialog: Installation status
  void _showInstallationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (_isInstallationCompleted ? AppColors.success : const Color(0xFFD97706)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isInstallationCompleted ? Icons.task_alt : Icons.build_outlined,
                color: _isInstallationCompleted ? AppColors.success : const Color(0xFFD97706),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Installation Progress',
                style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isInstallationCompleted) ...[
              const Text(
                'Customer installation ticket has been completed and resolved!',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textPrimary, height: 1.4),
              ),
              const SizedBox(height: 8),
              if (_installationTicketNumber != null)
                Text(
                  'Ticket #: $_installationTicketNumber',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              const SizedBox(height: 4),
              const Text(
                'Status: Resolved / Closed ✓',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
              const SizedBox(height: 8),
              const Text(
                'The NOC step has been unlocked and can now be issued.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.success),
              ),
            ] else if (_isInstallationCreated) ...[
              const Text(
                'An installation ticket has been created for this customer, but is not yet marked as resolved/closed.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textPrimary, height: 1.4),
              ),
              const SizedBox(height: 8),
              if (_installationTicketNumber != null)
                Text(
                  'Ticket #: $_installationTicketNumber',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              const SizedBox(height: 4),
              Text(
                'Status: ${_installationStatus.toUpperCase()}',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Complete the installation and mark ticket as resolved to unlock the NOC certificate.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
              ),
            ] else ...[
              const Text(
                'No installation ticket found for this customer. To complete this step and unlock NOC, an installation ticket must be created and marked resolved.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textPrimary, height: 1.4),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/installations');
            },
            child: const Text('Go to Installations'),
          ),
        ],
      ),
    );
  }

  // Step 10: NOC Step tap handler
  Future<void> _handleNocStepTap() async {
    if (!_isInstallationCompleted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: AppColors.warning, size: 22),
              SizedBox(width: 10),
              Text('NOC Locked', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'The No Objection Certificate (NOC) can only be generated after customer installation has been created and marked as completed/resolved.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got It')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/installations');
              },
              child: const Text('View Installations'),
            ),
          ],
        ),
      );
      return;
    }

    // If NOC already issued, view it
    if (_nocDoc != null) {
      _viewNocPdf(_nocDoc!);
      return;
    }

    // Otherwise prompt to generate NOC
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_outlined, color: Color(0xFF286B37), size: 22),
            SizedBox(width: 10),
            Text('Generate NOC', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Customer installation is verified and completed. Would you like to generate and finalize the official No Objection Certificate (NOC) now?',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF286B37),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _generateNoc();
            },
            child: const Text('Generate NOC Now'),
          ),
        ],
      ),
    );
  }

  // Generate NOC Certificate directly
  Future<void> _generateNoc() async {
    if (!_isInstallationCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot generate NOC: Customer installation must be completed first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF286B37)),
                SizedBox(width: 16),
                Text(
                  'Generating NOC Certificate...',
                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final pipeline = widget.pipeline;
      final supabase = ref.read(supabaseClientProvider);

      // Fetch live quotation info if present
      Map<String, dynamic>? qData;
      if (pipeline.quotation?.id != null) {
        final res = await supabase.from('quotations').select().eq('id', pipeline.quotation!.id).maybeSingle();
        if (res != null) qData = res;
      }

      String customerName = pipeline.customer?.companyName.trim() ?? '';
      if (customerName.isEmpty) customerName = pipeline.customer?.customerName.trim() ?? '';
      if (customerName.isEmpty) customerName = 'Customer';

      Map<String, dynamic>? instData;
      try {
        final instRes = await supabase.from('installations').select().eq('customer_id', pipeline.customerId).limit(1).maybeSingle();
        if (instRes != null) instData = instRes;
      } catch (_) {}

      final siteAddress = QgNocExtractor.resolveSiteAddress(
        installation: instData,
        quotation: qData,
        customer: pipeline.customer != null ? {'address': pipeline.customer!.address} : null,
      );

      final rawLines = (qData?['line_items'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          (pipeline.quotation?.lineItems.map((i) => {
                'description': i.description,
                'qty': i.qty,
                'unit': i.uom,
              }).toList() ??
              []);

      final itemsTreatedAsProducts = await QgNocExtractor.fetchItemsTreatedAsProducts(supabase);

      String productName = '';
      if (rawLines.isNotEmpty) {
        final firstDesc = (rawLines.first['description'] ?? rawLines.first['item_name'])?.toString().trim() ?? '';
        if (firstDesc.isNotEmpty) productName = firstDesc;
      }
      if (productName.isEmpty && pipeline.quotation != null && pipeline.quotation!.lineItems.isNotEmpty) {
        productName = pipeline.quotation!.lineItems.first.description.trim();
      }
      if (productName.isEmpty) productName = pipeline.product?.name ?? 'Standard System';

      final equipmentLines = QgNocExtractor.extractEquipmentLines(
        lineItems: rawLines,
        defaultProductName: productName,
        itemsTreatedAsProducts: itemsTreatedAsProducts,
      );

      final compConfig = await QgNocRepository.fetchCompanyDetailsFromTemplate(
        supabase,
        productId: pipeline.productId,
        productName: productName,
      );
      final companyName = compConfig['company_name']?.toString() ?? 'INSIYA TRADING CORPORATION';
      final companyAddress = compConfig['company_address']?.toString() ?? compConfig['address']?.toString() ?? '';
      final companyPhone = compConfig['company_phone']?.toString() ?? compConfig['phone']?.toString() ?? '';
      final companyEmail = compConfig['company_email']?.toString() ?? compConfig['email']?.toString() ?? '';
      final companyWebsite = compConfig['company_website']?.toString() ?? compConfig['website']?.toString() ?? 'www.izyheat.com';
      final logoUrl = compConfig['logo_url']?.toString();

      final subject = 'No Objection Certificate for Installation & Commissioning of $productName.';
      final quoteNumber = qData?['quotation_number']?.toString() ?? pipeline.quotation?.quotationNumber;

      final nocProfile = await QgNocRepository.instance.getProfileForProduct(productName);
      final profileConfirmations = nocProfile.confirmationLines.isNotEmpty
          ? nocProfile.confirmationLines.map((l) => l.replaceAll('{Product}', productName)).toList()
          : [
              '1. The installation of the $productName system is permitted at the above location.',
              '2. The system installed as per standard safety norms and guidelines.',
              '3. Necessary precautions has been taken to avoid noise, vibration, or water leakage issues.',
            ];
      final profileClosing = (nocProfile.closingSentence ?? 'This NOC is issued upon request for installation and operation of the {Product} System.')
          .replaceAll('{Product}', productName);

      final payload = QgNocPayload(
        companyName: companyName,
        companyAddress: companyAddress,
        companyEmail: companyEmail,
        companyPhone: companyPhone,
        companyWebsite: companyWebsite,
        logoUrl: logoUrl,
        salutation: 'M/s',
        customerName: customerName,
        address: siteAddress,
        productName: productName,
        subject: subject,
        date: DateTime.now(),
        equipmentLabel: productName,
        equipmentLines: equipmentLines,
        workType: '$productName Installation work',
        wiring: 'Done',
        testing: 'Done',
        remark: 'All Installation & Commissioning work Completed as per work order',
        confirmations: profileConfirmations,
        closingSentence: profileClosing,
        wordingMode: NocWordingMode.templateExact,
        quotationNumber: quoteNumber,
      );

      final pdfBytes = await PdfNocBuilder.buildNocPdf(payload);

      final issuedDoc = await QgNocRepository.finalizeAndIssueNoc(
        dealId: pipeline.id,
        quotationId: qData?['id']?.toString() ?? pipeline.quotation?.id,
        customerName: customerName,
        siteAddress: siteAddress,
        productName: productName,
        wordingMode: NocWordingMode.templateExact,
        equipmentLines: equipmentLines,
        pdfBytes: pdfBytes,
        companySnapshot: compConfig,
        confirmations: profileConfirmations,
        closingSentence: profileClosing,
        overrideReason: 'Completed deal installation & commissioning verified for $productName',
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
        setState(() {
          _nocDoc = issuedDoc;
          _isNocCompleted = true;
        });

        ref.invalidate(pipelineDetailProvider(widget.pipeline.id));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ NOC ${issuedDoc.nocNumber} issued successfully!'),
            backgroundColor: const Color(0xFF286B37),
          ),
        );

        _viewNocPdf(issuedDoc);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate NOC: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // View NOC PDF preview
  Future<void> _viewNocPdf(QgNocDocument doc) async {
    final profile = ref.read(currentProfileProvider);
    final userRoles = profile?.roles ?? (profile != null ? [profile.primaryRole] : <UserRole>[]);
    final canViewNoc = userRoles.contains(UserRole.admin) || userRoles.contains(UserRole.manager) || userRoles.contains(UserRole.sales) || userRoles.contains(UserRole.salesHead);
    if (!canViewNoc) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to view NOC PDF.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    try {
      final payload = QgNocPayload(
        companyName: doc.companySnapshot['company_name']?.toString() ?? 'INSIYA TRADING CORPORATION',
        companyAddress: doc.companySnapshot['company_address']?.toString() ?? doc.companySnapshot['short_address']?.toString() ?? '',
        companyEmail: doc.companySnapshot['company_email']?.toString() ?? doc.companySnapshot['email']?.toString() ?? '',
        companyPhone: doc.companySnapshot['company_phone']?.toString() ?? doc.companySnapshot['phone']?.toString() ?? '',
        companyWebsite: doc.companySnapshot['company_website']?.toString() ?? doc.companySnapshot['website']?.toString() ?? 'www.izyheat.com',
        logoUrl: doc.companySnapshot['logo_url']?.toString(),
        salutation: 'M/s',
        customerName: doc.customerName,
        address: doc.siteAddress,
        productName: doc.productName,
        subject: 'No Objection Certificate for Installation & Commissioning of ${doc.productName}.',
        date: doc.issuedDate,
        equipmentLabel: doc.productName,
        equipmentLines: doc.equipmentLines,
        workType: '${doc.productName} Installation work',
        wiring: 'Done',
        testing: 'Done',
        remark: 'All Installation & Commissioning work Completed as per work order',
        confirmations: doc.confirmations,
        closingSentence: doc.closingSentence ?? 'This NOC is issued upon request for installation and operation of the ${doc.productName} System.',
        wordingMode: NocWordingMode.templateExact,
        quotationNumber: doc.quotationNumber,
      );

      final pdfBytes = await PdfNocBuilder.buildNocPdf(payload);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            fileName: (doc.pdfName != null && doc.pdfName!.isNotEmpty)
                ? doc.pdfName!
                : 'NOC_${doc.nocNumber.replaceAll('/', '_')}.pdf',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to view NOC: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // General step tap handler with role permissions
  void _handleStepTap(int stepIndex, bool isDone) {
    final profile = ref.read(currentProfileProvider);
    final userRoles = profile?.roles ?? (profile != null ? [profile.primaryRole] : <UserRole>[]);
    final isAdminOrManager = userRoles.contains(UserRole.admin) || userRoles.contains(UserRole.manager);
    final isSales = userRoles.contains(UserRole.sales) || userRoles.contains(UserRole.salesHead);
    final isBoq = userRoles.contains(UserRole.boq);
    final isFactory = userRoles.contains(UserRole.factory);
    final isPurchase = userRoles.contains(UserRole.purchase);

    switch (stepIndex) {
      case 1: // Quotation
        if (isDone) {
          if (!isAdminOrManager && !isSales) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You do not have permission to view Quotation PDF.'),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
          _viewQuotationPdf();
        } else {
          if (!isAdminOrManager && !isSales) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You do not have permission to create Quotation.'),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
          context.push('/quotations/create?pipelineId=${widget.pipeline.id}&productId=${widget.pipeline.productId}&customerId=${widget.pipeline.customerId}');
        }
        break;
      case 2: // Sales Order
        if (isDone) {
          if (!isAdminOrManager && !isSales && !isBoq) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You do not have permission to view Sales Order documents.'),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
          _viewSalesOrderDialog();
        } else {
          if (!isAdminOrManager && !isSales) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You do not have permission to create Sales Order.'),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
          context.push('/sales-orders/create?pipelineId=${widget.pipeline.id}');
        }
        break;
      case 5: // Factory BOQ
      case 6: // Site BOQ
        if (!isAdminOrManager && !isBoq && !isSales) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to view BOQ documents.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        context.push('/boq/${widget.pipeline.id}');
        break;
      case 7: // Factory Manufacture
        if (!isAdminOrManager && !isFactory) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to view Factory Order documents.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        context.push('/factory-orders/${widget.pipeline.id}');
        break;
      case 8: // Purchase Order
        if (!isAdminOrManager && !isPurchase) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to view Purchase Order documents.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        context.push('/purchase-orders/${widget.pipeline.id}');
        break;
    }
  }

  Future<void> _viewQuotationPdf() async {
    final quotation = widget.pipeline.quotation;
    if (quotation == null) return;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
      final supabase = ref.read(supabaseClientProvider);
      Map<String, dynamic> templateConfig = {};
      try {
        final res = await supabase.from('pdf_templates').select().eq('document_type', 'quotation').maybeSingle();
        if (res != null && res['template_config'] != null) {
          templateConfig = res['template_config'] as Map<String, dynamic>;
        }
      } catch (_) {}

      final customer = widget.pipeline.customer ??
          Customer(
            id: widget.pipeline.customerId,
            companyName: 'Customer',
            contactPerson: 'Customer',
            phone: '',
            email: '',
            createdBy: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      final product = widget.pipeline.product ??
          Product(
            id: widget.pipeline.productId,
            name: 'Standard System',
            category: 'Solar',
            baseSpecs: const ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      final bytes = await PdfService.generateQuotationPdf(
        quotation: quotation,
        customer: customer,
        product: product,
        templateConfig: templateConfig,
      );
      if (mounted) Navigator.pop(context);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: bytes,
              fileName: 'Quotation_${quotation.quotationNumber.replaceAll('/', '_')}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _viewSalesOrderDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sales Order Actions', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: const Text(
          'Select document to view or generate:',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/sales-orders/${widget.pipeline.salesOrder?.id}');
            },
            child: const Text('View Sales Order'),
          ),
          if (widget.pipeline.customer != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                DeliveryChallanModal.show(
                  context,
                  pipelineId: widget.pipeline.id,
                  customer: widget.pipeline.customer!,
                );
              },
              child: const Text('Delivery Challan'),
            ),
        ],
      ),
    );
  }
}
