// lib/features/factory_order/screens/factory_order_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/factory_order.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/pipeline.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../pipelines/providers/pipelines_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/user_role.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../../core/router/app_router.dart';

class FactoryOrderScreen extends ConsumerStatefulWidget {
  final String pipelineId;

  const FactoryOrderScreen({super.key, required this.pipelineId});

  @override
  ConsumerState<FactoryOrderScreen> createState() => _FactoryOrderScreenState();
}

class _FactoryOrderScreenState extends ConsumerState<FactoryOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  DateTime? _expectedCompletionDate;
  DateTime? _boqDispatchDate;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  FactoryOrder? _existingOrder;
  SalesPipeline? _pipeline;
  List<FactoryOrderItem> _items = [];
  List<Map<String, dynamic>> _catalogItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final supabase = ref.read(supabaseClientProvider);

      // Load catalog items
      final catalogData = await supabase
          .from('manufacturing_items')
          .select('id, name, description')
          .order('name');
      _catalogItems = List<Map<String, dynamic>>.from(catalogData);

      final pipelineData = await supabase
          .from('sales_pipelines')
          .select('*, products(*), customers(*)')
          .eq('id', widget.pipelineId)
          .single();
      _pipeline = SalesPipeline.fromJson(pipelineData);

      // Fetch BOQ dispatch date
      final boqData = await supabase
          .from('boqs')
          .select('tentative_dispatch_date')
          .eq('pipeline_id', widget.pipelineId)
          .maybeSingle();

      if (boqData != null && boqData['tentative_dispatch_date'] != null) {
        _boqDispatchDate = DateTime.tryParse(boqData['tentative_dispatch_date'] as String);
      }

      // Load existing factory order
      final foData = await supabase
          .from('factory_orders')
          .select()
          .eq('pipeline_id', widget.pipelineId)
          .maybeSingle();

      if (foData != null) {
        _existingOrder = FactoryOrder.fromJson(foData);
        _isEditing = _existingOrder!.status != FactoryOrderStatus.completed;
        _notesController.text = _existingOrder!.factoryNotes ?? '';
        _expectedCompletionDate = _existingOrder!.expectedCompletionDate;
        _items = List<FactoryOrderItem>.from(_existingOrder!.items);
      } else {
        _isEditing = true;
        _items = [];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveOrder(FactoryOrderStatus status) async {
    if (!_formKey.currentState!.validate()) return;

    final role = ref.read(currentProfileProvider)?.primaryRole;

    // Only factory / admin can set it to in_production
    if (status == FactoryOrderStatus.inProduction &&
        role != UserRole.factory &&
        role != UserRole.admin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only factory team can start production'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (status == FactoryOrderStatus.completed &&
        _expectedCompletionDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an expected completion date first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final specs = <String, dynamic>{};

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      final data = {
        'pipeline_id': widget.pipelineId,
        'production_specs': specs,
        'factory_notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'expected_completion_date': _expectedCompletionDate?.toIso8601String(),
        'status': status.dbValue,
        'items': _items.map((i) => i.toJson()).toList(),
      };

      final wasCompleted =
          _existingOrder?.status == FactoryOrderStatus.completed;

      String orderId;
      if (_existingOrder != null) {
        await supabase
            .from('factory_orders')
            .update(data)
            .eq('id', _existingOrder!.id);
        orderId = _existingOrder!.id;
      } else {
        final res = await supabase
            .from('factory_orders')
            .insert(data)
            .select('id')
            .single();
        orderId = (res as Map)['id'] as String;
      }

      // Generate and upload PDF if completed
      if (status == FactoryOrderStatus.completed) {
        await _generateAndUploadPdf(orderId, showPrintDialog: false);
      }

      if (status == FactoryOrderStatus.completed && !wasCompleted) {
        // Advance pipeline
        await supabase.from('sales_pipelines').update(
            {'current_step': 'purchase_order'}).eq('id', widget.pipelineId);

        // Notify sales executive who created the pipeline
        await supabase.from('notifications').insert({
          'user_id': _pipeline!.createdBy,
          'title': 'Factory Order Completed',
          'body':
              'The factory order for ${_pipeline?.product?.name ?? "product"} has been completed by the factory team.',
          'type': 'step_unlocked',
          'related_pipeline_id': widget.pipelineId,
        });

        // Notify admin team
        final adminUsers = await supabase
            .from('profiles')
            .select('id')
            .eq('role', 'admin')
            .eq('is_active', true);

        for (final u in (adminUsers as List<dynamic>)) {
          final adminId = (u as Map)['id'];
          if (adminId != _pipeline!.createdBy) {
            await supabase.from('notifications').insert({
              'user_id': adminId,
              'title': 'Factory Order Completed',
              'body':
                  'The factory order for ${_pipeline?.product?.name ?? "product"} has been completed.',
              'type': 'step_unlocked',
              'related_pipeline_id': widget.pipelineId,
            });
          }
        }

        // Notify purchase team
        final purchaseUsers = await supabase
            .from('profiles')
            .select('id')
            .eq('role', 'purchase')
            .eq('is_active', true);

        for (final u in (purchaseUsers as List<dynamic>)) {
          await supabase.from('notifications').insert({
            'user_id': (u as Map)['id'],
            'title': 'New Material Requisition Assigned',
            'body':
                'Factory order completed. Material Requisition step is now available.',
            'type': 'step_unlocked',
            'related_pipeline_id': widget.pipelineId,
          });
        }

        // Audit log
        await supabase.from('step_audit_log').insert({
          'pipeline_id': widget.pipelineId,
          'step_name': 'factory_order',
          'action': 'confirmed',
          'performed_by': supabase.auth.currentUser!.id,
        });
      } else if (wasCompleted) {
        // Audit log for update
        await supabase.from('step_audit_log').insert({
          'pipeline_id': widget.pipelineId,
          'step_name': 'factory_order',
          'action': 'updated',
          'performed_by': supabase.auth.currentUser!.id,
        });
      }

      ref.invalidate(pipelineDetailProvider(widget.pipelineId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == FactoryOrderStatus.completed
                  ? '✓ Factory Order completed! Material Requisition step unlocked.'
                  : '✓ Factory Order updated.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.go(AppRoutes.pipelineDetail.replaceAll(':id', widget.pipelineId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showChangeQtyDialog(int idx, FactoryOrderItem item) {
    final currentQty = item.qty.toInt() <= 0 ? 1 : item.qty.toInt();
    final controller = TextEditingController(text: currentQty.toString());
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Change Quantity',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Color(0xFF1E1B4B),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.itemName,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantity (units)',
                hintText: 'Enter quantity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                setState(() {
                  _items[idx] = FactoryOrderItem(
                    itemName: item.itemName,
                    qty: val.toDouble(),
                    remarks: item.remarks,
                  );
                });
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity (minimum 1)'),
                    backgroundColor: AppColors.error,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddManufacturingItemSheet() {
    final searchController = TextEditingController();
    String searchText = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // Filter catalog items
            final filtered = _catalogItems.where((item) {
              final name = item['name'].toString().toLowerCase();
              return name.contains(searchText.toLowerCase());
            }).toList();

            final exactMatch = _catalogItems.any((item) =>
                item['name'].toString().trim().toLowerCase() ==
                searchText.trim().toLowerCase());

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Select Item to Manufacture',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search catalog items...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchText = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (c, idx) {
                        final item = filtered[idx];
                        return ListTile(
                          title: Text(
                            item['name'] ?? '',
                            style: const TextStyle(
                                fontFamily: 'Inter', fontWeight: FontWeight.w600),
                          ),
                          subtitle: item['description'] != null
                              ? Text(item['description'],
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12))
                              : null,
                          trailing: const Icon(Icons.add, color: AppColors.primary),
                          onTap: () {
                            setState(() {
                              _items.add(FactoryOrderItem(
                                itemName: item['name'] as String,
                                qty: 1,
                              ));
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                  if (searchText.trim().isNotEmpty && !exactMatch) ...[
                    const Divider(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final name = searchText.trim();
                          try {
                            final supabase = ref.read(supabaseClientProvider);
                            final response = await supabase
                                .from('manufacturing_items')
                                .insert({'name': name})
                                .select('id, name, description')
                                .single();
                            
                            final newItem = Map<String, dynamic>.from(response as Map);
                            setState(() {
                              _catalogItems.add(newItem);
                              _items.add(FactoryOrderItem(
                                itemName: newItem['name'] as String,
                                qty: 1,
                              ));
                            });
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✓ "$name" added to catalog!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                            Navigator.pop(ctx);
                          } catch (e) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppColors.error),
                            );
                          }
                        },
                        icon: const Icon(Icons.add_to_photos_outlined),
                        label: Text('Create & Select "$searchText"'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    ).then((_) => searchController.dispose());
  }

  Future<void> _generateAndUploadPdf(String orderId, {bool showPrintDialog = true}) async {
    final supabase = ref.read(supabaseClientProvider);
    final foData = await supabase
        .from('factory_orders')
        .select()
        .eq('id', orderId)
        .single();
    final factoryOrder = FactoryOrder.fromJson(foData);

    // Fetch latest pipeline data with customer and product details
    final pipelineData = await supabase
        .from('sales_pipelines')
        .select('*, customers(*), products(*)')
        .eq('id', factoryOrder.pipelineId)
        .single();
    final pipeline = SalesPipeline.fromJson(pipelineData);

    final customer = pipeline.customer ?? Customer(
      id: pipeline.customerId,
      companyName: 'Default Customer',
      contactPerson: 'Contact Person',
      phone: '',
      email: '',
      createdBy: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final product = pipeline.product ?? Product(
      id: pipeline.productId,
      name: 'Default Product',
      category: 'HVAC',
      baseSpecs: const ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Map<String, dynamic> templateConfig;
    try {
      final templateData = await supabase
          .from('pdf_templates')
          .select()
          .eq('document_type', 'factory_order')
          .single();
      templateConfig =
          (templateData)['template_config'] as Map<String, dynamic>;
    } catch (_) {
      templateConfig = {
        'company_name': 'IZYHEAT',
        'company_address': 'IZYHEAT Office, India',
        'company_phone': '+91 99999 99999',
        'company_email': 'info@izyheat.com',
        'company_gst': '27AAAAA1111A1Z1',
        'footer_text': 'Thank you for your business.',
        'terms_default':
            '1. Payment: 50% advance, 50% before delivery.\n2. Delivery: 2-3 weeks.',
      };
    }

    // Generate PDF bytes
    final pdfBytes = await PdfService.generateFactoryOrderPdf(
      factoryOrder: factoryOrder,
      customer: customer,
      product: product,
      templateConfig: templateConfig,
    );

    // Write audit log
    await supabase.from('step_audit_log').insert({
      'pipeline_id': widget.pipelineId,
      'step_name': 'factory_order',
      'action': 'pdf_generated',
      'performed_by': supabase.auth.currentUser!.id,
    });

    if (showPrintDialog && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            fileName: 'FactoryOrder_${factoryOrder.orderNumber.replaceAll('/', '_')}.pdf',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final profile = ref.watch(currentProfileProvider);
    final role = profile?.primaryRole;
    final isCompleted = _existingOrder?.status == FactoryOrderStatus.completed;
    final enabled = _isEditing && role != UserRole.purchase;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isCompleted && !_isEditing
            ? 'Factory Order (Completed)'
            : 'Factory Order'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isCompleted && !_isEditing) ...[
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit, color: Colors.white, size: 16),
              label: const Text('Edit Details',
                  style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
            ),
            IconButton(
              icon: const Icon(Icons.print, color: Colors.white),
              onPressed: () => _generateAndUploadPdf(_existingOrder!.id),
            ),
          ],
          if (_isEditing && isCompleted)
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () => _saveOrder(FactoryOrderStatus.completed),
              child: const Text('Save Changes',
                  style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            // Tentative Dispatch Date Alert Banner
            if (_boqDispatchDate != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tentative Dispatch Scheduled',
                            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                          ),
                          Text(
                            'Dispatch Target: ${DateFormat('dd MMMM yyyy').format(_boqDispatchDate!)}',
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Header card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pipeline?.customer?.companyName ?? '',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    _pipeline?.product?.name ?? '',
                    style: const TextStyle(
                        fontFamily: 'Inter', color: AppColors.textSecondary),
                  ),
                  if (_existingOrder != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _existingOrder!.orderNumber,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: _existingOrder!.status),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Expected completion date
            const Text(
              'Expected Completion Date',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: !enabled
                  ? null
                  : () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _expectedCompletionDate ??
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _expectedCompletionDate = date);
                      }
                    },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _expectedCompletionDate != null
                          ? DateFormat('dd MMM yyyy')
                              .format(_expectedCompletionDate!)
                          : 'Select date...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: _expectedCompletionDate != null
                            ? AppColors.textPrimary
                            : AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Manufacturing Items Section
            const Text(
              'Items to Manufacture',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No manufacturing items added yet.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ..._items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final currentQty = item.qty.toInt() <= 0 ? 1 : item.qty.toInt();

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          item.itemName,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Stepper: [-]  [Qty]  [+]
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Decrement button (-)
                            InkWell(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                              onTap: !enabled || currentQty <= 1
                                  ? null
                                  : () {
                                      setState(() {
                                        _items[idx] = FactoryOrderItem(
                                          itemName: item.itemName,
                                          qty: (currentQty - 1).toDouble(),
                                          remarks: item.remarks,
                                        );
                                      });
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Icon(
                                  Icons.remove,
                                  size: 16,
                                  color: !enabled || currentQty <= 1
                                      ? Colors.grey.shade400
                                      : const Color(0xFF1E1B4B),
                                ),
                              ),
                            ),
                            // Click to change Qty (strictly integer, no decimals)
                            InkWell(
                              onTap: !enabled ? null : () => _showChangeQtyDialog(idx, item),
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 44),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.symmetric(
                                    vertical: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                child: Text(
                                  '$currentQty',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E1B4B),
                                  ),
                                ),
                              ),
                            ),
                            // Increment button (+)
                            InkWell(
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                              onTap: !enabled
                                  ? null
                                  : () {
                                      setState(() {
                                        _items[idx] = FactoryOrderItem(
                                          itemName: item.itemName,
                                          qty: (currentQty + 1).toDouble(),
                                          remarks: item.remarks,
                                        );
                                      });
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Icon(
                                  Icons.add,
                                  size: 16,
                                  color: !enabled
                                      ? Colors.grey.shade400
                                      : const Color(0xFF1E1B4B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (enabled) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                          tooltip: 'Remove Item',
                          onPressed: () {
                            setState(() {
                              _items.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                );
              }),
            if (enabled) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _showAddManufacturingItemSheet,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Item to Manufacture'),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Notes
            const Text(
              'Factory Notes',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesController,
              maxLines: 5,
              enabled: enabled,
              decoration: const InputDecoration(
                hintText: 'Add internal production notes...',
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            if ((!isCompleted || _isEditing) && role != UserRole.purchase) ...[
              if (role == UserRole.factory || role == UserRole.admin)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () => _saveOrder(FactoryOrderStatus.completed),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.done_all),
                    label: Text(_isSaving
                        ? 'Saving...'
                        : (isCompleted
                            ? 'Save Changes & Print'
                            : 'Mark as Complete & Unlock Material Requisition')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              if (!isCompleted)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => _saveOrder(FactoryOrderStatus.inProduction),
                    child: const Text('Save / Update'),
                  ),
                ),
            ],
            if (isCompleted && !_isEditing)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Factory order completed. Material Requisition step is unlocked.',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.success,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          _generateAndUploadPdf(_existingOrder!.id),
                      child: const Text('Print PDF'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final FactoryOrderStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bg;
    switch (status) {
      case FactoryOrderStatus.pending:
        color = AppColors.warning;
        bg = AppColors.warningLight;
        break;
      case FactoryOrderStatus.inProduction:
        color = AppColors.info;
        bg = AppColors.infoLight;
        break;
      case FactoryOrderStatus.completed:
        color = AppColors.success;
        bg = AppColors.successLight;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
