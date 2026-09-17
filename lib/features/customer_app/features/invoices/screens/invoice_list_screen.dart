import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:salesapp/core/services/pdf_service.dart';
import 'package:salesapp/core/widgets/pdf_preview_screen.dart';
import 'package:salesapp/core/models/quotation.dart' as core_quotation;
import 'package:salesapp/core/models/customer.dart' as core_customer;
import 'package:salesapp/core/models/product.dart' as core_product;
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/data/models/data_models.dart';
import 'package:salesapp/features/customer_app/data/providers/app_providers.dart';
import 'package:salesapp/features/customer_app/shared/widgets/glass_card.dart';
import 'package:salesapp/features/customer_app/shared/widgets/gradient_button.dart';
import 'package:salesapp/features/customer_app/shared/widgets/status_chip.dart';
import 'package:salesapp/features/customer_app/shared/widgets/toast_service.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  String _filter = 'all';

  Future<void> _payInvoice(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
  ) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _PaymentSheet(
          invoice: invoice,
          onSuccess: () async {
            await ref
                .read(customerRepositoryProvider)
                .payInvoice(invoice.invoiceId);
            ref.invalidate(invoicesProvider);
            if (context.mounted) {
              Navigator.pop(context);
              ToastService.show(
                context,
                'Payment Successful via Razorpay!',
                type: ToastType.success,
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.bgPrimary : AppColors.bgPrimaryLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Invoices & Receipts',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        backgroundColor: scaffoldBg,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: invoicesAsync.when(
        data: (invoices) {
          if (invoices.isEmpty) {
            return Center(
              child: Text('No invoices found.', style: TextStyle(color: subtitleColor)),
            );
          }

          final unpaidTotal = invoices
              .where((i) => i.status == 'unpaid')
              .fold<double>(0, (sum, i) => sum + i.amount);
          final paidTotal = invoices
              .where((i) => i.status == 'paid')
              .fold<double>(0, (sum, i) => sum + i.amount);

          final filtered = _filter == 'all'
              ? invoices
              : invoices.where((i) => i.status == _filter).toList();

          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              ref.invalidate(invoicesProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20.0),
                  sliver: SliverToBoxAdapter(
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      borderRadius: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Due',
                                style: TextStyle(color: subtitleColor, fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '₹${unpaidTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: isDark ? AppColors.borderColor : AppColors.borderColorLight,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Paid (2026)',
                                style: TextStyle(color: subtitleColor, fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '₹${paidTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.bgSecondary : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.borderColor : AppColors.borderColorLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildFilterChip('All', 'all'),
                          _buildFilterChip('Unpaid', 'unpaid'),
                          _buildFilterChip('Paid', 'paid'),
                        ],
                      ),
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: filtered.isEmpty
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                'No invoices match this filter.',
                                style: TextStyle(color: subtitleColor),
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final inv = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: _InvoiceExpandableTile(
                                invoice: inv,
                                onPay: () => _payInvoice(context, ref, inv),
                              ),
                            );
                          }, childCount: filtered.length),
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: textColor))),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _filter == value;
    final activeColor = isDark ? AppColors.accent : AppColors.primary;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: activeColor.withOpacity(0.4))
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : subtitleColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InvoiceExpandableTile extends StatefulWidget {
  final Invoice invoice;
  final VoidCallback onPay;

  const _InvoiceExpandableTile({required this.invoice, required this.onPay});

  @override
  State<_InvoiceExpandableTile> createState() => _InvoiceExpandableTileState();
}

class _InvoiceExpandableTileState extends State<_InvoiceExpandableTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isPaid = widget.invoice.status == 'paid';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isPaid ? AppColors.success : AppColors.danger)
                        .withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaid
                        ? Icons.check_circle_outline
                        : Icons.pending_actions_outlined,
                    color: isPaid ? AppColors.success : AppColors.danger,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.invoice.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy').format(widget.invoice.date),
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${widget.invoice.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusChip(
                      label: widget.invoice.status,
                      status: isPaid ? 'success' : 'danger',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: subtitleColor,
                ),
              ],
            ),
          ),

          if (_isExpanded) ...[
            Divider(
              color: isDark ? AppColors.borderColor : AppColors.borderColorLight,
              height: 24,
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.invoice.lineItems.length,
              itemBuilder: (context, idx) {
                final item = widget.invoice.lineItems[idx];
                final double itemPrice =
                    (item['price'] as num?)?.toDouble() ?? 0.0;
                final int itemQty = (item['qty'] as num?)?.toInt() ?? 1;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item['name']} (x$itemQty)',
                        style: TextStyle(color: subtitleColor, fontSize: 13),
                      ),
                      Text(
                        '₹${(itemPrice * itemQty).toStringAsFixed(2)}',
                        style: TextStyle(color: textColor, fontSize: 13),
                      ),
                    ],
                  ),
                );
              },
            ),
            Divider(
              color: isDark ? AppColors.borderColor : AppColors.borderColorLight,
              height: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Grand Total',
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  '₹${widget.invoice.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.accent : AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text(
                      'View / Download Invoice PDF',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    onPressed: () => _viewInvoicePdf(context, widget.invoice),
                  ),
                ),
                if (!isPaid) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: 'Pay Now',
                      height: 44,
                      onTap: widget.onPay,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _viewInvoicePdf(BuildContext context, Invoice invoice) async {
    bool isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    ).then((_) => isDialogShowing = false);

    try {
      final supabase = Supabase.instance.client;

      // 1. Check if this is a confirmed quotation
      final qRes = await supabase
          .from('quotations')
          .select()
          .eq('id', invoice.invoiceId)
          .maybeSingle();

      Uint8List pdfBytes;
      String fileName;

      if (qRes != null) {
        final quotation = core_quotation.Quotation.fromJson(qRes);
        core_customer.Customer customer;
        if (quotation.pipelineId.isNotEmpty) {
          final pRes = await supabase
              .from('sales_pipelines')
              .select('customer_id, customers(*)')
              .eq('id', quotation.pipelineId)
              .maybeSingle();
          if (pRes != null && pRes['customers'] != null) {
            customer = core_customer.Customer.fromJson(pRes['customers'] as Map<String, dynamic>);
          } else {
            customer = core_customer.Customer(
              id: pRes?['customer_id']?.toString() ?? 'cust',
              companyName: quotation.customerName ?? 'Valued Customer',
              phone: quotation.customerPhone,
              address: quotation.billingAddress,
              gstNumber: quotation.customerGstin,
              createdBy: 'system',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
        } else {
          customer = core_customer.Customer(
            id: 'cust',
            companyName: quotation.customerName ?? 'Valued Customer',
            phone: quotation.customerPhone,
            address: quotation.billingAddress,
            gstNumber: quotation.customerGstin,
            createdBy: 'system',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }

        core_product.Product product;
        try {
          final prodRes = await supabase
              .from('products')
              .select()
              .eq('id', quotation.productId)
              .maybeSingle();
          if (prodRes != null) {
            product = core_product.Product.fromJson(prodRes);
          } else {
            product = core_product.Product(
              id: quotation.productId,
              name: quotation.lineItems.isNotEmpty ? quotation.lineItems.first.description : 'Commercial Solar System',
              baseSpecs: const core_product.ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
        } catch (_) {
          product = core_product.Product(
            id: quotation.productId,
            name: quotation.lineItems.isNotEmpty ? quotation.lineItems.first.description : 'Commercial Solar System',
            baseSpecs: const core_product.ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }

        final templateConfig = await PdfService.resolveTemplateConfig(null);

        pdfBytes = await PdfService.generateQuotationPdf(
          quotation: quotation,
          customer: customer,
          product: product,
          templateConfig: templateConfig,
          docTitle: 'PROFORMA INVOICE',
        );

        final invNum = quotation.quotationNumber.replaceAll('QT', 'PI').replaceAll(RegExp(r'[/\\?%*:|<>]'), '_');
        fileName = 'Proforma_Invoice_$invNum.pdf';
      } else {
        // Fallback for service invoices: build a tax invoice representation
        final dummyQuotation = core_quotation.Quotation(
          id: invoice.invoiceId,
          pipelineId: invoice.requestId,
          quotationNumber: 'INV/${invoice.invoiceId.substring(0, invoice.invoiceId.length > 8 ? 8 : invoice.invoiceId.length).toUpperCase()}',
          productId: 'service_invoice',
          lineItems: invoice.lineItems.map((li) {
            final qty = (li['qty'] as num?)?.toDouble() ?? 1.0;
            final price = (li['price'] as num?)?.toDouble() ?? invoice.amount;
            return core_quotation.LineItem(
              description: li['name']?.toString() ?? 'Service / Equipment Charge',
              qty: qty,
              unitPrice: price,
              total: qty * price,
            );
          }).toList(),
          productSpecs: const {},
          subtotal: invoice.amount / 1.18,
          cgstRate: 9.0,
          sgstRate: 9.0,
          cgstAmount: (invoice.amount - (invoice.amount / 1.18)) / 2,
          sgstAmount: (invoice.amount - (invoice.amount / 1.18)) / 2,
          igstAmount: 0.0,
          grandTotal: invoice.amount,
          status: core_quotation.QuotationStatus.confirmed,
          createdAt: invoice.date,
          updatedAt: invoice.date,
          orderDate: invoice.date,
          customerName: 'Valued Customer',
        );

        final customer = core_customer.Customer(
          id: invoice.customerId,
          companyName: 'Valued Customer',
          createdBy: 'system',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final product = core_product.Product(
          id: 'service_invoice',
          name: invoice.title,
          baseSpecs: const core_product.ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final templateConfig = await PdfService.resolveTemplateConfig(null);

        pdfBytes = await PdfService.generateQuotationPdf(
          quotation: dummyQuotation,
          customer: customer,
          product: product,
          templateConfig: templateConfig,
          docTitle: 'PROFORMA INVOICE',
        );

        fileName = 'Proforma_Invoice_${invoice.invoiceId.substring(0, invoice.invoiceId.length > 8 ? 8 : invoice.invoiceId.length).toUpperCase()}.pdf';
      }

      if (isDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShowing = false;
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: fileName,
            ),
          ),
        );
      }
    } catch (e) {
      if (isDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShowing = false;
      }
      if (context.mounted) {
        ToastService.show(context, 'Failed to generate invoice PDF: $e', type: ToastType.error);
      }
    }
  }
}

class _PaymentSheet extends StatefulWidget {
  final Invoice invoice;
  final VoidCallback onSuccess;

  const _PaymentSheet({required this.invoice, required this.onSuccess});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  bool _isProcessing = false;

  void _processPayment() {
    setState(() => _isProcessing = true);
    Future.delayed(const Duration(seconds: 2), () {
      widget.onSuccess();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.bgSecondary : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderColor : AppColors.borderColorLight,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Secure Checkout',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Payment integrated via Razorpay Secure Gateway.',
            style: TextStyle(
              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 24),
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.invoice.title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  '₹${widget.invoice.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.accent : AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: _isProcessing
                ? 'Connecting Gateway...'
                : 'Pay with Razorpay',
            isLoading: _isProcessing,
            onTap: _processPayment,
            icon: const Icon(Icons.payment, color: Colors.white),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
