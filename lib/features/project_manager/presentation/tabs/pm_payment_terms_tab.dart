import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_providers.dart';
import '../../data/models/pm_payment_term.dart';
import '../widgets/pm_button.dart';
import '../widgets/pm_card.dart';
import '../widgets/pm_badge.dart';

class PmPaymentTermsTab extends ConsumerWidget {
  final String projectId;
  final double orderValue;
  final VoidCallback onRefresh;

  const PmPaymentTermsTab({
    super.key,
    required this.projectId,
    required this.orderValue,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pm = context.pm;
    final termsAsync = ref.watch(pmPaymentTermsProvider(projectId));
    final currency = NumberFormat('#,##,##0', 'en_IN');

    return termsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: pm.destructive))),
      data: (terms) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Payment Terms Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pm.foreground)),
                    const SizedBox(width: 8),
                    PmBadge(label: '${terms.length} Terms', variant: PmBadgeVariant.secondary),
                  ],
                ),
                PmButton(
                  size: PmButtonSize.sm,
                  onPressed: () => _showAddEditModal(context, ref),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus, size: 14),
                      SizedBox(width: 6),
                      Text('Add Term'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (terms.isEmpty)
              PmCard(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(LucideIcons.circleDollarSign, size: 40, color: pm.mutedForeground.withOpacity(0.5)),
                      const SizedBox(height: 10),
                      Text('No payment milestone terms defined yet.', style: TextStyle(color: pm.mutedForeground)),
                      const SizedBox(height: 12),
                      PmButton(
                        size: PmButtonSize.sm,
                        onPressed: () => _showAddEditModal(context, ref),
                        child: const Text('+ Add Milestone Term'),
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
                    columns: const [
                      DataColumn(label: Text('PAYMENT TERM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(numeric: true, label: Text('%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(numeric: true, label: Text('AMOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(numeric: true, label: Text('RECEIVED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(numeric: true, label: Text('PENDING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('REMARK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                    rows: terms.map((t) {
                      return DataRow(
                        cells: [
                          DataCell(Text(t.paymentTerm, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          DataCell(Text('${t.termPercentage}%', style: const TextStyle(fontSize: 12))),
                          DataCell(Text('₹${currency.format(t.amount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                          DataCell(Text('₹${currency.format(t.receivedAmount)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pm.success))),
                          DataCell(Text('₹${currency.format(t.pendingAmount)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.pendingAmount > 0 ? pm.warning : pm.mutedForeground))),
                          DataCell(Text(t.remark ?? '-', style: TextStyle(fontSize: 12, color: pm.mutedForeground))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(LucideIcons.pencil, size: 14),
                                  onPressed: () => _showAddEditModal(context, ref, t),
                                ),
                                IconButton(
                                  icon: Icon(LucideIcons.trash2, size: 14, color: pm.destructive),
                                  onPressed: () async {
                                    await ref.read(pmLedgerRepositoryProvider).deletePaymentTerm(t.id);
                                    ref.invalidate(pmPaymentTermsProvider(projectId));
                                    onRefresh();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showAddEditModal(BuildContext context, WidgetRef ref, [PmPaymentTerm? term]) {
    showDialog(
      context: context,
      builder: (ctx) => _PaymentTermDialog(
        projectId: projectId,
        orderValue: orderValue,
        term: term,
        onSaved: () {
          ref.invalidate(pmPaymentTermsProvider(projectId));
          onRefresh();
        },
      ),
    );
  }
}

class _PaymentTermDialog extends StatefulWidget {
  final String projectId;
  final double orderValue;
  final PmPaymentTerm? term;
  final VoidCallback onSaved;

  const _PaymentTermDialog({
    required this.projectId,
    required this.orderValue,
    this.term,
    required this.onSaved,
  });

  @override
  State<_PaymentTermDialog> createState() => _PaymentTermDialogState();
}

class _PaymentTermDialogState extends State<_PaymentTermDialog> {
  final _formKey = GlobalKey<FormState>();
  final _termCtrl = TextEditingController();
  final _percentCtrl = TextEditingController(text: '0');
  final _amountCtrl = TextEditingController(text: '0');
  final _receivedCtrl = TextEditingController(text: '0');
  final _pendingCtrl = TextEditingController(text: '0');
  final _remarkCtrl = TextEditingController();
  bool _isLoading = false;

  final List<String> _commonTerms = [
    'Advance',
    'Material on Site',
    'Installation',
    'Testing & Commissioning',
    'Handover / Final Settlement',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.term != null) {
      _termCtrl.text = widget.term!.paymentTerm;
      _percentCtrl.text = widget.term!.termPercentage.toStringAsFixed(0);
      _amountCtrl.text = widget.term!.amount.toStringAsFixed(0);
      _receivedCtrl.text = widget.term!.receivedAmount.toStringAsFixed(0);
      _pendingCtrl.text = widget.term!.pendingAmount.toStringAsFixed(0);
      _remarkCtrl.text = widget.term!.remark ?? '';
    } else {
      _termCtrl.text = _commonTerms.first;
    }
  }

  void _onPercentChanged(String val) {
    final p = double.tryParse(val) ?? 0;
    final amt = widget.orderValue * (p / 100);
    _amountCtrl.text = amt.toStringAsFixed(0);
    final rec = double.tryParse(_receivedCtrl.text) ?? 0;
    _pendingCtrl.text = (amt - rec).toStringAsFixed(0);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final amt = double.tryParse(_amountCtrl.text) ?? 0;
      final rec = double.tryParse(_receivedCtrl.text) ?? 0;

      final data = {
        'project_id': widget.projectId,
        'payment_term': _termCtrl.text.trim(),
        'term_percentage': double.tryParse(_percentCtrl.text) ?? 0.0,
        'amount': amt,
        'received_amount': rec,
        'pending_amount': amt - rec,
        'remark': _remarkCtrl.text.trim(),
      };

      final ref = ProviderScope.containerOf(context);
      if (widget.term != null) {
        await ref.read(pmLedgerRepositoryProvider).updatePaymentTerm(widget.term!.id, data);
      } else {
        await ref.read(pmLedgerRepositoryProvider).addPaymentTerm(data);
      }

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        constraints: const BoxConstraints(maxWidth: 480),
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
                      Text(widget.term != null ? 'Edit Payment Term' : 'Add Payment Term',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: pm.foreground)),
                      IconButton(icon: const Icon(LucideIcons.x, size: 16), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Dropdown or Custom Term
                  DropdownButtonFormField<String>(
                    value: _commonTerms.contains(_termCtrl.text) ? _termCtrl.text : null,
                    hint: const Text('Select Milestone or type custom'),
                    items: _commonTerms.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _termCtrl.text = val);
                    },
                    decoration: InputDecoration(
                      labelText: 'Common Milestones',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _termCtrl,
                    decoration: InputDecoration(
                      labelText: 'Custom Payment Term Name',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _percentCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: _onPercentChanged,
                          decoration: InputDecoration(
                            labelText: 'Percentage (%)',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount (₹)',
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
                          controller: _receivedCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final amt = double.tryParse(_amountCtrl.text) ?? 0;
                            final rec = double.tryParse(val) ?? 0;
                            _pendingCtrl.text = (amt - rec).toStringAsFixed(0);
                          },
                          decoration: InputDecoration(
                            labelText: 'Received Amount (₹)',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _pendingCtrl,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Pending Amount (₹)',
                            isDense: true,
                            filled: true,
                            fillColor: pm.secondary.withOpacity(0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _remarkCtrl,
                    decoration: InputDecoration(
                      labelText: 'Remark / Notes',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PmButton(
                    isLoading: _isLoading,
                    onPressed: _save,
                    child: Text(widget.term != null ? 'Update Term' : 'Save Term'),
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
