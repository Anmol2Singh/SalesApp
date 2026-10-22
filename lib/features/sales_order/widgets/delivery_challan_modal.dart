// lib/features/sales_order/widgets/delivery_challan_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/pipeline.dart';
import '../../../core/models/sales_order.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../pipelines/providers/pipelines_provider.dart';
import '../../pipelines/widgets/work_progress_box.dart';

class DeliveryChallanModal extends ConsumerStatefulWidget {
  final String pipelineId;
  final Customer customer;

  const DeliveryChallanModal({
    super.key,
    required this.pipelineId,
    required this.customer,
  });

  static Future<void> show(
    BuildContext context, {
    required String pipelineId,
    required Customer customer,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliveryChallanModal(
        pipelineId: pipelineId,
        customer: customer,
      ),
    );
  }

  @override
  ConsumerState<DeliveryChallanModal> createState() =>
      _DeliveryChallanModalState();
}

class _DeliveryChallanModalState extends ConsumerState<DeliveryChallanModal> {
  DateTime _challanDate = DateTime.now();
  final Map<int, TextEditingController> _remarkControllers = {};
  bool _isGenerating = false;

  @override
  void dispose() {
    for (final controller in _remarkControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initControllers(List<SalesOrderLineItem> items) {
    for (int i = 0; i < items.length; i++) {
      if (!_remarkControllers.containsKey(i)) {
        _remarkControllers[i] =
            TextEditingController(text: items[i].remark ?? '');
      }
    }
  }

  Future<void> _generateChallan(
    SalesPipeline pipeline,
    SalesOrder salesOrder,
  ) async {
    setState(() => _isGenerating = true);
    try {
      final supabase = ref.read(supabaseClientProvider);

      // 1. Build updated line items with user entered remarks
      final updatedLineItems = salesOrder.lineItems.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final remark = _remarkControllers[idx]?.text.trim();
        return item.copyWith(remark: remark != null && remark.isNotEmpty ? remark : null);
      }).toList();

      // 2. Persist remarks to sales_orders table in Supabase
      try {
        await supabase.from('sales_orders').update({
          'line_items': updatedLineItems.map((e) => e.toJson()).toList(),
        }).eq('id', salesOrder.id);
        ref.invalidate(pipelineDetailProvider(widget.pipelineId));
      } catch (_) {
        // If persistence fails due to network/policy, proceed with local generation
      }

      // 3. Fetch template config
      Map<String, dynamic> templateConfig = {};
      try {
        final res = await supabase
            .from('pdf_templates')
            .select()
            .eq('document_type', 'sales_order')
            .maybeSingle();
        if (res != null && res['template_config'] != null) {
          templateConfig = res['template_config'] as Map<String, dynamic>;
        }
      } catch (_) {}

      final product = pipeline.product ??
          Product(
            id: pipeline.productId,
            name: 'Product',
            category: 'Solar',
            baseSpecs: const ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      // 4. Generate Delivery Challan PDF bytes
      final pdfBytes = await PdfService.generateDeliveryChallanPdf(
        salesOrder: salesOrder,
        customer: widget.customer,
        product: product,
        templateConfig: templateConfig,
        quotationNumber: pipeline.quotation?.quotationNumber,
        challanDate: _challanDate,
        customLineItems: updatedLineItems,
      );

      final challanNo = PdfService.formatDeliveryChallanNumber(
        salesOrder.salesOrderNumber,
        _challanDate,
      );
      final fileName = '${challanNo.replaceAll('/', '_')}.pdf';

      // 4b. Record Delivery Challan generation in Work Progress
      try {
        await WorkProgressService.updateProgressMeta(
          supabase,
          widget.pipelineId,
          challanGenerated: true,
        );
        ref.invalidate(pipelineDetailProvider(widget.pipelineId));
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pop(); // Close bottom sheet

      // 5. Open in standard preview screen with Download, Print, Share
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            fileName: fileName,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating Delivery Challan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pipelineAsync = ref.watch(pipelineDetailProvider(widget.pipelineId));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: pipelineAsync.when(
        data: (pipeline) {
          final salesOrder = pipeline.salesOrder;
          if (salesOrder == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 48, color: AppColors.warning),
                  const SizedBox(height: 12),
                  const Text(
                    'Sales Order Required',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A Delivery Challan can only be generated once the Sales Order for this deal has been created and confirmed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }

          _initControllers(salesOrder.lineItems);

          final challanNo = PdfService.formatDeliveryChallanNumber(
            salesOrder.salesOrderNumber,
            _challanDate,
          );
          final quotationNo = pipeline.quotation?.quotationNumber ?? 'N/A';

          return Column(
            children: [
              // Sheet Header handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DELIVERY CHALLAN',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            challanNo,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Metadata card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'Challan Date:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _challanDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2035),
                                    );
                                    if (picked != null) {
                                      setState(() => _challanDate = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateFormat('dd/MM/yyyy')
                                              .format(_challanDate),
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'Ref No. (Quotation):',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  quotationNo,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (salesOrder.vehicleNumber != null &&
                              salesOrder.vehicleNumber!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Vehicle No:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    salesOrder.vehicleNumber!,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section title
                    const Text(
                      'Line Item Remarks / Serial Numbers',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Remarks will be printed directly beneath the item name in the Delivery Challan PDF.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Line items list with remark input
                    ...salesOrder.lineItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final controller = _remarkControllers[idx]!;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '#${idx + 1}',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.description,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Qty: ${item.qty == item.qty.roundToDouble() ? item.qty.toInt() : item.qty} ${item.uom.toUpperCase()}',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'e.g. Sr. No- 860025101802003 or note',
                                hintStyle: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                prefixIcon: const Icon(
                                  Icons.edit_note,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceVariant,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Bottom generate button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating
                        ? null
                        : () => _generateChallan(pipeline, salesOrder),
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 20),
                    label: Text(
                      _isGenerating
                          ? 'Generating PDF...'
                          : 'GENERATE DELIVERY CHALLAN',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading deal: $e'),
          ),
        ),
      ),
    );
  }
}
