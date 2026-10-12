import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/pm_tokens.dart';
import '../widgets/pm_card.dart';
import '../widgets/pm_badge.dart';
import '../widgets/pm_button.dart';
import '../widgets/pm_stat_card.dart';
import '../../data/models/pm_daily_transaction.dart';
import '../../providers/pm_company_provider.dart';
import '../../providers/pm_providers.dart';

class PmDailyTransactionsScreen extends ConsumerStatefulWidget {
  const PmDailyTransactionsScreen({super.key});

  @override
  ConsumerState<PmDailyTransactionsScreen> createState() => _PmDailyTransactionsScreenState();
}

class _PmDailyTransactionsScreenState extends ConsumerState<PmDailyTransactionsScreen> {
  final _searchController = TextEditingController();
  final _currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTransactionDialog([PmDailyTransaction? editing]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DailyTransactionDialog(editing: editing),
    );
  }

  Future<void> _confirmDelete(PmDailyTransaction tx) async {
    final pm = context.pm;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text('Are you sure you want to delete entry #${tx.srNo} (${tx.partyName})? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: pm.destructive),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(pmDailyTransactionsRepositoryProvider);
        await repo.deleteTransaction(tx.id);
        ref.invalidate(pmDailyTransactionsListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete transaction: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;
    final filter = ref.watch(dailyTransactionsFilterProvider);
    final txAsync = ref.watch(pmDailyTransactionsListProvider);

    return Scaffold(
      backgroundColor: pm.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Nav Header
            Container(
              decoration: BoxDecoration(
                color: pm.card,
                border: Border(bottom: BorderSide(color: pm.border)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (context.canPop()) ...[
                    IconButton(
                      icon: const Icon(LucideIcons.arrowLeft, size: 20),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Transactions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: pm.foreground,
                        ),
                      ),
                      Text(
                        'Day-Book & Cashflow Register',
                        style: TextStyle(fontSize: 12, color: pm.mutedForeground),
                      ),
                    ],
                  ),
                  const Spacer(),
                  PmButton(
                    onPressed: () => _openTransactionDialog(),
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
            ),

            Expanded(
              child: txAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.triangleAlert, size: 40, color: pm.destructive),
                      const SizedBox(height: 12),
                      Text('Error loading day-book: $err', style: TextStyle(color: pm.mutedForeground)),
                      const SizedBox(height: 12),
                      PmButton(
                        variant: PmButtonVariant.outline,
                        onPressed: () => ref.invalidate(pmDailyTransactionsListProvider),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.refreshCw, size: 14),
                            SizedBox(width: 6),
                            Text('Retry'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                data: (transactions) {
                  // Calculate Summary Totals
                  double totalCredit = 0;
                  double totalDebit = 0;
                  for (final t in transactions) {
                    totalCredit += t.creditAmount;
                    totalDebit += t.debitAmount;
                  }
                  final netBalance = totalCredit - totalDebit;

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(pmDailyTransactionsListProvider),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // KPI Stat Cards Row
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 700;
                            return GridView.count(
                              crossAxisCount: isMobile ? 2 : 4,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: isMobile ? 1.6 : 2.2,
                              children: [
                                PmStatCard(
                                  title: 'Total Inflow (Credits)',
                                  value: _currencyFmt.format(totalCredit),
                                  icon: Icon(LucideIcons.arrowDownLeft, color: pm.success, size: 20),
                                  accentColor: pm.success,
                                ),
                                PmStatCard(
                                  title: 'Total Outflow (Debits)',
                                  value: _currencyFmt.format(totalDebit),
                                  icon: Icon(LucideIcons.arrowUpRight, color: pm.destructive, size: 20),
                                  accentColor: pm.destructive,
                                ),
                                PmStatCard(
                                  title: 'Net Cash Balance',
                                  value: _currencyFmt.format(netBalance),
                                  icon: Icon(LucideIcons.wallet, color: netBalance >= 0 ? pm.success : pm.destructive, size: 20),
                                  accentColor: netBalance >= 0 ? pm.success : pm.destructive,
                                ),
                                PmStatCard(
                                  title: 'Entries Count',
                                  value: transactions.length.toString(),
                                  icon: Icon(LucideIcons.receipt, color: pm.primary, size: 20),
                                  accentColor: pm.primary,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Timeframe & Filter Bar
                        PmCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Timeframe Segmented Chips
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: ['Today', 'Week', 'Month', 'Lifetime', 'Custom'].map((tf) {
                                    final isSelected = filter.timeframe == tf;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(tf),
                                        selected: isSelected,
                                        selectedColor: pm.primary,
                                        labelStyle: TextStyle(
                                          color: isSelected ? pm.primaryForeground : pm.mutedForeground,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                        onSelected: (selected) {
                                          if (selected) {
                                            if (tf == 'Custom') {
                                              _pickCustomDateRange();
                                            } else {
                                              ref.read(dailyTransactionsFilterProvider.notifier).update(
                                                    (s) => s.copyWith(timeframe: tf, startDate: null, endDate: null),
                                                  );
                                            }
                                          }
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Search & Secondary Filter Chips
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        hintText: 'Search party, firm, transaction...',
                                        hintStyle: TextStyle(color: pm.mutedForeground, fontSize: 13),
                                        prefixIcon: Icon(LucideIcons.search, size: 16, color: pm.mutedForeground),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: pm.border),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: pm.border),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        ref.read(dailyTransactionsFilterProvider.notifier).update(
                                              (s) => s.copyWith(searchQuery: val.trim()),
                                            );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Nature Dropdown (All, Sale, Purchase, Expense)
                                  DropdownButtonHideUnderline(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: pm.border),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButton<String>(
                                        value: filter.entryNature,
                                        isDense: true,
                                        items: const [
                                          DropdownMenuItem(value: 'ALL', child: Text('All Types', style: TextStyle(fontSize: 13))),
                                          DropdownMenuItem(value: 'Sale', child: Text('Sale', style: TextStyle(fontSize: 13))),
                                          DropdownMenuItem(value: 'Purchase', child: Text('Purchase', style: TextStyle(fontSize: 13))),
                                          DropdownMenuItem(value: 'Expense', child: Text('Expense', style: TextStyle(fontSize: 13))),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            ref.read(dailyTransactionsFilterProvider.notifier).update(
                                                  (s) => s.copyWith(entryNature: val),
                                                );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Flow Dropdown (All, credit, debit)
                                  DropdownButtonHideUnderline(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: pm.border),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButton<String>(
                                        value: filter.flowType,
                                        isDense: true,
                                        items: const [
                                          DropdownMenuItem(value: 'ALL', child: Text('Flow: All', style: TextStyle(fontSize: 13))),
                                          DropdownMenuItem(value: 'credit', child: Text('Credit (+)', style: TextStyle(fontSize: 13))),
                                          DropdownMenuItem(value: 'debit', child: Text('Debit (-)', style: TextStyle(fontSize: 13))),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            ref.read(dailyTransactionsFilterProvider.notifier).update(
                                                  (s) => s.copyWith(flowType: val),
                                                );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Entries List / Table
                        if (transactions.isEmpty)
                          PmCard(
                            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.inbox, size: 48, color: pm.mutedForeground),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No transactions found for selected period',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: pm.foreground,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Change filters or tap "+ Add Entry" to record cash movements.',
                                    style: TextStyle(fontSize: 13, color: pm.mutedForeground),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...transactions.map((tx) => _buildTransactionCard(context, tx)),
                      ],
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

  Widget _buildTransactionCard(BuildContext context, PmDailyTransaction tx) {
    final pm = context.pm;
    final isCredit = tx.type == PmTransactionFlow.credit;
    final amount = isCredit ? tx.creditAmount : tx.debitAmount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PmCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sr No & Flow Icon Badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCredit
                    ? pm.successSurface
                    : pm.destructive.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  isCredit ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                  color: isCredit ? pm.success : pm.destructive,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Main Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tx.partyName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: pm.foreground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PmBadge(
                        label: tx.entryNature.displayName,
                        variant: tx.entryNature == PmEntryNature.sale
                            ? PmBadgeVariant.success
                            : tx.entryNature == PmEntryNature.purchase
                                ? PmBadgeVariant.info
                                : PmBadgeVariant.warning,
                      ),
                      const Spacer(),
                      Text(
                        '${isCredit ? "+" : "-"} ${_currencyFmt.format(amount)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isCredit ? pm.success : pm.destructive,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Text(
                        '${_dateFmt.format(tx.date)}  •  ${tx.paymentMode}',
                        style: TextStyle(fontSize: 12, color: pm.mutedForeground),
                      ),
                      if (tx.firmName.isNotEmpty) ...[
                        Text('  •  ', style: TextStyle(color: pm.mutedForeground)),
                        Text(
                          tx.firmName,
                          style: TextStyle(fontSize: 12, color: pm.mutedForeground),
                        ),
                      ],
                      if (tx.transactionName.isNotEmpty) ...[
                        Text('  •  ', style: TextStyle(color: pm.mutedForeground)),
                        Text(
                          tx.transactionName,
                          style: TextStyle(fontSize: 12, color: pm.primary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),

                  if (tx.remark != null && tx.remark!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      tx.remark!,
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: pm.mutedForeground),
                    ),
                  ],
                ],
              ),
            ),

            // Row actions
            PopupMenuButton<String>(
              icon: Icon(LucideIcons.ellipsisVertical, size: 16, color: pm.mutedForeground),
              onSelected: (action) {
                if (action == 'edit') {
                  _openTransactionDialog(tx);
                } else if (action == 'delete') {
                  _confirmDelete(tx);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(LucideIcons.pencil, size: 15),
                      SizedBox(width: 8),
                      Text('Edit Entry'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(LucideIcons.trash2, size: 15, color: pm.destructive),
                      const SizedBox(width: 8),
                      Text('Delete Entry', style: TextStyle(color: pm.destructive)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(dailyTransactionsFilterProvider.notifier).update(
            (s) => s.copyWith(
              timeframe: 'Custom',
              startDate: picked.start,
              endDate: picked.end,
            ),
          );
    }
  }
}

// -----------------------------------------------------------------------------
// ADD / EDIT TRANSACTION DIALOG
// -----------------------------------------------------------------------------
class _DailyTransactionDialog extends ConsumerStatefulWidget {
  final PmDailyTransaction? editing;

  const _DailyTransactionDialog({this.editing});

  @override
  ConsumerState<_DailyTransactionDialog> createState() => _DailyTransactionDialogState();
}

class _DailyTransactionDialogState extends ConsumerState<_DailyTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late TextEditingController _srNoController;
  late TextEditingController _partyController;
  late TextEditingController _firmController;
  late TextEditingController _txNameController;
  late TextEditingController _amountController;
  late TextEditingController _remarkController;

  String _paymentMode = 'Cash';
  PmEntryNature _nature = PmEntryNature.sale;
  PmTransactionFlow _flow = PmTransactionFlow.credit;
  bool _saving = false;

  final List<String> _modes = ['Cash', 'Cheque', 'RTGS / NEFT', 'UPI', 'Bank Transfer', 'Other'];

  @override
  void initState() {
    super.initState();
    final edit = widget.editing;
    _date = edit?.date ?? DateTime.now();
    _srNoController = TextEditingController(text: edit != null ? edit.srNo.toString() : '1');
    _partyController = TextEditingController(text: edit?.partyName ?? '');
    _firmController = TextEditingController(text: edit?.firmName ?? '');
    _txNameController = TextEditingController(text: edit?.transactionName ?? '');
    final amt = edit != null
        ? (edit.type == PmTransactionFlow.credit ? edit.creditAmount : edit.debitAmount)
        : 0.0;
    _amountController = TextEditingController(text: amt > 0 ? amt.toStringAsFixed(0) : '');
    _remarkController = TextEditingController(text: edit?.remark ?? '');
    if (edit != null) {
      _paymentMode = edit.paymentMode;
      _nature = edit.entryNature;
      _flow = edit.type;
    } else {
      _fetchNextSrNo();
    }
  }

  Future<void> _fetchNextSrNo() async {
    try {
      final repo = ref.read(pmDailyTransactionsRepositoryProvider);
      final company = ref.read(pmActiveCompanyProvider);
      final nextSr = await repo.getNextSrNo(company.id, _date);
      if (mounted) {
        _srNoController.text = nextSr.toString();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _srNoController.dispose();
    _partyController.dispose();
    _firmController.dispose();
    _txNameController.dispose();
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(pmDailyTransactionsRepositoryProvider);
      final company = ref.read(pmActiveCompanyProvider);
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

      final data = <String, dynamic>{
        'company_id': company.id,
        'date': _date.toIso8601String().split('T').first,
        'sr_no': int.tryParse(_srNoController.text.trim()) ?? 1,
        'firm_name': _firmController.text.trim(),
        'party_name': _partyController.text.trim(),
        'payment_mode': _paymentMode,
        'transaction_name': _txNameController.text.trim(),
        'entry_nature': _nature.dbValue,
        'type': _flow.dbValue,
        'debit_amount': _flow == PmTransactionFlow.debit ? amount : 0.0,
        'credit_amount': _flow == PmTransactionFlow.credit ? amount : 0.0,
        'remark': _remarkController.text.trim().isEmpty ? null : _remarkController.text.trim(),
      };

      if (widget.editing != null) {
        await repo.updateTransaction(widget.editing!.id, data);
      } else {
        await repo.createTransaction(data);
      }

      ref.invalidate(pmDailyTransactionsListProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.editing != null
                  ? 'Transaction updated successfully.'
                  : 'Transaction added successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save transaction: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;
    final isEdit = widget.editing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Transaction' : 'New Transaction Entry'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date & Sr No
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _date = picked);
                            if (!isEdit) _fetchNextSrNo();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date *',
                            prefixIcon: Icon(LucideIcons.calendar, size: 16),
                          ),
                          child: Text(DateFormat('dd MMM yyyy').format(_date)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _srNoController,
                        decoration: const InputDecoration(labelText: 'Sr No *'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Flow Selector: Credit (+) or Debit (-)
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<PmTransactionFlow>(
                        value: PmTransactionFlow.credit,
                        groupValue: _flow,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Credit (Inflow +)', style: TextStyle(fontSize: 13, color: pm.success)),
                        onChanged: (v) {
                          if (v != null) setState(() => _flow = v);
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<PmTransactionFlow>(
                        value: PmTransactionFlow.debit,
                        groupValue: _flow,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Debit (Outflow -)', style: TextStyle(fontSize: 13, color: pm.destructive)),
                        onChanged: (v) {
                          if (v != null) setState(() => _flow = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Amount
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹) *',
                    prefixText: '₹ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter amount';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Party Name
                TextFormField(
                  controller: _partyController,
                  decoration: const InputDecoration(
                    labelText: 'Party / Customer / Vendor Name *',
                    prefixIcon: Icon(LucideIcons.user, size: 16),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter party name' : null,
                ),
                const SizedBox(height: 12),

                // Firm Name
                TextFormField(
                  controller: _firmController,
                  decoration: const InputDecoration(
                    labelText: 'Firm Name',
                    prefixIcon: Icon(LucideIcons.building, size: 16),
                  ),
                ),
                const SizedBox(height: 12),

                // Entry Nature & Payment Mode
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<PmEntryNature>(
                        value: _nature,
                        decoration: const InputDecoration(labelText: 'Nature *'),
                        items: PmEntryNature.values.map((n) {
                          return DropdownMenuItem(value: n, child: Text(n.displayName));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _nature = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _paymentMode,
                        decoration: const InputDecoration(labelText: 'Payment Mode *'),
                        items: _modes.map((m) {
                          return DropdownMenuItem(value: m, child: Text(m));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _paymentMode = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Transaction Name / Description
                TextFormField(
                  controller: _txNameController,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Purpose / Tag *',
                    hintText: 'e.g. Advance Payment, Material, Transport',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Remark
                TextFormField(
                  controller: _remarkController,
                  decoration: const InputDecoration(
                    labelText: 'Remarks / Notes',
                    hintText: 'Optional remarks...',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: pm.primary),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? 'Save Changes' : 'Add Entry'),
        ),
      ],
    );
  }
}
