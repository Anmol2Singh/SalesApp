import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_providers.dart';
import '../widgets/pm_button.dart';
import '../widgets/pm_card.dart';

class PmQuickCallRemarkScreen extends ConsumerStatefulWidget {
  final String id;
  final bool isPurchase;

  const PmQuickCallRemarkScreen({
    super.key,
    required this.id,
    this.isPurchase = false,
  });

  @override
  ConsumerState<PmQuickCallRemarkScreen> createState() => _PmQuickCallRemarkScreenState();
}

class _PmQuickCallRemarkScreenState extends ConsumerState<PmQuickCallRemarkScreen> {
  DateTime _date = DateTime.now();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter discussion notes')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        if (widget.isPurchase) 'purchase_id': widget.id else 'project_id': widget.id,
        'date': _date.toIso8601String().split('T').first,
        'description': _descCtrl.text.trim(),
      };

      await ref.read(pmLedgerRepositoryProvider).addCallingRecord(data);
      ref.invalidate(pmCallingRecordsProvider((id: widget.id, isPurchase: widget.isPurchase)));
      if (widget.isPurchase) {
        ref.invalidate(pmPurchaseDetailProvider(widget.id));
        ref.invalidate(pmPurchasesListProvider);
      } else {
        ref.invalidate(pmProjectDetailProvider(widget.id));
        ref.invalidate(pmProjectsListProvider);
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;
    final recordsAsync = ref.watch(pmCallingRecordsProvider((id: widget.id, isPurchase: widget.isPurchase)));
    final dateFormat = DateFormat('dd-MM-yyyy');

    return Scaffold(
      backgroundColor: pm.background,
      appBar: AppBar(
        backgroundColor: pm.card,
        foregroundColor: pm.foreground,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        title: const Text('Log Call / Follow-up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        leading: IconButton(icon: const Icon(LucideIcons.arrowLeft, size: 18), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PmCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Add New Call Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pm.foreground)),
                        const SizedBox(height: 14),
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
                                Text('Follow-up Date: ${DateFormat('dd-MM-yyyy').format(_date)}', style: TextStyle(fontSize: 13, color: pm.foreground)),
                                Icon(LucideIcons.calendar, size: 16, color: pm.primary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Discussion Notes & Next Steps*',
                            alignLabelWithHint: true,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(pm.radiusMd)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        PmButton(
                          isLoading: _isLoading,
                          onPressed: _submit,
                          child: const Text('Save Call Log'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Recent Call History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pm.foreground)),
                  const SizedBox(height: 12),
                  recordsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text('Error: $err'),
                    data: (records) {
                      if (records.isEmpty) {
                        return Center(child: Text('No previous calls recorded.', style: TextStyle(color: pm.mutedForeground)));
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final rec = records[i];
                          return PmCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(dateFormat.format(rec.date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    Icon(LucideIcons.phone, size: 14, color: pm.primary),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(rec.description ?? '', style: TextStyle(fontSize: 13, color: pm.foreground)),
                              ],
                            ),
                          );
                        },
                      );
                    },
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
