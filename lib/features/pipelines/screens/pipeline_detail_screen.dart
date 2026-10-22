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
import '../../quotation/providers/quotation_provider.dart';
import '../../sales_order/widgets/delivery_challan_modal.dart';
import '../../quotation_generator/config/qg_noc_flags.dart';
import '../../quotation_generator/data/qg_noc_repository.dart';
import '../../quotation_generator/models/qg_noc_document.dart';
import '../../quotation_generator/models/qg_noc_builder_state.dart';
import '../../quotation_generator/services/pdf_noc_builder.dart';
import '../../quotation_generator/services/qg_noc_extractor.dart';
import '../widgets/work_progress_box.dart';

class PipelineDetailScreen extends ConsumerWidget {
  final String pipelineId;

  const PipelineDetailScreen({super.key, required this.pipelineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(singleDealStreamProvider(pipelineId));
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
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deal unlocked')));
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
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deal marked 100% Complete!'), backgroundColor: AppColors.success),
                    );
                  }
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
            tooltip: 'Refresh Deal',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text('Refreshing deal...'),
                    ],
                  ),
                  duration: Duration(milliseconds: 600),
                ),
              );
              try {
                ref.invalidate(pipelineDetailProvider(pipelineId));
                await ref.read(pipelineDetailProvider(pipelineId).future);
                ref.read(pipelinesNotifierProvider.notifier).load(refresh: true);
                ref.invalidate(pendingQuotationsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Deal refreshed'),
                      duration: Duration(seconds: 1),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Refresh failed: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Breadcrumbs(
            items: [
              BreadcrumbItem(
                label: 'Dashboard',
                route: profile != null
                    ? getRoleHome(profile.primaryRole)
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

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(pipelineDetailProvider(pipeline.id));
        await ref.read(pipelineDetailProvider(pipeline.id).future);
        ref.read(pipelinesNotifierProvider.notifier).load(refresh: true);
        ref.invalidate(pendingQuotationsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
          // Approval Alert Banner (when quotation pending approval)
          if (pipeline.quotation?.status == QuotationStatus.pendingApproval) ...[
            _ApprovalAlertBanner(
              pipeline: pipeline,
              canApprove: profile?.roles.any((r) => r.canApproveQuotations) ?? false,
            ),
            const SizedBox(height: 16),
          ]
          // Rejection Feedback Banner (when quotation rejected)
          else if (pipeline.quotation?.status == QuotationStatus.rejected) ...[
            _RejectionFeedbackBanner(pipeline: pipeline),
            const SizedBox(height: 16),
          ]
          // Suspended Banner (only for non-rejection suspension)
          else if (pipeline.status == PipelineStatus.suspended) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deal Suspended',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'This deal has been suspended and cannot be proceeded further.',
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
          // Work Progress Box
          WorkProgressBox(pipeline: pipeline),
          const SizedBox(height: 16),
          // Step tracker (Deal Progress)
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
                      PipelineStep.quotation: (pipeline.quotation != null && ((profile?.roles.any((r) => r.canApproveQuotations) ?? false) || pipeline.quotation?.status == QuotationStatus.confirmed)) ? 'available' : null,
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
                    final canApproveQuotes = profile?.roles.any((r) => r.canApproveQuotations) ?? false;
                    if (step == PipelineStep.quotation && !canApproveQuotes && pipeline.quotation?.status != QuotationStatus.confirmed) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Quotation PDF is locked until approved by Sales Head / Admin.'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                      return;
                    }

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
                    
                    final userRoles = profile?.roles ?? (profile != null ? [profile.primaryRole] : <UserRole>[]);
                    final isAllowed = (userRoles.contains(UserRole.admin) || userRoles.contains(UserRole.sales) || userRoles.contains(UserRole.salesHead) || userRoles.contains(UserRole.manager)) ||
                        (userRoles.contains(UserRole.factory) && step == PipelineStep.factoryOrder) ||
                        (userRoles.contains(UserRole.purchase) && step == PipelineStep.purchaseOrder) ||
                        (userRoles.contains(UserRole.boq) && step == PipelineStep.boq);

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
                                if (currentRoles.contains(UserRole.admin) || currentRoles.contains(UserRole.manager) || currentRoles.contains(UserRole.sales) || currentRoles.contains(UserRole.salesHead))
                                  TextButton(onPressed: () => Navigator.pop(ctx, 'challan'), child: const Text('Delivery Challan')),
                              ];
                            }(),
                          ),
                        );
                        if (variant == null) return;
                        if (variant == 'challan') {
                          if (!context.mounted) return;
                          if (pipeline.customer != null) {
                            DeliveryChallanModal.show(
                              context,
                              pipelineId: pipeline.id,
                              customer: pipeline.customer!,
                            );
                          }
                          return;
                        }
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
                                fileName: _getStepPdfFileName(pipeline, step, variant: variant),
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
          if (isDealCompleted && (profile?.roles.contains(UserRole.admin) == true || profile?.roles.contains(UserRole.sales) == true || profile?.roles.contains(UserRole.manager) == true || profile?.roles.contains(UserRole.salesHead) == true)) ...[
            _AmcActionCard(pipeline: pipeline),
            const SizedBox(height: 12),
            _WarrantyCardActionCard(pipeline: pipeline),
            if (kQgNocEnabled) ...[
              const SizedBox(height: 12),
              _NocActionCard(pipeline: pipeline),
            ],
          ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  ),
);
  }
}

String _getDealProductName(SalesPipeline pipeline) {
  if (pipeline.quotation != null && pipeline.quotation!.lineItems.isNotEmpty) {
    final desc = pipeline.quotation!.lineItems.first.description.trim();
    if (desc.isNotEmpty) {
      return desc.replaceAll(' - ', ' • ');
    }
  }
  return pipeline.product?.name ?? 'Standard System';
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
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _getDealProductName(pipeline),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final isPendingApproval = pipeline.quotation?.status == QuotationStatus.pendingApproval;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPendingApproval ? const Color(0xFFD97706) : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPendingApproval
                          ? '⚠️ Needs Approval'
                          : ((_checkAllStepsCompleted(pipeline) || pipeline.status == PipelineStatus.completed)
                              ? 'Completed (100%)'
                              : pipeline.status.displayName),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
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

    final isQuotationApproved = pipeline.quotation?.status == QuotationStatus.confirmed;
    final isQuotationPending = pipeline.quotation?.status == QuotationStatus.pendingApproval;
    final isQuotationRejected = pipeline.quotation?.status == QuotationStatus.rejected;

    // Subsequent steps are strictly locked if quotation is not confirmed
    final isStepBlockedByApproval = step.stepIndex > PipelineStep.quotation.stepIndex && !isQuotationApproved;
    final isLocked = (!hasData && (stepIndex > currentStepIndex)) || isStepBlockedByApproval;

    // A step is only visually "completed" if it actually has data filled in
    final displayCompleted = hasData && (step != PipelineStep.quotation || !isQuotationPending);
    final displayActive = !hasData && !isLocked && (isActive || isCompleted);

    // Show action section when: the step is the current active step OR step has data (completed)
    // Or when the step is earlier than current (so Sales Head/Admin can fill missing steps)
    final showActionSection = !isLocked && (isActive || isCompleted || hasData);
    
    // Post-Approval Lock and 100% Completion Lock
    final currentRoles = ref.watch(currentProfileProvider)?.roles ?? [];
    final isAdmin = currentRoles.contains(UserRole.admin);
    final isSalesHead = currentRoles.contains(UserRole.salesHead);
    final is100PercentComplete = pipeline.status == PipelineStatus.completed;
    final canApproveQuotations = currentRoles.any((r) => r.canApproveQuotations);
    
    bool isButtonEnabled = !isLocked;
    String buttonText = hasData ? 'View / Edit' : 'Fill In';

    if (step == PipelineStep.quotation) {
      if (isQuotationPending) {
        if (!canApproveQuotations) {
          isButtonEnabled = false;
          buttonText = 'Under Review';
        } else {
          buttonText = 'Review Quotation';
        }
      } else if (isQuotationRejected) {
        isButtonEnabled = true;
        buttonText = 'Edit & Resubmit';
      } else if (isQuotationApproved) {
        if (!isAdmin) {
          isButtonEnabled = false;
          buttonText = 'Approved (Locked)';
        }
      }
    } else {
      if (is100PercentComplete && !isAdmin && !isSalesHead) {
        isButtonEnabled = false;
      }
    }

    // Determine if this user can act on this step
    final canAct = _canUserAct(ref);

    // PDF visibility: role-based
    bool isPdfVisible = false;
    final roles = ref.read(currentProfileProvider)?.roles ?? [UserRole.customer];
    if (roles.contains(UserRole.admin) || roles.contains(UserRole.manager)) {
      isPdfVisible = true;
    } else {
      switch (step) {
        case PipelineStep.quotation:
          // Sales executive cannot view PDF before quotation approval
          if (roles.contains(UserRole.sales) && !canApproveQuotations) {
            isPdfVisible = isQuotationApproved;
          } else {
            isPdfVisible = roles.contains(UserRole.sales) || roles.contains(UserRole.salesHead);
          }
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

    if (step == PipelineStep.quotation && isQuotationPending) {
      borderColor = const Color(0xFFF59E0B);
      bgColor = const Color(0xFFFFFDF5);
      statusIcon = Icons.hourglass_top_rounded;
      iconColor = const Color(0xFFD97706);
    } else if (step == PipelineStep.quotation && isQuotationRejected) {
      borderColor = const Color(0xFFFCA5A5);
      bgColor = const Color(0xFFFFF1F2);
      statusIcon = Icons.error_outline_rounded;
      iconColor = const Color(0xFFEF4444);
    } else if (displayCompleted) {
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(statusIcon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _getStepTitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: isLocked
                                ? AppColors.textDisabled
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (step == PipelineStep.quotation && isQuotationPending) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: const Text(
                            'Pending Approval',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ] else if (step == PipelineStep.quotation && isQuotationRejected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.error),
                          ),
                          child: const Text(
                            'Changes Requested',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isLocked)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      isStepBlockedByApproval ? 'Requires Approval' : 'Locked',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: AppColors.textDisabled,
                      ),
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
                                  if (currentRoles.contains(UserRole.admin) || currentRoles.contains(UserRole.manager) || currentRoles.contains(UserRole.sales) || currentRoles.contains(UserRole.salesHead))
                                    TextButton(onPressed: () => Navigator.pop(ctx, 'challan'), child: const Text('Delivery Challan')),
                                ];
                              }(),
                            ),
                          );
                          if (variant == null) return;
                          if (variant == 'challan') {
                            if (!context.mounted) return;
                            if (pipeline.customer != null) {
                              DeliveryChallanModal.show(
                                context,
                                pipelineId: pipeline.id,
                                customer: pipeline.customer!,
                              );
                            }
                            return;
                          }
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
                            final fileName = _getStepPdfFileName(pipeline, step, variant: variant);
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
                  if (step == PipelineStep.quotation && isQuotationPending && canApproveQuotations) ...[
                    OutlinedButton(
                      onPressed: () => _navigate(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Text(
                        'View Form',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showReviewAndApproveModal(context, ref, pipeline),
                      icon: const Icon(Icons.rate_review_outlined, size: 14),
                      label: const Text(
                        'Review & Approve',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ] else if (canAct) ...[
                    ElevatedButton(
                      onPressed: isButtonEnabled ? () => _navigate(context) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (step == PipelineStep.quotation && isQuotationRejected)
                            ? const Color(0xFFEA580C)
                            : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
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

  bool _canUserAct(WidgetRef ref) {
    final roles = ref.read(currentProfileProvider)?.roles ?? [];
    if (roles.isEmpty) return false;
    if (pipeline.status == PipelineStatus.suspended && pipeline.quotation?.status != QuotationStatus.rejected) return false;

    // Manager role has strictly read-only permission (cannot act on steps)
    if (roles.contains(UserRole.manager) && !roles.contains(UserRole.admin)) {
      return false;
    }

    bool hasRole(UserRole r) => roles.contains(r);
    
    if (hasRole(UserRole.admin) || hasRole(UserRole.salesHead)) return true;

    switch (step) {
      case PipelineStep.quotation:
      case PipelineStep.salesOrder:
        return hasRole(UserRole.sales);
      case PipelineStep.boq:
        return hasRole(UserRole.boq);
      case PipelineStep.factoryOrder:
        return hasRole(UserRole.factory);
      case PipelineStep.purchaseOrder:
        return hasRole(UserRole.purchase);
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

String _getStepPdfFileName(SalesPipeline pipeline, PipelineStep step, {String? variant}) {
  switch (step) {
    case PipelineStep.quotation:
      if (pipeline.quotation?.quotationNumber != null && pipeline.quotation!.quotationNumber.isNotEmpty) {
        return '${pipeline.quotation!.quotationNumber.replaceAll('/', '_')}.pdf';
      }
      break;
    case PipelineStep.salesOrder:
      if (pipeline.salesOrder?.salesOrderNumber != null && pipeline.salesOrder!.salesOrderNumber.isNotEmpty) {
        final base = pipeline.salesOrder!.salesOrderNumber.replaceAll('/', '_');
        return variant == 'production' ? '${base}_Production.pdf' : '$base.pdf';
      }
      break;
    case PipelineStep.boq:
      if (pipeline.boq?.boqNumber != null && pipeline.boq!.boqNumber.isNotEmpty) {
        final base = pipeline.boq!.boqNumber.replaceAll('/', '_');
        if (variant == 'company') return '${base}_CompanyScope.pdf';
        if (variant == 'customer') return '${base}_CustomerScope.pdf';
        return '$base.pdf';
      }
      break;
    case PipelineStep.factoryOrder:
      if (pipeline.factoryOrder?.orderNumber != null && pipeline.factoryOrder!.orderNumber.isNotEmpty) {
        return '${pipeline.factoryOrder!.orderNumber.replaceAll('/', '_')}.pdf';
      }
      break;
    case PipelineStep.purchaseOrder:
      if (pipeline.purchaseOrder?.poNumber != null && pipeline.purchaseOrder!.poNumber.isNotEmpty) {
        return '${pipeline.purchaseOrder!.poNumber.replaceAll('/', '_')}.pdf';
      }
      break;
    default:
      break;
  }
  return '${step.displayName}_${pipeline.id.substring(0, 8)}.pdf';
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
                      color: amc.status.color.withValues(alpha: 0.1),
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
    if (pipeline.status != PipelineStatus.completed && !_checkAllStepsCompleted(pipeline)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
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

Future<Map<String, dynamic>> _fetchLiveQuotationInfo(
  WidgetRef ref,
  SalesPipeline pipeline,
) async {
  try {
    final supabase = ref.read(supabaseClientProvider);
    Map<String, dynamic>? qData;
    if (pipeline.quotation?.id != null) {
      final res = await supabase
          .from('quotations')
          .select()
          .eq('id', pipeline.quotation!.id)
          .maybeSingle();
      if (res != null) qData = res;
    }
    if (qData == null) {
      final res = await supabase
          .from('quotations')
          .select()
          .eq('pipeline_id', pipeline.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null) qData = res;
    }

    String productName = '';
    final rawLines = (qData?['line_items'] as List?) ?? [];
    if (rawLines.isNotEmpty) {
      final first = rawLines.first;
      if (first is Map) {
        productName = (first['description'] ?? first['item_name'] ?? first['name'])?.toString().trim() ?? '';
      }
    }
    if (productName.isEmpty && pipeline.quotation != null && pipeline.quotation!.lineItems.isNotEmpty) {
      productName = pipeline.quotation!.lineItems.first.description.trim();
    }
    if (productName.isEmpty) {
      productName = pipeline.product?.name ?? '';
    }
    if (productName.isEmpty && pipeline.productId.isNotEmpty) {
      final pRes = await supabase
          .from('products')
          .select('name')
          .eq('id', pipeline.productId)
          .maybeSingle();
      if (pRes != null && pRes['name'] != null) {
        productName = pRes['name'].toString();
      }
    }

    String customerName = pipeline.customer?.companyName ??
        pipeline.customer?.customerName ??
        '';
    if (customerName.isEmpty && pipeline.customerId.isNotEmpty) {
      final cRes = await supabase
          .from('customers')
          .select('company_name, customer_name')
          .eq('id', pipeline.customerId)
          .maybeSingle();
      if (cRes != null) {
        customerName = (cRes['company_name'] as String?)?.isNotEmpty == true
            ? cRes['company_name']
            : (cRes['customer_name'] ?? '');
      }
    }

    final grandTotal = (qData?['grand_total'] as num?)?.toDouble() ??
        (pipeline.quotation?.grandTotal ?? 0.0);
    final quoteNumber = qData?['quotation_number']?.toString() ??
        pipeline.quotation?.quotationNumber ??
        '';
    final salesman = qData?['salesman']?.toString() ??
        pipeline.quotation?.salesman ??
        pipeline.createdByProfile?.fullName ??
        'Sales Executive';

    return {
      'quotationId': qData?['id']?.toString() ?? pipeline.quotation?.id,
      'productName': productName.isNotEmpty ? productName : 'Standard System',
      'customerName': customerName.isNotEmpty ? customerName : 'Customer',
      'quoteNumber': quoteNumber,
      'grandTotal': grandTotal,
      'salesman': salesman,
    };
  } catch (_) {
    return {
      'quotationId': pipeline.quotation?.id,
      'productName': _getDealProductName(pipeline),
      'customerName': pipeline.customer?.companyName ??
          pipeline.customer?.customerName ??
          'Customer',
      'quoteNumber': pipeline.quotation?.quotationNumber ?? '',
      'grandTotal': pipeline.quotation?.grandTotal ?? 0.0,
      'salesman': pipeline.quotation?.salesman ??
          pipeline.createdByProfile?.fullName ??
          'Sales Executive',
    };
  }
}

class _ApprovalAlertBanner extends ConsumerWidget {
  final SalesPipeline pipeline;
  final bool canApprove;

  const _ApprovalAlertBanner({
    required this.pipeline,
    required this.canApprove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchLiveQuotationInfo(ref, pipeline),
      initialData: {
        'quotationId': pipeline.quotation?.id,
        'productName': _getDealProductName(pipeline),
        'customerName': pipeline.customer?.companyName ??
            pipeline.customer?.customerName ??
            'Customer',
        'quoteNumber': pipeline.quotation?.quotationNumber ?? '',
        'grandTotal': pipeline.quotation?.grandTotal ?? 0.0,
        'salesman': pipeline.quotation?.salesman ??
            pipeline.createdByProfile?.fullName ??
            'Sales Executive',
      },
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final submitter = data['salesman']?.toString() ?? 'Sales Executive';
        final productName = data['productName']?.toString() ?? 'Standard System';
        final customerName = data['customerName']?.toString() ?? 'Customer';
        final quoteNumber = data['quoteNumber']?.toString() ?? '';
        final grandTotal = (data['grandTotal'] as num?)?.toDouble() ?? 0.0;
        final totalStr = '₹${NumberFormat('#,##,##0.00', 'en_IN').format(grandTotal)}';

        final quotation = pipeline.quotation;
        final dateStr = quotation != null
            ? DateFormat('dd MMM yyyy, hh:mm a').format(quotation.createdAt)
            : '';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pending_actions_rounded,
                        color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Approval Required: Quotation Review',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Submitted by $submitter${dateStr.isNotEmpty ? " • $dateStr" : ""}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Pending Approval',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Executive Detail Summary Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Customer',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            )),
                        Flexible(
                          child: Text(
                            customerName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Product',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            )),
                        Flexible(
                          child: Text(
                            productName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    if (quoteNumber.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Quotation #',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              )),
                          Text(
                            quoteNumber,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Quotation Value',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            )),
                        Text(
                          totalStr,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (canApprove) ...[
                const Text(
                  'Please review the quotation details and pricing terms before advancing the pipeline to Sales Order.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF78350F)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _executeApprovalFlow(context, ref, pipeline, isApprove: false),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reject / Request Changes'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _executeApprovalFlow(context, ref, pipeline, isApprove: true),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Approve Quotation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: const [
                    Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFFB45309)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Waiting for Admin / Sales Head approval. Quotation cannot proceed to Sales Order until approved.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RejectionFeedbackBanner extends StatelessWidget {
  final SalesPipeline pipeline;

  const _RejectionFeedbackBanner({required this.pipeline});

  @override
  Widget build(BuildContext context) {
    final remarks = pipeline.notes ?? 'Changes were requested by the reviewer.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_return_rounded, color: Color(0xFFEA580C), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Changes Requested by Approver',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9A3412),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  remarks,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFFC2410C),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'The sales executive can edit the quotation step below and resubmit it for approval.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showReviewAndApproveModal(
  BuildContext context,
  WidgetRef ref,
  SalesPipeline pipeline,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return FutureBuilder<Map<String, dynamic>>(
        future: _fetchLiveQuotationInfo(ref, pipeline),
        initialData: {
          'quotationId': pipeline.quotation?.id,
          'productName': _getDealProductName(pipeline),
          'customerName': pipeline.customer?.companyName ??
              pipeline.customer?.customerName ??
              'Customer',
          'quoteNumber': pipeline.quotation?.quotationNumber ?? '',
          'grandTotal': pipeline.quotation?.grandTotal ?? 0.0,
          'salesman': pipeline.quotation?.salesman ??
              pipeline.createdByProfile?.fullName ??
              'Sales Executive',
        },
        builder: (context, snapshot) {
          final data = snapshot.data ?? {};
          final cust = data['customerName']?.toString() ?? 'Customer';
          final prodName = data['productName']?.toString() ?? 'Standard System';
          final salesman = data['salesman']?.toString() ?? 'Sales Executive';
          final quoteNum = data['quoteNumber']?.toString() ?? '';
          final grandTotal = (data['grandTotal'] as num?)?.toDouble() ?? 0.0;
          final totalStr = '₹${NumberFormat('#,##,##0.00', 'en_IN').format(grandTotal)}';

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
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Customer',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          Flexible(
                            child: Text(cust,
                                style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Product',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          Flexible(
                            child: Text(prodName,
                                style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      if (quoteNum.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Quotation #',
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            Text(quoteNum,
                                style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Salesperson',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          Text(salesman,
                              style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          Text(totalStr,
                              style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _executeApprovalFlow(context, ref, pipeline, isApprove: false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Reject / Request Changes'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _executeApprovalFlow(context, ref, pipeline, isApprove: true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Approve Quotation'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _executeApprovalFlow(
  BuildContext context,
  WidgetRef ref,
  SalesPipeline pipeline, {
  required bool isApprove,
}) async {
  String? quotationId = pipeline.quotation?.id;
  if (quotationId == null) {
    try {
      final res = await ref
          .read(supabaseClientProvider)
          .from('quotations')
          .select('id')
          .eq('pipeline_id', pipeline.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res != null) {
        quotationId = res['id']?.toString();
      }
    } catch (_) {}
  }
  if (quotationId == null) return;
  if (!context.mounted) return;

  String? rejectionRemark;
  if (!isApprove) {
    final controller = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reject Quotation / Request Changes',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide the reason / remarks for rejection. The sales executive will see this and will be able to edit and resubmit.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason / Remarks',
                hintText: 'e.g. Please update discount terms to 5%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a rejection reason.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (proceed != true) return;
    rejectionRemark = controller.text.trim();
  }

  try {
    final supabase = ref.read(supabaseClientProvider);
    final profile = ref.read(currentProfileProvider);
    final currentUserId = supabase.auth.currentUser!.id;

    if (isApprove) {
      await supabase.from('quotations').update({
        'status': 'confirmed',
        'approved_by': currentUserId,
        'approved_at': DateTime.now().toIso8601String(),
        'confirmed_by': currentUserId,
        'confirmed_at': DateTime.now().toIso8601String(),
      }).eq('id', quotationId);

      await supabase.from('sales_pipelines').update({
        'current_step': 'sales_order',
        'status': 'in_progress',
        'notes': 'Quotation approved by ${profile?.fullName ?? "Sales Head / Admin"}.',
      }).eq('id', pipeline.id);
    } else {
      await supabase.from('quotations').update({
        'status': 'rejected',
        'approved_by': currentUserId,
        'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', quotationId);

      await supabase.from('sales_pipelines').update({
        'status': 'in_progress',
        'notes': 'Changes requested: $rejectionRemark',
      }).eq('id', pipeline.id);
    }

    ref.invalidate(pipelineDetailProvider(pipeline.id));
    ref.invalidate(pipelinesNotifierProvider);
    ref.invalidate(pendingQuotationsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isApprove
              ? '✓ Quotation approved successfully'
              : 'Quotation rejected and feedback saved.'),
          backgroundColor: isApprove ? AppColors.success : AppColors.error,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}

class _NocActionCard extends ConsumerStatefulWidget {
  final SalesPipeline pipeline;
  const _NocActionCard({required this.pipeline});

  @override
  ConsumerState<_NocActionCard> createState() => _NocActionCardState();
}

class _NocActionCardState extends ConsumerState<_NocActionCard> {
  List<QgNocDocument>? _nocDocs;
  bool _loading = true;
  bool _isInstallationComplete = false;

  @override
  void initState() {
    super.initState();
    _fetchNocs();
  }

  @override
  void didUpdateWidget(covariant _NocActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pipeline.id != widget.pipeline.id ||
        oldWidget.pipeline.updatedAt != widget.pipeline.updatedAt ||
        oldWidget.pipeline.notes != widget.pipeline.notes) {
      _fetchNocs();
    }
  }

  Future<void> _fetchNocs() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final docsFuture = QgNocRepository.listNocs(dealId: widget.pipeline.id);
      final instFuture = WorkProgressService.isInstallationComplete(
        supabase,
        widget.pipeline.customerId,
        widget.pipeline.id,
      );

      final results = await Future.wait([docsFuture, instFuture]);
      final docs = results[0] as List<QgNocDocument>;
      final isInstDone = results[1] as bool;

      if (mounted) {
        setState(() {
          _nocDocs = docs;
          _isInstallationComplete = isInstDone;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _viewNocPdf(QgNocDocument doc) async {
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
        confirmations: doc.confirmations.isNotEmpty
            ? doc.confirmations
            : (await QgNocRepository.instance.getProfileForProduct(doc.productName))
                .confirmationLines
                .map((l) => l.replaceAll('{Product}', doc.productName))
                .toList(),
        closingSentence: doc.closingSentence ??
            'This NOC is issued upon request for installation and operation of the ${doc.productName} System.',
        wordingMode: NocWordingMode.templateExact,
        quotationNumber: doc.quotationNumber,
      );

      final pdfBytes = await PdfNocBuilder.buildNocPdf(payload);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: '${doc.nocNumber.replaceAll('/', '_')}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error viewing NOC: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _generateNocDirectly() async {
    final pipeline = widget.pipeline;
    if (pipeline.status != PipelineStatus.completed && !_checkAllStepsCompleted(pipeline)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NOC Certificate can only be generated once the deal is 100% completed.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final supabase = ref.read(supabaseClientProvider);
    final isInstallationComplete = await WorkProgressService.isInstallationComplete(
      supabase,
      pipeline.customerId,
      pipeline.id,
    );
    if (!isInstallationComplete) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot generate NOC: Customer installation must be completed (status: Resolved/Closed) first.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
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

      // 1. Fetch live quotation info if present
      Map<String, dynamic>? qData;
      if (pipeline.quotation?.id != null) {
        final res = await supabase.from('quotations').select().eq('id', pipeline.quotation!.id).maybeSingle();
        if (res != null) qData = res;
      }
      if (qData == null) {
        final res = await supabase
            .from('quotations')
            .select()
            .eq('pipeline_id', pipeline.id)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (res != null) qData = res;
      }

      // 2. Customer Name (business / contact)
      String customerName = pipeline.customer?.companyName.trim() ?? '';
      if (customerName.isEmpty) {
        customerName = pipeline.customer?.customerName.trim() ?? '';
      }
      if (customerName.isEmpty && pipeline.customerId.isNotEmpty) {
        final cRes = await supabase.from('customers').select().eq('id', pipeline.customerId).maybeSingle();
        if (cRes != null) {
          customerName = (cRes['company_name'] as String?)?.trim().isNotEmpty == true
              ? cRes['company_name']
              : (cRes['customer_name'] ?? '');
        }
      }
      if (customerName.isEmpty) customerName = 'Customer';

      // 3. Site Address
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

      // 4. Quotation line items & inventory products filtering
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

      // 5. Product name derivation (take from quotation only from deals)
      String productName = '';
      if (rawLines.isNotEmpty) {
        final firstDesc = (rawLines.first['description'] ?? rawLines.first['item_name'] ?? rawLines.first['name'])?.toString().trim() ?? '';
        if (firstDesc.isNotEmpty) {
          productName = firstDesc;
        }
      }
      if (productName.isEmpty && pipeline.quotation != null && pipeline.quotation!.lineItems.isNotEmpty) {
        productName = pipeline.quotation!.lineItems.first.description.trim();
      }
      if (productName.isEmpty) {
        productName = pipeline.product?.name ?? '';
      }
      if (productName.isEmpty && pipeline.productId.isNotEmpty) {
        final pRes = await supabase.from('products').select('name').eq('id', pipeline.productId).maybeSingle();
        if (pRes != null && pRes['name'] != null) {
          productName = pRes['name'].toString();
        }
      }

      if (productName.isEmpty || productName.toLowerCase() == 'standard system' || productName.toLowerCase() == 'product') {
        final descStr = rawLines.map((e) => (e['description'] ?? '').toString().toLowerCase()).join(' ');
        if (descStr.contains('heat pump') || descStr.contains('iz-')) {
          productName = 'Heat Pump';
        } else if (descStr.contains('barrier')) {
          productName = 'Boom Barrier';
        } else if (descStr.contains('tank')) {
          productName = 'Storage Tank';
        } else {
          productName = 'Heat Pump';
        }
      }

      final equipmentLines = QgNocExtractor.extractEquipmentLines(
        lineItems: rawLines,
        defaultProductName: productName,
        itemsTreatedAsProducts: itemsTreatedAsProducts,
      );

      // 6. Company details strictly following assigned product company
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

      // 7. Auto-generated Subject
      final subject = 'No Objection Certificate for Installation & Commissioning of $productName.';
      final quoteNumber = qData?['quotation_number']?.toString() ?? pipeline.quotation?.quotationNumber;

      // 8. Fetch Profile and Build Payload
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

      // 9. Build PDF bytes
      final pdfBytes = await PdfNocBuilder.buildNocPdf(payload);

      // 10. Issue & Finalize in database (strictly 1 per deal)
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
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        setState(() {
          _nocDocs = [issuedDoc];
        });

        // Immediately open PDF in PdfPreviewScreen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: '${issuedDoc.nocNumber.replaceAll('/', '_')}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating NOC: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _getNocProductName(QgNocDocument doc, SalesPipeline pipeline) {
    if (pipeline.quotation != null && pipeline.quotation!.lineItems.isNotEmpty) {
      final qDesc = pipeline.quotation!.lineItems.first.description.trim();
      if (qDesc.isNotEmpty) return qDesc;
    }
    if (doc.productName.isNotEmpty &&
        doc.productName.toLowerCase() != 'heat pump' &&
        doc.productName.toLowerCase() != 'standard system') {
      return doc.productName;
    }
    return doc.productName.isNotEmpty ? doc.productName : (pipeline.product?.name ?? 'Heat Pump');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pipeline.status != PipelineStatus.completed && !_checkAllStepsCompleted(widget.pipeline)) {
      return const SizedBox.shrink();
    }
    if (_loading) return const SizedBox.shrink();

    final docs = _nocDocs ?? [];
    final hasDocs = docs.isNotEmpty;
    final profile = ref.watch(currentProfileProvider);
    final bool isManagerOnly = (profile?.roles.contains(UserRole.manager) ?? false) && !(profile?.roles.contains(UserRole.admin) ?? false);

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
              const Icon(Icons.verified_outlined, color: Color(0xFF286B37)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasDocs ? 'Installation NOC Issued' : 'Installation NOC Certificate',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (hasDocs) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF286B37).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    docs.first.nocNumber,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF286B37),
                    ),
                  ),
                ),
                if (!isManagerOnly) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Delete NOC Certificate',
                    child: InkWell(
                      onTap: () => _confirmDeleteNoc(docs.first),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECACA), width: 0.8),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasDocs
                ? 'Satisfactory installation & commissioning certificate issued for ${_getNocProductName(docs.first, widget.pipeline)}. Strictly 1 NOC per deal.'
                : !_isInstallationComplete
                    ? 'No Objection Certificate (NOC) is locked. The customer installation step must be completed and marked as resolved before generating NOC.'
                    : 'Generate official No Objection Certificate (NOC) for customer sign-off and commissioning handover.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: !_isInstallationComplete && !hasDocs ? const Color(0xFFD97706) : AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: hasDocs
                  ? () => _viewNocPdf(docs.first)
                  : ((isManagerOnly || !_isInstallationComplete) ? null : () => _generateNocDirectly()),
              icon: Icon(
                hasDocs
                    ? Icons.picture_as_pdf
                    : !_isInstallationComplete
                        ? Icons.lock_outline_rounded
                        : Icons.add_circle_outline,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                hasDocs
                    ? 'View NOC'
                    : !_isInstallationComplete
                        ? 'Installation Incomplete (NOC Locked)'
                        : (isManagerOnly ? 'NOC Not Issued' : 'Generate NOC'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasDocs || _isInstallationComplete
                    ? const Color(0xFF286B37)
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                elevation: 0,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteNoc(QgNocDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete NOC Certificate'),
        content: Text(
          'Are you sure you want to delete this No Objection Certificate (${doc.nocNumber})?\n\nYou can generate a new NOC afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await QgNocRepository.deleteNoc(doc.id);
        if (mounted) {
          setState(() {
            _nocDocs = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('NOC deleted successfully. You can now re-generate it.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting NOC: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

