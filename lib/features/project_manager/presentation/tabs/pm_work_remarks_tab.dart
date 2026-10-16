import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_providers.dart';
import '../../data/models/pm_work_remark.dart';
import '../widgets/pm_button.dart';
import '../widgets/pm_card.dart';
import '../widgets/pm_badge.dart';

class PmWorkRemarksTab extends ConsumerWidget {
  final String projectId;
  final VoidCallback onRefresh;

  const PmWorkRemarksTab({
    super.key,
    required this.projectId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pm = context.pm;
    final remarksAsync = ref.watch(pmWorkRemarksProvider(projectId));
    final dateFormat = DateFormat('dd-MM-yyyy');

    return remarksAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: pm.destructive))),
      data: (remarks) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Site Work Remarks & Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pm.foreground)),
                    const SizedBox(width: 8),
                    PmBadge(label: '${remarks.length} Remarks', variant: PmBadgeVariant.secondary),
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
                      Text('Add Remark'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (remarks.isEmpty)
              PmCard(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(LucideIcons.fileText, size: 40, color: pm.mutedForeground.withOpacity(0.5)),
                      const SizedBox(height: 10),
                      Text('No work remarks added yet for this project.', style: TextStyle(color: pm.mutedForeground)),
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
                            '+ Add Work Remark',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: remarks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final rec = remarks[i];
                  return PmCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: pm.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(LucideIcons.messageSquare, size: 16, color: pm.info),
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
                                          await ref.read(pmLedgerRepositoryProvider).deleteWorkRemark(rec.id);
                                          ref.invalidate(pmWorkRemarksProvider(projectId));
                                          onRefresh();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rec.remark ?? 'No remark text.',
                                style: TextStyle(fontSize: 13, color: pm.foreground, height: 1.4),
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

  void _showAddEditModal(BuildContext context, WidgetRef ref, [PmWorkRemark? remark]) {
    showDialog(
      context: context,
      builder: (ctx) => _WorkRemarkDialog(
        projectId: projectId,
        remark: remark,
        onSaved: () {
          ref.invalidate(pmWorkRemarksProvider(projectId));
          onRefresh();
        },
      ),
    );
  }
}

class _WorkRemarkDialog extends StatefulWidget {
  final String projectId;
  final PmWorkRemark? remark;
  final VoidCallback onSaved;

  const _WorkRemarkDialog({
    required this.projectId,
    this.remark,
    required this.onSaved,
  });

  @override
  State<_WorkRemarkDialog> createState() => _WorkRemarkDialogState();
}

class _WorkRemarkDialogState extends State<_WorkRemarkDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime _date = DateTime.now();
  final _remarkCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.remark != null) {
      _date = widget.remark!.date;
      _remarkCtrl.text = widget.remark!.remark ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'project_id': widget.projectId,
        'sr_no': widget.remark?.srNo ?? 1,
        'date': _date.toIso8601String().split('T').first,
        'remark': _remarkCtrl.text.trim(),
      };

      final ref = ProviderScope.containerOf(context);
      if (widget.remark != null) {
        await ref.read(pmLedgerRepositoryProvider).updateWorkRemark(widget.remark!.id, data);
      } else {
        await ref.read(pmLedgerRepositoryProvider).addWorkRemark(data);
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
                    Text(widget.remark != null ? 'Edit Work Remark' : 'Add Work Remark',
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
                  controller: _remarkCtrl,
                  maxLines: 4,
                  validator: (v) => v?.trim().isEmpty == true ? 'Remark cannot be empty' : null,
                  decoration: InputDecoration(
                    labelText: 'Work Remark / Site Note',
                    alignLabelWithHint: true,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                  ),
                ),
                const SizedBox(height: 16),
                PmButton(
                  isLoading: _isLoading,
                  onPressed: _save,
                  child: Text(widget.remark != null ? 'Update Remark' : 'Save Remark'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
