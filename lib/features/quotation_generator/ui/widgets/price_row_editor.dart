// lib/features/quotation_generator/ui/widgets/price_row_editor.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/price_row.dart';
import '../../services/price_calculator.dart';

class PriceRowEditor extends StatelessWidget {
  final List<PriceRow> rows;
  final ValueChanged<List<PriceRow>> onRowsChanged;
  final String priceEntryMode; // 'exclusive' | 'inclusive'
  final ValueChanged<String>? onPriceEntryModeChanged;
  final int? targetTotal;
  final ValueChanged<int?>? onTargetTotalChanged;

  const PriceRowEditor({
    super.key,
    required this.rows,
    required this.onRowsChanged,
    this.priceEntryMode = 'exclusive',
    this.onPriceEntryModeChanged,
    this.targetTotal,
    this.onTargetTotalChanged,
  });

  void _addRow() {
    final nextSerial = (rows.length + 1).toString().padLeft(2, '0');
    final newRows = List<PriceRow>.from(rows)
      ..add(PriceRow(
        id: 'row_${DateTime.now().millisecondsSinceEpoch}',
        serialNo: nextSerial,
        description: 'Additional Item',
        status: PriceRowStatus.included,
        qty: 1,
        rate: 0,
      ));
    _renumberAndEmit(newRows);
  }

  void _removeRow(int index) {
    final newRows = List<PriceRow>.from(rows)..removeAt(index);
    _renumberAndEmit(newRows);
  }

  void _updateRow(int index, PriceRow updated) {
    final newRows = List<PriceRow>.from(rows);
    newRows[index] = updated;
    onRowsChanged(newRows);
  }

  void _renumberAndEmit(List<PriceRow> list) {
    final renumbered = <PriceRow>[];
    for (int i = 0; i < list.length; i++) {
      final s = (i + 1).toString().padLeft(2, '0');
      renumbered.add(list[i].copyWith(serialNo: s));
    }
    onRowsChanged(renumbered);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Mode Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Price Table Rows',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (onPriceEntryModeChanged != null)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'exclusive', label: Text('Exclusive')),
                  ButtonSegment(value: 'inclusive', label: Text('Inclusive')),
                ],
                selected: {priceEntryMode},
                onSelectionChanged: (set) {
                  onPriceEntryModeChanged!(set.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),

        // Target Total Input (When in Inclusive Mode)
        if (priceEntryMode == 'inclusive' && onTargetTotalChanged != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Target Inclusive Total (exact to rupee):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: TextFormField(
                    initialValue: targetTotal != null && targetTotal! > 0 ? '$targetTotal' : '',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) {
                      final n = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                      onTargetTotalChanged!(n);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),

        // Rows List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final row = rows[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row Top: Serial, Description, Remove
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          row.serialNo,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: row.description,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                            border: InputBorder.none,
                            hintText: 'Item Description',
                          ),
                          onChanged: (val) => _updateRow(index, row.copyWith(description: val)),
                        ),
                      ),
                      if (rows.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          onPressed: () => _removeRow(index),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Status Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: PriceRowStatus.values.map((st) {
                      final isSelected = row.status == st;
                      return ChoiceChip(
                        label: Text(st.label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onSelected: (selected) {
                          if (selected) {
                            _updateRow(index, row.copyWith(status: st));
                          }
                        },
                      );
                    }).toList(),
                  ),

                  // If Priced: Qty & Rate Inputs
                  if (row.isPriced) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: '${row.qty}',
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Qty',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (val) {
                              final q = int.tryParse(val) ?? 1;
                              _updateRow(index, row.copyWith(qty: q, amount: q * row.rate));
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: row.rate > 0 ? '${row.rate}' : '',
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Rate (₹)',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onChanged: (val) {
                              final r = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                              _updateRow(index, row.copyWith(rate: r, amount: row.qty * r));
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Amount', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                              Text(
                                PriceCalculator.formatIndianCurrency(row.amount),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // If Custom Text: Custom input
                  if (row.status == PriceRowStatus.customText) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: row.customStatusText ?? '',
                      decoration: InputDecoration(
                        labelText: 'Custom Display Text (e.g. As per BOQ)',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => _updateRow(index, row.copyWith(customStatusText: val)),
                    ),
                  ],
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Add Row to Price Schedule'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
