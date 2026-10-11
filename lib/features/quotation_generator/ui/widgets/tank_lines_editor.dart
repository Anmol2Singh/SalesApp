// lib/features/quotation_generator/ui/widgets/tank_lines_editor.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/tank_line_item.dart';
import '../../services/price_calculator.dart';

class TankLinesEditor extends StatelessWidget {
  final List<TankLineItem> tankLines;
  final ValueChanged<List<TankLineItem>> onLinesChanged;

  const TankLinesEditor({
    super.key,
    required this.tankLines,
    required this.onLinesChanged,
  });

  void _addTankLine() {
    final nextId = 'tank_${DateTime.now().millisecondsSinceEpoch}';
    final newLines = List<TankLineItem>.from(tankLines)
      ..add(TankLineItem(
        id: nextId,
        capacityLitres: 500,
        qty: 1,
        isPressurized: true,
        rate: 0,
        innerTankMaterial: 'GI',
        innerTankThickness: '3mm',
        outerCladdingThickness: '3mm',
        insulationMaterial: 'PUF',
        insulationThickness: '50mm',
      ));
    onLinesChanged(newLines);
  }

  void _removeTankLine(int index) {
    if (tankLines.length <= 1) return;
    final newLines = List<TankLineItem>.from(tankLines)..removeAt(index);
    onLinesChanged(newLines);
  }

  void _updateTankLine(int index, TankLineItem updated) {
    final newLines = List<TankLineItem>.from(tankLines);
    newLines[index] = updated;
    onLinesChanged(newLines);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Storage Tank Specifications',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            TextButton.icon(
              onPressed: _addTankLine,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Tank Line'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tankLines.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final tank = tankLines[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tank #${index + 1} (${tank.capacityLitres}L ${tank.innerTankMaterial})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                      ),
                      if (tankLines.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                          onPressed: () => _removeTankLine(index),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Capacity & Quantity
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: [100, 200, 300, 500, 1000, 1500, 2000, 2500, 3000, 4000, 5000].contains(tank.capacityLitres)
                              ? tank.capacityLitres
                              : null,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'Capacity (Litres)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: [100, 200, 300, 500, 1000, 1500, 2000, 2500, 3000, 4000, 5000].map((c) {
                            return DropdownMenuItem(value: c, child: Text('$c L'));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) _updateTankLine(index, tank.copyWith(capacityLitres: val));
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: '${tank.qty}',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (val) {
                            final q = int.tryParse(val) ?? 1;
                            _updateTankLine(index, tank.copyWith(qty: q));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Material (GI / MS / ENAMEL) & Pressurized
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: ['GI', 'MS', 'ENAMEL'].contains(tank.innerTankMaterial.toUpperCase())
                              ? tank.innerTankMaterial.toUpperCase()
                              : 'GI',
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: 'MOC (Material)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'GI', child: Text('GI (Galvanized)')),
                            DropdownMenuItem(value: 'MS', child: Text('MS (Mild Steel)')),
                            DropdownMenuItem(value: 'ENAMEL', child: Text('ENAMEL Coated')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              // Auto-set preset thickness
                              String innerT = '3mm';
                              String outerT = '3mm';
                              if (val == 'MS') {
                                innerT = '5mm';
                                outerT = '6mm';
                              } else if (val == 'ENAMEL') {
                                innerT = '2mm';
                                outerT = '2mm';
                              }
                              _updateTankLine(index, tank.copyWith(
                                innerTankMaterial: val,
                                innerTankThickness: innerT,
                                outerCladdingThickness: outerT,
                              ));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(tank.isPressurized ? 'Pressurized' : 'Non-Pressurized', style: const TextStyle(fontSize: 12)),
                          value: tank.isPressurized,
                          onChanged: (val) => _updateTankLine(index, tank.copyWith(isPressurized: val)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Rate
                  TextFormField(
                    initialValue: tank.rate > 0 ? '${tank.rate}' : '',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Unit Rate (₹)',
                      helperText: 'Total: ${PriceCalculator.formatIndianCurrency(tank.rate * tank.qty)}',
                      prefixText: '₹ ',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) {
                      final r = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                      _updateTankLine(index, tank.copyWith(rate: r));
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
