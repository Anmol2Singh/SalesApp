import '../data/models/lead_model.dart';
import '../../../core/models/crm_date_filter.dart';
import '../../../core/widgets/crm_date_filter_bar.dart';
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
  CrmDateFilter _dateFilter = const CrmDateFilter();

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(crmWonCustomersProvider);
    final prospectsAsync = ref.watch(prospectsProvider);

    final wonLeadsCount = leadsAsync.value?.where((l) => l.convertedToCustomerId != null || l.status == 'Won').length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Converted Customers'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$wonLeadsCount',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Converted Customers',
            onPressed: () {
              final leads = ref.read(crmWonCustomersProvider).value;
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
              ref.read(crmWonCustomersProvider.notifier).load(refresh: true);
              ref.read(prospectsProvider.notifier).load(refresh: true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Total Converted Customers: $wonLeadsCount',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Won Leads',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          CrmDateFilterBar(
            filter: _dateFilter,
            dateFieldName: 'Won Date',
            resultCount: leadsAsync.value?.length ?? 0,
            onFilterChanged: (newFilter) {
              final needsReload = _dateFilter.preset != newFilter.preset ||
                  _dateFilter.customStart != newFilter.customStart ||
                  _dateFilter.customEnd != newFilter.customEnd;
              setState(() => _dateFilter = newFilter);
              if (needsReload) {
                ref.read(crmWonCustomersProvider.notifier).load(dateFilter: newFilter);
              }
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(crmWonCustomersProvider.notifier).load(refresh: true);
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
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text('No converted customers found.', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ],
                    );
                  }

                                  Widget buildCustomerCard(Lead lead) {
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
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                        ),
                      );
                }

                if (_dateFilter.isGrouped) {
                  final Map<String, List<Lead>> grouped = {};
                  for (final l in filtered) {
                    final bucket = CrmDateFilter.getBucket(l.updatedAt);
                    grouped.putIfAbsent(bucket, () => []).add(l);
                  }

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${entry.key} (${entry.value.length})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Divider(color: Colors.grey.shade300, height: 1)),
                            ],
                          ),
                        ),
                        for (final lead in entry.value) ...[
                          buildCustomerCard(lead),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, itemIndex) {
                    return buildCustomerCard(filtered[itemIndex]);
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }
}
