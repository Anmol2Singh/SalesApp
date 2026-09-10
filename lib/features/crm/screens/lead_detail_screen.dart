// lib/features/crm/screens/lead_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../data/models/lead_model.dart';
import '../data/models/prospect_model.dart';
import '../services/crm_pdf_service.dart';
import '../providers/crm_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../quotation/screens/quotation_form_screen.dart';
import '../../../core/models/quotation.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';

class LeadDetailScreen extends ConsumerWidget {
  final String id;

  const LeadDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lead = ref.watch(leadByIdProvider(id));
    final prospect = lead?.prospectId != null ? ref.watch(prospectByIdProvider(lead!.prospectId!)) : null;
    final profile = ref.watch(currentProfileProvider);
    final isSalesOrAdmin = profile?.primaryRole.isSalesOrAdmin ?? false;

    if (lead == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Lead Details')),
        body: const Center(child: Text('Lead not found or loading...', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final displayName = (lead.prospectName != null && lead.prospectName!.isNotEmpty)
        ? lead.prospectName!
        : (prospect?.name ?? 'Lead #${lead.id.substring(0, 6)}');
    final displayPhone = (lead.contactPhone != null && lead.contactPhone!.isNotEmpty)
        ? lead.contactPhone!
        : (prospect?.phone ?? '');
    final displayEmail = prospect?.email;

    final isConverted = lead.convertedToCustomerId != null || lead.status == 'Won';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Download Communication & Lead PDF',
            onPressed: () => _downloadReportPdf(context, ref, lead, prospect),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(leadsProvider.notifier).load(refresh: true);
              ref.read(leadCommunicationsProvider(lead.id).notifier).load();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Lead Header Card
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: isConverted ? AppColors.success.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                          child: Icon(
                            isConverted ? Icons.check_circle : Icons.trending_up,
                            size: 32,
                            color: isConverted ? AppColors.success : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lead.productName,
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              if (displayPhone.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(displayPhone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Quick Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (displayPhone.isNotEmpty) ...[
                          _QuickActionButton(
                            icon: Icons.phone,
                            label: 'Call',
                            color: AppColors.primary,
                            onTap: () => _makePhoneCall(context, ref, lead.id, displayPhone),
                          ),
                          const SizedBox(width: 24),
                          _QuickActionButton(
                            icon: Icons.chat,
                            label: 'WhatsApp',
                            color: const Color(0xFF25D366),
                            onTap: () => _openWhatsApp(context, ref, lead.id, displayPhone),
                          ),
                        ],
                        if (displayEmail != null && displayEmail.isNotEmpty) ...[
                          const SizedBox(width: 24),
                          _QuickActionButton(
                            icon: Icons.email,
                            label: 'Email',
                            color: Colors.blue,
                            onTap: () => _sendEmail(context, ref, lead.id, displayEmail),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Deal Details Card
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Deal Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        _StatusDropdown(leadId: lead.id, currentStatus: lead.status, isConverted: isConverted),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.solar_power_outlined, 'Product', lead.productName),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.currency_rupee, 'Est. Value', '₹${lead.estimatedValue.toStringAsFixed(2)}'),
                    if (lead.expectedDate != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.event_outlined,
                        'Expected Close',
                        '${lead.expectedDate!.day.toString().padLeft(2, '0')}/${lead.expectedDate!.month.toString().padLeft(2, '0')}/${lead.expectedDate!.year}',
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.calendar_today_outlined,
                      'Created Date',
                      '${lead.createdAt.day.toString().padLeft(2, '0')}/${lead.createdAt.month.toString().padLeft(2, '0')}/${lead.createdAt.year}',
                    ),
                    if (lead.capacity != null && lead.capacity!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.speed_outlined, 'Capacity', lead.capacity!),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.assignment_ind_outlined, size: 20, color: AppColors.textSecondary),
                        const SizedBox(width: 12),
                        const SizedBox(width: 110, child: Text('Salesperson', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lead.assignedByName ?? 'Not Assigned',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: lead.assignedByName != null ? AppColors.textPrimary : Colors.grey,
                                  ),
                                ),
                              ),
                              if (isSalesOrAdmin)
                                InkWell(
                                  onTap: () => _showAssignLeadSheet(context, ref, lead),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      lead.assignedTo != null ? 'Reassign' : 'Assign',
                                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (lead.convertedByName != null && lead.convertedByName!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.verified_user_outlined, 'Converted by', lead.convertedByName!),
                    ],
                    if (lead.notes != null && lead.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Notes / Requirements:', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(lead.notes!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Lead Quotations & Revision History
            _LeadQuotationsSection(lead: lead, isSalesOrAdmin: isSalesOrAdmin),
            const SizedBox(height: 16),

            // 4. Communication History (Only inside Lead)
            _LeadCommunicationSection(
              leadId: lead.id,
              onDownloadPdf: () => _downloadReportPdf(context, ref, lead, prospect),
            ),
            const SizedBox(height: 24),

            // 4. Bottom Action
            if (isConverted)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.success,
                  side: const BorderSide(color: AppColors.success),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (lead.convertedToCustomerId != null) {
                    context.push('/customers/${lead.convertedToCustomerId}');
                  } else {
                    context.go('/crm/customers');
                  }
                },
                icon: const Icon(Icons.check_circle, color: AppColors.success),
                label: const Text('Deal Won • View Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            else if (isSalesOrAdmin)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showConvertToCustomerSheet(context, ref, lead, displayName, displayPhone, displayEmail, prospect?.address, prospect?.gst),
                icon: const Icon(Icons.star, color: Colors.white),
                label: const Text('Convert to Customer (Won)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReportPdf(BuildContext context, WidgetRef ref, Lead lead, Prospect? prospect) async {
    try {
      final comms = ref.read(leadCommunicationsProvider(lead.id)).value ?? [];
      final pdfBytes = await CrmPdfService.generateLeadReportPdf(
        lead: lead,
        prospect: prospect,
        communications: comms,
      );
      final cleanName = (lead.prospectName ?? 'Lead').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = '${cleanName}_Communication_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: fileName,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      ],
    );
  }

  void _showAssignLeadSheet(BuildContext context, WidgetRef ref, Lead lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return _AssignLeadDetailSheet(lead: lead);
      },
    );
  }

  void _showConvertToCustomerSheet(
    BuildContext context,
    WidgetRef ref,
    Lead lead,
    String defaultName,
    String defaultPhone,
    String? defaultEmail,
    String? defaultAddress,
    String? defaultGst,
  ) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: defaultName);
    final phoneCtrl = TextEditingController(text: defaultPhone);
    final emailCtrl = TextEditingController(text: defaultEmail ?? '');
    final addressCtrl = TextEditingController(text: defaultAddress ?? '');
    final gstCtrl = TextEditingController(text: defaultGst ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Convert Lead to Customer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          IconButton(onPressed: () => ctx.pop(), icon: const Icon(Icons.close)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Marking this deal as Won will create a permanent Customer account for "${lead.productName}".',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Customer / Company Name *', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone Number *', border: OutlineInputBorder()),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email Address (Optional)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(labelText: 'Address (Optional)', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: gstCtrl,
                        decoration: const InputDecoration(labelText: 'GST Number (Optional)', border: OutlineInputBorder()),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheetState(() => isSaving = true);
                                try {
                                  await ref.read(leadsProvider.notifier).convertToCustomer(
                                        leadId: lead.id,
                                        customerName: nameCtrl.text.trim(),
                                        phone: phoneCtrl.text.trim(),
                                        email: emailCtrl.text.trim(),
                                        address: addressCtrl.text.trim(),
                                        gstNumber: gstCtrl.text.trim(),
                                      );
                                  if (ctx.mounted) {
                                    ctx.pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Lead converted to Customer successfully!'), backgroundColor: AppColors.success),
                                    );
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                                    );
                                  }
                                } finally {
                                  if (ctx.mounted) setSheetState(() => isSaving = false);
                                }
                              },
                        child: isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Confirm Won & Create Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _makePhoneCall(BuildContext context, WidgetRef ref, String leadId, String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final uri = Uri.parse('tel:$cleanPhone');
      await launchUrl(uri);
      _promptLogCommunication(context, ref, leadId, 'Call');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not initiate phone call: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _openWhatsApp(BuildContext context, WidgetRef ref, String leadId, String phone) async {
    try {
      var cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length == 10) {
        cleanPhone = '91$cleanPhone';
      }
      final uri = Uri.parse('https://wa.me/$cleanPhone');
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      _promptLogCommunication(context, ref, leadId, 'WhatsApp');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _sendEmail(BuildContext context, WidgetRef ref, String leadId, String email) async {
    try {
      final uri = Uri.parse('mailto:${email.trim()}');
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      _promptLogCommunication(context, ref, leadId, 'Email');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Email app: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _promptLogCommunication(BuildContext context, WidgetRef ref, String leadId, String type) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (context.mounted) {
        _showLogDialog(context, ref, leadId, defaultType: type);
      }
    });
  }

  static void _showLogDialog(BuildContext context, WidgetRef ref, String leadId, {String defaultType = 'Call'}) {
    final summaryCtrl = TextEditingController();
    String selectedType = defaultType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Log Communication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      IconButton(onPressed: () => ctx.pop(), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Interaction Type', border: OutlineInputBorder()),
                    items: ['Call', 'WhatsApp', 'Email', 'Meeting', 'Note']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: summaryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Summary / Outcome *',
                      hintText: 'e.g. Discussed pricing, customer requested 10% discount',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      if (summaryCtrl.text.trim().isEmpty) return;
                      await ref.read(leadCommunicationsProvider(leadId).notifier).logCommunication(
                            type: selectedType,
                            summary: summaryCtrl.text.trim(),
                          );
                      if (ctx.mounted) {
                        ctx.pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Interaction logged!'), backgroundColor: AppColors.success),
                        );
                      }
                    },
                    child: const Text('Save Interaction', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LeadCommunicationSection extends ConsumerWidget {
  final String leadId;
  final VoidCallback onDownloadPdf;

  const _LeadCommunicationSection({required this.leadId, required this.onDownloadPdf});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commsAsync = ref.watch(leadCommunicationsProvider(leadId));

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Communication Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, size: 20, color: AppColors.primary),
                      tooltip: 'Download PDF',
                      onPressed: onDownloadPdf,
                    ),
                    TextButton.icon(
                      onPressed: () => LeadDetailScreen._showLogDialog(context, ref, leadId),
                      icon: const Icon(Icons.add_comment_outlined, size: 18),
                      label: const Text('Add Log', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            commsAsync.when(
              data: (comms) {
                if (comms.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text('No interactions logged yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: comms.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final comm = comms[index];
                    IconData icon = Icons.note;
                    Color color = Colors.grey;

                    if (comm.type == 'Call') {
                      icon = Icons.phone;
                      color = AppColors.primary;
                    } else if (comm.type == 'WhatsApp') {
                      icon = Icons.chat;
                      color = const Color(0xFF25D366);
                    } else if (comm.type == 'Email') {
                      icon = Icons.email;
                      color = Colors.blue;
                    } else if (comm.type == 'Meeting') {
                      icon = Icons.groups;
                      color = Colors.purple;
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(icon, size: 16, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(comm.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                  Text(
                                    '${comm.createdAt.day}/${comm.createdAt.month} ${comm.createdAt.hour.toString().padLeft(2, '0')}:${comm.createdAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(comm.summary, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error loading logs: $e', style: const TextStyle(color: AppColors.error))),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDropdown extends ConsumerWidget {
  final String leadId;
  final String currentStatus;
  final bool isConverted;

  const _StatusDropdown({required this.leadId, required this.currentStatus, required this.isConverted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isConverted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(12)),
        child: const Text('Won', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
      );
    }

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentStatus,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          items: ['New', 'In Progress', 'Negotiating', 'Won', 'Lost']
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              ref.read(leadsProvider.notifier).updateStatus(leadId, val);
            }
          },
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AssignLeadDetailSheet extends ConsumerStatefulWidget {
  final Lead lead;

  const _AssignLeadDetailSheet({required this.lead});

  @override
  ConsumerState<_AssignLeadDetailSheet> createState() =>
      _AssignLeadDetailSheetState();
}

class _AssignLeadDetailSheetState extends ConsumerState<_AssignLeadDetailSheet> {
  String? _selectedSalesUserId;
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
        res = await db.from('profiles').select('id, full_name, primary_role, roles, email').order('full_name');
      } catch (_) {
        res = await db.from('profiles').select().order('created_at', ascending: false);
      }

      final list = <Map<String, dynamic>>[];
      for (final r in (res as List? ?? [])) {
        final role = (r['primary_role'] as String? ?? '').toLowerCase();
        final rolesList = (r['roles'] is List)
            ? (r['roles'] as List).map((e) => e.toString().toLowerCase()).toList()
            : [];
        if (role == 'sales' ||
            role == 'admin' ||
            role == 'manager' ||
            role == 'sales_head' ||
            role.contains('sales') ||
            rolesList.contains('sales') ||
            rolesList.contains('sales_head') ||
            rolesList.contains('admin')) {
          list.add(r as Map<String, dynamic>);
        }
      }

      final List<dynamic> rawStaffList = (res is List) ? res : [];
      final finalList = list.isNotEmpty
          ? list
          : rawStaffList
              .where((r) {
                final role = (r['primary_role'] as String? ?? '').toLowerCase();
                return role != 'customer' && role != 'technician';
              })
              .map((r) => r as Map<String, dynamic>)
              .toList();

      if (mounted) {
        setState(() {
          _salesStaff = finalList;
          _selectedSalesUserId = widget.lead.assignedTo ??
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
      await ref.read(leadsProvider.notifier).assignLead(
            leadId: widget.lead.id,
            salesUserId: _selectedSalesUserId!,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Lead assigned to salesperson successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning lead: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Assign / Transfer Lead',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Assign "${widget.lead.prospectName ?? "this lead"}" to a sales representative.',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_fetchingStaff)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_salesStaff.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No sales representatives found.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedSalesUserId,
              decoration: const InputDecoration(
                labelText: 'Select Sales Representative',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_pin_outlined),
              ),
              items: _salesStaff.map((s) {
                final name = s['full_name'] as String? ?? s['email'] as String? ?? 'Staff';
                final role = (s['primary_role'] as String? ?? 'STAFF').toUpperCase();
                return DropdownMenuItem<String>(
                  value: s['id'] as String,
                  child: Text('$name ($role)'),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedSalesUserId = val),
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isLoading || _selectedSalesUserId == null ? null : _assign,
            child: _isLoading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Confirm Assignment', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _LeadQuotationsSection extends ConsumerStatefulWidget {
  final Lead lead;
  final bool isSalesOrAdmin;

  const _LeadQuotationsSection({
    required this.lead,
    required this.isSalesOrAdmin,
  });

  @override
  ConsumerState<_LeadQuotationsSection> createState() =>
      _LeadQuotationsSectionState();
}

class _LeadQuotationsSectionState
    extends ConsumerState<_LeadQuotationsSection> {
  bool _isLoading = true;
  List<Quotation> _quotations = [];

  @override
  void initState() {
    super.initState();
    _loadQuotations();
  }

  Future<void> _loadQuotations() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase
          .from('quotations')
          .select()
          .eq('lead_id', widget.lead.id)
          .order('revision', ascending: false);

      final list = (res as List)
          .map((json) => Quotation.fromJson(json as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _quotations = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _viewPdf(Quotation quot) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      Map<String, dynamic> templateConfig;
      try {
        final tData = await supabase
            .from('pdf_templates')
            .select()
            .eq('document_type', 'quotation')
            .single();
        templateConfig = tData['template_config'] as Map<String, dynamic>;
      } catch (_) {
        templateConfig = {
          'company_name': 'INSIYA SOLAR INDUSTRY',
          'company_address':
              'GAT NO 133/1, LAND AREA 10, KOREGAON BHIMA, SHIRUR, Ratnagiri, Maharashtra - 412216, India',
          'company_phone': '9292922992',
          'company_email': 'insiyasolarindustry@gmail.com',
          'company_gst': '27AAOPI2766H1ZE',
          'footer_text': 'Thank you for your business.',
        };
      }

      final customer = Customer(
        id: widget.lead.id,
        companyName: quot.customerName ?? widget.lead.prospectName ?? 'Customer',
        phone: quot.customerPhone ?? widget.lead.contactPhone ?? '',
        address: quot.billingAddress ?? '',
        gstNumber: quot.customerGstin,
        createdBy: widget.lead.assignedTo ?? '',
        createdAt: quot.createdAt,
        updatedAt: quot.updatedAt,
      );

      final product = Product(
        id: 'prod',
        name: widget.lead.productName,
        category: 'Solar',
        baseSpecs: const ProductBaseSpecs(
            quotationFields: [], boqRequiredFields: []),
        isActive: true,
        createdAt: quot.createdAt,
        updatedAt: quot.updatedAt,
      );

      final pdfBytes = await PdfService.generateQuotationPdf(
        quotation: quot,
        customer: customer,
        product: product,
        templateConfig: templateConfig,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName:
                  'Quotation_Rev${quot.revision}_${quot.quotationNumber.replaceAll('/', '_')}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rendering PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openCreateQuotation({Quotation? initialQuotation}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => QuotationFormScreen(
          leadId: widget.lead.id,
          initialQuotation: initialQuotation,
          revisionNumber: initialQuotation != null ? initialQuotation.revision + 1 : null,
        ),
      ),
    );
    _loadQuotations();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##,##0.00', 'en_IN');

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.request_quote_outlined, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Quotations & Revisions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_quotations.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_quotations.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (widget.isSalesOrAdmin)
                  ElevatedButton.icon(
                    onPressed: () => _openCreateQuotation(),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text(
                      'Quotation',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(80, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_quotations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.description_outlined, size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      const Text(
                        'No quotation generated for this lead yet.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      if (widget.isSalesOrAdmin) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _openCreateQuotation(),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Generate First Quotation (Rev 1)'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              ..._quotations.map((quot) {
                final isLatest = _quotations.first.id == quot.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLatest ? const Color(0xFFF0F7FF) : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isLatest ? const Color(0xFF93C5FD) : AppColors.border,
                      width: isLatest ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Rev ${quot.revision}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (isLatest) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'LATEST',
                                    style: TextStyle(
                                      color: Color(0xFF1D4ED8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          _buildStatusBadge(quot.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        quot.quotationNumber.isNotEmpty
                            ? quot.quotationNumber
                            : 'Quote #${quot.id.substring(0, 8)}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(quot.createdAt),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          Text(
                            '₹${currencyFormat.format(quot.grandTotal)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _viewPdf(quot),
                            icon: const Icon(Icons.picture_as_pdf, size: 14),
                            label: const Text('View PDF', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: const Size(60, 30),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          if (widget.isSalesOrAdmin) ...[
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _openCreateQuotation(initialQuotation: quot),
                              icon: const Icon(Icons.history_edu, size: 14, color: Colors.white),
                              label: Text(
                                'Revise (Rev ${quot.revision + 1})',
                                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: const Size(60, 30),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(QuotationStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case QuotationStatus.confirmed:
        bg = AppColors.successLight;
        fg = AppColors.success;
        label = 'Confirmed';
        break;
      case QuotationStatus.pendingApproval:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        label = 'Pending Approval';
        break;
      case QuotationStatus.rejected:
        bg = AppColors.errorLight;
        fg = AppColors.error;
        label = 'Rejected';
        break;
      case QuotationStatus.draft:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        label = 'Draft';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
