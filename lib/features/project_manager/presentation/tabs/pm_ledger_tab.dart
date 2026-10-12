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
import '../widgets/pm_button.dart';
import '../widgets/pm_card.dart';
import '../widgets/pm_badge.dart';

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
  final _dateFormat = DateFormat('dd-MM-yyyy');

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

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;
    final entriesAsync = ref.watch(pmLedgerEntriesProvider((id: widget.recordId, isPurchase: widget.isPurchase)));
    final activeCompany = ref.watch(pmActiveCompanyProvider);

    return entriesAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (err, _) => Center(child: Text('Error loading ledger: $err', style: TextStyle(color: pm.destructive))),
      data: (entries) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toolbar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      widget.isPurchase ? 'Vendor Financial Ledger' : 'Financial Statement',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pm.foreground),
                    ),
                    const SizedBox(width: 8),
                    PmBadge(label: '${entries.length} Entries', variant: PmBadgeVariant.secondary),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    PmButton(
                      variant: PmButtonVariant.outline,
                      size: PmButtonSize.sm,
                      onPressed: () async {
                        final pdfBytes = await PmPdfService.generateProjectLedgerPdf(
                          project: widget.project,
                          entries: entries,
                          companyName: activeCompany.name,
                          isPurchase: widget.isPurchase,
                        );
                        await Printing.layoutPdf(onLayout: (_) => pdfBytes, name: 'Ledger_${widget.project.siteName}.pdf');
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
                        final excelBytes = PmExcelService.exportLedgerToExcel(
                          entries: entries,
                          isPurchase: widget.isPurchase,
                        );
                        if (excelBytes != null) {
                          Printing.sharePdf(bytes: excelBytes, filename: 'Ledger_${widget.project.siteName}.xlsx');
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
                    PmButton(
                      size: PmButtonSize.sm,
                      onPressed: () => _showAddEditDialog(),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.plus, size: 14),
                          SizedBox(width: 6),
                          Text('Add Entry'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (entries.isEmpty)
              PmCard(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(LucideIcons.receipt, size: 40, color: pm.mutedForeground.withOpacity(0.5)),
                      const SizedBox(height: 10),
                      Text('No ledger entries yet.', style: TextStyle(color: pm.mutedForeground)),
                      const SizedBox(height: 12),
                      PmButton(
                        size: PmButtonSize.sm,
                        onPressed: () => _showAddEditDialog(),
                        child: const Text('+ Add First Ledger Entry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              PmCard(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(pm.secondary.withOpacity(0.6)),
                    columns: [
                      const DataColumn(label: Text('SR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('PARTICULARS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('REF / INV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(widget.isPurchase ? 'BILL RECD' : 'BILL SUBMITTED', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(numeric: true, label: Text(widget.isPurchase ? 'QUOTATION' : 'ORDER VALUE', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(numeric: true, label: Text(widget.isPurchase ? 'PAID' : 'PAYMENT RECD', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      const DataColumn(numeric: true, label: Text('RUNNING BAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                    rows: () {
                      double runningBal = 0;
                      return entries.map((e) {
                        if (widget.isPurchase) {
                          runningBal += e.orderValue - e.paymentReceived;
                        } else {
                          runningBal += (e.orderValue + e.extraWorkValue) - e.paymentReceived;
                        }

                        return DataRow(
                          cells: [
                            DataCell(Text('#${e.srNo}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pm.mutedForeground))),
                            DataCell(Text(_dateFormat.format(e.date), style: const TextStyle(fontSize: 12))),
                            DataCell(Text(e.paymentType ?? '-', style: const TextStyle(fontSize: 12))),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 200),
                                child: Text(e.particulars ?? '-', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            DataCell(Text(e.invoiceNo ?? e.referenceNumber ?? '-', style: TextStyle(fontSize: 11, color: pm.mutedForeground))),
                            DataCell(
                              Checkbox(
                                value: widget.isPurchase ? e.billReceived : e.billSubmitted,
                                onChanged: (val) async {
                                  final updateData = widget.isPurchase
                                      ? {'bill_received': val ?? false}
                                      : {'bill_submitted': val ?? false};
                                  await ref.read(pmLedgerRepositoryProvider).updateLedgerEntry(e.id, updateData, isPurchase: widget.isPurchase);
                                  ref.invalidate(pmLedgerEntriesProvider((id: widget.recordId, isPurchase: widget.isPurchase)));
                                },
                              ),
                            ),
                            DataCell(Text('₹${_currencyFormat.format(e.orderValue)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            DataCell(Text('₹${_currencyFormat.format(e.paymentReceived)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pm.success))),
                            DataCell(Text('₹${_currencyFormat.format(runningBal)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: runningBal >= 0 ? pm.success : pm.destructive))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(LucideIcons.pencil, size: 14),
                                    onPressed: () => _showAddEditDialog(e),
                                  ),
                                  IconButton(
                                    icon: Icon(LucideIcons.trash2, size: 14, color: pm.destructive),
                                    onPressed: () => _deleteEntry(e.id),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    }(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

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
  String _paymentType = 'Bank Transfer / NEFT';
  final _particularsCtrl = TextEditingController();
  final _refNoCtrl = TextEditingController();
  final _invNoCtrl = TextEditingController();
  final _orderValueCtrl = TextEditingController(text: '0');
  final _paymentRecdCtrl = TextEditingController(text: '0');
  bool _billSubmitted = false;
  bool _isLoading = false;

  final List<String> _types = [
    'Advance',
    'Bank Transfer / NEFT',
    'RTGS',
    'Cheque',
    'Cash',
    'UPI / Online',
    'Milestone Payment',
    'Final Settlement',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _date = widget.entry!.date;
      _paymentType = widget.entry!.paymentType ?? _types.first;
      _particularsCtrl.text = widget.entry!.particulars ?? '';
      _refNoCtrl.text = widget.entry!.referenceNumber ?? '';
      _invNoCtrl.text = widget.entry!.invoiceNo ?? '';
      _orderValueCtrl.text = widget.entry!.orderValue.toStringAsFixed(0);
      _paymentRecdCtrl.text = widget.entry!.paymentReceived.toStringAsFixed(0);
      _billSubmitted = widget.isPurchase ? widget.entry!.billReceived : widget.entry!.billSubmitted;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        if (widget.isPurchase) 'purchase_id': widget.recordId else 'project_id': widget.recordId,
        'sr_no': widget.entry?.srNo ?? 1,
        'date': _date.toIso8601String().split('T').first,
        'payment_type': _paymentType,
        'particulars': _particularsCtrl.text.trim(),
        'reference_number': _refNoCtrl.text.trim(),
        'invoice_no': _invNoCtrl.text.trim(),
        if (widget.isPurchase) 'quotation_value': double.tryParse(_orderValueCtrl.text) ?? 0.0 else 'order_value': double.tryParse(_orderValueCtrl.text) ?? 0.0,
        if (widget.isPurchase) 'payment_paid': double.tryParse(_paymentRecdCtrl.text) ?? 0.0 else 'payment_received': double.tryParse(_paymentRecdCtrl.text) ?? 0.0,
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

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;
    return Dialog(
      backgroundColor: pm.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pm.radiusLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                      Text(
                        widget.entry != null ? 'Edit Ledger Entry' : 'Add Ledger Entry',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: pm.foreground),
                      ),
                      IconButton(icon: const Icon(LucideIcons.x, size: 16), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Date Picker
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(border: Border.all(color: pm.border), borderRadius: BorderRadius.circular(pm.radiusMd)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Date: ${DateFormat('dd-MM-yyyy').format(_date)}', style: TextStyle(fontSize: 13, color: pm.foreground)),
                          Icon(LucideIcons.calendar, size: 16, color: pm.primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Payment Type Dropdown
                  DropdownButtonFormField<String>(
                    value: _types.contains(_paymentType) ? _paymentType : _types.first,
                    items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _paymentType = val);
                    },
                    decoration: InputDecoration(
                      labelText: 'Payment / Transaction Mode',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _particularsCtrl,
                    decoration: InputDecoration(
                      labelText: 'Particulars / Description',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _refNoCtrl,
                          decoration: InputDecoration(
                            labelText: 'Ref Number / UTR',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _invNoCtrl,
                          decoration: InputDecoration(
                            labelText: 'Invoice Number',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _orderValueCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: widget.isPurchase ? 'Quotation Value (₹)' : 'Order Value (₹)',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _paymentRecdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: widget.isPurchase ? 'Payment Paid (₹)' : 'Payment Recd (₹)',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: Text(widget.isPurchase ? 'Bill Received' : 'Bill Submitted', style: const TextStyle(fontSize: 13)),
                    value: _billSubmitted,
                    onChanged: (val) => setState(() => _billSubmitted = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  PmButton(
                    isLoading: _isLoading,
                    onPressed: _submit,
                    child: Text(widget.entry != null ? 'Update Entry' : 'Add Entry'),
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
