import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_providers.dart';
import '../../data/models/pm_calling_record.dart';
import '../widgets/pm_button.dart';
import '../widgets/pm_card.dart';
import '../widgets/pm_badge.dart';

class PmCallingRecordsTab extends ConsumerWidget {
  final String recordId;
  final bool isPurchase;
  final VoidCallback onRefresh;

  const PmCallingRecordsTab({
    super.key,
    required this.recordId,
    this.isPurchase = false,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pm = context.pm;
    final recordsAsync = ref.watch(pmCallingRecordsProvider((id: recordId, isPurchase: isPurchase)));
    final dateFormat = DateFormat('dd-MM-yyyy');

    return recordsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: pm.destructive))),
      data: (records) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Call & Follow-up Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pm.foreground)),
                    const SizedBox(width: 8),
                    PmBadge(label: '${records.length} Logs', variant: PmBadgeVariant.secondary),
                  ],
                ),
                PmButton(
                  size: PmButtonSize.sm,
                  onPressed: () => _showAddEditModal(context, ref),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.phoneCall, size: 14),
                      SizedBox(width: 6),
                      Text('Log Call'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (records.isEmpty)
              PmCard(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(LucideIcons.phoneOff, size: 40, color: pm.mutedForeground.withOpacity(0.5)),
                      const SizedBox(height: 10),
                      Text('No calling records logged yet.', style: TextStyle(color: pm.mutedForeground)),
                      const SizedBox(height: 12),
                      PmButton(
                        size: PmButtonSize.sm,
                        onPressed: () => _showAddEditModal(context, ref),
                        child: const Text('+ Log First Call'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final rec = records[i];
                  return PmCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: pm.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(LucideIcons.phone, size: 16, color: pm.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateFormat.format(rec.date),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: pm.foreground),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(LucideIcons.pencil, size: 14),
                                        onPressed: () => _showAddEditModal(context, ref, rec),
                                      ),
                                      IconButton(
                                        icon: Icon(LucideIcons.trash2, size: 14, color: pm.destructive),
                                        onPressed: () async {
                                          await ref.read(pmLedgerRepositoryProvider).deleteCallingRecord(rec.id);
                                          ref.invalidate(pmCallingRecordsProvider((id: recordId, isPurchase: isPurchase)));
                                          onRefresh();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rec.description ?? 'No call description provided.',
                                style: TextStyle(fontSize: 13, color: pm.mutedForeground, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  void _showAddEditModal(BuildContext context, WidgetRef ref, [PmCallingRecord? record]) {
    showDialog(
      context: context,
      builder: (ctx) => _CallingRecordDialog(
        recordId: recordId,
        isPurchase: isPurchase,
        record: record,
        onSaved: () {
          ref.invalidate(pmCallingRecordsProvider((id: recordId, isPurchase: isPurchase)));
          onRefresh();
        },
      ),
    );
  }
}

class _CallingRecordDialog extends StatefulWidget {
  final String recordId;
  final bool isPurchase;
  final PmCallingRecord? record;
  final VoidCallback onSaved;

  const _CallingRecordDialog({
    required this.recordId,
    this.isPurchase = false,
    this.record,
    required this.onSaved,
  });

  @override
  State<_CallingRecordDialog> createState() => _CallingRecordDialogState();
}

class _CallingRecordDialogState extends State<_CallingRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.record != null) {
      _date = widget.record!.date;
      _descCtrl.text = widget.record!.description ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        if (widget.isPurchase) 'purchase_id': widget.recordId else 'project_id': widget.recordId,
        'date': _date.toIso8601String().split('T').first,
        'description': _descCtrl.text.trim(),
      };

      final ref = ProviderScope.containerOf(context);
      if (widget.record != null) {
        await ref.read(pmLedgerRepositoryProvider).updateCallingRecord(widget.record!.id, data);
      } else {
        await ref.read(pmLedgerRepositoryProvider).addCallingRecord(data);
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
                    Text(widget.record != null ? 'Edit Call Record' : 'Log Phone Conversation',
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
                        Text('Call / Follow-up Date: ${DateFormat('dd-MM-yyyy').format(_date)}', style: TextStyle(fontSize: 13, color: pm.foreground)),
                        Icon(LucideIcons.calendar, size: 16, color: pm.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  validator: (v) => v?.trim().isEmpty == true ? 'Description is required' : null,
                  decoration: InputDecoration(
                    labelText: 'Discussion Notes & Next Steps',
                    alignLabelWithHint: true,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                  ),
                ),
                const SizedBox(height: 16),
                PmButton(
                  isLoading: _isLoading,
                  onPressed: _save,
                  child: Text(widget.record != null ? 'Update Log' : 'Save Call Log'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
