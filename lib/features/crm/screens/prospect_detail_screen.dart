import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/searchable_dropdown.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/models/prospect_model.dart';
import '../providers/crm_providers.dart';
import '../../../core/services/record_edit_permissions.dart';
import '../widgets/crm_delete_dialog.dart';

class ProspectDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const ProspectDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ProspectDetailScreen> createState() => _ProspectDetailScreenState();
}

class _ProspectDetailScreenState extends ConsumerState<ProspectDetailScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(prospectsProvider.notifier).load();
    });
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await Future.wait([
        ref.read(prospectsProvider.notifier).load(refresh: false),
        ref.read(leadsProvider.notifier).load(refresh: false),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('✓ Prospect details refreshed'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prospectsAsync = ref.watch(prospectsProvider);
    final prospect = ref.watch(prospectByIdProvider(widget.id));
    final profile = ref.watch(currentProfileProvider);

    if (prospect == null) {
      if (prospectsAsync.isLoading) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Prospect Details')),
          body: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading prospect details...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Prospect Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/crm/prospects');
              }
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Prospect Not Found',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This prospect may have been deleted or removed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/crm/prospects');
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to Prospects'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final leads = ref.watch(leadsProvider).value ?? [];
    final hasValidLead = prospect.convertedToLeadId != null &&
        leads.any((l) => l.id == prospect.convertedToLeadId);
    final isConverted = hasValidLead;

    // If prospect references a deleted lead, silently clean it up in DB
    if (prospect.convertedToLeadId != null && !hasValidLead) {
      ref.read(supabaseClientProvider)
          .from('crm_prospects')
          .update({'converted_to_lead_id': null})
          .eq('id', prospect.id)
          .then((_) {});
    }

    final isSalesOrAdmin = profile?.primaryRole.isSalesOrAdmin ?? false;
    final isAdmin = profile?.primaryRole == UserRole.admin || profile?.primaryRole == UserRole.manager;
    final isOnlyAdmin = profile?.primaryRole == UserRole.admin || profile?.roles.contains(UserRole.admin) == true;
    final isSalesRole = profile?.primaryRole == UserRole.sales || (profile?.roles.contains(UserRole.sales) ?? false);
    final isAssignedToMe = prospect.assignedTo != null && prospect.assignedTo == profile?.id;
    final isCreatedByMe = prospect.createdBy == profile?.id;
    final isTransferredAway = isCreatedByMe && prospect.assignedTo != null && prospect.assignedTo != profile?.id;

    final canEdit = RecordEditPermissions.canEditRecord(
      userRole: profile?.primaryRole,
      allRoles: profile?.roles ?? [],
      currentUserId: profile?.id,
      creatorId: prospect.createdBy,
      assigneeId: prospect.assignedTo,
    );

    // Can convert if: isSalesOrAdmin AND (Admin OR Assigned Salesperson OR Creator Salesperson without assignment)
    final canConvert = !isConverted && isSalesOrAdmin && (isAdmin || isAssignedToMe || (isSalesRole && prospect.assignedTo == null));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(prospect.name),
        actions: [
          if (canEdit && !isConverted)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Prospect',
              onPressed: () => _showEditProspectModal(context, ref, prospect),
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              tooltip: 'Transfer / Assign Salesperson',
              onPressed: () => _showTransferModal(context, ref, prospect),
            ),
          if (isOnlyAdmin)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171), size: 20),
                tooltip: 'Delete Prospect (Admin)',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => _confirmDeleteProspect(context, ref, prospect),
              ),
            ),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isRefreshing ? null : _handleRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isRefreshing) const LinearProgressIndicator(minHeight: 2.5),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isAdmin && prospect.reassignmentRequested)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⚠️ REASSIGNMENT REQUESTED',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.brown,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Reason: "${prospect.reassignmentReason ?? 'Salesperson requested reassignment'}"',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _showTransferModal(context, ref, prospect),
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

            // Header Profile Card
            Card(
              elevation: 0,
              color: isAssignedToMe ? const Color(0xFFFFFBEB) : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isAssignedToMe ? const Color(0xFFF59E0B) : AppColors.border,
                  width: isAssignedToMe ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: isConverted
                          ? AppColors.success.withOpacity(0.1)
                          : (isAssignedToMe ? const Color(0xFFFEF3C7) : AppColors.primary.withOpacity(0.1)),
                      child: Icon(
                        isConverted
                            ? Icons.check_circle
                            : (isAssignedToMe ? Icons.assignment_ind : Icons.person),
                        size: 40,
                        color: isConverted
                            ? AppColors.success
                            : (isAssignedToMe ? const Color(0xFFD97706) : AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      prospect.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    if (prospect.company != null && prospect.company!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(prospect.company!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                    if (isAssignedToMe) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stars, size: 14, color: Color(0xFFD97706)),
                            SizedBox(width: 6),
                            Text(
                              '🎯 Transferred / Assigned by Admin to You',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Quick Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _QuickActionButton(
                          icon: Icons.phone,
                          label: 'Call',
                          color: AppColors.primary,
                          onTap: () => _makePhoneCall(prospect.phone),
                        ),
                        const SizedBox(width: 24),
                        _QuickActionButton(
                          icon: Icons.chat,
                          label: 'WhatsApp',
                          color: const Color(0xFF25D366),
                          onTap: () => _openWhatsApp(prospect.phone),
                        ),
                        if (prospect.email != null && prospect.email!.isNotEmpty) ...[
                          const SizedBox(width: 24),
                          _QuickActionButton(
                            icon: Icons.email,
                            label: 'Email',
                            color: Colors.blue,
                            onTap: () => _sendEmail(prospect.email!),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Contact & Info Card
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
                    const Text('Prospect Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.phone_outlined, 'Phone', prospect.phone),
                    if (prospect.email != null && prospect.email!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.email_outlined, 'Email', prospect.email!),
                    ],
                    if (prospect.address != null && prospect.address!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.location_on_outlined, 'Address', prospect.address!),
                    ],
                    if (prospect.gst != null && prospect.gst!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.receipt_long_outlined, 'GST Number', prospect.gst!),
                    ],
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.source_outlined, 'Lead Source', prospect.source),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.person_outline,
                      'Added By',
                      '${prospect.createdByName ?? "Staff"} (${(prospect.createdByRole ?? "STAFF").toUpperCase()})',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.assignment_ind_outlined, size: 20, color: AppColors.textSecondary),
                        const SizedBox(width: 12),
                        const SizedBox(
                          width: 110,
                          child: Text(
                            'Assigned To',
                            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  prospect.assignedByName ?? (prospect.assignedTo != null ? 'Assigned' : 'Not Assigned'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: (prospect.assignedByName != null || prospect.assignedTo != null)
                                        ? AppColors.textPrimary
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              if (isAdmin)
                                InkWell(
                                  onTap: () => _showTransferModal(context, ref, prospect),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      prospect.assignedTo != null ? 'Reassign' : 'Assign',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.calendar_today_outlined,
                      'Created Date',
                      '${prospect.createdAt.day.toString().padLeft(2, '0')}/${prospect.createdAt.month.toString().padLeft(2, '0')}/${prospect.createdAt.year}',
                    ),
                    if (prospect.notes != null && prospect.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.note_alt_outlined, 'Notes', prospect.notes!),
                    ],
                    if (isConverted) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.verified, color: AppColors.success, size: 20),
                          const SizedBox(width: 12),
                          const Text('Status: ', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Converted to Lead', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            if (isConverted)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  context.push('/crm/leads/${prospect.convertedToLeadId}');
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View Qualified Lead', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            else if (canConvert) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showConvertToLeadSheet(context, ref, prospect),
                icon: const Icon(Icons.trending_up, color: Colors.white),
                label: const Text('Convert to Lead', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    foregroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showTransferModal(context, ref, prospect),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Transfer / Reassign to Sales Rep', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ] else if (isSalesRole) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.orange),
                    foregroundColor: Colors.orange.shade800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showRequestReassignDialog(context, ref, prospect),
                  icon: const Icon(Icons.outgoing_mail),
                  label: const Text('Request Admin to Reassign Prospect', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: Colors.grey.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isTransferredAway
                            ? 'Transferred to ${prospect.assignedByName ?? "another sales rep"}. View only.'
                            : 'Prospect logged by you. Sales team will handle follow-up & conversion.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      ],
    );
  }

  void _showEditProspectModal(BuildContext context, WidgetRef ref, Prospect prospect) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _EditProspectSheet(prospect: prospect),
      ),
    );
  }

  void _showConvertToLeadSheet(BuildContext context, WidgetRef ref, Prospect prospect) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ConvertToLeadForm(prospect: prospect),
        );
      },
    );
  }

  void _showTransferModal(BuildContext context, WidgetRef ref, Prospect prospect) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return _AssignProspectDetailSheet(prospect: prospect);
      },
    );
  }

  void _showRequestReassignDialog(BuildContext context, WidgetRef ref, Prospect prospect) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Reassignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request Admin to transfer "${prospect.name}" to another salesperson.'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason for reassignment (Optional)',
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
              Navigator.pop(ctx);
              await ref.read(prospectsProvider.notifier).requestTransfer(
                    prospectId: prospect.id,
                    prospectName: prospect.name,
                    reason: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Reassignment request sent to Admin successfully.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Send Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _confirmDeleteProspect(BuildContext context, WidgetRef ref, Prospect prospect) async {
    final isConverted = prospect.convertedToLeadId != null;
    final supabase = ref.read(supabaseClientProvider);
    String? customerId;

    if (isConverted) {
      try {
        final leadRes = await supabase
            .from('crm_leads')
            .select('converted_to_customer_id')
            .eq('id', prospect.convertedToLeadId!)
            .maybeSingle();
        customerId = leadRes?['converted_to_customer_id'] as String?;
      } catch (_) {}

      if (customerId == null) {
        try {
          final custRes = await supabase
              .from('customers')
              .select('id')
              .eq('phone', prospect.phone)
              .maybeSingle();
          customerId = custRes?['id'] as String?;
        } catch (_) {}
      }
    }

    if (!context.mounted) return;

    if (customerId != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => CrmDeleteConvertedDialog(
          recordName: prospect.name,
          recordType: 'Prospect',
        ),
      );

      if (choice == null || choice == 'cancel') return;
      final isBoth = choice == 'crm_and_customer';

      if (!context.mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => CrmDeleteConfirmDialog(
          title: isBoth ? 'Confirm Permanent Delete' : 'Delete from CRM Only',
          message: isBoth
              ? 'Are you sure you want to permanently delete "${prospect.name}" from CRM AND remove their customer profile? This action cannot be undone.'
              : 'Are you sure you want to remove "${prospect.name}" from CRM? Their customer account and sales history will remain safely preserved.',
          confirmLabel: isBoth ? 'Delete Both' : 'Delete from CRM',
          isDestructive: true,
        ),
      );

      if (confirm == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        isBoth ? 'Deleting from CRM & Customers...' : 'Deleting prospect...',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        try {
          await ref.read(prospectsProvider.notifier).deleteProspect(
                prospectId: prospect.id,
                deleteCustomer: isBoth,
                customerId: customerId,
              );
          await ref.read(leadsProvider.notifier).load();

          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // dismiss progress dialog
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/crm/prospects');
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isBoth
                            ? '✓ Prospect and customer record deleted successfully'
                            : '✓ Prospect deleted successfully',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // dismiss progress dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Error deleting prospect: $e'),
                    ),
                  ],
                ),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => CrmDeleteConfirmDialog(
          title: 'Delete Prospect',
          message: 'Are you sure you want to delete prospect "${prospect.name}"? This action cannot be undone.',
          confirmLabel: 'Delete',
          isDestructive: true,
        ),
      );

      if (confirm == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        'Deleting prospect...',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        try {
          await ref.read(prospectsProvider.notifier).deleteProspect(prospectId: prospect.id);
          await ref.read(leadsProvider.notifier).load();

          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // dismiss progress dialog
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/crm/prospects');
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '✓ Prospect deleted successfully',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // dismiss progress dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Error deleting prospect: $e'),
                    ),
                  ],
                ),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    }
  }
}

class _EditProspectSheet extends ConsumerStatefulWidget {
  final Prospect prospect;
  const _EditProspectSheet({required this.prospect});

  @override
  ConsumerState<_EditProspectSheet> createState() => _EditProspectSheetState();
}

class _EditProspectSheetState extends ConsumerState<_EditProspectSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _notesCtrl;
  late String _source;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.prospect.name);
    _phoneCtrl = TextEditingController(text: widget.prospect.phone);
    _emailCtrl = TextEditingController(text: widget.prospect.email ?? '');
    _addressCtrl = TextEditingController(text: widget.prospect.address ?? '');
    _gstCtrl = TextEditingController(text: widget.prospect.gst ?? '');
    _companyCtrl = TextEditingController(text: widget.prospect.company ?? '');
    _notesCtrl = TextEditingController(text: widget.prospect.notes ?? '');
    _source = widget.prospect.source;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    _companyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(prospectsProvider.notifier).updateProspect(
            prospectId: widget.prospect.id,
            name: _nameCtrl.text,
            phone: _phoneCtrl.text,
            email: _emailCtrl.text,
            address: _addressCtrl.text,
            gst: _gstCtrl.text,
            company: _companyCtrl.text,
            source: _source,
            notes: _notesCtrl.text,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Prospect details updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating prospect: $e'),
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
      creatorId: widget.prospect.createdBy,
      assigneeId: widget.prospect.assignedTo,
    );
    final canEditPhone = RecordEditPermissions.canEditField(
      fieldName: 'phone',
      userRole: profile?.primaryRole,
      allRoles: profile?.roles ?? [],
      currentUserId: profile?.id,
      creatorId: widget.prospect.createdBy,
      assigneeId: widget.prospect.assignedTo,
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
                children: [
                  const Expanded(
                    child: Text(
                      'Edit Prospect Details',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                controller: _nameCtrl,
                enabled: canEditName,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: const OutlineInputBorder(),
                  helperText: canEditName ? null : 'Only creator or admin can edit name',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Full name is required' : null,
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _companyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Company (Optional)',
                        prefixIcon: Icon(Icons.business_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _gstCtrl,
                      decoration: const InputDecoration(
                        labelText: 'GST Number (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                ],
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

class _AssignProspectDetailSheet extends ConsumerStatefulWidget {
  final Prospect prospect;

  const _AssignProspectDetailSheet({required this.prospect});

  @override
  ConsumerState<_AssignProspectDetailSheet> createState() => _AssignProspectDetailSheetState();
}

class _AssignProspectDetailSheetState extends ConsumerState<_AssignProspectDetailSheet> {
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
          if (_salesStaff.isNotEmpty && _selectedSalesUserId == null) {
            _selectedSalesUserId = _salesStaff.first['id'] as String?;
          }
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
      await ref.read(prospectsProvider.notifier).assignProspect(
            prospectId: widget.prospect.id,
            salesUserId: _selectedSalesUserId!,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Prospect transferred to salesperson successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning prospect: $e'), backgroundColor: AppColors.error),
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
            children: [
              const Expanded(
                child: Text(
                  'Transfer Prospect to Sales Rep',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Assign "${widget.prospect.name}" to a salesperson for follow-ups.',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_fetchingStaff)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_salesStaff.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No sales representatives found in system.', style: TextStyle(color: AppColors.textSecondary)),
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
                final name = s['full_name'] as String? ?? s['email'] as String? ?? 'Sales Executive';
                return DropdownMenuItem<String>(
                  value: s['id'] as String,
                  child: Text('$name (Sales Executive)'),
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
                : const Text('Confirm Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class ProductComboItem {
  final String displayName;
  final String productName;
  final String? capacity;
  final double price;
  final String uom;

  const ProductComboItem({
    required this.displayName,
    required this.productName,
    this.capacity,
    this.price = 0.0,
    this.uom = 'SET',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductComboItem &&
          runtimeType == other.runtimeType &&
          displayName == other.displayName;

  @override
  int get hashCode => displayName.hashCode;
}

class ConvertToLeadForm extends ConsumerStatefulWidget {
  final Prospect prospect;

  const ConvertToLeadForm({super.key, required this.prospect});

  @override
  ConsumerState<ConvertToLeadForm> createState() => _ConvertToLeadFormState();
}

class _ConvertToLeadFormState extends ConsumerState<ConvertToLeadForm> {
  final _formKey = GlobalKey<FormState>();
  ProductComboItem? _selectedComboItem;
  static List<ProductComboItem>? _cachedCombos;
  static final List<ProductComboItem> _defaultCombos = [
    const ProductComboItem(displayName: 'Boom Barrier - IZ-2026', productName: 'Boom Barrier', capacity: 'IZ-2026', price: 152500.0, uom: 'SET'),
    const ProductComboItem(displayName: 'Boom Barrier - IZ-2001', productName: 'Boom Barrier', capacity: 'IZ-2001', price: 40000.0, uom: 'NOS'),
    const ProductComboItem(displayName: 'Heat Pump - 4kW', productName: 'Heat Pump', capacity: '4kW', price: 110000.0, uom: 'SET'),
    const ProductComboItem(displayName: 'Heat Pump - 8kW', productName: 'Heat Pump', capacity: '8kW', price: 180000.0, uom: 'SET'),
    const ProductComboItem(displayName: 'Heat Pump - 10kW', productName: 'Heat Pump', capacity: '10kW', price: 230000.0, uom: 'SET'),
    const ProductComboItem(displayName: 'Heat Pump - 18kW', productName: 'Heat Pump', capacity: '18kW', price: 330000.0, uom: 'SET'),
    const ProductComboItem(displayName: 'Solar Water Heater - 200 Ltr', productName: 'Solar Water Heater', capacity: '200 Ltr', price: 60000.0, uom: 'NOS'),
    const ProductComboItem(displayName: 'Solar Water Heater - 500 Ltr', productName: 'Solar Water Heater', capacity: '500 Ltr', price: 120000.0, uom: 'NOS'),
    const ProductComboItem(displayName: 'Solar Water Heater - 1000 Ltr', productName: 'Solar Water Heater', capacity: '1000 Ltr', price: 210000.0, uom: 'NOS'),
    const ProductComboItem(displayName: 'Commercial 10kW', productName: 'Commercial 10kW', capacity: '10kW', price: 542800.0, uom: 'SET'),
  ];
  List<ProductComboItem> _availableCombos = [];
  final _valCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _expectedDate;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _availableCombos = List<ProductComboItem>.from(_cachedCombos ?? _defaultCombos);
    if (_availableCombos.isNotEmpty) {
      _selectedComboItem = _availableCombos.first;
      _valCtrl.text = _selectedComboItem!.price > 0 ? _selectedComboItem!.price.toStringAsFixed(0) : '0.00';
    }
    _loadCombos();
  }

  Future<void> _loadCombos() async {
    try {
      final supabase = ref.read(supabaseClientProvider);

      // Fetch products and inventory items
      final prodRes = await supabase.from('products').select('id, name, base_specs');
      final invRes = await supabase.from('inventory_items').select('id, item_name, price, uom').order('item_name');

      final List<Map<String, dynamic>> inventoryItems = (invRes as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

      final List<ProductComboItem> combos = [];

      for (final p in (prodRes as List? ?? [])) {
        final prodName = p['name'] as String? ?? '';
        final specs = p['base_specs'] as Map<String, dynamic>? ?? {};
        List<String> capacities = [];
        if (specs['capacities'] is List) {
          capacities = (specs['capacities'] as List).map((c) => c.toString()).toList();
        }
        if (capacities.isEmpty) {
          if (prodName.toLowerCase().contains('heat pump')) {
            capacities = ['4kW', '8kW', '10kW', '18kW'];
          } else if (prodName.toLowerCase().contains('water heater')) {
            capacities = ['100 Ltr', '200 Ltr', '300 Ltr', '500 Ltr', '1000 Ltr'];
          } else if (prodName.toLowerCase().contains('barrier')) {
            capacities = ['IZ-2001', 'IZ-2026'];
          } else {
            capacities = ['Standard'];
          }
        }

        for (final cap in capacities) {
          final displayName = '$prodName - $cap';
          double price = 0.0;
          String uom = 'SET';

          final cleanCap = cap.replaceAll(RegExp(r'\s+'), '').toLowerCase();
          final cleanProd = prodName.toLowerCase();

          for (final inv in inventoryItems) {
            final invName = (inv['item_name'] as String? ?? '').replaceAll(RegExp(r'\s+'), '').toLowerCase();
            if (invName.contains(cleanCap) || (invName.contains(cleanProd) && invName.contains(cleanCap))) {
              price = (inv['price'] as num?)?.toDouble() ?? 0.0;
              uom = inv['uom'] as String? ?? 'SET';
              break;
            }
          }

          combos.add(ProductComboItem(
            displayName: displayName,
            productName: prodName,
            capacity: cap,
            price: price,
            uom: uom,
          ));
        }
      }

      // Also add standalone inventory items if price > 0
      for (final inv in inventoryItems) {
        final invName = inv['item_name'] as String? ?? '';
        final price = (inv['price'] as num?)?.toDouble() ?? 0.0;
        final uom = inv['uom'] as String? ?? 'NOS';
        if (!combos.any((c) => c.displayName.toLowerCase() == invName.toLowerCase())) {
          combos.add(ProductComboItem(
            displayName: invName,
            productName: invName,
            price: price,
            uom: uom,
          ));
        }
      }

      if (mounted && combos.isNotEmpty) {
        setState(() {
          _availableCombos = combos;
          _cachedCombos = combos;
          if (_selectedComboItem == null || !_availableCombos.any((c) => c.displayName == _selectedComboItem!.displayName)) {
            _selectedComboItem = _availableCombos.first;
            _valCtrl.text = _selectedComboItem!.price > 0 ? _selectedComboItem!.price.toStringAsFixed(0) : '0.00';
          }
        });
      }
    } catch (_) {
      // Default combos are already populated
    }
  }

  @override
  void dispose() {
    _valCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConvert() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedComboItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a registered product'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isConverting = true);
    try {
      final leadId = await ref.read(prospectsProvider.notifier).convertToLead(
            prospectId: widget.prospect.id,
            prospectName: widget.prospect.name,
            contactPhone: widget.prospect.phone,
            productName: _selectedComboItem!.displayName,
            estimatedValue: double.tryParse(_valCtrl.text.trim()) ?? _selectedComboItem!.price,
            expectedDate: _expectedDate,
            notes: _notesCtrl.text.trim(),
            capacity: _selectedComboItem!.capacity,
          );

      if (mounted) {
        context.pop();
        ref.read(leadsProvider.notifier).load(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Converted to Lead successfully!'), backgroundColor: AppColors.success),
        );
        if (leadId != null) {
          context.push('/crm/leads/$leadId');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error converting to lead: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: (availableHeight * 0.9).clamp(320.0, double.infinity)),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Convert to Qualified Lead',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Converting "${widget.prospect.name}" into an active deal opportunity.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),

              SearchableDropdown<ProductComboItem>(
                label: 'Product Name (Product + Capacity) *',
                hint: 'Search product or capacity...',
                value: _selectedComboItem,
                items: _availableCombos,
                  itemLabel: (item) => item.displayName,
                  itemSubtitle: (item) => item.price > 0
                      ? '₹${NumberFormat('#,##,##0', 'en_IN').format(item.price)} (${item.uom})'
                      : item.uom,
                  itemLeading: (item) => const Icon(Icons.solar_power_outlined, color: AppColors.primary),
                  onChanged: (selected) {
                    setState(() {
                      _selectedComboItem = selected;
                      if (selected != null) {
                        _valCtrl.text = selected.price > 0 ? selected.price.toStringAsFixed(0) : '0.00';
                      }
                    });
                  },
                  validator: (val) => val == null ? 'Please select a product' : null,
                ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _valCtrl,
                readOnly: true,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Estimated Deal Value (₹) *',
                  hintText: '0.00',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.currency_rupee),
                  helperText: 'Auto-fetched from inventory price',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Deal value is required';
                  final numVal = double.tryParse(val.trim());
                  if (numVal == null || numVal < 0) return 'Enter a valid amount';
                  return null;
                },
              ),

              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expectedDate ?? today.add(const Duration(days: 14)),
                    firstDate: today.add(const Duration(days: 1)),
                    lastDate: today.add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _expectedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expected Closing Date (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event_outlined),
                  ),
                  child: Text(
                    _expectedDate != null
                        ? '${_expectedDate!.day}/${_expectedDate!.month}/${_expectedDate!.year}'
                        : 'Select date',
                    style: TextStyle(
                      color: _expectedDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Requirement Notes (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isConverting ? null : _handleConvert,
                child: _isConverting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm Conversion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
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
