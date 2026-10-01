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
      .select('*, sales_pipelines(*, customers(*), products(*)), profiles!created_by(full_name)')
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
                    'All Quotations Reviewed',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'No pending quotations requiring Sales Head / Admin approval.',
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
              final profileData = item['profiles'] as Map<String, dynamic>? ?? {};
              final submittedBy = profileData['full_name'] as String? ?? 'Unknown Staff';

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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Submitted by: $submittedBy',
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    if (canApprove)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _handleApproval(context, ref, quotation.id, false, quotation.pipelineId),
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                              child: const Text('Reject / Request Changes'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _handleApproval(context, ref, quotation.id, true, quotation.pipelineId),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                              child: const Text('Approve Quote'),
                            ),
                          ),
                        ],
                      )
                    else
                      const Text('Requires Sales Head / Admin approval permission.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary)),
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

  Future<void> _handleApproval(BuildContext context, WidgetRef ref, String quotationId, bool isApproved, String pipelineId) async {
    String? rejectionRemark;
    if (!isApproved) {
      final controller = TextEditingController();
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Reject Quotation', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
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

      if (isApproved) {
        await supabase.from('quotations').update({
          'status': 'confirmed',
          'approved_by': currentUserId,
          'approved_at': DateTime.now().toIso8601String(),
          'confirmed_by': currentUserId,
          'confirmed_at': DateTime.now().toIso8601String(),
        }).eq('id', quotationId);

        if (pipelineId.isNotEmpty) {
          await supabase.from('sales_pipelines').update({
            'current_step': 'sales_order',
            'notes': 'Quotation approved by ${profile?.fullName ?? "Sales Head / Admin"}.',
          }).eq('id', pipelineId);
        }
      } else {
        await supabase.from('quotations').update({
          'status': 'rejected',
          'approved_by': currentUserId,
          'approved_at': DateTime.now().toIso8601String(),
        }).eq('id', quotationId);

        if (pipelineId.isNotEmpty) {
          await supabase.from('sales_pipelines').update({
            'notes': 'Changes requested: $rejectionRemark',
          }).eq('id', pipelineId);
        }
      }

      ref.invalidate(pendingQuotationsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isApproved ? '✓ Quotation approved successfully' : 'Quotation rejected and feedback saved.'),
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
