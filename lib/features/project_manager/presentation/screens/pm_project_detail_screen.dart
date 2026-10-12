import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_providers.dart';
import '../widgets/pm_badge.dart';
import '../widgets/pm_button.dart';
import '../tabs/pm_ledger_tab.dart';
import '../tabs/pm_payment_terms_tab.dart';
import '../tabs/pm_expenses_tab.dart';
import '../tabs/pm_calling_records_tab.dart';
import '../tabs/pm_swh_checklist_tab.dart';
import '../tabs/pm_work_remarks_tab.dart';

class PmProjectDetailScreen extends ConsumerStatefulWidget {
  final String id;
  final bool isPurchase;

  const PmProjectDetailScreen({
    super.key,
    required this.id,
    this.isPurchase = false,
  });

  @override
  ConsumerState<PmProjectDetailScreen> createState() => _PmProjectDetailScreenState();
}

class _PmProjectDetailScreenState extends ConsumerState<PmProjectDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat('#,##,##0', 'en_IN');

  List<String> get _tabs => widget.isPurchase
      ? ['Financial Ledger', 'Call Records']
      : [
          'Financial Ledger',
          'Payment Terms',
          'Project Expenses',
          'Call Records',
          'Checklist',
          'Work Remarks',
        ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    if (widget.isPurchase) {
      ref.invalidate(pmPurchaseDetailProvider(widget.id));
      ref.invalidate(pmPurchasesListProvider);
    } else {
      ref.invalidate(pmProjectDetailProvider(widget.id));
      ref.invalidate(pmProjectsListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;

    final AsyncValue<dynamic> detailAsync = widget.isPurchase
        ? ref.watch(pmPurchaseDetailProvider(widget.id))
        : ref.watch(pmProjectDetailProvider(widget.id));

    return Scaffold(
      backgroundColor: pm.background,
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.triangleAlert, size: 40, color: pm.destructive),
                const SizedBox(height: 12),
                Text('Error loading details: $err', style: TextStyle(color: pm.destructive)),
                const SizedBox(height: 12),
                PmButton(size: PmButtonSize.sm, onPressed: _refreshAll, child: const Text('Retry')),
              ],
            ),
          ),
          data: (dynamic record) {
            if (record == null) {
              return Center(
                child: Text('Record not found.', style: TextStyle(color: pm.mutedForeground)),
              );
            }

            final bal = (record.balance as num).toDouble();
            final orderVal = (record.orderValue as num).toDouble();
            final paidVal = (record.paymentReceived as num).toDouble();
            final extraVal = (record.extraWorkValue as num).toDouble();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Bar
                Container(
                  color: pm.card,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PmButton(
                            variant: PmButtonVariant.ghost,
                            size: PmButtonSize.sm,
                            onPressed: () => context.pop(),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.arrowLeft, size: 14),
                                SizedBox(width: 6),
                                Text('Back'),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              PmButton(
                                variant: PmButtonVariant.outline,
                                size: PmButtonSize.sm,
                                onPressed: () {
                                  context.push(
                                    '/pm/projects/${widget.id}/edit${widget.isPurchase ? "?mode=purchase" : ""}',
                                  );
                                },
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.pencil, size: 14),
                                    SizedBox(width: 6),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              PmButton(
                                variant: PmButtonVariant.destructive,
                                size: PmButtonSize.sm,
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Account?'),
                                      content: const Text('This will delete this project/vendor account along with all its ledger entries. Cannot be undone.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                        ElevatedButton(
                                          onPressed: () => Navigator.of(ctx).pop(true),
                                          style: ElevatedButton.styleFrom(backgroundColor: pm.destructive),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    if (widget.isPurchase) {
                                      await ref.read(pmPurchasesRepositoryProvider).deletePurchase(widget.id);
                                      ref.invalidate(pmPurchasesListProvider);
                                    } else {
                                      await ref.read(pmProjectsRepositoryProvider).deleteProject(widget.id);
                                      ref.invalidate(pmProjectsListProvider);
                                    }
                                    if (context.mounted) context.pop();
                                  }
                                },
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.trash2, size: 14),
                                    SizedBox(width: 6),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('#${record.idNo}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: pm.mutedForeground)),
                                    const SizedBox(width: 8),
                                    PmBadge(label: record.orderType, variant: PmBadgeVariant.secondary),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  record.siteName,
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: pm.foreground, fontFamily: 'Inter'),
                                ),
                                if (record.partyPrintName != null && record.partyPrintName!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Party: ${record.partyPrintName}',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: pm.mutedForeground),
                                  ),
                                ],
                                if (record.mobileNumber != null && record.mobileNumber!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(LucideIcons.phone, size: 12, color: pm.primary),
                                      const SizedBox(width: 6),
                                      Text(record.mobileNumber!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: pm.primary)),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Quick Financial Highlights
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: pm.secondary.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(pm.radiusMd),
                          border: Border.all(color: pm.border),
                        ),
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 8,
                          children: [
                            _QuickStat(label: widget.isPurchase ? 'Quotation' : 'Order Value', value: '₹${_currencyFormat.format(orderVal)}'),
                            if (!widget.isPurchase)
                              _QuickStat(label: 'Extra Work', value: '₹${_currencyFormat.format(extraVal)}'),
                            _QuickStat(label: widget.isPurchase ? 'Paid Out' : 'Received', value: '₹${_currencyFormat.format(paidVal)}', color: pm.success),
                            _QuickStat(
                              label: 'Outstanding Balance',
                              value: '₹${_currencyFormat.format(bal)}',
                              color: bal > 0 ? pm.success : (bal < 0 ? pm.destructive : null),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Pill Tabs Header
                Container(
                  color: pm.card,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      decoration: BoxDecoration(
                        color: pm.secondary.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(pm.radiusLg),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicator: BoxDecoration(
                          color: pm.card,
                          borderRadius: BorderRadius.circular(pm.radiusMd),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1)),
                          ],
                        ),
                        labelColor: pm.primary,
                        unselectedLabelColor: pm.mutedForeground,
                        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                        dividerColor: Colors.transparent,
                        tabs: _tabs.map((t) => Tab(text: t, height: 34)).toList(),
                      ),
                    ),
                  ),
                ),

                // Tab Content Body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TabBarView(
                      controller: _tabController,
                      children: widget.isPurchase
                          ? [
                              PmLedgerTab(
                                recordId: widget.id,
                                project: record,
                                isPurchase: true,
                                onRefresh: _refreshAll,
                              ),
                              PmCallingRecordsTab(
                                recordId: widget.id,
                                isPurchase: true,
                                onRefresh: _refreshAll,
                              ),
                            ]
                          : [
                              PmLedgerTab(
                                recordId: widget.id,
                                project: record,
                                isPurchase: false,
                                onRefresh: _refreshAll,
                              ),
                              PmPaymentTermsTab(
                                projectId: widget.id,
                                orderValue: orderVal,
                                onRefresh: _refreshAll,
                              ),
                              PmExpensesTab(
                                projectId: widget.id,
                                onRefresh: _refreshAll,
                              ),
                              PmCallingRecordsTab(
                                recordId: widget.id,
                                isPurchase: false,
                                onRefresh: _refreshAll,
                              ),
                              PmSwhChecklistTab(
                                projectId: widget.id,
                                onRefresh: _refreshAll,
                              ),
                              PmWorkRemarksTab(
                                projectId: widget.id,
                                onRefresh: _refreshAll,
                              ),
                            ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _QuickStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
