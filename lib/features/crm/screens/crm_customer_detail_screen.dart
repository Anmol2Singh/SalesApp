// lib/features/crm/screens/crm_customer_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/crm_providers.dart';
import '../../amc/providers/amc_provider.dart';
import '../../../core/models/amc_contract.dart';

class CrmCustomerDetailScreen extends ConsumerWidget {
  final String leadId;

  const CrmCustomerDetailScreen({super.key, required this.leadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lead = ref.watch(leadByIdProvider(leadId));
    final prospect = lead?.prospectId != null ? ref.watch(prospectByIdProvider(lead!.prospectId!)) : null;

    if (lead == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Customer Details')),
        body: const Center(child: Text('Record not found.', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final displayName = (lead.prospectName != null && lead.prospectName!.isNotEmpty)
        ? lead.prospectName!
        : (prospect?.name ?? 'Customer');
    final displayPhone = (lead.contactPhone != null && lead.contactPhone!.isNotEmpty)
        ? lead.contactPhone!
        : (prospect?.phone ?? '');
    final displayEmail = prospect?.email;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(displayName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer Header Card
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
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.success.withOpacity(0.1),
                      child: const Icon(Icons.star, size: 40, color: AppColors.success),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      displayName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Won Customer', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(height: 16),
                    // Quick Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (displayPhone.isNotEmpty) ...[
                          _QuickActionButton(
                            icon: Icons.phone,
                            label: 'Call',
                            color: AppColors.primary,
                            onTap: () => _makePhoneCall(displayPhone),
                          ),
                          const SizedBox(width: 24),
                          _QuickActionButton(
                            icon: Icons.chat,
                            label: 'WhatsApp',
                            color: const Color(0xFF25D366),
                            onTap: () => _openWhatsApp(displayPhone),
                          ),
                        ],
                        if (displayEmail != null && displayEmail.isNotEmpty) ...[
                          const SizedBox(width: 24),
                          _QuickActionButton(
                            icon: Icons.email,
                            label: 'Email',
                            color: Colors.blue,
                            onTap: () => _sendEmail(displayEmail),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Deal Details Card
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
                    const Text('Deal & Contract Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const Divider(height: 24),
                    _buildDetailRow(Icons.solar_power_outlined, 'Product', lead.productName),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.currency_rupee, 'Deal Value', '₹${lead.estimatedValue.toStringAsFixed(2)}'),
                    if (displayPhone.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.phone_outlined, 'Phone', displayPhone),
                    ],
                    if (displayEmail != null && displayEmail.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.email_outlined, 'Email', displayEmail),
                    ],
                    if (prospect?.address != null && prospect!.address!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.location_on_outlined, 'Address', prospect.address!),
                    ],
                    if (prospect?.gst != null && prospect!.gst!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.receipt_long_outlined, 'GST Number', prospect.gst!),
                    ],
                    if (lead.assignedByName != null && lead.assignedByName!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.badge_outlined, 'Assigned Salesperson', lead.assignedByName!),
                    ],
                    if (lead.convertedByName != null && lead.convertedByName!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.verified_user_outlined, 'Converted by', lead.convertedByName!),
                    ],
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.calendar_today_outlined,
                      'Won Date',
                      '${lead.updatedAt.day.toString().padLeft(2, '0')}/${lead.updatedAt.month.toString().padLeft(2, '0')}/${lead.updatedAt.year}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Active AMC Card (if customer exists)
            if (lead.convertedToCustomerId != null)
              Consumer(
                builder: (context, ref, _) {
                  final amcsAsync = ref.watch(amcForCustomerProvider(lead.convertedToCustomerId!));
                  return amcsAsync.when(
                    data: (amcs) {
                      final activeAmc = amcs.where((a) => a.status == AmcContractStatus.active || a.status == AmcContractStatus.expiringSoon).firstOrNull;
                      return Card(
                        elevation: 0,
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: activeAmc != null ? AppColors.success.withOpacity(0.5) : AppColors.border,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    activeAmc != null ? Icons.verified_user : Icons.shield_outlined,
                                    color: activeAmc != null ? AppColors.success : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Annual Maintenance Contract (AMC)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (activeAmc != null ? AppColors.success : Colors.grey).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      activeAmc != null ? activeAmc.status.displayName : 'No Active AMC',
                                      style: TextStyle(
                                        color: activeAmc != null ? AppColors.success : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (activeAmc != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Contract: ${activeAmc.amcNumber}\nPeriod: ${activeAmc.startDate != null ? DateFormat('dd MMM yyyy').format(activeAmc.startDate!) : '-'} to ${activeAmc.endDate != null ? DateFormat('dd MMM yyyy').format(activeAmc.endDate!) : '-'}',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
            const SizedBox(height: 20),

            // Bottom Actions
            if (lead.convertedToCustomerId != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  context.push('/customers/${lead.convertedToCustomerId}');
                },
                icon: const Icon(Icons.business),
                label: const Text('Open Master Customer Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
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
