// lib/features/quotation/screens/quotation_approval_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/quotation.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';

final pendingQuotationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('quotations')
      .select('*, sales_pipelines(*, customers(*), products(*))')
      .eq('status', 'pending_approval')
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response as List);
});

class QuotationApprovalScreen extends ConsumerWidget {
  const QuotationApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingQuotationsProvider);
    final profile = ref.watch(currentProfileProvider);
    final canApprove = profile?.primaryRole.canApproveQuotations ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quotation Approvals'),
      ),
      body: pendingAsync.when(
        data: (quotes) {
          if (quotes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_outlined, size: 48, color: AppColors.success),
                  SizedBox(height: 12),
                  Text(
                    'All Quotations Approved',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'No pending quotations requiring Service Head approval.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: quotes.length,
            itemBuilder: (context, index) {
              final item = quotes[index];
              final quotation = Quotation.fromJson(item);
              final pipelineData = item['sales_pipelines'] as Map<String, dynamic>? ?? {};
              final customerData = pipelineData['customers'] as Map<String, dynamic>? ?? {};
              final productData = pipelineData['products'] as Map<String, dynamic>? ?? {};

              final customerName = customerData['company_name'] as String? ?? 'Customer';
              final productName = productData['name'] as String? ?? 'Product';

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          quotation.quotationNumber,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(6)),
                          child: const Text('Pending Approval', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Customer: $customerName', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('Product: $productName', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(
                      'Total Amount: Rs. ${NumberFormat('#,##,##0.00', 'en_IN').format(quotation.grandTotal)}',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    if (canApprove)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _handleApproval(context, ref, quotation.id, false),
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _handleApproval(context, ref, quotation.id, true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                              child: const Text('Approve Quote'),
                            ),
                          ),
                        ],
                      )
                    else
                      const Text('Requires Service Head / Admin approval permission.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _handleApproval(BuildContext context, WidgetRef ref, String quotationId, bool isApproved) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final status = isApproved ? 'confirmed' : 'rejected';

      await supabase.from('quotations').update({
        'status': status,
        'approved_by': supabase.auth.currentUser!.id,
        'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', quotationId);

      ref.invalidate(pendingQuotationsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isApproved ? '✓ Quotation approved successfully' : 'Quotation rejected'),
            backgroundColor: isApproved ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}
