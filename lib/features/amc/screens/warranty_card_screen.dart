// lib/features/amc/screens/warranty_card_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/warranty_card.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/widgets/pdf_preview_screen.dart';

final warrantyCardProvider = FutureProvider.family<WarrantyCard?, String>((ref, pipelineId) async {
  try {
    final supabase = ref.watch(supabaseClientProvider);
    final data = await supabase
        .from('warranty_cards')
        .select()
        .eq('pipeline_id', pipelineId)
        .maybeSingle();

    if (data == null) return null;
    return WarrantyCard.fromJson(data);
  } catch (e) {
    // Gracefully fallback if table does not exist or fetch fails
    return null;
  }
});

final pipelineDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, pipelineId) async {
  try {
    final supabase = ref.watch(supabaseClientProvider);
    final data = await supabase
        .from('sales_pipelines')
        .select()
        .eq('id', pipelineId)
        .maybeSingle();
    return data;
  } catch (_) {
    return null;
  }
});

class WarrantyCardScreen extends ConsumerStatefulWidget {
  final String pipelineId;
  final String customerId;

  const WarrantyCardScreen({
    super.key,
    required this.pipelineId,
    required this.customerId,
  });

  @override
  ConsumerState<WarrantyCardScreen> createState() => _WarrantyCardScreenState();
}

class _WarrantyCardScreenState extends ConsumerState<WarrantyCardScreen> {
  bool _isActivating = false;
  bool _isRefreshing = false;
  bool _checkedAutoRefresh = false;

  void _checkAndAutoRefreshGenericCard(WarrantyCard card) {
    if (_checkedAutoRefresh || _isRefreshing) return;
    final hasGeneric = card.productWarranties.isEmpty ||
        card.productWarranties.any((p) =>
            p.productName.toLowerCase() == 'equipment / system' ||
            p.productName.toLowerCase() == 'standard system');
    if (hasGeneric) {
      _checkedAutoRefresh = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refreshWarrantyCard(card, silent: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardAsync = ref.watch(warrantyCardProvider(widget.pipelineId));
    final pipelineAsync = ref.watch(pipelineDetailProvider(widget.pipelineId));
    final profile = ref.watch(currentProfileProvider);
    final canActivate = profile?.primaryRole.canActivateWarrantyCard ?? false;

    final pData = pipelineAsync.value;
    final isCompleted = pData?['status'] == 'completed' || pData?['current_step'] == 'completed';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Warranty Card & Certificate'),
        actions: [
          if (cardAsync.value != null)
            IconButton(
              icon: _isRefreshing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh),
              tooltip: 'Refresh Card',
              onPressed: _isRefreshing ? null : () => _refreshWarrantyCard(cardAsync.value!),
            ),
        ],
      ),
      body: !isCompleted && cardAsync.value == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: AppColors.warningLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline, size: 56, color: AppColors.warning),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Warranty Card Locked 🔒',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This deal is not yet 100% completed. Warranty cards can only be generated after all steps of the deal (Quotation, Sales Order, BOQ, Factory Order, Delivery) are finished and confirmed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : cardAsync.when(
              data: (card) {
                if (card == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.card_membership, size: 54, color: AppColors.textDisabled),
                        const SizedBox(height: 12),
                        const Text('No Warranty Card Created', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        if (canActivate)
                          ElevatedButton.icon(
                            onPressed: _createDefaultWarrantyCard,
                            icon: const Icon(Icons.add),
                            label: const Text('Generate Warranty Card'),
                          )
                        else
                          const Text('Only Admin/Manager can create warranty cards.', style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                _checkAndAutoRefreshGenericCard(card);

                final productWarranties = card.productWarranties;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: card.isActivated ? AppColors.success : AppColors.warning),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('WARRANTY CERTIFICATE', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primary)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: card.isActivated ? AppColors.successLight : AppColors.warningLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  card.isActivated ? 'ACTIVATED' : 'APPROVAL PENDING',
                                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 11, color: card.isActivated ? AppColors.success : AppColors.warning),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          _item('Warranty Number', card.warrantyNumber ?? card.invoiceNumber ?? 'N/A'),
                          _item('Customer Name', card.customerName ?? 'N/A'),
                          _item('Contact Phone', card.customerPhone ?? 'N/A'),
                          _item('Email', card.customerEmail ?? 'N/A'),
                          _item('Overall Coverage', '${card.warrantyYears} Year(s) Max Coverage'),
                          _item('Start Date', card.startDate != null ? DateFormat('dd MMM yyyy').format(card.startDate!) : 'N/A'),
                          _item('End Date', card.endDate != null ? DateFormat('dd MMM yyyy').format(card.endDate!) : 'N/A'),

                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'COVERED PRODUCTS & WARRANTIES',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                '${productWarranties.length} item(s)',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          ...productWarranties.map((p) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.productName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        p.warrantyYears > 0 ? '${p.warrantyYears} Year${p.warrantyYears > 1 ? "s" : ""} (${p.warrantyMonths} Mos)' : '${p.warrantyMonths} Months',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Start: ${p.startDate != null ? DateFormat('dd MMM yyyy').format(p.startDate!) : (card.startDate != null ? DateFormat('dd MMM yyyy').format(card.startDate!) : "N/A")}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    Text(
                                      'Expiry: ${p.endDate != null ? DateFormat('dd MMM yyyy').format(p.endDate!) : (card.endDate != null ? DateFormat('dd MMM yyyy').format(card.endDate!) : "N/A")}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (canActivate && !card.isActivated) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.warning),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Admin/Manager approval is required to activate download capability.',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.warning),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _isActivating ? null : () => _toggleActivation(card.id, true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                              child: const Text('Approve & Activate'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isRefreshing ? null : () => _refreshWarrantyCard(card),
                            icon: _isRefreshing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.refresh, size: 18),
                            label: const Text('Refresh Card'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: card.isActivated ? () => _downloadPdf(card) : null,
                            icon: const Icon(Icons.file_download, size: 18),
                            label: Text(card.isActivated ? 'Download Warranty PDF' : 'Download Locked'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
    );
  }

  Widget _item(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textSecondary)),
          Text(val, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<List<ProductWarrantyItem>> _resolveDealProductsAndWarranties(DateTime startDate) async {
    final supabase = ref.read(supabaseClientProvider);
    final items = <ProductWarrantyItem>[];

    // 1. Fetch inventory items to know inventory warranties
    final inventoryList = <Map<String, dynamic>>[];
    try {
      final invRes = await supabase.from('inventory_items').select('id, item_name, warranty_months');
      for (final r in (invRes as List? ?? [])) {
        inventoryList.add(Map<String, dynamic>.from(r as Map));
      }
    } catch (_) {}

    int getMonthsForName(String name) {
      final lower = name.toLowerCase();
      // Match against inventory item
      for (final inv in inventoryList) {
        final invName = (inv['item_name'] as String? ?? '').toLowerCase();
        if (invName.isNotEmpty && (lower.contains(invName) || invName.contains(lower))) {
          final m = (inv['warranty_months'] as num?)?.toInt();
          if (m != null && m > 0) return m;
        }
      }
      // Defaults as per inventory standards:
      if (lower.contains('heat pump') || lower.contains('heatpump') || lower.contains('izyheat')) {
        return 24; // 2 years
      }
      if (lower.contains('tank') || lower.contains('water tank') || lower.contains('storage tank')) {
        return 60; // 5 years
      }
      if (lower.contains('boom barrier') || lower.contains('barrier')) {
        return 24; // 2 years
      }
      return 12; // 1 year
    }

    // 2. Fetch deal with quotation (take product names from quotation only from deals)
    try {
      final dealRes = await supabase.from('sales_pipelines').select('''
        id,
        product_id,
        products(id, name),
        quotations(id, line_items)
      ''').eq('id', widget.pipelineId).maybeSingle();

      Map<String, dynamic>? quoteData;
      if (dealRes != null && dealRes['quotations'] != null) {
        if (dealRes['quotations'] is Map) {
          quoteData = Map<String, dynamic>.from(dealRes['quotations'] as Map);
        } else if (dealRes['quotations'] is List && (dealRes['quotations'] as List).isNotEmpty) {
          quoteData = Map<String, dynamic>.from((dealRes['quotations'] as List).first as Map);
        }
      }

      // If dealRes quotations line_items is empty or not loaded, query directly from quotations table
      if (quoteData == null || quoteData['line_items'] == null || (quoteData['line_items'] as List).isEmpty) {
        try {
          final qRes = await supabase
              .from('quotations')
              .select('id, line_items')
              .eq('pipeline_id', widget.pipelineId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (qRes != null) {
            quoteData = Map<String, dynamic>.from(qRes);
          }
        } catch (_) {}
      }

      final Map<String, int> foundProducts = {};

      // Requirement: take product names from quotation only from deals
      if (quoteData != null) {
        final lineItems = quoteData['line_items'] as List? ?? [];
        for (final li in lineItems) {
          if (li is Map) {
            final desc = (li['description'] ?? li['item_name'] ?? li['name'])?.toString().trim() ?? '';
            if (desc.isNotEmpty && !foundProducts.keys.any((k) => k.toLowerCase() == desc.toLowerCase())) {
              final months = getMonthsForName(desc);
              foundProducts[desc] = months;
            }
          }
        }
      }

      // Fallback only if quotation has no products
      if (foundProducts.isEmpty && dealRes != null) {
        final prodMap = dealRes['products'] as Map?;
        final mainProdName = prodMap?['name'] as String? ?? '';
        if (mainProdName.isNotEmpty) {
          foundProducts[mainProdName] = getMonthsForName(mainProdName);
        }
      }

      for (final entry in foundProducts.entries) {
        final months = entry.value;
        final years = (months / 12).ceil();
        final endDate = DateTime(startDate.year + years, startDate.month + (months % 12), startDate.day);
        items.add(
          ProductWarrantyItem(
            productName: entry.key,
            warrantyYears: years,
            warrantyMonths: months,
            startDate: startDate,
            endDate: endDate,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error resolving deal products: $e');
    }

    if (items.isEmpty) {
      items.add(
        ProductWarrantyItem(
          productName: 'Equipment / System',
          warrantyYears: 1,
          warrantyMonths: 12,
          startDate: startDate,
          endDate: DateTime(startDate.year + 1, startDate.month, startDate.day),
        ),
      );
    }

    return items;
  }

  Future<void> _refreshWarrantyCard(WarrantyCard existingCard, {bool silent = false}) async {
    setState(() => _isRefreshing = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final startDate = existingCard.startDate ?? DateTime.now();
      final products = await _resolveDealProductsAndWarranties(startDate);

      int maxYears = 1;
      DateTime maxEndDate = existingCard.endDate ?? DateTime(startDate.year + 1, startDate.month, startDate.day);
      for (final p in products) {
        if (p.warrantyYears > maxYears) maxYears = p.warrantyYears;
        if (p.endDate != null && p.endDate!.isAfter(maxEndDate)) {
          maxEndDate = p.endDate!;
        }
      }

      final payload = {
        'amc_details': jsonEncode({
          'products': products.map((p) => p.toJson()).toList(),
          'refreshed_at': DateTime.now().toIso8601String(),
        }),
        'warranty_years': maxYears,
        'end_date': maxEndDate.toIso8601String(),
      };

      await supabase.from('warranty_cards').update(payload).eq('id', existingCard.id);
      ref.invalidate(warrantyCardProvider(widget.pipelineId));

      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Warranty card refreshed with latest deal products and warranties!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing card: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _createDefaultWarrantyCard() async {
    int selectedYears = 1;
    DateTime startDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            DateTime calculatedEndDate = DateTime(startDate.year + selectedYears, startDate.month, startDate.day);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Generate Warranty Card', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Warranty Period (Years):', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: selectedYears,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: [1, 2, 3, 5]
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y Year${y > 1 ? "s" : ""}')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedYears = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Start Date:', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setModalState(() => startDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(startDate), style: const TextStyle(fontSize: 14)),
                          const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Auto-Calculated End Date:', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy').format(calculatedEndDate),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _saveWarrantyCardToDb(selectedYears, startDate, calculatedEndDate);
                  },
                  child: const Text('Confirm & Create', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveWarrantyCardToDb(int years, DateTime start, DateTime end) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      String customerName = 'Valued Customer';
      String phone = '';
      String email = '';

      try {
        final custData = await supabase.from('customers').select().eq('id', widget.customerId).single();
        customerName = custData['customer_name'] as String? ?? custData['contact_person'] as String? ?? custData['company_name'] as String? ?? 'Valued Customer';
        phone = custData['phone'] as String? ?? '';
        email = custData['email'] as String? ?? '';
      } catch (_) {}

      final now = DateTime.now();
      final yearShort = (now.year % 100).toString();
      final nextYearShort = ((now.year + 1) % 100).toString();
      final seq = (now.millisecondsSinceEpoch % 8999) + 1000;
      final warrantyNum = '#WRN/$yearShort-$nextYearShort/$seq';

      final products = await _resolveDealProductsAndWarranties(start);
      int maxYears = years;
      DateTime maxEndDate = end;
      for (final p in products) {
        if (p.warrantyYears > maxYears) maxYears = p.warrantyYears;
        if (p.endDate != null && p.endDate!.isAfter(maxEndDate)) {
          maxEndDate = p.endDate!;
        }
      }

      final payload = {
        'pipeline_id': widget.pipelineId,
        'customer_id': widget.customerId,
        'warranty_number': warrantyNum,
        'invoice_number': warrantyNum,
        'customer_name': customerName,
        'customer_phone': phone,
        'customer_email': email,
        'warranty_years': maxYears,
        'start_date': start.toIso8601String(),
        'end_date': maxEndDate.toIso8601String(),
        'amc_details': jsonEncode({
          'products': products.map((p) => p.toJson()).toList(),
          'created_at': DateTime.now().toIso8601String(),
        }),
        'is_activated': false,
      };

      await supabase.from('warranty_cards').insert(payload);
      ref.invalidate(warrantyCardProvider(widget.pipelineId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warranty Card generated successfully!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating warranty card: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _toggleActivation(String cardId, bool activate) async {
    setState(() => _isActivating = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('warranty_cards').update({
        'is_activated': activate,
        'activated_by': supabase.auth.currentUser!.id,
        'activated_at': DateTime.now().toIso8601String(),
      }).eq('id', cardId);
      ref.invalidate(warrantyCardProvider(widget.pipelineId));
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  Future<void> _downloadPdf(WarrantyCard card) async {
    final pdfBytes = await PdfService.generateWarrantyCardPdf(
      card: card,
      templateConfig: {'company_name': 'INSIYA SOLAR INDUSTRY'},
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PdfPreviewScreen(pdfBytes: pdfBytes, fileName: 'WarrantyCard_${card.invoiceNumber}.pdf'),
        ),
      );
    }
  }
}
