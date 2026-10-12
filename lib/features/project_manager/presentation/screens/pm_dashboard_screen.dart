import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    final recordsAsync = isPurchase
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
                      : records.where((r) {
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

                  for (final r in records) {
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
                                  title: isPurchase ? 'Active Vendors' : 'Active Sites',
                                  value: records.length.toString(),
                                  description: isPurchase ? 'Total vendors managed' : 'Total customer sites',
                                  icon: const Icon(LucideIcons.briefcase),
                                  accentColor: pm.primary,
                                ),
                                PmStatCard(
                                  title: isPurchase ? 'Quotation Value' : 'Total Order Value',
                                  value: '₹${_currencyFormat.format(totalOrder)}',
                                  description: 'Combined booking sum',
                                  icon: const Icon(LucideIcons.indianRupee),
                                  accentColor: pm.info,
                                ),
                                PmStatCard(
                                  title: isPurchase ? 'Payment Paid' : 'Payment Received',
                                  value: '₹${_currencyFormat.format(totalPaid)}',
                                  description: isPurchase ? 'Total payout made' : 'Total funds collected',
                                  icon: const Icon(LucideIcons.wallet),
                                  accentColor: pm.success,
                                ),
                                PmStatCard(
                                  title: 'Outstanding Balance',
                                  value: '₹${_currencyFormat.format(totalBalance)}',
                                  description: 'Total pending balance',
                                  icon: const Icon(LucideIcons.trendingDown),
                                  accentColor: totalBalance > 0 ? pm.warning : pm.destructive,
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

                          const SizedBox(height: 20),

                          // Table Title & Export Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPurchase ? 'Vendor Directory' : 'Project Directory',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: pm.foreground,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  Text(
                                    isPurchase
                                        ? 'Manage and track all vendor purchase accounts'
                                        : 'Manage and track all installation sites',
                                    style: TextStyle(fontSize: 12, color: pm.mutedForeground),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  PmButton(
                                    variant: PmButtonVariant.outline,
                                    size: PmButtonSize.sm,
                                    onPressed: () async {
                                      final pdfBytes = await PmPdfService.generateDirectoryPdf(
                                        records: filtered,
                                        companyName: activeCompany.name,
                                        isPurchase: isPurchase,
                                      );
                                      await Printing.layoutPdf(
                                        onLayout: (_) => pdfBytes,
                                        name: '${activeCompany.name}_Directory.pdf',
                                      );
                                    },
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.fileText, size: 14),
                                        SizedBox(width: 6),
                                        Text('PDF'),
                                      ],
                                    ),
                                  ),
                                  PmButton(
                                    variant: PmButtonVariant.outline,
                                    size: PmButtonSize.sm,
                                    onPressed: () {
                                      final excelBytes = PmExcelService.exportDirectoryToExcel(
                                        records: filtered,
                                        isPurchase: isPurchase,
                                      );
                                      if (excelBytes != null) {
                                        Printing.sharePdf(
                                          bytes: excelBytes,
                                          filename: '${activeCompany.name}_Directory.xlsx',
                                        );
                                      }
                                    },
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.fileSpreadsheet, size: 14),
                                        SizedBox(width: 6),
                                        Text('Excel'),
                                      ],
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
