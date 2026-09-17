import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/pipeline.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/quotation.dart';
import '../../../core/widgets/step_tracker.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/pipelines_provider.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/widgets/breadcrumbs.dart';
import '../../amc/providers/amc_provider.dart';
import '../../../core/models/amc_contract.dart';

class PipelineDetailScreen extends ConsumerWidget {
  final String pipelineId;

  const PipelineDetailScreen({super.key, required this.pipelineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipelineAsync = ref.watch(pipelineDetailProvider(pipelineId));
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Deal Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.pipelines);
            }
          },
        ),
        actions: [
          if (profile?.roles.contains(UserRole.admin) == true) ...[
            if (pipelineAsync.valueOrNull?.status == PipelineStatus.completed)
              TextButton.icon(
                onPressed: () async {
                  // Admin Unlock logic
                  final db = ref.read(supabaseClientProvider);
                  await db.from('sales_pipelines').update({'status': 'in_progress'}).eq('id', pipelineId);
                  ref.invalidate(pipelineDetailProvider(pipelineId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deal unlocked')));
                },
                icon: const Icon(Icons.lock_open, color: Colors.white),
                label: const Text('Unlock', style: TextStyle(color: Colors.white)),
              )
            else if (pipelineAsync.valueOrNull != null && _checkAllStepsCompleted(pipelineAsync.valueOrNull!))
              TextButton.icon(
                onPressed: () async {
                  final db = ref.read(supabaseClientProvider);
                  await db.from('sales_pipelines').update({
                    'current_step': 'completed',
                    'status': 'completed',
                  }).eq('id', pipelineId);
                  ref.invalidate(pipelineDetailProvider(pipelineId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deal marked 100% Complete!'), backgroundColor: AppColors.success),
                  );
                },
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text('Mark 100% Complete', style: TextStyle(color: Colors.white)),
              ),
          ],
          if (profile?.primaryRole == UserRole.admin || profile?.roles.contains(UserRole.admin) == true)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Delete Deal (Admin Only)',
              onPressed: () => _confirmDeleteDeal(context, ref, pipelineAsync.valueOrNull),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(pipelineDetailProvider(pipelineId)),
          ),
        ],
      ),
      body: Column(
        children: [
          Breadcrumbs(
            items: [
              BreadcrumbItem(
                label: 'Dashboard',
                route: profile?.primaryRole == UserRole.admin
                    ? AppRoutes.adminDashboard
                    : AppRoutes.salesDashboard,
              ),
              BreadcrumbItem(label: 'Deals', route: AppRoutes.pipelines),
              BreadcrumbItem(label: 'Deal Detail'),
            ],
          ),
          Expanded(
            child: pipelineAsync.when(
              data: (pipeline) => _PipelineDetailContent(
                pipeline: pipeline,
                userRole: profile?.primaryRole,
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text('Error: $e'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(pipelineDetailProvider(pipelineId)),
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

  void _confirmDeleteDeal(BuildContext context, WidgetRef ref, SalesPipeline? pipeline) {
    final dealName = pipeline?.customer?.companyName ?? 'this deal';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Deal?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to permanently delete deal "$dealName"?\n\nThis will remove all associated quotations, orders, and records. This action cannot be undone.',
          style: const TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final db = ref.read(supabaseClientProvider);
                try {
                  await db.rpc('delete_sales_pipeline', params: {'p_pipeline_id': pipelineId});
                } catch (_) {}

                try {
                  // 1. Get associated AMC contract IDs if any
                  List amcIds = [];
                  try {
                    final amcRows = await db.from('amc_contracts').select('id').eq('pipeline_id', pipelineId);
                    amcIds = (amcRows as List).map((r) => r['id']).toList();
                  } catch (_) {}

                  // 2. Delete step_audit_log entries linked to pipeline or AMC contracts
                  try {
                    await db.from('step_audit_log').delete().eq('pipeline_id', pipelineId);
                  } catch (_) {}

                  if (amcIds.isNotEmpty) {
                    for (final aid in amcIds) {
                      try {
                        await db.from('step_audit_log').delete().eq('amc_contract_id', aid);
                      } catch (_) {}
                      try {
                        await db.from('amc_service_visits').delete().eq('amc_contract_id', aid);
                      } catch (_) {}
                    }
                    try {
                      await db.from('amc_contracts').delete().eq('pipeline_id', pipelineId);
                    } catch (_) {}
                  }

                  // 3. Delete deal_audit_log
                  try {
                    await db.from('deal_audit_log').delete().eq('pipeline_id', pipelineId);
                  } catch (_) {}

                  // 4. Delete step documents
                  try { await db.from('stage_signatures').delete().eq('pipeline_id', pipelineId); } catch (_) {}
                  try { await db.from('proforma_invoices').delete().eq('pipeline_id', pipelineId); } catch (_) {}
                  try { await db.from('tax_invoices').delete().eq('pipeline_id', pipelineId); } catch (_) {}
                  try { await db.from('purchase_orders').delete().eq('pipeline_id', pipelineId); } catch (_) {}
                  try { await db.from('factory_orders').delete().eq('pipeline_id', pipelineId); } catch (_) {}
                  try { await db.from('boqs').delete().eq('pipeline_id', pipelineId); } catch (_) {}
                  try { await db.from('sales_orders').delete().eq('pipeline_id', pipelineId); } catch (_) {}
                  try { await db.from('quotations').delete().eq('pipeline_id', pipelineId); } catch (_) {}
                  try { await db.from('warranty_cards').delete().eq('pipeline_id', pipelineId); } catch (_) {}

                  // 5. Delete sales_pipelines
                  await db.from('sales_pipelines').delete().eq('id', pipelineId);
                } catch (e) {
                  final check = await db.from('sales_pipelines').select('id').eq('id', pipelineId).maybeSingle();
                  if (check != null) {
                    rethrow;
                  }
                }
                ref.read(pipelinesNotifierProvider.notifier).load(refresh: true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Deal deleted successfully.'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.pipelines);
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting deal: $e'), backgroundColor: const Color(0xFFEF4444)),
                  );
                }
              }
            },
            child: const Text('Delete Deal', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

bool _checkAllStepsCompleted(SalesPipeline pipeline) {
  final config = pipeline.stepsConfig;
  if (config != null && config.isNotEmpty) {
    for (final s in config) {
      final key = s['key'] ?? s['id'];
      if (key == 'quotation' && pipeline.quotation == null) return false;
      if (key == 'sales_order' && pipeline.salesOrder == null) return false;
      if (key == 'boq' && pipeline.boq == null) return false;
      if (key == 'factory_order' && pipeline.factoryOrder == null) return false;
      if (key == 'purchase_order' && pipeline.purchaseOrder == null) return false;
    }
    return true;
  }
  return pipeline.quotation != null &&
      pipeline.salesOrder != null &&
      pipeline.boq != null &&
      pipeline.factoryOrder != null &&
      pipeline.purchaseOrder != null;
}

class _PipelineDetailContent extends ConsumerWidget {
  final SalesPipeline pipeline;
  final UserRole? userRole;

  const _PipelineDetailContent({required this.pipeline, this.userRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final allStepsFilled = _checkAllStepsCompleted(pipeline);
    final isDealCompleted = pipeline.status == PipelineStatus.completed || allStepsFilled;

    // Automatically sync completed status to DB if all steps are completed
    if (allStepsFilled && pipeline.status != PipelineStatus.completed) {
      Future.microtask(() async {
        try {
          final db = ref.read(supabaseClientProvider);
          await db.from('sales_pipelines').update({
            'current_step': 'completed',
            'status': 'completed',
          }).eq('id', pipeline.id);
          ref.invalidate(pipelineDetailProvider(pipeline.id));
        } catch (_) {}
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Header card
          _HeaderCard(pipeline: pipeline),
          const SizedBox(height: 16),
          if (pipeline.status == PipelineStatus.suspended) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deal Suspended',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pipeline.quotation?.status == QuotationStatus.rejected
                              ? 'This deal has been suspended because the quotation was rejected by the Sales Head.'
                              : 'This deal has been suspended and cannot be proceeded further.',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (isDealCompleted) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '🔒 Deal 100% Complete',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'This deal is completed and locked from further edits.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Step tracker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deal Progress',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                StepTrackerWidget(
                  productId: pipeline.productId,
                  currentStep: isDealCompleted ? PipelineStep.completed : pipeline.currentStep,
                  stepsConfig: pipeline.stepsConfig,
                  pdfUrls: {
                    if (profile?.primaryRole == UserRole.admin || profile?.primaryRole == UserRole.sales || profile?.primaryRole == UserRole.salesHead) ...{
                      PipelineStep.quotation: pipeline.quotation != null ? 'available' : null,
                      PipelineStep.salesOrder: pipeline.salesOrder != null ? 'available' : null,
                      PipelineStep.boq: pipeline.boq != null ? 'available' : null,
                      PipelineStep.factoryOrder: pipeline.factoryOrder != null ? 'available' : null,
                      PipelineStep.purchaseOrder: pipeline.purchaseOrder != null ? 'available' : null,
                    } else ...{
                      if (profile?.primaryRole == UserRole.boq && pipeline.boq != null)
                        PipelineStep.boq: 'available',
                      if (profile?.primaryRole == UserRole.factory && pipeline.factoryOrder != null)
                        PipelineStep.factoryOrder: 'available',
                      if (profile?.primaryRole == UserRole.purchase && pipeline.purchaseOrder != null)
                        PipelineStep.purchaseOrder: 'available',
                    }
                  },
                  onStepTap: (step) async {
                    bool isAvailable = false;
                    switch (step) {
                      case PipelineStep.quotation:
                        isAvailable = pipeline.quotation != null;
                        break;
                      case PipelineStep.salesOrder:
                        isAvailable = pipeline.salesOrder != null;
                        break;
                      case PipelineStep.boq:
                        isAvailable = pipeline.boq != null;
                        break;
                      case PipelineStep.factoryOrder:
                        isAvailable = pipeline.factoryOrder != null;
                        break;
                      case PipelineStep.purchaseOrder:
                        isAvailable = pipeline.purchaseOrder != null;
                        break;
                      default:
                        break;
                    }
                    
                    final role = profile?.primaryRole;
                    final isAllowed = (role == UserRole.admin || role == UserRole.sales || role == UserRole.salesHead) ||
                        (role == UserRole.factory && step == PipelineStep.factoryOrder) ||
                        (role == UserRole.purchase && step == PipelineStep.purchaseOrder) ||
                        (role == UserRole.boq && step == PipelineStep.boq);

                    if (isAvailable && isAllowed) {
                      String? variant;
                      if (step == PipelineStep.salesOrder) {
                        variant = await showDialog<String>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Select PDF Variant'),
                            content: const Text(
                              'Choose the variant of Sales Order you want to view:',
                              style: TextStyle(fontFamily: 'Inter'),
                            ),
                            actions: () {
                              final currentRoles = ref.read(currentProfileProvider)?.roles ?? [UserRole.customer];
                              return [
                                if (currentRoles.contains(UserRole.admin) || currentRoles.contains(UserRole.manager) || currentRoles.contains(UserRole.sales) || currentRoles.contains(UserRole.salesHead))
                                  TextButton(onPressed: () => Navigator.pop(ctx, 'commercial'), child: const Text('Commercial (Main)')),
                                if (currentRoles.contains(UserRole.admin) || currentRoles.contains(UserRole.manager) || currentRoles.contains(UserRole.boq))
                                  TextButton(onPressed: () => Navigator.pop(ctx, 'technical'), child: const Text('Technical (BOQ)')),
                                if (currentRoles.contains(UserRole.admin) || currentRoles.contains(UserRole.manager) || currentRoles.contains(UserRole.factory))
                                  TextButton(onPressed: () => Navigator.pop(ctx, 'production'), child: const Text('Production (Factory)')),
                              ];
                            }(),
                          ),
                        );
                        if (variant == null) return;
                      }

                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      );
                      try {
                        final bytes = await _generatePdfOnTheFly(ref, pipeline, step, variant: variant);
                        if (context.mounted) Navigator.pop(context);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PdfPreviewScreen(
                                pdfBytes: bytes,
                                fileName: '${step.displayName}_${pipeline.id.substring(0, 8)}.pdf',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) Navigator.pop(context);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to open PDF: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Step action cards
          _StepActionCard(
            step: PipelineStep.quotation,
            pipeline: pipeline,
            userRole: userRole,
          ),
          const SizedBox(height: 10),
          _StepActionCard(
            step: PipelineStep.salesOrder,
            pipeline: pipeline,
            userRole: userRole,
          ),
          const SizedBox(height: 10),
          _StepActionCard(
            step: PipelineStep.boq,
            pipeline: pipeline,
            userRole: userRole,
          ),
          const SizedBox(height: 10),
          _StepActionCard(
            step: PipelineStep.factoryOrder,
            pipeline: pipeline,
            userRole: userRole,
          ),
          const SizedBox(height: 10),
          _StepActionCard(
            step: PipelineStep.purchaseOrder,
            pipeline: pipeline,
            userRole: userRole,
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          if (profile?.roles.contains(UserRole.admin) == true || profile?.roles.contains(UserRole.sales) == true || profile?.roles.contains(UserRole.manager) == true || profile?.roles.contains(UserRole.salesHead) == true) ...[
            _AmcActionCard(pipeline: pipeline),
            const SizedBox(height: 12),
            _WarrantyCardActionCard(pipeline: pipeline),
          ],
          const SizedBox(height: 40),
        ],
      ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final SalesPipeline pipeline;

  const _HeaderCard({required this.pipeline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pipeline.product?.name ?? 'Unknown Product',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (_checkAllStepsCompleted(pipeline) || pipeline.status == PipelineStatus.completed)
                      ? 'Completed (100%)'
                      : pipeline.status.displayName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (pipeline.customer != null) ...[
            Row(
              children: [
                const Icon(Icons.business_outlined,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  pipeline.customer!.companyName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                'Started ${DateFormat('dd MMM yyyy').format(pipeline.createdAt)}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
              if (pipeline.createdByProfile != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.person_outline,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  pipeline.createdByProfile!.fullName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StepActionCard extends ConsumerWidget {
  final PipelineStep step;
  final SalesPipeline pipeline;
  final UserRole? userRole;

  const _StepActionCard({
    required this.step,
    required this.pipeline,
    this.userRole,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStepIndex = pipeline.currentStep == PipelineStep.completed
        ? 5
        : pipeline.currentStep.stepIndex;
    final stepIndex = step.stepIndex;
    final isCompleted = stepIndex < currentStepIndex;
    final isActive = stepIndex == currentStepIndex;

    // Determine if this step has been completed/filled
    final bool hasData;
    switch (step) {
      case PipelineStep.quotation:
        hasData = pipeline.quotation != null;
        break;
      case PipelineStep.salesOrder:
        hasData = pipeline.salesOrder != null;
        break;
      case PipelineStep.boq:
        hasData = pipeline.boq != null;
        break;
      case PipelineStep.factoryOrder:
        hasData = pipeline.factoryOrder != null;
        break;
      case PipelineStep.purchaseOrder:
        hasData = pipeline.purchaseOrder != null;
        break;
      default:
        hasData = false;
    }

    final displayCompleted = (isCompleted && (step != PipelineStep.quotation || hasData)) || hasData;
    final displayActive = (isActive || (step == PipelineStep.quotation && !hasData)) && !hasData;

    final isLocked = !hasData && (stepIndex > currentStepIndex);
    final showActionSection = isActive || displayCompleted;
    
    // Post-Approval Lock and 100% Completion Lock
    final isAdmin = userRole == UserRole.admin;
    final is100PercentComplete = pipeline.status == PipelineStatus.completed;
    final isApproved = pipeline.quotation?.status == QuotationStatus.confirmed;
    
    bool isButtonEnabled = !isLocked;
    if (is100PercentComplete && !isAdmin) {
      isButtonEnabled = false; // Hide edit option
    } else if (isApproved && hasData && !isAdmin) {
      isButtonEnabled = false; // Disable editing of completed steps post-approval for standard roles
    }

    // Determine if this user can act on this step
    final canAct = _canUserAct();

    // PDF visibility: role-based
    bool isPdfVisible = false;
    final roles = ref.read(currentProfileProvider)?.roles ?? [UserRole.customer];
    if (roles.contains(UserRole.admin) || roles.contains(UserRole.manager)) {
      isPdfVisible = true;
    } else {
      switch (step) {
        case PipelineStep.quotation:
          isPdfVisible = roles.contains(UserRole.sales) || roles.contains(UserRole.salesHead);
          break;
        case PipelineStep.salesOrder:
          isPdfVisible = roles.contains(UserRole.sales) || roles.contains(UserRole.salesHead) || roles.contains(UserRole.boq) || roles.contains(UserRole.factory);
          break;
        case PipelineStep.boq:
          isPdfVisible = roles.contains(UserRole.boq) || roles.contains(UserRole.factory);
          break;
        case PipelineStep.factoryOrder:
          isPdfVisible = roles.contains(UserRole.factory);
          break;
        case PipelineStep.purchaseOrder:
          isPdfVisible = roles.contains(UserRole.purchase);
          break;
        default:
          isPdfVisible = false;
      }
    }

    Color borderColor;
    Color bgColor;
    IconData statusIcon;
    Color iconColor;

    if (displayCompleted) {
      borderColor = AppColors.stepCompleted;
      bgColor = AppColors.successLight;
      statusIcon = Icons.check_circle;
      iconColor = AppColors.stepCompleted;
    } else if (displayActive) {
      borderColor = AppColors.accent;
      bgColor = const Color(0xFFFFF8EE);
      statusIcon = Icons.radio_button_checked;
      iconColor = AppColors.accent;
    } else {
      borderColor = AppColors.border;
      bgColor = AppColors.surface;
      statusIcon = Icons.lock_outline;
      iconColor = AppColors.textDisabled;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: displayActive ? 1.5 : 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(statusIcon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getStepTitle(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isLocked
                          ? AppColors.textDisabled
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isLocked)
                  const Text(
                    'Locked',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textDisabled,
                    ),
                  ),
              ],
            ),
          ),
          if (showActionSection) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  if (hasData && isPdfVisible) ...[
                    InkWell(
                      onTap: () async {
                        bool isAvailable = false;
                        switch (step) {
                          case PipelineStep.quotation:
                            isAvailable = pipeline.quotation != null;
                            break;
                          case PipelineStep.salesOrder:
                            isAvailable = pipeline.salesOrder != null;
                            break;
                          case PipelineStep.boq:
                            isAvailable = pipeline.boq != null;
                            break;
                          case PipelineStep.factoryOrder:
                            isAvailable = pipeline.factoryOrder != null;
                            break;
                          case PipelineStep.purchaseOrder:
                            isAvailable = pipeline.purchaseOrder != null;
                            break;
                          default:
                            break;
                        }
                        if (!isAvailable) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PDF data not available for this step.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        String? variant;
                        if (step == PipelineStep.salesOrder) {
                          variant = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Select PDF Variant'),
                              content: const Text(
                                'Choose the variant of Sales Order you want to view:',
                                style: TextStyle(fontFamily: 'Inter'),
                              ),
                              actions: () {
                                final currentRoles = ref.read(currentProfileProvider)?.roles ?? [UserRole.customer];
                                return [
                                  if (currentRoles.contains(UserRole.admin) || currentRoles.contains(UserRole.manager) || currentRoles.contains(UserRole.sales) || currentRoles.contains(UserRole.salesHead))
                                    TextButton(onPressed: () => Navigator.pop(ctx, 'commercial'), child: const Text('Commercial (Main)')),
                                  if (currentRoles.contains(UserRole.admin) || currentRoles.contains(UserRole.manager) || currentRoles.contains(UserRole.boq))
                                    TextButton(onPressed: () => Navigator.pop(ctx, 'technical'), child: const Text('Technical (BOQ)')),
                                  if (currentRoles.contains(UserRole.admin) || currentRoles.contains(UserRole.manager) || currentRoles.contains(UserRole.factory))
                                    TextButton(onPressed: () => Navigator.pop(ctx, 'production'), child: const Text('Production (Factory)')),
                                ];
                              }(),
                            ),
                          );
                          if (variant == null) return;
                        } else if (step == PipelineStep.boq) {
                          variant = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Select BOQ Scope'),
                              content: const Text(
                                'Choose the version of BOQ PDF you want to view:',
                                style: TextStyle(fontFamily: 'Inter'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, 'all'),
                                  child: const Text('Main BOQ (All)'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, 'company'),
                                  child: const Text('Company Scope'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, 'customer'),
                                  child: const Text('Customer Scope'),
                                ),
                              ],
                            ),
                          );
                          if (variant == null) return;
                        }

                        if (!context.mounted) return;
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => const Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        );
                        try {
                          final bytes = await _generatePdfOnTheFly(ref, pipeline, step, variant: variant);
                          if (context.mounted) Navigator.pop(context);
                          if (context.mounted) {
                            String fileName = '${step.displayName}_${pipeline.id.substring(0, 8)}.pdf';
                            if (step == PipelineStep.boq) {
                              if (variant == 'company') {
                                fileName = 'BOQ_CompanyScope_${pipeline.id.substring(0, 8)}.pdf';
                              } else if (variant == 'customer') {
                                fileName = 'BOQ_CustomerScope_${pipeline.id.substring(0, 8)}.pdf';
                              }
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PdfPreviewScreen(
                                  pdfBytes: bytes,
                                  fileName: fileName,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) Navigator.pop(context);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to open PDF: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.picture_as_pdf,
                            color: AppColors.info,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'PDF Available',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: AppColors.info,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (canAct)
                    ElevatedButton(
                      onPressed: isButtonEnabled ? () => _navigate(context) : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                      ),
                      child: Text(
                        hasData ? 'View / Edit' : 'Fill In',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (step) {
      case PipelineStep.quotation:
        return 'Step 1 — Quotation';
      case PipelineStep.salesOrder:
        return 'Step 2 — Sales Order';
      case PipelineStep.boq:
        return 'Step 3 — Bill of Quantities (BOQ)';
      case PipelineStep.factoryOrder:
        return 'Step 4 — Factory Order';
      case PipelineStep.purchaseOrder:
        return 'Step 5 — Material Requisition';
      case PipelineStep.completed:
        return 'Completed';
    }
  }

  bool _canUserAct() {
    if (userRole == null) return false;
    if (pipeline.status == PipelineStatus.suspended) return false;
    switch (step) {
      case PipelineStep.quotation:
      case PipelineStep.salesOrder:
        return userRole == UserRole.sales || userRole == UserRole.admin || userRole == UserRole.salesHead;
      case PipelineStep.boq:
        return userRole == UserRole.boq ||
            userRole == UserRole.sales ||
            userRole == UserRole.admin ||
            userRole == UserRole.salesHead;
      case PipelineStep.factoryOrder:
        return userRole == UserRole.factory ||
            userRole == UserRole.sales ||
            userRole == UserRole.admin ||
            userRole == UserRole.salesHead;
      case PipelineStep.purchaseOrder:
        return userRole == UserRole.purchase || userRole == UserRole.admin || userRole == UserRole.salesHead;
      case PipelineStep.completed:
        return false;
    }
  }

  void _navigate(BuildContext context) {
    switch (step) {
      case PipelineStep.quotation:
        context.push(
          AppRoutes.quotationForm.replaceAll(':id', pipeline.id),
        );
        break;
      case PipelineStep.salesOrder:
        context.push(
          AppRoutes.salesOrderForm.replaceAll(':id', pipeline.id),
        );
        break;
      case PipelineStep.boq:
        context.push(AppRoutes.boqForm.replaceAll(':id', pipeline.id));
        break;
      case PipelineStep.factoryOrder:
        context.push(
          AppRoutes.factoryOrderForm.replaceAll(':id', pipeline.id),
        );
        break;
      case PipelineStep.purchaseOrder:
        context.push(
          AppRoutes.purchaseOrderForm.replaceAll(':id', pipeline.id),
        );
        break;
      case PipelineStep.completed:
        break;
    }
  }
}

Future<Map<String, dynamic>> _fetchTemplateConfig(WidgetRef ref, String docType) async {
  try {
    final supabase = ref.read(supabaseClientProvider);
    final templateData = await supabase
        .from('pdf_templates')
        .select()
        .eq('document_type', docType)
        .single();
    return (templateData)['template_config'] as Map<String, dynamic>;
  } catch (_) {
    return {
      'company_name': 'IZYHEAT',
      'company_address': 'IZYHEAT Office, India',
      'company_phone': '+91 99999 99999',
      'company_email': 'info@izyheat.com',
      'company_gst': '27AAAAA1111A1Z1',
      'footer_text': 'Thank you for your business.',
      'terms_default': '1. Payment: 50% advance, 50% before delivery.\n2. Delivery: 2-3 weeks.',
    };
  }
}

Future<Uint8List> _generatePdfOnTheFly(WidgetRef ref, SalesPipeline pipeline, PipelineStep step, {String? variant}) async {
  final supabase = ref.read(supabaseClientProvider);

  // Safely resolve customer and product with fallbacks in case of RLS filters or missing relations
  Customer customer = pipeline.customer ?? Customer(
    id: pipeline.customerId,
    companyName: 'Default Customer',
    contactPerson: 'Contact Person',
    phone: '',
    email: '',
    createdBy: '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  if (pipeline.customer == null) {
    try {
      final customerData = await supabase
          .from('customers')
          .select()
          .eq('id', pipeline.customerId)
          .single();
      customer = Customer.fromJson(customerData);
    } catch (_) {}
  }

  Product product = pipeline.product ?? Product(
    id: pipeline.productId,
    name: 'Default Product',
    category: 'HVAC',
    baseSpecs: const ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
    isActive: true,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  if (pipeline.product == null) {
    try {
      final productData = await supabase
          .from('products')
          .select()
          .eq('id', pipeline.productId)
          .single();
      product = Product.fromJson(productData);
    } catch (_) {}
  }

  switch (step) {
    case PipelineStep.quotation:
      if (pipeline.quotation == null) throw Exception('Quotation data not found');
      final templateConfig = await _fetchTemplateConfig(ref, 'quotation');
      return await PdfService.generateQuotationPdf(
        quotation: pipeline.quotation!,
        customer: customer,
        product: product,
        templateConfig: templateConfig,
      );
    case PipelineStep.salesOrder:
      if (pipeline.salesOrder == null) throw Exception('Sales Order data not found');
      final templateConfig = await _fetchTemplateConfig(ref, 'sales_order');
      return await PdfService.generateSalesOrderPdf(
        salesOrder: pipeline.salesOrder!,
        customer: customer,
        product: product,
        variant: variant ?? 'commercial',
        templateConfig: templateConfig,
      );
    case PipelineStep.boq:
      if (pipeline.boq == null) throw Exception('BOQ data not found');
      final templateConfig = await _fetchTemplateConfig(ref, 'boq');
      if (pipeline.quotation == null) throw Exception('Quotation data not found for BOQ reference');
      return await PdfService.generateBoqPdf(
        boq: pipeline.boq!,
        customer: customer,
        product: product,
        quotation: pipeline.quotation!,
        templateConfig: templateConfig,
        scopeFilter: variant ?? 'all',
      );
    case PipelineStep.factoryOrder:
      if (pipeline.factoryOrder == null) throw Exception('Factory order data not found');
      final templateConfig = await _fetchTemplateConfig(ref, 'factory_order');
      return await PdfService.generateFactoryOrderPdf(
        factoryOrder: pipeline.factoryOrder!,
        customer: customer,
        product: product,
        templateConfig: templateConfig,
      );
    case PipelineStep.purchaseOrder:
      if (pipeline.purchaseOrder == null) throw Exception('Material Requisition data not found');
      final templateConfig = await _fetchTemplateConfig(ref, 'purchase_order');
      return await PdfService.generatePurchaseOrderPdf(
        purchaseOrder: pipeline.purchaseOrder!,
        customer: customer,
        product: product,
        templateConfig: templateConfig,
      );
    default:
      throw Exception('Invalid step');
  }
}

class _AmcActionCard extends ConsumerWidget {
  final SalesPipeline pipeline;

  const _AmcActionCard({required this.pipeline});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pipeline.status != PipelineStatus.completed && !_checkAllStepsCompleted(pipeline)) {
      return const SizedBox.shrink();
    }

    final amcAsync = ref.watch(amcForCustomerProductProvider((
      customerId: pipeline.customerId,
      productId: pipeline.productId,
    )));

    return amcAsync.when(
      data: (amc) {
        if (amc == null) {
          // No AMC at all -> Avail AMC
          return _buildAmcCard(
            context,
            title: 'Annual Maintenance Contract (AMC)',
            subtitle: 'This pipeline is completed. Avail AMC to manage scheduled maintenance, visits, and renewals for this product.',
            buttonText: 'Avail AMC',
            icon: Icons.shield_outlined,
            color: AppColors.primary,
            onPressed: () {
              context.push(
                '/amc/setup?customerId=${pipeline.customerId}&productId=${pipeline.productId}&pipelineId=${pipeline.id}',
              );
            },
          );
        }

        if (amc.status == AmcContractStatus.interested) {
          // Interested -> Finalize AMC Contract
          return _buildAmcCard(
            context,
            title: 'Annual Maintenance Contract (AMC)',
            subtitle: 'Customer expressed interest in AMC during quotation. Complete and activate the contract now.',
            buttonText: 'Finalize AMC Contract',
            icon: Icons.assignment_turned_in_outlined,
            color: Colors.amber[800]!,
            onPressed: () {
              context.push('/amc/setup?amcId=${amc.id}');
            },
          );
        }

        if (amc.status == AmcContractStatus.pendingSetup) {
          // Pending setup -> Complete/Activate
          return _buildAmcCard(
            context,
            title: 'Annual Maintenance Contract (AMC)',
            subtitle: 'AMC has been requested post-sale. Complete the terms, amount, and schedule visits to activate.',
            buttonText: 'Complete Setup',
            icon: Icons.assignment_turned_in_outlined,
            color: Colors.amber[800]!,
            onPressed: () {
              context.push('/amc/setup?amcId=${amc.id}');
            },
          );
        }

        // Active / Expiring / Expired / Cancelled
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: amc.status.color),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Annual Maintenance Contract (AMC)',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: amc.status.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      amc.status.displayName,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: amc.status.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Contract Number: ${amc.amcNumber}\nPeriod: ${amc.startDate != null ? DateFormat('dd MMM yyyy').format(amc.startDate!) : '-'} to ${amc.endDate != null ? DateFormat('dd MMM yyyy').format(amc.endDate!) : '-'}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/amc/details/${amc.id}'),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View AMC Contract'),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildAmcCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String buttonText,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                  label: Text(buttonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarrantyCardActionCard extends StatelessWidget {
  final SalesPipeline pipeline;
  const _WarrantyCardActionCard({required this.pipeline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_membership, color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Official Warranty Card & Certificate',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate, activate, or download official Warranty Certificate for this deal.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => context.push('/warranty/${pipeline.id}?customerId=${pipeline.customerId}'),
            icon: const Icon(Icons.verified_outlined, size: 16),
            label: const Text('Open Warranty Card'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 42),
            ),
          ),
        ],
      ),
    );
  }
}
