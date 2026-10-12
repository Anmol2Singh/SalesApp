import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_mode_provider.dart';
import '../../providers/pm_company_provider.dart';
import '../../providers/pm_providers.dart';
import '../../data/services/pm_pdf_service.dart';
import '../../data/services/pm_excel_service.dart';
import '../widgets/pm_header_bar.dart';
import '../widgets/pm_stat_card.dart';
import '../widgets/pm_directory_table.dart';
import '../widgets/pm_button.dart';
import '../widgets/pm_pdf_preview_modal.dart';
import '../widgets/pm_excel_preview_modal.dart';
import '../widgets/pm_excel_import_modal.dart';
import '../widgets/pm_excel_bulk_update_modal.dart';

class PmDashboardScreen extends ConsumerStatefulWidget {
  const PmDashboardScreen({super.key});

  @override
  ConsumerState<PmDashboardScreen> createState() => _PmDashboardScreenState();
}

class _PmDashboardScreenState extends ConsumerState<PmDashboardScreen> {
  String _searchQuery = '';
  final _currencyFormat = NumberFormat('#,##,##0', 'en_IN');

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;
    final mode = ref.watch(pmRecordModeProvider);
    final isPurchase = mode.isPurchase;
    final activeCompany = ref.watch(pmActiveCompanyProvider);

    final AsyncValue<List<dynamic>> recordsAsync = isPurchase
        ? ref.watch(pmPurchasesListProvider)
        : ref.watch(pmProjectsListProvider);

    return Scaffold(
      backgroundColor: pm.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            PmHeaderBar(
              searchQuery: _searchQuery,
              onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
              onRefresh: () {
                if (isPurchase) {
                  ref.invalidate(pmPurchasesListProvider);
                } else {
                  ref.invalidate(pmProjectsListProvider);
                }
              },
            ),

            // Content Body
            Expanded(
              child: recordsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.triangleAlert, size: 40, color: pm.destructive),
                      const SizedBox(height: 12),
                      Text('Error loading records: $err', style: TextStyle(color: pm.destructive)),
                      const SizedBox(height: 12),
                      PmButton(
                        size: PmButtonSize.sm,
                        onPressed: () {
                          if (isPurchase) {
                            ref.invalidate(pmPurchasesListProvider);
                          } else {
                            ref.invalidate(pmProjectsListProvider);
                          }
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (records) {
                  final filtered = _searchQuery.isEmpty
                      ? records
                      : records.where((dynamic r) {
                          final q = _searchQuery.toLowerCase();
                          final siteName = (r.siteName ?? '').toString().toLowerCase();
                          final party = (r.partyPrintName ?? '').toString().toLowerCase();
                          final mob = (r.mobileNumber ?? '').toString().toLowerCase();
                          final addr = (r.address ?? '').toString().toLowerCase();
                          final idNo = r.idNo.toString();
                          return siteName.contains(q) ||
                              party.contains(q) ||
                              mob.contains(q) ||
                              addr.contains(q) ||
                              idNo.contains(q);
                        }).toList();

                  // Compute summary totals
                  double totalOrder = 0;
                  double totalPaid = 0;
                  double totalBalance = 0;

                  for (final dynamic r in records) {
                    totalOrder += (r.orderValue as num).toDouble();
                    totalPaid += (r.paymentReceived as num).toDouble();
                    totalBalance += (r.balance as num).toDouble();
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      if (isPurchase) {
                        ref.invalidate(pmPurchasesListProvider);
                      } else {
                        ref.invalidate(pmProjectsListProvider);
                      }
                    },
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // KPI Summary Cards
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 900;
                              final cards = [
                                PmStatCard(
                                  title: isPurchase ? 'Active Vendors' : 'Active Projects',
                                  value: records.length.toString(),
                                  description: isPurchase ? 'Total vendors managed' : 'Total projects managed',
                                  icon: const Icon(LucideIcons.briefcase),
                                  iconBgColor: const Color(0xFFE0F2FE),
                                  iconColor: const Color(0xFF0284C7),
                                ),
                                PmStatCard(
                                  title: isPurchase ? 'Quotation Value' : 'Total Order Value',
                                  value: '₹${_currencyFormat.format(totalOrder)}',
                                  description: 'Combined contract values',
                                  icon: const Icon(LucideIcons.indianRupee),
                                  iconBgColor: const Color(0xFFE0F7FA),
                                  iconColor: const Color(0xFF0284C7),
                                ),
                                PmStatCard(
                                  title: isPurchase ? 'Payment Paid' : 'Payment Received',
                                  value: '₹${_currencyFormat.format(totalPaid)}',
                                  description: 'Total funds collected',
                                  icon: const Icon(LucideIcons.wallet),
                                  iconBgColor: const Color(0xFFDCFCE7),
                                  iconColor: const Color(0xFF16A34A),
                                ),
                                PmStatCard(
                                  title: 'Outstanding Balance',
                                  value: '₹${_currencyFormat.format(totalBalance)}',
                                  description: 'Remaining to be collected',
                                  icon: const Icon(LucideIcons.trendingDown),
                                  iconBgColor: const Color(0xFFDCFCE7),
                                  iconColor: const Color(0xFF16A34A),
                                ),
                              ];

                              if (isWide) {
                                return Row(
                                  children: cards
                                      .map((c) => Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              child: c,
                                            ),
                                          ))
                                      .toList(),
                                );
                              }

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: cards
                                    .map((c) => SizedBox(
                                          width: (constraints.maxWidth - 12) / 2 > 260
                                              ? (constraints.maxWidth - 12) / 2
                                              : constraints.maxWidth,
                                          child: c,
                                        ))
                                    .toList(),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // Table Title & Action Bar (Matching Screenshot 1)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPurchase ? 'Vendor Directory' : 'Project Directory',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isPurchase
                                        ? 'Manage and track all vendor purchase accounts'
                                        : 'Manage and track all installation sites',
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Total count pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(9999),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text(
                                      '${filtered.length} Total',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF005CE6),
                                      ),
                                    ),
                                  ),
                                  // Filter pill
                                  InkWell(
                                    onTap: () => context.push('/pm/filter'),
                                    borderRadius: BorderRadius.circular(9999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(9999),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.slidersHorizontal, size: 13, color: Color(0xFF005CE6)),
                                          SizedBox(width: 6),
                                          Text('Filter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Generate PDF pill
                                  InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => PmPdfPreviewModal(
                                          records: filtered,
                                          companyName: activeCompany.name,
                                          isPurchase: isPurchase,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(9999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(9999),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.fileText, size: 13, color: Color(0xFFEF4444)),
                                          SizedBox(width: 6),
                                          Text('Generate PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Export to Excel pill
                                  InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => PmExcelPreviewModal(
                                          records: filtered,
                                          companyName: activeCompany.name,
                                          isPurchase: isPurchase,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(9999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(9999),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.fileSpreadsheet, size: 13, color: Color(0xFF16A34A)),
                                          SizedBox(width: 6),
                                          Text('Export to Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Update via Excel pill
                                  InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => PmExcelBulkUpdateModal(
                                          isPurchase: isPurchase,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(9999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(9999),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.refreshCw, size: 13, color: Color(0xFF8B5CF6)),
                                          SizedBox(width: 6),
                                          Text('Update via Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Import Excel pill
                                  InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => PmExcelImportModal(
                                          isPurchase: isPurchase,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(9999),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(9999),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.upload, size: 13, color: Color(0xFF005CE6)),
                                          SizedBox(width: 6),
                                          Text('Import Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF005CE6))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Directory Table Widget
                          PmDirectoryTable(
                            records: filtered,
                            isPurchase: isPurchase,
                            onBulkDelete: (ids) async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Selected Records?'),
                                  content: Text('Are you sure you want to permanently delete ${ids.length} records? This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      style: ElevatedButton.styleFrom(backgroundColor: pm.destructive),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                if (isPurchase) {
                                  await ref.read(pmPurchasesRepositoryProvider).bulkDeletePurchases(ids);
                                  ref.invalidate(pmPurchasesListProvider);
                                } else {
                                  await ref.read(pmProjectsRepositoryProvider).bulkDeleteProjects(ids);
                                  ref.invalidate(pmProjectsListProvider);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
