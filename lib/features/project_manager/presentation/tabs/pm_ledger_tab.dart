import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_providers.dart';
import '../../providers/pm_company_provider.dart';
import '../../data/models/pm_ledger_entry.dart';
import '../../data/services/pm_pdf_service.dart';
import '../../data/services/pm_excel_service.dart';

class PmLedgerTab extends ConsumerStatefulWidget {
  final String recordId;
  final dynamic project;
  final bool isPurchase;
  final VoidCallback onRefresh;

  const PmLedgerTab({
    super.key,
    required this.recordId,
    required this.project,
    this.isPurchase = false,
    required this.onRefresh,
  });

  @override
  ConsumerState<PmLedgerTab> createState() => _PmLedgerTabState();
}

class _PmLedgerTabState extends ConsumerState<PmLedgerTab> {
  final _currencyFormat = NumberFormat('#,##,##0', 'en_IN');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  void _showAddEditDialog([PmLedgerEntry? entry]) {
    showDialog(
      context: context,
      builder: (ctx) => _AddEditLedgerModal(
        recordId: widget.recordId,
        entry: entry,
        isPurchase: widget.isPurchase,
        onSaved: () async {
          if (widget.isPurchase) {
            await ref.read(pmPurchasesRepositoryProvider).syncPurchaseTotals(widget.recordId);
          } else {
            await ref.read(pmProjectsRepositoryProvider).syncProjectTotals(widget.recordId);
          }
          ref.invalidate(pmLedgerEntriesProvider((id: widget.recordId, isPurchase: widget.isPurchase)));
          widget.onRefresh();
        },
      ),
    );
  }

  Future<void> _deleteEntry(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('Are you sure you want to delete this ledger entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(pmLedgerRepositoryProvider).deleteLedgerEntry(id, isPurchase: widget.isPurchase);
      if (widget.isPurchase) {
        await ref.read(pmPurchasesRepositoryProvider).syncPurchaseTotals(widget.recordId);
      } else {
        await ref.read(pmProjectsRepositoryProvider).syncProjectTotals(widget.recordId);
      }
      ref.invalidate(pmLedgerEntriesProvider((id: widget.recordId, isPurchase: widget.isPurchase)));
      widget.onRefresh();
    }
  }

  void _openFullScreenLedger() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Ledger Full Screen',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        return _FullScreenLedgerDialog(
          recordId: widget.recordId,
          project: widget.project,
          isPurchase: widget.isPurchase,
          onRefresh: widget.onRefresh,
          onAddEdit: (entry) => _showAddEditDialog(entry),
          onDelete: (id) => _deleteEntry(id),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;
    final entriesAsync = ref.watch(pmLedgerEntriesProvider((id: widget.recordId, isPurchase: widget.isPurchase)));
    final activeCompany = ref.watch(pmActiveCompanyProvider);

    return entriesAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (err, _) => Center(child: Text('Error loading ledger: $err', style: TextStyle(color: pm.destructive))),
      data: (entries) {
        // Calculate totals for footer
        double totalSalesM = 0;
        double totalMOutward = 0;
        double totalOrderVal = 0;
        double totalExtraWork = 0;
        double totalReceived = 0;

        for (final e in entries) {
          totalSalesM += e.salesMValue;
          totalMOutward += e.mOutwardValue;
          totalOrderVal += e.orderValue;
          totalExtraWork += e.extraWorkValue;
          totalReceived += e.paymentReceived;
        }

        return LayoutBuilder(
          builder: (context, cardConstraints) {
            final isNarrow = cardConstraints.maxWidth < 750;

            final titleWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ledger Records',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Detailed financial history for this project',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            );

            final actionsWrap = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                      // Export PDF
                      InkWell(
                        onTap: () async {
                          final pdfBytes = await PmPdfService.generateProjectLedgerPdf(
                            project: widget.project,
                            entries: entries,
                            companyName: activeCompany.name,
                            isPurchase: widget.isPurchase,
                          );
                          await Printing.layoutPdf(
                            onLayout: (_) => pdfBytes,
                            name: 'Ledger_${widget.project.siteName}.pdf',
                          );
                        },
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.download, size: 14, color: Color(0xFF005CE6)),
                              SizedBox(width: 6),
                              Text('Export PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                      ),
                      // Export Excel
                      InkWell(
                        onTap: () {
                          final excelBytes = PmExcelService.exportLedgerToExcel(
                            entries: entries,
                            isPurchase: widget.isPurchase,
                          );
                          if (excelBytes != null) {
                            Printing.sharePdf(bytes: excelBytes, filename: 'Ledger_${widget.project.siteName}.xlsx');
                          }
                        },
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.fileSpreadsheet, size: 14, color: Color(0xFF16A34A)),
                              SizedBox(width: 6),
                              Text('Export Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                      ),
                      // Import Excel
                      InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Import Excel template ready')),
                          );
                        },
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.upload, size: 14, color: Color(0xFF005CE6)),
                              SizedBox(width: 6),
                              Text('Import Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF005CE6))),
                            ],
                          ),
                        ),
                      ),
                      // Full Screen Button
                      InkWell(
                        onTap: () => _openFullScreenLedger(),
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.maximize2, size: 14, color: Color(0xFF0F172A)),
                              SizedBox(width: 6),
                              Text('Full Screen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                      ),
                      // + Add New Entry Button
                      InkWell(
                        onTap: () => _showAddEditDialog(),
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF005CE6),
                            borderRadius: BorderRadius.circular(9999),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF005CE6).withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.plus, size: 15, color: Colors.white),
                              SizedBox(width: 6),
                              Text('+ Add New Entry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isNarrow) ...[
                      titleWidget,
                      const SizedBox(height: 12),
                      actionsWrap,
                    ] else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          titleWidget,
                          actionsWrap,
                        ],
                      ),
                    const SizedBox(height: 16),

              if (entries.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(LucideIcons.receipt, size: 40, color: const Color(0xFF94A3B8).withOpacity(0.5)),
                        const SizedBox(height: 10),
                        const Text('No ledger entries yet.', style: TextStyle(color: Color(0xFF64748B))),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => _showAddEditDialog(),
                          borderRadius: BorderRadius.circular(9999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF005CE6),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: const Text('+ Add First Ledger Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, ledgerConstraints) {
                    final double availableWidth = ledgerConstraints.maxWidth;
                    // 11 columns, 10 gaps. Estimated base content width ~ 780.
                    const baseSpacing = 20.0;
                    double dynamicSpacing = baseSpacing;
                    if (availableWidth > 780) {
                      dynamicSpacing = math.max(baseSpacing, (availableWidth - 780) / 10 + 16.0);
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: availableWidth),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          headingRowHeight: 44,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 52,
                          horizontalMargin: 16,
                          columnSpacing: dynamicSpacing,
                    columns: const [
                      DataColumn(label: Text('SR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                      DataColumn(label: Text('DATE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                      DataColumn(label: Text('PAYMENT TYPE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                      DataColumn(label: Text('PARTICULARS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                      DataColumn(label: Text('BILL', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                      DataColumn(numeric: true, label: Text('SALES M', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                      DataColumn(numeric: true, label: Text('M OUTWARD', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                      DataColumn(numeric: true, label: Text('ORDER VAL', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                      DataColumn(numeric: true, label: Text('EXTRA WRK', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                      DataColumn(numeric: true, label: Text('RECEIVED', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                      DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                    ],
                    rows: [
                      ...entries.map((e) {
                        final isReceipt = (e.particulars ?? '').toLowerCase().contains('advance') ||
                            (e.particulars ?? '').toLowerCase().contains('receipt') ||
                            e.paymentReceived > 0;

                        return DataRow(
                          cells: [
                            DataCell(Text('${e.srNo}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                            DataCell(Text(_dateFormat.format(e.date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                            // PAYMENT TYPE (Pill badge)
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  (e.paymentType ?? 'ONLINE').toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                                ),
                              ),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  e.particulars ?? '-',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            // BILL Status (Pill badge: PENDING or RECEIPT)
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isReceipt ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(9999),
                                  border: isReceipt ? null : Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  isReceipt ? 'RECEIPT' : 'PENDING',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: isReceipt ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            // SALES M (Pale yellow background)
                            DataCell(
                              Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEFCE8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  e.salesMValue > 0 ? '₹${_currencyFormat.format(e.salesMValue)}' : '',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                ),
                              ),
                            ),
                            // M OUTWARD (Pale yellow background)
                            DataCell(
                              Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEFCE8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  e.mOutwardValue > 0 ? '₹${_currencyFormat.format(e.mOutwardValue)}' : '',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                e.orderValue > 0 ? '₹${_currencyFormat.format(e.orderValue)}' : '',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                            ),
                            DataCell(
                              Text(
                                e.extraWorkValue > 0 ? '₹${_currencyFormat.format(e.extraWorkValue)}' : '',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                            ),
                            // RECEIVED (Pale green background, bold green text)
                            DataCell(
                              Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: e.paymentReceived > 0 ? const Color(0xFFF0FDF4) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  e.paymentReceived > 0 ? '₹${_currencyFormat.format(e.paymentReceived)}' : '',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(LucideIcons.pencil, size: 14, color: Color(0xFF64748B)),
                                    onPressed: () => _showAddEditDialog(e),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.trash2, size: 14, color: Color(0xFFEF4444)),
                                    onPressed: () => _deleteEntry(e.id),
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                      // NET TOTALS FOOTER ROW (Screenshot 2)
                      DataRow(
                        color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        cells: [
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(
                            Text(
                              'NET TOTALS:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                          ),
                          DataCell(
                            Text(
                              '₹${_currencyFormat.format(totalSalesM)}.00',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ),
                          DataCell(
                            Text(
                              '₹${_currencyFormat.format(totalMOutward)}.00',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ),
                          DataCell(
                            Text(
                              '₹${_currencyFormat.format(totalOrderVal)}.00',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ),
                          DataCell(
                            Text(
                              '₹${_currencyFormat.format(totalExtraWork)}.00',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ),
                          DataCell(
                            Text(
                              '₹${_currencyFormat.format(totalReceived)}.00',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                            ),
                          ),
                          const DataCell(Text('')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
            ],
          ),
        ),
      );
    },
  );
      },
    );
  }
}

// Add/Edit Modal matching Screenshot 3
class _AddEditLedgerModal extends StatefulWidget {
  final String recordId;
  final PmLedgerEntry? entry;
  final bool isPurchase;
  final VoidCallback onSaved;

  const _AddEditLedgerModal({
    required this.recordId,
    this.entry,
    this.isPurchase = false,
    required this.onSaved,
  });

  @override
  State<_AddEditLedgerModal> createState() => _AddEditLedgerModalState();
}

class _AddEditLedgerModalState extends State<_AddEditLedgerModal> {
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  String _paymentType = 'Cash';
  String _particulars = 'Bill';

  final _particularsCustomCtrl = TextEditingController();
  final _refNoCtrl = TextEditingController();
  final _invNoCtrl = TextEditingController();
  final _salesMCtrl = TextEditingController();
  final _mOutwardCtrl = TextEditingController();
  final _orderValueCtrl = TextEditingController();
  final _extraWorkCtrl = TextEditingController();
  final _paymentRecdCtrl = TextEditingController();

  bool _billSubmitted = false;
  bool _paymentReceipt = false;
  bool _isLoading = false;

  final List<String> _types = [
    'Cash',
    'Bank Transfer / NEFT',
    'RTGS',
    'Cheque',
    'Online',
    'Advance',
    'Final Settlement',
  ];

  final List<String> _particularsOptions = [
    'Bill',
    'System work',
    'Advance',
    'Material Supply',
    'Installation Charges',
    'Transport / Freight',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _date = widget.entry!.date;
      _paymentType = widget.entry!.paymentType ?? 'Cash';
      _particulars = widget.entry!.particulars ?? 'Bill';
      if (!_particularsOptions.contains(_particulars)) {
        _particularsCustomCtrl.text = _particulars;
        _particulars = 'Other';
      }
      _refNoCtrl.text = widget.entry!.referenceNumber ?? '';
      _invNoCtrl.text = widget.entry!.invoiceNo ?? '';
      _salesMCtrl.text = widget.entry!.salesMValue > 0 ? widget.entry!.salesMValue.toStringAsFixed(0) : '';
      _mOutwardCtrl.text = widget.entry!.mOutwardValue > 0 ? widget.entry!.mOutwardValue.toStringAsFixed(0) : '';
      _orderValueCtrl.text = widget.entry!.orderValue > 0 ? widget.entry!.orderValue.toStringAsFixed(0) : '';
      _extraWorkCtrl.text = widget.entry!.extraWorkValue > 0 ? widget.entry!.extraWorkValue.toStringAsFixed(0) : '';
      _paymentRecdCtrl.text = widget.entry!.paymentReceived > 0 ? widget.entry!.paymentReceived.toStringAsFixed(0) : '';
      _billSubmitted = widget.isPurchase ? widget.entry!.billReceived : widget.entry!.billSubmitted;
      _paymentReceipt = widget.entry!.paymentReceived > 0;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final actualParticulars = _particulars == 'Other' ? _particularsCustomCtrl.text.trim() : _particulars;

      final data = {
        if (widget.isPurchase) 'purchase_id': widget.recordId else 'project_id': widget.recordId,
        'sr_no': widget.entry?.srNo ?? 1,
        'date': _date.toIso8601String().split('T').first,
        'payment_type': _paymentType,
        'particulars': actualParticulars.isNotEmpty ? actualParticulars : 'Bill',
        'reference_number': _refNoCtrl.text.trim(),
        'invoice_no': _invNoCtrl.text.trim(),
        'sales_m_value': double.tryParse(_salesMCtrl.text) ?? 0.0,
        'm_outward_value': double.tryParse(_mOutwardCtrl.text) ?? 0.0,
        'order_value': double.tryParse(_orderValueCtrl.text) ?? 0.0,
        'extra_work_value': double.tryParse(_extraWorkCtrl.text) ?? 0.0,
        'payment_received': double.tryParse(_paymentRecdCtrl.text) ?? 0.0,
        if (widget.isPurchase) 'quotation_value': double.tryParse(_orderValueCtrl.text) ?? 0.0,
        if (widget.isPurchase) 'payment_paid': double.tryParse(_paymentRecdCtrl.text) ?? 0.0,
        if (widget.isPurchase) 'bill_received': _billSubmitted else 'bill_submitted': _billSubmitted,
      };

      final ref = ProviderScope.containerOf(context);
      if (widget.entry != null) {
        await ref.read(pmLedgerRepositoryProvider).updateLedgerEntry(widget.entry!.id, data, isPurchase: widget.isPurchase);
      } else {
        await ref.read(pmLedgerRepositoryProvider).addLedgerEntry(data, isPurchase: widget.isPurchase);
      }

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildFieldBox({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title + Close Icon (Screenshot 3)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.entry != null ? 'Edit Ledger Entry' : 'Add Ledger Entry',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Row: Date & Payment Type
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _date,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) setState(() => _date = picked);
                              },
                              child: _buildFieldBox(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(DateFormat('dd-MM-yyyy').format(_date), style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A))),
                                      const Icon(LucideIcons.calendar, size: 16, color: Color(0xFF0F172A)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Payment Type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Payment Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                InkWell(
                                  onTap: () {},
                                  child: const Text('Edit Dropdown List', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF005CE6))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildFieldBox(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _types.contains(_paymentType) ? _paymentType : _types.first,
                                  isExpanded: true,
                                  icon: const Icon(LucideIcons.chevronDown, size: 16, color: Color(0xFF64748B)),
                                  items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A))))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _paymentType = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Row: Reference Number & Invoice No
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Reference Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            _buildFieldBox(
                              child: TextFormField(
                                controller: _refNoCtrl,
                                style: const TextStyle(fontSize: 13.5),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Invoice No', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            _buildFieldBox(
                              child: TextFormField(
                                controller: _invNoCtrl,
                                style: const TextStyle(fontSize: 13.5),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Particulars
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Particulars', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          InkWell(
                            onTap: () {},
                            child: const Text('Edit Dropdown List', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF005CE6))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildFieldBox(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _particularsOptions.contains(_particulars) ? _particulars : 'Bill',
                            isExpanded: true,
                            icon: const Icon(LucideIcons.chevronDown, size: 16, color: Color(0xFF64748B)),
                            items: _particularsOptions.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A))))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _particulars = val);
                            },
                          ),
                        ),
                      ),
                      if (_particulars == 'Other') ...[
                        const SizedBox(height: 8),
                        _buildFieldBox(
                          child: TextFormField(
                            controller: _particularsCustomCtrl,
                            style: const TextStyle(fontSize: 13.5),
                            decoration: const InputDecoration(
                              hintText: 'Enter custom particulars...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Checkboxes: Bill Submitted & Payment Receipt
                  Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _billSubmitted,
                            activeColor: const Color(0xFF005CE6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) => setState(() => _billSubmitted = val ?? false),
                          ),
                          const Text('Bill Submitted', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _paymentReceipt,
                            activeColor: const Color(0xFF005CE6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) => setState(() => _paymentReceipt = val ?? false),
                          ),
                          const Text('Payment Receipt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ],
                  ),

                  const Divider(color: Color(0xFFE2E8F0), height: 28),

                  // Material Section (Screenshot 3)
                  const Text(
                    'Material Section',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Sales M Value', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            _buildFieldBox(
                              child: TextFormField(
                                controller: _salesMCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 13.5),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('M Outward Value', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            _buildFieldBox(
                              child: TextFormField(
                                controller: _mOutwardCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 13.5),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Divider(color: Color(0xFFE2E8F0), height: 28),

                  // Account Section (Screenshot 3: bright sky blue header)
                  const Text(
                    'Account Section',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Order Value', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            _buildFieldBox(
                              child: TextFormField(
                                controller: _orderValueCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 13.5),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Extra Work Value', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            _buildFieldBox(
                              child: TextFormField(
                                controller: _extraWorkCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 13.5),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payment Received', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            _buildFieldBox(
                              child: TextFormField(
                                controller: _paymentRecdCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 13.5),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Bottom Action Buttons (Screenshot 3)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Cancel Button
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Add Entry Button
                      InkWell(
                        onTap: _isLoading ? null : _submit,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF005CE6),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF005CE6).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(
                                  widget.entry != null ? 'Update Entry' : 'Add Entry',
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenLedgerDialog extends ConsumerWidget {
  final String recordId;
  final dynamic project;
  final bool isPurchase;
  final VoidCallback onRefresh;
  final void Function(PmLedgerEntry? entry) onAddEdit;
  final Future<void> Function(String id) onDelete;

  const _FullScreenLedgerDialog({
    required this.recordId,
    required this.project,
    required this.isPurchase,
    required this.onRefresh,
    required this.onAddEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(pmLedgerEntriesProvider((id: recordId, isPurchase: isPurchase)));
    final activeCompany = ref.watch(pmActiveCompanyProvider);
    final currencyFormat = NumberFormat('#,##,##0', 'en_IN');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF005CE6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.receipt, size: 20, color: Color(0xFF005CE6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              project.siteName ?? 'Ledger Records',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Text(
                                '#${project.idNo}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Full Screen Ledger Record View • ${activeCompany.name}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      // Add Entry
                      InkWell(
                        onTap: () => onAddEdit(null),
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF005CE6),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.plus, size: 14, color: Colors.white),
                              SizedBox(width: 6),
                              Text('+ Add Entry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                      // Close / Minimize
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.minimize2, size: 14, color: Color(0xFF0F172A)),
                              SizedBox(width: 6),
                              Text('Exit Full Screen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: entriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
                data: (entries) {
                  if (entries.isEmpty) {
                    return const Center(child: Text('No ledger entries recorded yet.'));
                  }

                  double totalSalesM = 0;
                  double totalMOutward = 0;
                  double totalOrderVal = 0;
                  double totalExtraWork = 0;
                  double totalReceived = 0;

                  for (final e in entries) {
                    totalSalesM += e.salesMValue;
                    totalMOutward += e.mOutwardValue;
                    totalOrderVal += e.orderValue;
                    totalExtraWork += e.extraWorkValue;
                    totalReceived += e.paymentReceived;
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            headingRowHeight: 46,
                            dataRowMinHeight: 48,
                            dataRowMaxHeight: 52,
                            horizontalMargin: 20,
                            columnSpacing: 28,
                            columns: const [
                              DataColumn(label: Text('SR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                              DataColumn(label: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                              DataColumn(label: Text('PAYMENT TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                              DataColumn(label: Text('PARTICULARS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                              DataColumn(label: Text('BILL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                              DataColumn(numeric: true, label: Text('SALES M', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                              DataColumn(numeric: true, label: Text('M OUTWARD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                              DataColumn(numeric: true, label: Text('ORDER VAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                              DataColumn(numeric: true, label: Text('EXTRA WRK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                              DataColumn(numeric: true, label: Text('RECEIVED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                              DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                            ],
                            rows: [
                              ...entries.map((e) {
                                final isReceipt = (e.particulars ?? '').toLowerCase().contains('advance') ||
                                    (e.particulars ?? '').toLowerCase().contains('receipt') ||
                                    e.paymentReceived > 0;

                                return DataRow(
                                  cells: [
                                    DataCell(Text('${e.srNo}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                                    DataCell(Text(dateFormat.format(e.date), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(9999),
                                        ),
                                        child: Text(
                                          (e.paymentType ?? 'ONLINE').toUpperCase(),
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 240),
                                        child: Text(
                                          e.particulars ?? '-',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isReceipt ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(9999),
                                          border: isReceipt ? null : Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Text(
                                          isReceipt ? 'RECEIPT' : 'PENDING',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: isReceipt ? Colors.white : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEFCE8),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          e.salesMValue > 0 ? '₹${currencyFormat.format(e.salesMValue)}' : '',
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEFCE8),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          e.mOutwardValue > 0 ? '₹${currencyFormat.format(e.mOutwardValue)}' : '',
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        e.orderValue > 0 ? '₹${currencyFormat.format(e.orderValue)}' : '',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        e.extraWorkValue > 0 ? '₹${currencyFormat.format(e.extraWorkValue)}' : '',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: e.paymentReceived > 0 ? const Color(0xFFF0FDF4) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          e.paymentReceived > 0 ? '₹${currencyFormat.format(e.paymentReceived)}' : '',
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(LucideIcons.pencil, size: 15, color: Color(0xFF64748B)),
                                            onPressed: () => onAddEdit(e),
                                            tooltip: 'Edit',
                                          ),
                                          IconButton(
                                            icon: const Icon(LucideIcons.trash2, size: 15, color: Color(0xFFEF4444)),
                                            onPressed: () => onDelete(e.id),
                                            tooltip: 'Delete',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              DataRow(
                                color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                cells: [
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  const DataCell(
                                    Text(
                                      'NET TOTALS:',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '₹${currencyFormat.format(totalSalesM)}.00',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '₹${currencyFormat.format(totalMOutward)}.00',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '₹${currencyFormat.format(totalOrderVal)}.00',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '₹${currencyFormat.format(totalExtraWork)}.00',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '₹${currencyFormat.format(totalReceived)}.00',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                                    ),
                                  ),
                                  const DataCell(Text('')),
                                ],
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
