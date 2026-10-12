import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_providers.dart';
import '../../data/models/pm_checklist_item.dart';
import '../widgets/pm_button.dart';
import '../widgets/pm_card.dart';
import '../widgets/pm_badge.dart';

class PmSwhChecklistTab extends ConsumerWidget {
  final String projectId;
  final VoidCallback onRefresh;

  const PmSwhChecklistTab({
    super.key,
    required this.projectId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pm = context.pm;
    final itemsAsync = ref.watch(pmChecklistItemsProvider(projectId));

    return itemsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: pm.destructive))),
      data: (items) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('SWH & Heat Pump Technical Checklist', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pm.foreground)),
                    const SizedBox(width: 8),
                    PmBadge(label: '${items.length} Items', variant: PmBadgeVariant.secondary),
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
                      Text('Add Item'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              PmCard(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(LucideIcons.listCheck, size: 40, color: pm.mutedForeground.withOpacity(0.5)),
                      const SizedBox(height: 10),
                      Text('No checklist items added for this installation yet.', style: TextStyle(color: pm.mutedForeground)),
                      const SizedBox(height: 12),
                      PmButton(
                        size: PmButtonSize.sm,
                        onPressed: () => _showAddEditModal(context, ref),
                        child: const Text('+ Add Checklist Item'),
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
                      DataColumn(label: Text('ITEM NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(numeric: true, label: Text('REQ QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('CUSTOMER SCOPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('OUR SCOPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(numeric: true, label: Text('DISPATCH QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('DISPATCHED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(numeric: true, label: Text('INSTALLED QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('INSTALLED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(numeric: true, label: Text('BALANCE QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('REMARK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                    rows: items.map((item) {
                      final balQty = item.reqQty - item.dispatchQty;
                      return DataRow(
                        cells: [
                          DataCell(Text('#${item.srNo}', style: TextStyle(fontSize: 11, color: pm.mutedForeground, fontWeight: FontWeight.bold))),
                          DataCell(Text(item.itemName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          DataCell(Text('${item.reqQty}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          DataCell(Checkbox(
                            value: item.customerScope,
                            onChanged: (val) async {
                              await ref.read(pmLedgerRepositoryProvider).updateChecklistItem(item.id, {'customer_scope': val ?? false});
                              ref.invalidate(pmChecklistItemsProvider(projectId));
                            },
                          )),
                          DataCell(Checkbox(
                            value: item.ourScope,
                            onChanged: (val) async {
                              await ref.read(pmLedgerRepositoryProvider).updateChecklistItem(item.id, {'our_scope': val ?? false});
                              ref.invalidate(pmChecklistItemsProvider(projectId));
                            },
                          )),
                          DataCell(Text('${item.dispatchQty}', style: const TextStyle(fontSize: 12))),
                          DataCell(Checkbox(
                            value: item.dispatchYesNo,
                            onChanged: (val) async {
                              await ref.read(pmLedgerRepositoryProvider).updateChecklistItem(item.id, {'dispatch_yes_no': val ?? false});
                              ref.invalidate(pmChecklistItemsProvider(projectId));
                            },
                          )),
                          DataCell(Text('${item.installedQty}', style: const TextStyle(fontSize: 12))),
                          DataCell(Checkbox(
                            value: item.installationYesNo,
                            onChanged: (val) async {
                              await ref.read(pmLedgerRepositoryProvider).updateChecklistItem(item.id, {'installation_yes_no': val ?? false});
                              ref.invalidate(pmChecklistItemsProvider(projectId));
                            },
                          )),
                          DataCell(Text(
                            '$balQty',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: balQty > 0 ? pm.warning : pm.success),
                          )),
                          DataCell(Text(item.remark ?? '-', style: TextStyle(fontSize: 12, color: pm.mutedForeground))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(LucideIcons.pencil, size: 14),
                                  onPressed: () => _showAddEditModal(context, ref, item),
                                ),
                                IconButton(
                                  icon: Icon(LucideIcons.trash2, size: 14, color: pm.destructive),
                                  onPressed: () async {
                                    await ref.read(pmLedgerRepositoryProvider).deleteChecklistItem(item.id);
                                    ref.invalidate(pmChecklistItemsProvider(projectId));
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

  void _showAddEditModal(BuildContext context, WidgetRef ref, [PmChecklistItem? item]) {
    showDialog(
      context: context,
      builder: (ctx) => _ChecklistDialog(
        projectId: projectId,
        item: item,
        onSaved: () {
          ref.invalidate(pmChecklistItemsProvider(projectId));
          onRefresh();
        },
      ),
    );
  }
}

class _ChecklistDialog extends StatefulWidget {
  final String projectId;
  final PmChecklistItem? item;
  final VoidCallback onSaved;

  const _ChecklistDialog({
    required this.projectId,
    this.item,
    required this.onSaved,
  });

  @override
  State<_ChecklistDialog> createState() => _ChecklistDialogState();
}

class _ChecklistDialogState extends State<_ChecklistDialog> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameCtrl = TextEditingController();
  final _reqQtyCtrl = TextEditingController(text: '1');
  final _dispatchQtyCtrl = TextEditingController(text: '0');
  final _installedQtyCtrl = TextEditingController(text: '0');
  final _remarkCtrl = TextEditingController();
  bool _customerScope = false;
  bool _ourScope = true;
  bool _dispatchYesNo = false;
  bool _installationYesNo = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _itemNameCtrl.text = widget.item!.itemName;
      _reqQtyCtrl.text = widget.item!.reqQty.toString();
      _customerScope = widget.item!.customerScope;
      _ourScope = widget.item!.ourScope;
      _dispatchQtyCtrl.text = widget.item!.dispatchQty.toString();
      _dispatchYesNo = widget.item!.dispatchYesNo;
      _installedQtyCtrl.text = widget.item!.installedQty.toString();
      _installationYesNo = widget.item!.installationYesNo;
      _remarkCtrl.text = widget.item!.remark ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final reqQ = double.tryParse(_reqQtyCtrl.text) ?? 0.0;
      final dispQ = double.tryParse(_dispatchQtyCtrl.text) ?? 0.0;

      final data = {
        'project_id': widget.projectId,
        'item_name': _itemNameCtrl.text.trim(),
        'req_qty': reqQ,
        'customer_scope': _customerScope,
        'our_scope': _ourScope,
        'dispatch_qty': dispQ,
        'dispatch_yes_no': _dispatchYesNo,
        'installed_qty': double.tryParse(_installedQtyCtrl.text) ?? 0.0,
        'installation_yes_no': _installationYesNo,
        'dispatch_balance_qty': reqQ - dispQ,
        'remark': _remarkCtrl.text.trim(),
      };

      final ref = ProviderScope.containerOf(context);
      if (widget.item != null) {
        await ref.read(pmLedgerRepositoryProvider).updateChecklistItem(widget.item!.id, data);
      } else {
        await ref.read(pmLedgerRepositoryProvider).addChecklistItem(data);
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
                      Text(widget.item != null ? 'Edit Checklist Item' : 'Add Checklist Item',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: pm.foreground)),
                      IconButton(icon: const Icon(LucideIcons.x, size: 16), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _itemNameCtrl,
                    validator: (v) => v?.trim().isEmpty == true ? 'Item name is required' : null,
                    decoration: InputDecoration(
                      labelText: 'Item Name / Description*',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _reqQtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Required Qty',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _dispatchQtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Dispatched Qty',
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
                        child: CheckboxListTile(
                          title: const Text('Our Scope', style: TextStyle(fontSize: 12)),
                          value: _ourScope,
                          onChanged: (val) => setState(() => _ourScope = val ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Customer Scope', style: TextStyle(fontSize: 12)),
                          value: _customerScope,
                          onChanged: (val) => setState(() => _customerScope = val ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
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
                    child: Text(widget.item != null ? 'Update Item' : 'Save Item'),
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
