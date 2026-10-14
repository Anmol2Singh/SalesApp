import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_providers.dart';
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

  IconData _getTabIcon(String tab) {
    switch (tab) {
      case 'Financial Ledger':
        return LucideIcons.receipt;
      case 'Payment Terms':
        return LucideIcons.calendar;
      case 'Project Expenses':
        return LucideIcons.wallet;
      case 'Call Records':
        return LucideIcons.phoneCall;
      case 'Checklist':
        return LucideIcons.checkSquare;
      case 'Work Remarks':
        return LucideIcons.messageSquare;
      default:
        return LucideIcons.fileText;
    }
  }

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

            final customerSince = record.createdAt != null
                ? DateFormat('dd/MM/yyyy').format(record.createdAt!)
                : (record.reminderDate != null ? DateFormat('dd/MM/yyyy').format(record.reminderDate!) : '10/10/2026');
            final salesMan = record.salesMan ?? record.salesmanName ?? 'Sagar Farate';
            final firmName = record.firmName ?? 'Insiya Trading Corporation';

            return LayoutBuilder(
              builder: (context, screenConstraints) {
                final isMobile = screenConstraints.maxWidth < 650;
                final isNarrow = screenConstraints.maxWidth < 750;
                final isWide = screenConstraints.maxWidth > 850;

                final backButton = InkWell(
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/pm');
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.arrowLeft, size: 16, color: Color(0xFF0F172A)),
                        SizedBox(width: 6),
                        Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                final moveCopyBtn = InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Move / Copy Customer')),
                    );
                  },
                  borderRadius: BorderRadius.circular(9999),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.folderInput, size: 14, color: Color(0xFF005CE6)),
                        const SizedBox(width: 6),
                        Text(
                          isMobile ? 'Move / Copy' : 'Move / Copy Customer',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                );

                final deleteBtn = InkWell(
                  onTap: () async {
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
                      if (context.mounted) {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/pm');
                        }
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(9999),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.trash2, size: 14, color: Color(0xFFEF4444)),
                        const SizedBox(width: 6),
                        Text(
                          isMobile ? 'Delete' : 'Delete Project',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ),
                );

                final editDetailsBtn = InkWell(
                  onTap: () {
                    context.push('/pm/projects/${widget.id}/edit${widget.isPurchase ? "?mode=purchase" : ""}');
                  },
                  borderRadius: BorderRadius.circular(9999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.pencil, size: 14, color: Color(0xFF475569)),
                        SizedBox(width: 6),
                        Text('Edit Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                );

                final newCallRemarkBtn = InkWell(
                  onTap: () {
                    context.push('/pm/quick-call-remark?id=${widget.id}&type=${widget.isPurchase ? "purchase" : "project"}');
                  },
                  borderRadius: BorderRadius.circular(9999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF005CE6),
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF005CE6).withOpacity(0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.phoneCall, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text('New Call Remark', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                );

                final metadataChipsWrap = Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Order Type Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Text(
                        record.orderType.toString().toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                      ),
                    ),
                    // Sales Man Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        'Sales Man: $salesMan',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                      ),
                    ),
                    // Firm Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Text(
                        'Firm: $firmName',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC2410C)),
                      ),
                    ),
                    // Customer Since Pill (Click to edit)
                    Tooltip(
                      message: 'Click to edit Customer Since date',
                      child: InkWell(
                        onTap: () async {
                          final initialDate = record.createdAt ?? DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            if (widget.isPurchase) {
                              await ref.read(pmPurchasesRepositoryProvider).updatePurchase(widget.id, {
                                'created_at': picked.toIso8601String(),
                              });
                            } else {
                              await ref.read(pmProjectsRepositoryProvider).updateProject(widget.id, {
                                'created_at': picked.toIso8601String(),
                              });
                            }
                            _refreshAll();
                          }
                        },
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Customer Since: $customerSince (ID: ${record.idNo})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                              ),
                              const SizedBox(width: 4),
                              const Icon(LucideIcons.calendar, size: 12, color: Color(0xFF15803D)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );

                final titleSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.siteName.toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.address ?? "Installation Site"}, GSTIN : ${record.gstNo ?? "27AAPCM6498L1ZE Maharashtra"}',
                      style: TextStyle(fontSize: isMobile ? 11.5 : 12.5, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    // Technical spec tags row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _SpecTag(label: 'Item Name: ${record.itemPurchased ?? "GI Pressurized Tank 500ltr"}'),
                        _SpecTag(label: 'Item Qty: ${record.itemQuantity ?? 2}'),
                        _SpecTag(label: 'Tank Type: ${record.tankType ?? "SOLAR WATER HEATER 700/38"}'),
                        _SpecTag(label: 'Tank: ${record.tankCapacity ?? 45}'),
                      ],
                    ),
                  ],
                );

                final financialSummaryBox = Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: isMobile
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _FinanceMetric(label: 'ORDER VALUE', value: '₹${_currencyFormat.format(orderVal)}', color: const Color(0xFF0F172A))),
                                const SizedBox(width: 12),
                                Expanded(child: _FinanceMetric(label: 'EXTRA WORK', value: '₹${_currencyFormat.format(extraVal)}', color: const Color(0xFF0F172A))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _FinanceMetric(label: 'RECEIVED', value: '₹${_currencyFormat.format(paidVal)}', color: const Color(0xFF16A34A))),
                                const SizedBox(width: 12),
                                Expanded(child: _FinanceMetric(label: 'BALANCE', value: '₹${_currencyFormat.format(bal)}', color: const Color(0xFF16A34A))),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FinanceMetric(label: 'ORDER VALUE', value: '₹${_currencyFormat.format(orderVal)}', color: const Color(0xFF0F172A)),
                            const SizedBox(width: 24),
                            _FinanceMetric(label: 'EXTRA WORK', value: '₹${_currencyFormat.format(extraVal)}', color: const Color(0xFF0F172A)),
                            const SizedBox(width: 24),
                            _FinanceMetric(label: 'RECEIVED', value: '₹${_currencyFormat.format(paidVal)}', color: const Color(0xFF16A34A)),
                            const SizedBox(width: 24),
                            _FinanceMetric(label: 'BALANCE', value: '₹${_currencyFormat.format(bal)}', color: const Color(0xFF16A34A)),
                          ],
                        ),
                );

                return NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Row 1: Back + Top Actions (Move/Copy, Delete)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                backButton,
                                Flexible(
                                  child: Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      moveCopyBtn,
                                      deleteBtn,
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Row 2: Metadata Badges + Right Action Buttons (Edit Details & New Call Remark)
                            if (isNarrow) ...[
                              Row(
                                children: [
                                  Expanded(child: editDetailsBtn),
                                  const SizedBox(width: 8),
                                  Expanded(child: newCallRemarkBtn),
                                ],
                              ),
                              const SizedBox(height: 10),
                              metadataChipsWrap,
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(child: metadataChipsWrap),
                                  const SizedBox(width: 12),
                                  editDetailsBtn,
                                  const SizedBox(width: 8),
                                  newCallRemarkBtn,
                                ],
                              ),

                            const SizedBox(height: 14),

                            // Row 3: Project Title, Address & Spec Badges vs Financial Card
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: titleSection),
                                  const SizedBox(width: 20),
                                  financialSummaryBox,
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  titleSection,
                                  const SizedBox(height: 16),
                                  financialSummaryBox,
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverTabBarDelegate(
                        height: 58,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              padding: const EdgeInsets.all(3.5),
                              child: TabBar(
                                controller: _tabController,
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                indicatorSize: TabBarIndicatorSize.tab,
                                indicatorPadding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                                indicator: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(9999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withOpacity(0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF005CE6).withOpacity(0.06),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                labelColor: const Color(0xFF005CE6),
                                unselectedLabelColor: const Color(0xFF64748B),
                                labelStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                                unselectedLabelStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                                dividerColor: Colors.transparent,
                                overlayColor: WidgetStateProperty.all(Colors.transparent),
                                tabs: _tabs.map((t) {
                                  final icon = _getTabIcon(t);
                                  return Tab(
                                    height: 35,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 14),
                                        const SizedBox(width: 7),
                                        Text(t.toUpperCase()),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  body: Padding(
                    padding: EdgeInsets.all(isMobile ? 10 : 16),
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SpecTag extends StatelessWidget {
  final String label;

  const _SpecTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0369A1),
        ),
      ),
    );
  }
}

class _FinanceMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FinanceMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SliverTabBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

