// lib/features/customers/screens/customer_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/user_role.dart';
import '../../../core/widgets/step_tracker.dart';
import '../providers/customers_provider.dart';
import '../../pipelines/providers/pipelines_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../amc/providers/amc_provider.dart';
import '../../../core/widgets/breadcrumbs.dart';
import '../../../core/services/record_edit_permissions.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: customerAsync.when(
        data: (customer) => CustomScrollView(
          slivers: [
            _buildAppBar(context, ref, customer),
            SliverToBoxAdapter(
              child: Breadcrumbs(
                items: [
                  BreadcrumbItem(
                    label: 'Dashboard',
                    route: profile?.primaryRole == UserRole.admin
                        ? AppRoutes.adminDashboard
                        : AppRoutes.salesDashboard,
                  ),
                  BreadcrumbItem(
                    label: 'Customers',
                    route: AppRoutes.customers,
                  ),
                  BreadcrumbItem(
                    label: customer.customerName,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: _buildContent(context, ref, customer, profile?.primaryRole),
            ),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e'),
        ),
      ),
      floatingActionButton: profile?.primaryRole.canCreateCustomers == true
          ? FloatingActionButton.extended(
              onPressed: () => _startNewPipeline(context, ref),
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

  Widget _buildAppBar(BuildContext context, WidgetRef ref, Customer customer) {
    final profile = ref.watch(currentProfileProvider);
    final canEdit = RecordEditPermissions.canEditRecord(
      userRole: profile?.primaryRole,
      allRoles: profile?.roles ?? [],
      currentUserId: profile?.id,
      creatorId: customer.createdBy,
      assigneeId: customer.assignedTo,
    );

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.customers);
          }
        },
      ),
      actions: [
        if (canEdit) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            tooltip: 'Edit Customer',
            onPressed: () => _showEditCustomerModal(context, ref, customer),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Delete or Deactivate Customer',
            onPressed: () => _showDeleteDeactivateModal(context, ref, customer),
          ),
        ],
      ],
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double top = constraints.biggest.height;
          final bool isCollapsed =
              top <= kToolbarHeight + MediaQuery.of(context).padding.top + 10;

          return FlexibleSpaceBar(
            centerTitle: true,
            titlePadding: const EdgeInsets.fromLTRB(56, 0, 56, 14),
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: Text(
                customer.companyName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 80, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            customer.companyName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.companyName,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (customer.contactPerson != null)
                              Text(
                                customer.contactPerson!,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
    UserRole? role,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact info card
          _InfoCard(customer: customer),
          const SizedBox(height: 20),
          Builder(
            builder: (context) {
              var pipelines = customer.pipelines ?? [];
              final profile = ref.read(currentProfileProvider);
              if (role == UserRole.sales && profile != null) {
                final isCustomerAssignedToMe = customer.assignedTo == profile.id;
                if (!isCustomerAssignedToMe) {
                  pipelines =
                      pipelines.where((p) => p.createdBy == profile.id).toList();
                }
              }

              if (pipelines.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sales Deals',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    _EmptyPipelinesState(
                      onAdd: role?.canCreateCustomers == true
                          ? () => _startNewPipeline(context, ref)
                          : null,
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sales Deals',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  ...pipelines.map(
                    (p) => _PipelineItem(
                      pipeline: p,
                      onTap: () => context.push(
                          AppRoutes.pipelineDetail.replaceAll(':id', p.id)),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _AmcSection(customerId: customer.id),
          const SizedBox(height: 80), // FAB space
        ],
      ),
    );
  }

  void _startNewPipeline(BuildContext context, WidgetRef ref) {
    _showProductPicker(context, ref);
  }

  void _showProductPicker(BuildContext context, WidgetRef ref) async {
    final supabase = ref.read(supabaseClientProvider);
    final products = await supabase
        .from('products')
        .select('id, name, category')
        .eq('is_active', true)
        .isFilter('deleted_at', null);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Product',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...(products as List<dynamic>).map((p) {
              final product = p as Map<String, dynamic>;
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      color: AppColors.primary, size: 20),
                ),
                title: Text(
                  product['name'] as String,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  product['category'] as String? ?? '',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    // Show a loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      ),
                    );

                    // Fetch workflow steps snapshot
                    final wfRes = await supabase
                        .from('workflow_definitions')
                        .select('steps')
                        .eq('product_id', product['id'])
                        .maybeSingle();
                    final steps = wfRes?['steps'] ??
                        [
                          {
                            'id': 'quotation',
                            'name': 'Quotation',
                            'owner_role': 'sales',
                            'pdf_generation': true
                          },
                          {
                            'id': 'sales_order',
                            'name': 'Sales Order',
                            'owner_role': 'sales_head',
                            'pdf_generation': true
                          },
                          {
                            'id': 'boq',
                            'name': 'BOQ',
                            'owner_role': 'factory',
                            'pdf_generation': false
                          },
                          {
                            'id': 'factory_order',
                            'name': 'Factory Order',
                            'owner_role': 'factory',
                            'pdf_generation': false
                          },
                          {
                            'id': 'purchase_order',
                            'name': 'Purchase Order',
                            'owner_role': 'purchase',
                            'pdf_generation': false
                          },
                        ];

                    // Create pipeline
                    final pipeline = await supabase
                        .from('sales_pipelines')
                        .insert({
                          'customer_id': customerId,
                          'product_id': product['id'],
                          'created_by': supabase.auth.currentUser!.id,
                          'current_step': 'quotation',
                          'status': 'in_progress',
                          'steps_config': steps,
                        })
                        .select()
                        .single();

                    // Write audit log
                    await supabase.from('step_audit_log').insert({
                      'pipeline_id': (pipeline as Map)['id'],
                      'step_name': 'pipeline',
                      'action': 'created',
                      'performed_by': supabase.auth.currentUser!.id,
                    });

                    // Invalidate providers
                    ref.invalidate(customerDetailProvider(customerId));
                    ref.invalidate(pipelinesNotifierProvider);

                    if (context.mounted) {
                      // Close the loading dialog
                      Navigator.pop(context);
                      // Navigate to details
                      context.push(
                        AppRoutes.pipelineDetail
                            .replaceAll(':id', pipeline['id'] as String),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      // Close the loading dialog if open
                      Navigator.pop(context);
                      // Show error snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating deal: ${e.toString()}'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends ConsumerWidget {
  final Customer customer;

  const _InfoCard({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final canViewPersonal = profile?.primaryRole.canViewCustomerPersonalData ?? false;
    final canEdit = RecordEditPermissions.canEditRecord(
      userRole: profile?.primaryRole,
      allRoles: profile?.roles ?? [],
      currentUserId: profile?.id,
      creatorId: customer.createdBy,
      assigneeId: customer.assignedTo,
    );
    final canAssign = profile?.primaryRole == UserRole.admin ||
        profile?.primaryRole == UserRole.salesHead ||
        profile?.primaryRole == UserRole.manager;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customer Details',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (canEdit)
                InkWell(
                  onTap: () => _showEditCustomerModal(context, ref, customer),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          if (customer.reassignmentRequested)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade400, width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚠️ REASSIGNMENT REQUESTED',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.brown,
                          ),
                        ),
                        if (customer.reassignmentReason != null && customer.reassignmentReason!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Reason: "${customer.reassignmentReason}"',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canAssign) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _showAssignCustomerSheet(context, ref, customer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Reassign', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          if (customer.assignedToName != null || customer.salesmanName != null || canAssign)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_pin, size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assigned Salesperson',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          customer.assignedToName?.isNotEmpty == true
                              ? customer.assignedToName!
                              : (customer.salesmanName?.isNotEmpty == true
                                  ? customer.salesmanName!
                                  : 'Not Assigned'),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canAssign)
                    InkWell(
                      onTap: () => _showAssignCustomerSheet(context, ref, customer),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              customer.assignedToName != null ? Icons.sync : Icons.person_add_alt_1,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              customer.assignedToName != null ? 'Reassign' : 'Assign',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!canAssign && (customer.assignedTo == profile?.id || customer.createdBy == profile?.id))
                    InkWell(
                      onTap: () => _showRequestReassignCustomerDialog(context, ref, customer),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.swap_horiz, size: 13, color: Colors.orange),
                            SizedBox(width: 4),
                            Text(
                              'Request Reassign',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (customer.convertedByName != null && customer.convertedByName!.isNotEmpty)
            _InfoRow(
              Icons.verified_user_outlined,
              'Converted by',
              customer.convertedByName!,
            ),
          if (customer.contactPerson != null && customer.contactPerson!.isNotEmpty)
            _InfoRow(Icons.person_outline, 'Contact Person', customer.contactPerson!),
          if (customer.phone != null && customer.phone!.isNotEmpty)
            _InfoRow(
                Icons.phone_outlined,
                'Phone',
                canViewPersonal
                    ? customer.phone!
                    : '[Protected - Admin/Sales Only]'),
          if (customer.email != null && customer.email!.isNotEmpty)
            _InfoRow(Icons.email_outlined, 'Email',
                canViewPersonal ? customer.email! : '[Protected]'),
          if (customer.address != null && customer.address!.isNotEmpty)
            _InfoRow(Icons.location_on_outlined, 'Address', customer.address!),
          if (customer.gstNumber != null && customer.gstNumber!.isNotEmpty)
            _InfoRow(Icons.receipt_long_outlined, 'GSTIN', customer.gstNumber!),
          if (customer.notes != null && customer.notes!.isNotEmpty)
            _InfoRow(Icons.note_alt_outlined, 'Notes', customer.notes!),
          _InfoRow(
            Icons.calendar_today_outlined,
            'Customer Since',
            DateFormat('dd MMM yyyy').format(customer.createdAt),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textPrimary,
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

class _PipelineItem extends StatelessWidget {
  final SalesPipelineSummary pipeline;
  final VoidCallback onTap;

  const _PipelineItem({required this.pipeline, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
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
                Text(
                  pipeline.productName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.12)),
                  ),
                  child: Text(
                    pipeline.currentStep.displayName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StepTrackerWidget(
              productId: pipeline.productId,
              currentStep: pipeline.currentStep,
            ),
            const SizedBox(height: 8),
            Text(
              'Started ${DateFormat('dd MMM yyyy').format(pipeline.createdAt)}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPipelinesState extends StatelessWidget {
  final VoidCallback? onAdd;

  const _EmptyPipelinesState({this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          const Icon(Icons.handshake_outlined,
              size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          const Text(
            'No deals yet',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start a new deal to track the sales lifecycle for a product.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Start Deal'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmcSection extends ConsumerWidget {
  final String customerId;

  const _AmcSection({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amcListAsync = ref.watch(amcForCustomerProvider(customerId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AMC Contracts',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        amcListAsync.when(
          data: (amcs) {
            if (amcs.isEmpty) {
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 36,
                        color: AppColors.textSecondary.withOpacity(0.5)),
                    const SizedBox(height: 10),
                    const Text(
                      'No AMC contracts found for this customer.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: amcs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final amc = amcs[index];
                final completedCount = (amc.serviceVisits ?? [])
                    .where((v) => v.status.name == 'completed')
                    .length;
                final totalVisits = amc.numberOfVisitsIncluded ?? 0;

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            amc.product?.name ?? 'Product ID: ${amc.productId}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: amc.status.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            amc.status.displayName,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: amc.status.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contract: ${amc.amcNumber}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Period: ${amc.startDate != null ? DateFormat('dd MMM yyyy').format(amc.startDate!) : '-'} to ${amc.endDate != null ? DateFormat('dd MMM yyyy').format(amc.endDate!) : '-'}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (totalVisits > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.build_circle_outlined,
                                    size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  'Visits: $completedCount of $totalVisits completed',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    onTap: () => context.push('/amc/details/${amc.id}'),
                  ),
                );
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (e, _) => Text(
            'Error loading AMCs: $e',
            style: const TextStyle(
                fontFamily: 'Inter', fontSize: 13, color: AppColors.error),
          ),
        ),
      ],
    );
  }
}

void _showDeleteDeactivateModal(BuildContext context, WidgetRef ref, Customer customer) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (modalCtx) {
      bool isProcessing = false;
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manage Customer Status',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer.companyName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isProcessing)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else ...[
                  // Option 1: Deactivate
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pause_circle_outline, color: Colors.amber.shade800, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Deactivate Customer',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hides this customer from active customer lists. All historical sales deals, quotations, and documents remain preserved safely.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.archive_outlined, size: 16),
                            label: const Text('Deactivate (Archive)', style: TextStyle(fontWeight: FontWeight.w600)),
                            onPressed: () async {
                              setModalState(() => isProcessing = true);
                              try {
                                final supabase = ref.read(supabaseClientProvider);
                                await supabase.from('customers').update({
                                  'deleted_at': DateTime.now().toIso8601String(),
                                  'updated_at': DateTime.now().toIso8601String(),
                                }).eq('id', customer.id);

                                ref.invalidate(customerDetailProvider(customer.id));
                                ref.read(customersNotifierProvider.notifier).load(refresh: true);

                                if (modalCtx.mounted) {
                                  Navigator.pop(modalCtx);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✓ ${customer.companyName} deactivated and archived.'),
                                      backgroundColor: Colors.amber.shade800,
                                    ),
                                  );
                                  context.go(AppRoutes.customers);
                                }
                              } catch (e) {
                                setModalState(() => isProcessing = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error deactivating: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Option 2: Permanently Delete
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.delete_forever_outlined, color: Colors.red.shade700, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Permanently Delete',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Permanently deletes this customer record from the database. Warning: This action cannot be undone.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.red.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.delete_forever, size: 16),
                            label: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.w600)),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: modalCtx,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Confirm Permanent Deletion'),
                                  content: Text(
                                    'Are you sure you want to permanently delete "${customer.companyName}"?\n\nIf active deals exist, records might fail or be removed permanently.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Confirm Delete', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                setModalState(() => isProcessing = true);
                                try {
                                  final supabase = ref.read(supabaseClientProvider);
                                  await supabase.from('customers').delete().eq('id', customer.id);

                                  ref.invalidate(customerDetailProvider(customer.id));
                                  ref.read(customersNotifierProvider.notifier).load(refresh: true);

                                  if (modalCtx.mounted) {
                                    Navigator.pop(modalCtx);
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('✓ ${customer.companyName} permanently deleted.'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                    context.go(AppRoutes.customers);
                                  }
                                } catch (e) {
                                  // In case foreign keys block hard delete, offer deactivation
                                  setModalState(() => isProcessing = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Cannot hard-delete (active records linked). Try "Deactivate" instead. Details: $e'),
                                        backgroundColor: AppColors.error,
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

void _showEditCustomerModal(BuildContext context, WidgetRef ref, Customer customer) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _EditCustomerSheet(customer: customer),
    ),
  );
}

class _EditCustomerSheet extends ConsumerStatefulWidget {
  final Customer customer;
  const _EditCustomerSheet({required this.customer});

  @override
  ConsumerState<_EditCustomerSheet> createState() => _EditCustomerSheetState();
}

class _EditCustomerSheetState extends ConsumerState<_EditCustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _companyNameCtrl;
  late final TextEditingController _contactPersonCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _notesCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _companyNameCtrl = TextEditingController(text: widget.customer.companyName);
    _contactPersonCtrl = TextEditingController(text: widget.customer.contactPerson ?? '');
    _phoneCtrl = TextEditingController(text: widget.customer.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.customer.email ?? '');
    _addressCtrl = TextEditingController(text: widget.customer.address ?? '');
    _gstCtrl = TextEditingController(text: widget.customer.gstNumber ?? '');
    _notesCtrl = TextEditingController(text: widget.customer.notes ?? '');
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _contactPersonCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('customers').update({
        'customer_name': _companyNameCtrl.text.trim(),
        'company_name': _companyNameCtrl.text.trim(),
        'contact_person': _contactPersonCtrl.text.trim().isEmpty ? null : _contactPersonCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'gst_number': _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim().toUpperCase(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.customer.id);

      ref.invalidate(customerDetailProvider(widget.customer.id));
      ref.read(customersNotifierProvider.notifier).load(refresh: true);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Customer details updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating customer: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final canEditName = RecordEditPermissions.canEditField(
      fieldName: 'name',
      userRole: profile?.primaryRole,
      allRoles: profile?.roles ?? [],
      currentUserId: profile?.id,
      creatorId: widget.customer.createdBy,
      assigneeId: widget.customer.assignedTo,
    );
    final canEditPhone = RecordEditPermissions.canEditField(
      fieldName: 'phone',
      userRole: profile?.primaryRole,
      allRoles: profile?.roles ?? [],
      currentUserId: profile?.id,
      creatorId: widget.customer.createdBy,
      assigneeId: widget.customer.assignedTo,
    );

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Customer Details',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _companyNameCtrl,
                enabled: canEditName,
                decoration: InputDecoration(
                  labelText: 'Company / Customer Name *',
                  prefixIcon: const Icon(Icons.business_outlined),
                  border: const OutlineInputBorder(),
                  helperText: canEditName ? null : 'Only creator or admin can edit name',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Company / Customer name is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contactPersonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contact Person',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                enabled: canEditPhone,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: const OutlineInputBorder(),
                  helperText: canEditPhone ? null : 'Only creator or admin can edit phone number',
                ),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Phone number is required';
                  if (val.trim().length < 7) return 'Enter a valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _gstCtrl,
                decoration: const InputDecoration(
                  labelText: 'GSTIN / GST Number',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'e.g. 27AAAAA1111A1Z1',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showAssignCustomerSheet(BuildContext context, WidgetRef ref, Customer customer) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AssignCustomerSheet(customer: customer),
  );
}

void _showRequestReassignCustomerDialog(BuildContext context, WidgetRef ref, Customer customer) {
  final reasonCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Request Customer Reassignment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Request Admin to reassign "${customer.companyName}" to another salesperson.'),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason for reassignment *',
              hintText: 'e.g., Territory change, capacity constraint, client preference...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: () async {
            if (reasonCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Please provide a reason for reassignment')),
              );
              return;
            }
            Navigator.pop(ctx);
            await ref.read(customersNotifierProvider.notifier).requestCustomerTransfer(
                  customerId: customer.id,
                  customerName: customer.companyName,
                  reason: reasonCtrl.text.trim(),
                );
            ref.invalidate(customerDetailProvider(customer.id));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Reassignment request submitted to Admin successfully.'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          },
          child: const Text('Submit Request', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

class _AssignCustomerSheet extends ConsumerStatefulWidget {
  final Customer customer;
  const _AssignCustomerSheet({required this.customer});

  @override
  ConsumerState<_AssignCustomerSheet> createState() => _AssignCustomerSheetState();
}

class _AssignCustomerSheetState extends ConsumerState<_AssignCustomerSheet> {
  String? _selectedSalesUserId;
  String _transferDealsMode = 'all';
  bool _isLoading = false;
  bool _fetchingStaff = true;
  List<Map<String, dynamic>> _salesStaff = [];

  @override
  void initState() {
    super.initState();
    _fetchSalesStaff();
  }

  Future<void> _fetchSalesStaff() async {
    setState(() => _fetchingStaff = true);
    try {
      final db = ref.read(supabaseClientProvider);
      dynamic res;
      try {
        res = await db.from('profiles').select('id, full_name, role, roles, email').order('full_name');
      } catch (_) {
        res = await db.from('profiles').select().order('created_at', ascending: false);
      }

      final list = <Map<String, dynamic>>[];
      for (final r in (res as List? ?? [])) {
        final role = (r['role'] as String? ?? '').toLowerCase();
        final rolesList = (r['roles'] is List)
            ? (r['roles'] as List).map((e) => e.toString().toLowerCase()).toList()
            : [];
        final name = (r['full_name'] as String? ?? '').toLowerCase();
        final email = (r['email'] as String? ?? '').toLowerCase();

        // 1. Exclude Admin, Managers, and Sales Heads (supervisors who have company-wide access)
        final isSupervisorOrAdmin = role == 'admin' ||
            role == 'administrator' ||
            role == 'manager' ||
            role == 'sales_head' ||
            role == 'saleshead' ||
            rolesList.contains('admin') ||
            rolesList.contains('administrator') ||
            rolesList.contains('manager') ||
            rolesList.contains('sales_head') ||
            rolesList.contains('saleshead') ||
            name.contains('admin') ||
            email.contains('admin');
        if (isSupervisorOrAdmin) continue;

        // 2. MUST be Sales Executive only (no other department roles)
        final isSalesExecutive = role == 'sales' ||
            role == 'sales_executive' ||
            rolesList.contains('sales') ||
            rolesList.contains('sales_executive');
        if (!isSalesExecutive) continue;

        list.add(r as Map<String, dynamic>);
      }

      final finalList = list;

      if (mounted) {
        setState(() {
          _salesStaff = finalList;
          _selectedSalesUserId = widget.customer.assignedTo ??
              (_salesStaff.isNotEmpty ? _salesStaff.first['id'] as String? : null);
        });
      }
    } catch (e) {
      debugPrint('Error fetching sales staff: $e');
    } finally {
      if (mounted) setState(() => _fetchingStaff = false);
    }
  }

  Future<void> _assign() async {
    if (_selectedSalesUserId == null) return;
    setState(() => _isLoading = true);
    try {
      final selectedUser = _salesStaff.firstWhere(
        (u) => u['id'] == _selectedSalesUserId,
        orElse: () => {'full_name': 'Sales Staff'},
      );
      final staffName = selectedUser['full_name'] as String? ?? 'Sales Staff';

      await ref.read(customersNotifierProvider.notifier).assignCustomer(
            customerId: widget.customer.id,
            salesUserId: _selectedSalesUserId!,
            salesUserName: staffName,
            transferDealsMode: _transferDealsMode,
          );

      ref.invalidate(customerDetailProvider(widget.customer.id));
      ref.invalidate(pipelinesNotifierProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Salesperson assigned and deals transferred successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign salesperson: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_pin, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assign Salesperson & Deals',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.customer.companyName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_fetchingStaff)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_salesStaff.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                'No sales personnel accounts found.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            )
          else ...[
            const Text(
              'Select Sales Executive / Head:',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
                color: AppColors.surface,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedSalesUserId,
                  hint: const Text('Choose sales staff member'),
                  items: _salesStaff.map((staff) {
                    final name = staff['full_name'] as String? ?? staff['email'] as String? ?? 'Sales Executive';
                    return DropdownMenuItem<String>(
                      value: staff['id'] as String,
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SALES EXECUTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSalesUserId = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Transfer Customer Deals:',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
                color: AppColors.surface,
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('All Deals (Active + Completed)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Assign all past and active pipeline deals to this salesperson', style: TextStyle(fontSize: 11)),
                    value: 'all',
                    groupValue: _transferDealsMode,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _transferDealsMode = val!),
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('Active Deals Only', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Transfer only in-progress deals; completed deals stay intact', style: TextStyle(fontSize: 11)),
                    value: 'active_only',
                    groupValue: _transferDealsMode,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _transferDealsMode = val!),
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('Customer Only', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Assign account representative without transferring existing deals', style: TextStyle(fontSize: 11)),
                    value: 'none',
                    groupValue: _transferDealsMode,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _transferDealsMode = val!),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isLoading || _selectedSalesUserId == null || _salesStaff.isEmpty)
                  ? null
                  : _assign,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Confirm Assignment',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
