// lib/features/amc/screens/amc_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/amc_contract.dart';
import '../../../core/models/amc_service_visit.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../providers/amc_provider.dart';

class AmcDetailScreen extends ConsumerWidget {
  final String amcId;

  const AmcDetailScreen({super.key, required this.amcId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amcAsync = ref.watch(amcDetailProvider(amcId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AMC Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.amcList);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(amcDetailProvider(amcId)),
          ),
        ],
      ),
      body: amcAsync.when(
        data: (contract) => _AmcDetailContent(contract: contract, amcId: amcId),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text('Error: $e'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(amcDetailProvider(amcId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmcDetailContent extends ConsumerWidget {
  final AmcContract contract;
  final String amcId;

  const _AmcDetailContent({required this.contract, required this.amcId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat('#,##,##0.00', 'en_IN');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          _HeaderCard(contract: contract),
          const SizedBox(height: 16),

          // Contract details card
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
                  'Contract Details',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _DetailRow('AMC Number', contract.amcNumber),
                _DetailRow('Status', contract.status.displayName),
                if (contract.startDate != null)
                  _DetailRow(
                      'Start Date', dateFormat.format(contract.startDate!)),
                if (contract.endDate != null)
                  _DetailRow('End Date', dateFormat.format(contract.endDate!)),
                if (contract.contractAmount != null)
                  _DetailRow('Contract Amount',
                      '₹${currencyFormat.format(contract.contractAmount!)}'),
                if (contract.numberOfVisitsIncluded != null)
                  _DetailRow(
                      'Visits Included', '${contract.numberOfVisitsIncluded}'),
                _DetailRow('Visits Completed', contract.visitsProgressText),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // PDF button
          if (contract.status == AmcContractStatus.active ||
              contract.status == AmcContractStatus.expiringSoon ||
              contract.status == AmcContractStatus.expired)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _viewPdf(context, ref),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('View / Print AMC Agreement'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                  side: const BorderSide(color: AppColors.info),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Service visits timeline
          const Text(
            'Service Visits',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          if (contract.serviceVisits == null || contract.serviceVisits!.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text(
                  'No service visits scheduled yet.\nFinalize the contract to generate visit schedule.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...contract.serviceVisits!.map(
              (visit) => _VisitTimelineItem(
                visit: visit,
                isLast: visit == contract.serviceVisits!.last,
                onMarkComplete: () =>
                    _showCompleteVisitSheet(context, ref, visit),
                onMarkMissed: () => _markVisitMissed(context, ref, visit),
              ),
            ),
          const SizedBox(height: 20),

          // Renew button
          if (contract.canBeRenewed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _renewContract(context, ref),
                icon: const Icon(Icons.autorenew),
                label: const Text('Renew Contract'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

          // Approve & Activate button for pending_setup or interested
          if (contract.status == AmcContractStatus.pendingSetup ||
              contract.status == AmcContractStatus.interested) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _approveAndActivateAmc(context, ref),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Approve & Activate AMC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Finalize button for interested/pending_setup
          if (contract.canBeFinalized)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push(
                  '${AppRoutes.amcSetup}?amcId=${contract.id}',
                ),
                icon: const Icon(Icons.edit_document),
                label: Text(
                  contract.status == AmcContractStatus.interested
                      ? 'Finalize AMC Contract'
                      : 'Complete AMC Setup',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _approveAndActivateAmc(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve AMC Contract'),
        content: Text(
          'Are you sure you want to approve contract ${contract.amcNumber} for ${contract.customer?.companyName ?? contract.customer?.customerName ?? "Customer"}? This will activate the contract and grant scheduled maintenance visits.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve & Activate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('amc_contracts').update({
        'status': 'active',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', contract.id);

      // Generate service visits if none exist
      final numVisits = contract.numberOfVisitsIncluded ?? 2;
      final visitsRes = await supabase
          .from('amc_service_visits')
          .select('id')
          .eq('amc_contract_id', contract.id);

      if ((visitsRes as List).isEmpty && contract.startDate != null && contract.endDate != null) {
        final totalDays = contract.endDate!.difference(contract.startDate!).inDays;
        final interval = totalDays / numVisits;
        final visits = <Map<String, dynamic>>[];
        for (int i = 0; i < numVisits; i++) {
          final visitDate = contract.startDate!.add(Duration(days: (interval * (i + 0.5)).round()));
          visits.add({
            'amc_contract_id': contract.id,
            'visit_number': i + 1,
            'scheduled_date': visitDate.toIso8601String().split('T').first,
            'status': 'scheduled',
          });
        }
        try {
          await supabase.from('amc_service_visits').insert(visits);
        } catch (_) {}
      }

      // Customer notification
      try {
        await supabase.from('notifications').insert({
          'user_id': contract.customerId,
          'title': 'AMC Contract Approved & Active! 🛡️',
          'body': 'Your AMC Contract ${contract.amcNumber} is now Active with $numVisits scheduled visits included.',
          'type': 'amc_approved',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      ref.invalidate(amcDetailProvider(amcId));
      ref.invalidate(amcNotifierProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ AMC Contract Approved and Activated Successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve AMC contract: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _viewPdf(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final supabase = ref.read(supabaseClientProvider);

      Map<String, dynamic> templateConfig;
      try {
        final templateData = await supabase
            .from('pdf_templates')
            .select()
            .eq('document_type', 'amc_contract')
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
          'footer_text': 'This is a computer-generated AMC agreement.',
          'terms_default': '',
        };
      }

      final pdfBytes = await PdfService.generateAmcContractPdf(
        contract: contract,
        templateConfig: templateConfig,
      );

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: 'AMC_${contract.amcNumber.replaceAll('/', '_')}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showCompleteVisitSheet(
      BuildContext context, WidgetRef ref, AmcServiceVisit visit) {
    if (visit.status != AmcVisitStatus.scheduled) return;

    final notesController = TextEditingController();
    bool signoff = false;
    DateTime completedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete Visit #${visit.visitNumber}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Completed Date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(completedDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: completedDate,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setSheetState(() => completedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Service Notes',
                  hintText: 'What was done during this visit...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Customer signed off',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14),
                ),
                value: signoff,
                onChanged: (v) => setSheetState(() => signoff = v ?? false),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _completeVisit(
                      context,
                      ref,
                      visit,
                      completedDate,
                      notesController.text.trim(),
                      signoff,
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeVisit(
    BuildContext context,
    WidgetRef ref,
    AmcServiceVisit visit,
    DateTime completedDate,
    String notes,
    bool signoff,
  ) async {
    try {
      final supabase = ref.read(supabaseClientProvider);

      await supabase.from('amc_service_visits').update({
        'status': 'completed',
        'completed_date': completedDate.toIso8601String().split('T').first,
        'service_notes': notes.isEmpty ? null : notes,
        'customer_signoff': signoff,
      }).eq('id', visit.id);

      // Write audit log
      await supabase.from('step_audit_log').insert({
        'amc_contract_id': contract.id,
        'step_name': 'amc_visit',
        'action': 'amc_visit_completed',
        'performed_by': supabase.auth.currentUser!.id,
        'notes':
            'Visit #${visit.visitNumber} completed on ${DateFormat('dd MMM yyyy').format(completedDate)}',
      });

      ref.invalidate(amcDetailProvider(amcId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Visit #${visit.visitNumber} marked as complete'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _markVisitMissed(
      BuildContext context, WidgetRef ref, AmcServiceVisit visit) async {
    if (visit.status != AmcVisitStatus.scheduled) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Visit as Missed'),
        content: Text(
          'Mark visit #${visit.visitNumber} scheduled for ${DateFormat('dd MMM yyyy').format(visit.scheduledDate)} as missed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Mark Missed',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('amc_service_visits')
          .update({'status': 'missed'}).eq('id', visit.id);

      ref.invalidate(amcDetailProvider(amcId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Visit #${visit.visitNumber} marked as missed'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _renewContract(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renew AMC Contract'),
        content: const Text(
          'This will create a new AMC contract pre-filled with the details from this one. You can then edit the dates and amount.',
          style: TextStyle(fontFamily: 'Inter', height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Renew'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Create new AMC contract
      final newStartDate = contract.endDate ?? DateTime.now();
      final newEndDate =
          DateTime(newStartDate.year + 1, newStartDate.month, newStartDate.day);

      final response = await supabase
          .from('amc_contracts')
          .insert({
            'customer_id': contract.customerId,
            'pipeline_id': contract.pipelineId,
            'product_id': contract.productId,
            'status': 'pending_setup',
            'start_date': newStartDate.toIso8601String().split('T').first,
            'end_date': newEndDate.toIso8601String().split('T').first,
            'contract_amount': contract.contractAmount,
            'number_of_visits_included': contract.numberOfVisitsIncluded,
            'terms_text': contract.termsText,
            'created_by': supabase.auth.currentUser!.id,
          })
          .select('id')
          .single();

      final newId = (response as Map)['id'] as String;

      // Write audit log
      await supabase.from('step_audit_log').insert({
        'amc_contract_id': newId,
        'step_name': 'amc_contract',
        'action': 'amc_renewed',
        'performed_by': supabase.auth.currentUser!.id,
        'notes': 'Renewed from ${contract.amcNumber}',
      });

      ref.invalidate(amcNotifierProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ New AMC contract created. Complete the setup.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.push('${AppRoutes.amcSetup}?amcId=$newId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _HeaderCard extends StatelessWidget {
  final AmcContract contract;

  const _HeaderCard({required this.contract});

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
                child: const Icon(Icons.build_circle_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  contract.product?.name ?? 'Unknown Product',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: contract.status.color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  contract.status.displayName,
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
          Row(
            children: [
              const Icon(Icons.business_outlined,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                contract.customer?.companyName ?? '',
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
          Row(
            children: [
              const Icon(Icons.tag, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                contract.amcNumber,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
              if (contract.createdByProfile != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.person_outline,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  contract.createdByProfile!.fullName,
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitTimelineItem extends StatelessWidget {
  final AmcServiceVisit visit;
  final bool isLast;
  final VoidCallback onMarkComplete;
  final VoidCallback onMarkMissed;

  const _VisitTimelineItem({
    required this.visit,
    required this.isLast,
    required this.onMarkComplete,
    required this.onMarkMissed,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: visit.status.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    visit.status.icon,
                    size: 14,
                    color: visit.status.color,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Visit content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: visit.isOverdue
                      ? AppColors.error.withOpacity(0.3)
                      : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Visit #${visit.visitNumber}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: visit.status.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          visit.status.displayName,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: visit.status.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scheduled: ${dateFormat.format(visit.scheduledDate)}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (visit.completedDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Completed: ${dateFormat.format(visit.completedDate!)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (visit.serviceNotes != null &&
                      visit.serviceNotes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        visit.serviceNotes!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                  if (visit.assignedToName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Assigned to: ${visit.assignedToName}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (visit.customerSignoff) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(Icons.verified,
                            size: 14, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          'Customer signed off',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Actions
                  if (visit.isPending) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onMarkComplete,
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Complete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.success,
                              side: const BorderSide(color: AppColors.success),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              textStyle: const TextStyle(
                                  fontFamily: 'Inter', fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: onMarkMissed,
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Missed'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 12),
                            textStyle: const TextStyle(
                                fontFamily: 'Inter', fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
