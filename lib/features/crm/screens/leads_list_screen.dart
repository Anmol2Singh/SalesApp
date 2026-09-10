// lib/features/crm/screens/leads_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/excel_service.dart';
import '../../admin/screens/product_catalog_screen.dart';
import '../data/models/prospect_model.dart';
import '../providers/crm_providers.dart';

class LeadsListScreen extends ConsumerStatefulWidget {
  const LeadsListScreen({super.key});

  @override
  ConsumerState<LeadsListScreen> createState() => _LeadsListScreenState();
}

class _LeadsListScreenState extends ConsumerState<LeadsListScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'All';

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadsProvider);
    final prospectsAsync = ref.watch(prospectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Leads & Deals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Leads',
            onPressed: () {
              final leads = ref.read(leadsProvider).value;
              final prospects = ref.read(prospectsProvider).value ?? [];
              if (leads != null && leads.isNotEmpty) {
                ExcelService.exportLeads(context, leads, prospects);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No leads to export')));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(leadsProvider.notifier).load(refresh: true);
              ref.read(prospectsProvider.notifier).load(refresh: true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(leadsProvider.notifier).load(refresh: true);
                ref.read(prospectsProvider.notifier).load(refresh: true);
              },
              child: leadsAsync.when(
                data: (leads) {
                  final prospects = prospectsAsync.value ?? [];

                  // Apply filters
                  var filtered = leads.where((l) {
                    final prospect = prospects.where((p) => p.id == l.prospectId).firstOrNull;
                    final displayName = (l.prospectName != null && l.prospectName!.isNotEmpty)
                        ? l.prospectName!
                        : (prospect?.name ?? '');
                    final phone = (l.contactPhone != null && l.contactPhone!.isNotEmpty)
                        ? l.contactPhone!
                        : (prospect?.phone ?? '');

                    final matchesSearch = displayName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                          phone.contains(_searchQuery) ||
                                          l.productName.toLowerCase().contains(_searchQuery.toLowerCase());
                    final matchesStatus = _selectedStatus == 'All' || l.status == _selectedStatus;
                    return matchesSearch && matchesStatus;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No leads found.', style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final lead = filtered[index];
                      final prospect = prospects.where((p) => p.id == lead.prospectId).firstOrNull;
                      final displayName = (lead.prospectName != null && lead.prospectName!.isNotEmpty)
                          ? lead.prospectName!
                          : (prospect?.name ?? 'Lead #${lead.id.substring(0, 6)}');
                      final displayPhone = (lead.contactPhone != null && lead.contactPhone!.isNotEmpty)
                          ? lead.contactPhone!
                          : (prospect?.phone ?? '');

                      final isWon = lead.status == 'Won' || lead.convertedToCustomerId != null;
                      final isLost = lead.status == 'Lost';

                      Color statusColor = Colors.blue;
                      if (isWon) statusColor = AppColors.success;
                      if (isLost) statusColor = AppColors.error;
                      if (lead.status == 'Negotiating') statusColor = Colors.purple;
                      if (lead.status == 'In Progress') statusColor = Colors.orange;

                      return Card(
                        elevation: 0,
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                        ),
                        child: ListTile(
                          onTap: () {
                            context.push('/crm/leads/${lead.id}');
                          },
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.1),
                            child: Icon(
                              isWon ? Icons.check_circle : (isLost ? Icons.cancel : Icons.trending_up),
                              color: statusColor,
                            ),
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lead.productName,
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Row(
                                children: [
                                  Text('₹${lead.estimatedValue.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 12)),
                                  if (displayPhone.isNotEmpty) ...[
                                    const Text(' • ', style: TextStyle(color: AppColors.textSecondary)),
                                    Text(displayPhone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor.withOpacity(0.5)),
                                ),
                                child: Text(
                                  lead.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLeadForm(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Lead', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search by prospect, product, phone...',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'New', 'In Progress', 'Negotiating', 'Won', 'Lost'].map((status) {
                final isSelected = _selectedStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      status,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedStatus = status);
                    },
                    selectedColor: AppColors.primary.withOpacity(0.15),
                    checkmarkColor: AppColors.primary,
                    backgroundColor: AppColors.background,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddLeadForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const AddDirectLeadForm(),
        );
      },
    );
  }
}

class AddDirectLeadForm extends ConsumerStatefulWidget {
  const AddDirectLeadForm({super.key});

  @override
  ConsumerState<AddDirectLeadForm> createState() => _AddDirectLeadFormState();
}

class _AddDirectLeadFormState extends ConsumerState<AddDirectLeadForm> {
  final _formKey = GlobalKey<FormState>();
  Prospect? _selectedProspect;
  final _contactPhoneCtrl = TextEditingController();
  String? _selectedProductName;
  final _valCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _expectedDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _contactPhoneCtrl.dispose();
    _valCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProspect == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a prospect'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_selectedProductName == null || _selectedProductName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a registered product'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final newLead = await ref.read(leadsProvider.notifier).addDirectLead(
            prospectName: _selectedProspect!.name,
            contactPhone: _contactPhoneCtrl.text.trim(),
            productName: _selectedProductName!,
            estimatedValue: double.tryParse(_valCtrl.text.trim()) ?? 0.0,
            expectedDate: _expectedDate,
            notes: _notesCtrl.text.trim(),
          );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lead created successfully!'), backgroundColor: AppColors.success),
        );
        if (newLead != null) {
          context.push('/crm/leads/${newLead.id}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating lead: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prospectsList = ref.watch(prospectsProvider).value ?? [];
    final productsAsync = ref.watch(productsProvider);
    final availableProducts = productsAsync.value?.map((p) => p.name).toList() ?? [
      'Boom Barrier',
      'Heat Pump',
      'Solar Water Heater',
    ];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
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
                  const Text('New Sales Lead', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),

              // 1. Searchable Prospect Selector
              if (prospectsList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No prospects found. Please add a prospect first before creating a lead.',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: () async {
                    final picked = await showModalBottomSheet<Prospect>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => _SearchableProspectSheet(prospects: prospectsList),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedProspect = picked;
                        _contactPhoneCtrl.text = picked.phone; // Auto fill phone number!
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Select Prospect *',
                      hintText: 'Search and choose prospect',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_search, color: AppColors.primary),
                      suffixIcon: _selectedProspect != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  _selectedProspect = null;
                                  _contactPhoneCtrl.clear();
                                });
                              },
                            )
                          : const Icon(Icons.arrow_drop_down),
                    ),
                    child: _selectedProspect == null
                        ? const Text('Choose from created prospects', style: TextStyle(color: AppColors.textSecondary))
                        : Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedProspect!.company != null && _selectedProspect!.company!.isNotEmpty
                                      ? '${_selectedProspect!.name} (${_selectedProspect!.company})'
                                      : _selectedProspect!.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              const SizedBox(height: 12),

              // 2. Auto-filled Phone Number
              TextFormField(
                controller: _contactPhoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone Number (Auto-filled)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              // 3. Registered Products Dropdown
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

              // 4. Estimated Deal Value
              TextFormField(
                controller: _valCtrl,
                decoration: const InputDecoration(
                  labelText: 'Estimated Deal Value (₹) *',
                  hintText: 'e.g. 500000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter estimated value' : null,
              ),
              const SizedBox(height: 12),

              // 5. Expected Closing Date
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
                        : 'Select closing date',
                    style: TextStyle(
                      color: _expectedDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 6. Notes
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Initial Notes / Requirements',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Lead', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchableProspectSheet extends StatefulWidget {
  final List<Prospect> prospects;
  const _SearchableProspectSheet({required this.prospects});

  @override
  State<_SearchableProspectSheet> createState() => _SearchableProspectSheetState();
}

class _SearchableProspectSheetState extends State<_SearchableProspectSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.prospects.where((p) {
      final q = _query.toLowerCase().trim();
      if (q.isEmpty) return true;
      final name = p.name.toLowerCase();
      final phone = p.phone.toLowerCase();
      final company = (p.company ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q) || company.contains(q);
    }).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.80),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.person_search, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Select Prospect',
                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, company...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty ? 'No prospects available' : 'No prospects match "$_query"',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final p = filtered[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          [
                            if (p.company != null && p.company!.isNotEmpty) p.company!,
                            p.phone,
                          ].join(' • '),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: p.source.isNotEmpty
                            ? Chip(
                                label: Text(p.source, style: const TextStyle(fontSize: 10)),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
