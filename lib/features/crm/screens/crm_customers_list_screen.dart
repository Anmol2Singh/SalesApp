// lib/features/crm/screens/crm_customers_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/excel_service.dart';
import '../providers/crm_providers.dart';

class CrmCustomersListScreen extends ConsumerStatefulWidget {
  const CrmCustomersListScreen({super.key});

  @override
  ConsumerState<CrmCustomersListScreen> createState() => _CrmCustomersListScreenState();
}

class _CrmCustomersListScreenState extends ConsumerState<CrmCustomersListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadsProvider);
    final prospectsAsync = ref.watch(prospectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Converted Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Converted Customers',
            onPressed: () {
              final leads = ref.read(leadsProvider).value;
              final prospects = ref.read(prospectsProvider).value ?? [];
              if (leads != null && leads.isNotEmpty) {
                final wonLeads = leads.where((l) => l.convertedToCustomerId != null || l.status == 'Won').toList();
                if (wonLeads.isNotEmpty) {
                  ExcelService.exportCrmCustomers(context, wonLeads, prospects);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No converted customers to export')));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export')));
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
                  var filtered = leads.where((l) {
                    if (l.convertedToCustomerId == null && l.status != 'Won') return false;
                    final prospect = prospects.where((p) => p.id == l.prospectId).firstOrNull;
                    final name = (l.prospectName != null && l.prospectName!.isNotEmpty)
                        ? l.prospectName!
                        : (prospect?.name ?? '');
                    final phone = (l.contactPhone != null && l.contactPhone!.isNotEmpty)
                        ? l.contactPhone!
                        : (prospect?.phone ?? '');

                    return name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                           phone.contains(_searchQuery) ||
                           l.productName.toLowerCase().contains(_searchQuery.toLowerCase());
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No converted customers found.', style: TextStyle(color: AppColors.textSecondary)),
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
                          : (prospect?.name ?? 'Customer');
                      final displayPhone = (lead.contactPhone != null && lead.contactPhone!.isNotEmpty)
                          ? lead.contactPhone!
                          : (prospect?.phone ?? '');

                      return Card(
                        elevation: 0,
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.border.withOpacity(0.5)),
                        ),
                        child: ListTile(
                          onTap: () {
                            context.push('/crm/customers/${lead.id}');
                          },
                          leading: CircleAvatar(
                            backgroundColor: AppColors.success.withOpacity(0.1),
                            child: const Icon(Icons.star, color: AppColors.success),
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lead.productName, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
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
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
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
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: TextField(
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search converted customers...',
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
    );
  }
}
