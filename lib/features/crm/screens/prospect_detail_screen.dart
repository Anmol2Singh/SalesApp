import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/screens/product_catalog_screen.dart';
import '../data/models/prospect_model.dart';
import '../providers/crm_providers.dart';

class ProspectDetailScreen extends ConsumerWidget {
  final String id;

  const ProspectDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prospect = ref.watch(prospectByIdProvider(id));
    final profile = ref.watch(currentProfileProvider);

    if (prospect == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Prospect Details')),
        body: const Center(child: Text('Prospect not found or loading...', style: TextStyle(color: AppColors.textSecondary))),
      );
    }

    final isConverted = prospect.convertedToLeadId != null;
    final isSalesOrAdmin = profile?.primaryRole.isSalesOrAdmin ?? false;
    final isAdmin = profile?.primaryRole == UserRole.admin || profile?.primaryRole == UserRole.manager;
    final isSalesRole = profile?.primaryRole == UserRole.sales || (profile?.roles.contains(UserRole.sales) ?? false);
    final isAssignedToMe = prospect.assignedTo != null && prospect.assignedTo == profile?.id;
    final isCreatedByMe = prospect.createdBy == profile?.id;
    final isTransferredAway = isCreatedByMe && prospect.assignedTo != null && prospect.assignedTo != profile?.id;

    // Can convert if: isSalesOrAdmin AND (Admin OR Assigned Salesperson OR Creator Salesperson without assignment)
    final canConvert = !isConverted && isSalesOrAdmin && (isAdmin || isAssignedToMe || (isSalesRole && prospect.assignedTo == null));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(prospect.name),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              tooltip: 'Transfer / Assign Salesperson',
              onPressed: () => _showTransferModal(context, ref, prospect),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(prospectsProvider.notifier).load(refresh: true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    if (prospect.assignedByName != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.assignment_ind_outlined, 'Assigned To', prospect.assignedByName!),
                    ],
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.calendar_today_outlined,
                      'Created Date',
                      '${prospect.createdAt.day.toString().padLeft(2, '0')}/${prospect.createdAt.month.toString().padLeft(2, '0')}/${prospect.createdAt.year}',
                    ),
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
        res = await db.from('profiles').select('id, full_name, primary_role, roles, email').order('full_name');
      } catch (_) {
        res = await db.from('profiles').select().order('created_at', ascending: false);
      }

      final list = <Map<String, dynamic>>[];
      for (final r in (res as List? ?? [])) {
        final role = (r['primary_role'] as String? ?? '').toLowerCase();
        final rolesList = (r['roles'] is List) ? (r['roles'] as List).map((e) => e.toString().toLowerCase()).toList() : [];
        if (role == 'sales' || role == 'admin' || role == 'manager' || role == 'sales_head' ||
            role.contains('sales') || rolesList.contains('sales') || rolesList.contains('sales_head') || rolesList.contains('admin')) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transfer Prospect to Sales Rep',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                : const Text('Confirm Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class ConvertToLeadForm extends ConsumerStatefulWidget {
  final Prospect prospect;

  const ConvertToLeadForm({super.key, required this.prospect});

  @override
  ConsumerState<ConvertToLeadForm> createState() => _ConvertToLeadFormState();
}

class _ConvertToLeadFormState extends ConsumerState<ConvertToLeadForm> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedProductName;
  String? _selectedCapacity;
  final Set<String> _selectedComponentNames = {};
  List<Map<String, dynamic>> _availableComponents = [];
  bool _loadingComponents = false;
  final _valCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _expectedDate;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _loadComponents();
  }

  Future<void> _loadComponents() async {
    setState(() => _loadingComponents = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final items = await supabase
          .from('inventory_items')
          .select('id, item_name, price, uom')
          .order('item_name');

      if (items.isNotEmpty) {
        setState(() {
          _availableComponents = items;
        });
      } else {
        _useFallbackComponents();
      }
    } catch (_) {
      _useFallbackComponents();
    } finally {
      if (mounted) setState(() => _loadingComponents = false);
    }
  }

  void _useFallbackComponents() {
    _availableComponents = [
      {'item_name': 'Heat Pump 10kw', 'price': 230000.0, 'uom': 'SET'},
      {'item_name': 'Heat Pump 4kw', 'price': 110000.0, 'uom': 'SET'},
      {'item_name': 'Heat Pump 18kw', 'price': 330000.0, 'uom': 'SET'},
      {'item_name': 'GI pressurised Tank 1000Ltr', 'price': 80000.0, 'uom': 'NOS'},
      {'item_name': 'GI pressurised Tank 500Ltr', 'price': 60000.0, 'uom': 'NOS'},
      {'item_name': 'Wilo circulation pump 25/6', 'price': 12500.0, 'uom': 'NOS'},
      {'item_name': 'Electrical Control Panel', 'price': 15000.0, 'uom': 'NOS'},
    ];
  }

  void _toggleComponent(Map<String, dynamic> comp, bool isSelected) {
    setState(() {
      final name = comp['item_name'] as String;
      if (isSelected) {
        _selectedComponentNames.add(name);
      } else {
        _selectedComponentNames.remove(name);
      }
      double sum = 0.0;
      for (final c in _availableComponents) {
        if (_selectedComponentNames.contains(c['item_name'])) {
          sum += (c['price'] as num?)?.toDouble() ?? 0.0;
        }
      }
      if (sum > 0) {
        _valCtrl.text = sum.toStringAsFixed(0);
      }
    });
  }

  @override
  void dispose() {
    _valCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConvert() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductName == null || _selectedProductName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a registered product'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isConverting = true);
    try {
      final selectedComps = _availableComponents
          .where((c) => _selectedComponentNames.contains(c['item_name']))
          .map((c) => {
                'name': c['item_name'],
                'price': (c['price'] as num?)?.toDouble() ?? 0.0,
                'uom': c['uom'] ?? 'NOS',
              })
          .toList();

      final leadId = await ref.read(prospectsProvider.notifier).convertToLead(
            prospectId: widget.prospect.id,
            prospectName: widget.prospect.name,
            contactPhone: widget.prospect.phone,
            productName: _selectedProductName!,
            estimatedValue: double.tryParse(_valCtrl.text.trim()) ?? 0.0,
            expectedDate: _expectedDate,
            notes: _notesCtrl.text.trim(),
            capacity: _selectedCapacity,
            components: selectedComps,
          );

      if (mounted) {
        context.pop();
        ref.read(leadsProvider.notifier).load(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Converted to Lead successfully!'), backgroundColor: AppColors.success),
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
    final productsAsync = ref.watch(productsProvider);
    final availableProducts = productsAsync.value?.map((p) => p.name).toList() ?? [
      'Boom Barrier',
      'Heat Pump',
      'Solar Water Heater',
    ];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: const EdgeInsets.all(24),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Convert to Qualified Lead', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Converting "${widget.prospect.name}" into an active deal opportunity.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedProductName,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  hintText: 'Select registered product',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.solar_power_outlined),
                ),
                items: availableProducts
                    .map((prod) => DropdownMenuItem(value: prod, child: Text(prod)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedProductName = val),
                validator: (v) => v == null || v.isEmpty ? 'Please select a product' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCapacity,
                decoration: const InputDecoration(
                  labelText: 'Capacity (Ltr / kW)',
                  hintText: 'Select capacity',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                ),
                items: [
                  '100 Ltr',
                  '200 Ltr',
                  '300 Ltr',
                  '500 Ltr',
                  '1000 Ltr',
                  '2000 Ltr',
                  '3 kW',
                  '4 kW',
                  '5 kW',
                  '10 kW',
                  '18 kW',
                ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _selectedCapacity = val),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select System Components (Auto-sums Value):',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              if (_loadingComponents)
                const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.surface,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _availableComponents.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _availableComponents[index];
                      final name = item['item_name'] as String? ?? '';
                      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                      final checked = _selectedComponentNames.contains(name);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        value: checked,
                        title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text('₹${NumberFormat('#,##,##0', 'en_IN').format(price)}', style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        activeColor: AppColors.primary,
                        onChanged: (val) => _toggleComponent(item, val ?? false),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valCtrl,
                decoration: const InputDecoration(
                  labelText: 'Estimated Deal Value (₹) *',
                  hintText: 'e.g. 250000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter estimated value' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 14)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
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
              const SizedBox(height: 12),
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
