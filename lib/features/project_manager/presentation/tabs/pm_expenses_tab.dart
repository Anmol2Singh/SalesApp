import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_providers.dart';
import '../../data/models/pm_expense.dart';
import '../widgets/pm_button.dart';
import '../widgets/pm_card.dart';
import '../widgets/pm_badge.dart';

class PmExpensesTab extends ConsumerWidget {
  final String projectId;
  final VoidCallback onRefresh;

  const PmExpensesTab({
    super.key,
    required this.projectId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pm = context.pm;
    final expensesAsync = ref.watch(pmExpensesProvider(projectId));
    final currency = NumberFormat('#,##,##0', 'en_IN');
    final dateFormat = DateFormat('dd-MM-yyyy');

    return expensesAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: pm.destructive))),
      data: (expenses) {
        double totalExpense = 0;
        for (final e in expenses) {
          totalExpense += e.expense;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Direct Project Expenses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pm.foreground)),
                    const SizedBox(width: 8),
                    PmBadge(label: 'Total: ₹${currency.format(totalExpense)}', variant: PmBadgeVariant.warning),
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
                      Text('Add Expense'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (expenses.isEmpty)
              PmCard(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(LucideIcons.receiptText, size: 40, color: pm.mutedForeground.withOpacity(0.5)),
                      const SizedBox(height: 10),
                      Text('No direct expenses recorded for this project yet.', style: TextStyle(color: pm.mutedForeground)),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _showAddEditModal(context, ref),
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF005CE6),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: const Text(
                            '+ Record Expense',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
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
                      DataColumn(label: Text('SR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('PARTICULAR / PURPOSE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(numeric: true, label: Text('EXPENSE AMOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                    rows: expenses.map((e) {
                      return DataRow(
                        cells: [
                          DataCell(Text('#${e.srNo}', style: TextStyle(fontSize: 11, color: pm.mutedForeground, fontWeight: FontWeight.bold))),
                          DataCell(Text(dateFormat.format(e.date), style: const TextStyle(fontSize: 12))),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 250),
                              child: Text(e.particular ?? '-', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          DataCell(Text('₹${currency.format(e.expense)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: pm.destructive))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(LucideIcons.pencil, size: 14),
                                  onPressed: () => _showAddEditModal(context, ref, e),
                                ),
                                IconButton(
                                  icon: Icon(LucideIcons.trash2, size: 14, color: pm.destructive),
                                  onPressed: () async {
                                    await ref.read(pmLedgerRepositoryProvider).deleteExpense(e.id);
                                    ref.invalidate(pmExpensesProvider(projectId));
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

  void _showAddEditModal(BuildContext context, WidgetRef ref, [PmExpense? expense]) {
    showDialog(
      context: context,
      builder: (ctx) => _ExpenseDialog(
        projectId: projectId,
        expense: expense,
        onSaved: () {
          ref.invalidate(pmExpensesProvider(projectId));
          onRefresh();
        },
      ),
    );
  }
}

class _ExpenseDialog extends StatefulWidget {
  final String projectId;
  final PmExpense? expense;
  final VoidCallback onSaved;

  const _ExpenseDialog({
    required this.projectId,
    this.expense,
    required this.onSaved,
  });

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  final _particularCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '0');
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _date = widget.expense!.date;
      _particularCtrl.text = widget.expense!.particular ?? '';
      _amountCtrl.text = widget.expense!.expense.toStringAsFixed(0);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'project_id': widget.projectId,
        'sr_no': widget.expense?.srNo ?? 1,
        'date': _date.toIso8601String().split('T').first,
        'particular': _particularCtrl.text.trim(),
        'expense': double.tryParse(_amountCtrl.text) ?? 0.0,
      };

      final ref = ProviderScope.containerOf(context);
      if (widget.expense != null) {
        await ref.read(pmLedgerRepositoryProvider).updateExpense(widget.expense!.id, data);
      } else {
        await ref.read(pmLedgerRepositoryProvider).addExpense(data);
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
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.expense != null ? 'Edit Expense' : 'Record Project Expense',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: pm.foreground)),
                    IconButton(icon: const Icon(LucideIcons.x, size: 16), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
                const SizedBox(height: 12),
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
                TextFormField(
                  controller: _particularCtrl,
                  decoration: InputDecoration(
                    labelText: 'Particulars / Description',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Expense Amount (₹)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                  ),
                ),
                const SizedBox(height: 16),
                PmButton(
                  isLoading: _isLoading,
                  onPressed: _save,
                  child: Text(widget.expense != null ? 'Update Expense' : 'Save Expense'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
