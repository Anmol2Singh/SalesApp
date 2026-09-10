// lib/features/amc/screens/warranty_card_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/warranty_card.dart';
import '../../../core/models/user_role.dart';
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

  @override
  Widget build(BuildContext context) {
    final cardAsync = ref.watch(warrantyCardProvider(widget.pipelineId));
    final pipelineAsync = ref.watch(pipelineDetailProvider(widget.pipelineId));
    final profile = ref.watch(currentProfileProvider);
    final canActivate = profile?.primaryRole.canActivateWarrantyCard ?? false;

    final pData = pipelineAsync.value;
    final isAdmin = profile?.primaryRole == UserRole.admin || (profile?.roles.contains(UserRole.admin) ?? false);
    final isCompleted = pData?['status'] == 'completed' || pData?['current_step'] == 'completed' || isAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Warranty Card & Certificate'),
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
                          _item('Warranty Period', '${card.warrantyYears} Year(s) Standard Warranty'),
                          _item('Start Date', card.startDate != null ? DateFormat('dd MMM yyyy').format(card.startDate!) : 'N/A'),
                          _item('End Date', card.endDate != null ? DateFormat('dd MMM yyyy').format(card.endDate!) : 'N/A'),
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

                    ElevatedButton.icon(
                      onPressed: card.isActivated ? () => _downloadPdf(card) : null,
                      icon: const Icon(Icons.file_download),
                      label: Text(card.isActivated ? 'Download Warranty Card PDF' : 'Download Locked (Requires Manager Activation)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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
                    value: selectedYears,
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

      final payload = {
        'pipeline_id': widget.pipelineId,
        'customer_id': widget.customerId,
        'warranty_number': warrantyNum,
        'invoice_number': warrantyNum,
        'customer_name': customerName,
        'customer_phone': phone,
        'customer_email': email,
        'warranty_years': years,
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
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
