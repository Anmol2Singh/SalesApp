// lib/features/quotation_generator/ui/widgets/item_resolve_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/qg_item_parser.dart';

/// Interactive dialog for resolving unmapped deal line items or overriding parsed attributes.
/// Strictly local until proposal is approved and finalized.
class ItemResolveDialog extends StatefulWidget {
  final ParsedItemResult initialItem;

  const ItemResolveDialog({
    super.key,
    required this.initialItem,
  });

  static Future<ParsedItemResult?> show(
    BuildContext context, {
    required ParsedItemResult item,
  }) {
    return showDialog<ParsedItemResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ItemResolveDialog(initialItem: item),
    );
  }

  @override
  State<ItemResolveDialog> createState() => _ItemResolveDialogState();
}

class _ItemResolveDialogState extends State<ItemResolveDialog> {
  late ParsedItemType _selectedType;
  
  // Heat Pump fields (digits-only whole number kW per Section 7a)
  late TextEditingController _hpKwCtrl;
  late TextEditingController _hpModelOverrideCtrl;
  bool _isManualModelOverride = false;

  // Tank fields
  late TextEditingController _tankLitresCtrl;
  String _tankMaterial = 'GI';
  bool _isPressurized = true;
  String _insulation = 'Puff';

  // All-in-One fields
  late TextEditingController _aioLitresCtrl;

  // Pool fields
  late TextEditingController _poolKwCtrl;

  // Pricing / Quantity fields
  late TextEditingController _qtyCtrl;
  late TextEditingController _rateCtrl;
  bool _isExtra = false;
  bool _isIncluded = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _selectedType = item.type;

    _hpKwCtrl = TextEditingController(
      text: item.hpKw != null ? item.hpKw.toString() : '',
    );
    _hpModelOverrideCtrl = TextEditingController(
      text: item.hpModel ?? '',
    );

    _tankLitresCtrl = TextEditingController(
      text: item.tankCapacityLitres != null ? item.tankCapacityLitres.toString() : '500',
    );
    _tankMaterial = item.tankMaterial ?? 'GI';
    _isPressurized = item.isPressurized;
    _insulation = item.insulationType ?? 'Puff';

    _aioLitresCtrl = TextEditingController(
      text: item.aioCapacityLitres != null ? item.aioCapacityLitres.toString() : '200',
    );

    _poolKwCtrl = TextEditingController(
      text: item.poolKw != null ? item.poolKw.toString() : '35',
    );

    _qtyCtrl = TextEditingController(text: item.qty.toString());
    _rateCtrl = TextEditingController(text: item.rate > 0 ? item.rate.toStringAsFixed(0) : '0');
    _isExtra = item.isExtra;
    _isIncluded = item.isIncluded;

    _hpKwCtrl.addListener(_onHpKwChanged);
  }

  @override
  void dispose() {
    _hpKwCtrl.removeListener(_onHpKwChanged);
    _hpKwCtrl.dispose();
    _hpModelOverrideCtrl.dispose();
    _tankLitresCtrl.dispose();
    _aioLitresCtrl.dispose();
    _poolKwCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _onHpKwChanged() {
    if (!_isManualModelOverride) {
      final kwD = double.tryParse(_hpKwCtrl.text.trim());
      if (kwD != null && kwD > 0) {
        final kw = kwD.round();
        _hpModelOverrideCtrl.text = QgItemParser.deriveHpModelFromKw(kw);
      } else {
        _hpModelOverrideCtrl.text = '';
      }
      setState(() {});
    }
  }

  void _onSave() {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    final amount = qty * rate;

    ParsedItemResult resolved;

    switch (_selectedType) {
      case ParsedItemType.heatPump:
        final kwD = double.tryParse(_hpKwCtrl.text.trim());
        if (kwD == null || kwD <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid kW for Heat Pump.')),
          );
          return;
        }
        final kw = kwD.round();

        final model = _hpModelOverrideCtrl.text.trim().isNotEmpty
            ? _hpModelOverrideCtrl.text.trim()
            : QgItemParser.deriveHpModelFromKw(kw);

        String? warning;
        String? catalogModel;
        if (kw == 88) {
          catalogModel = 'IZ-90C';
          warning = 'Catalog lists this unit as IZ-90C';
        }

        resolved = widget.initialItem.copyWith(
          type: ParsedItemType.heatPump,
          status: ItemResolveStatus.resolved,
          unmappedReason: null,
          hpKw: kw,
          hpModel: model,
          catalogModel: catalogModel,
          warningMessage: warning,
          qty: qty,
          rate: rate,
          amount: amount,
        );
        break;

      case ParsedItemType.tank:
        final litres = int.tryParse(_tankLitresCtrl.text.trim()) ?? 500;
        resolved = widget.initialItem.copyWith(
          type: ParsedItemType.tank,
          status: ItemResolveStatus.resolved,
          unmappedReason: null,
          tankCapacityLitres: litres,
          tankMaterial: _tankMaterial,
          isPressurized: _isPressurized,
          insulationType: _insulation,
          qty: qty,
          rate: rate,
          amount: amount,
        );
        break;

      case ParsedItemType.allInOne:
      case ParsedItemType.wallMounted:
        final litres = int.tryParse(_aioLitresCtrl.text.trim()) ?? 200;
        resolved = widget.initialItem.copyWith(
          type: _selectedType,
          status: ItemResolveStatus.resolved,
          unmappedReason: null,
          aioCapacityLitres: litres,
          qty: qty,
          rate: rate,
          amount: amount,
        );
        break;

      case ParsedItemType.pool:
        final kw = int.tryParse(_poolKwCtrl.text.trim()) ?? 35;
        resolved = widget.initialItem.copyWith(
          type: ParsedItemType.pool,
          status: ItemResolveStatus.resolved,
          unmappedReason: null,
          poolKw: kw,
          poolModel: 'IZ-${kw}SP',
          qty: qty,
          rate: rate,
          amount: amount,
        );
        break;

      case ParsedItemType.supplementary:
        resolved = widget.initialItem.copyWith(
          type: ParsedItemType.supplementary,
          status: ItemResolveStatus.resolved,
          unmappedReason: null,
          qty: qty,
          rate: rate,
          amount: amount,
          isExtra: _isExtra,
          isIncluded: _isIncluded,
        );
        break;

      default:
        resolved = widget.initialItem.copyWith(
          type: _selectedType,
          status: ItemResolveStatus.resolved,
          unmappedReason: null,
          qty: qty,
          rate: rate,
          amount: amount,
        );
        break;
    }

    Navigator.of(context).pop(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.initialItem;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.build_circle_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resolve Line Item',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Map deal line text to proposal specification format',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Raw text display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Original Line Text:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(item.rawDescription, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if (item.unmappedReason != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.unmappedReason!,
                              style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Item Type Selector
              DropdownButtonFormField<ParsedItemType>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Item Classification',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: ParsedItemType.heatPump, child: Text('Air Source Heat Pump')),
                  DropdownMenuItem(value: ParsedItemType.tank, child: Text('Hot Water Storage Tank')),
                  DropdownMenuItem(value: ParsedItemType.allInOne, child: Text('All in One (Floor Mounted)')),
                  DropdownMenuItem(value: ParsedItemType.wallMounted, child: Text('All in One (Wall Mounted)')),
                  DropdownMenuItem(value: ParsedItemType.pool, child: Text('Swimming Pool Heat Pump')),
                  DropdownMenuItem(value: ParsedItemType.supplementary, child: Text('Supplementary Item')),
                  DropdownMenuItem(value: ParsedItemType.parts, child: Text('Parts / Accessories')),
                  DropdownMenuItem(value: ParsedItemType.other, child: Text('Other Item')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 16),

              // Type specific editors
              if (_selectedType == ParsedItemType.heatPump) ...[
                // Whole number kW input
                TextFormField(
                  controller: _hpKwCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Heat Pump Capacity (kW)',
                    hintText: 'e.g. 38, 8, 4, 40 (or decimals like 3.6)',
                    suffixText: 'kW',
                    helperText: 'Decimals will map to the closest available catalog kW model.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hpModelOverrideCtrl,
                  decoration: InputDecoration(
                    labelText: 'Derived Model Number',
                    hintText: 'Auto-derived: IZ-{kW}C',
                    helperText: 'Auto-derived from kW. Edit only for rare exceptions.',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_isManualModelOverride ? Icons.lock_open : Icons.lock_outline),
                      tooltip: _isManualModelOverride ? 'Manual override active' : 'Click to override',
                      onPressed: () {
                        setState(() => _isManualModelOverride = !_isManualModelOverride);
                      },
                    ),
                  ),
                  readOnly: !_isManualModelOverride,
                ),
                if (_hpKwCtrl.text.trim() == '88') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppColors.info),
                        SizedBox(width: 8),
                        Text('Catalog lists this unit as IZ-90C', style: TextStyle(fontSize: 12, color: AppColors.info)),
                      ],
                    ),
                  ),
                ],
              ],

              if (_selectedType == ParsedItemType.tank) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tankLitresCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Capacity (Litres)',
                          hintText: 'e.g. 500, 1000, 3000',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _tankMaterial,
                        decoration: const InputDecoration(
                          labelText: 'Material',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'GI', child: Text('GI')),
                          DropdownMenuItem(value: 'MS', child: Text('MS')),
                          DropdownMenuItem(value: 'Enamel', child: Text('Enamel')),
                          DropdownMenuItem(value: 'SS', child: Text('SS (304)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _tankMaterial = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _insulation,
                        decoration: const InputDecoration(
                          labelText: 'Insulation',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Puff', child: Text('Puff Insulation')),
                          DropdownMenuItem(value: 'Rockwool', child: Text('Rockwool Insulation')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _insulation = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Pressurized', style: TextStyle(fontSize: 13)),
                        value: _isPressurized,
                        onChanged: (val) => setState(() => _isPressurized = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],

              if (_selectedType == ParsedItemType.allInOne || _selectedType == ParsedItemType.wallMounted) ...[
                TextFormField(
                  controller: _aioLitresCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Tank Volume (Litres)',
                    hintText: 'e.g. 60, 80, 100, 200, 300, 500',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              if (_selectedType == ParsedItemType.pool) ...[
                TextFormField(
                  controller: _poolKwCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Pool Heat Pump Capacity (kW)',
                    hintText: 'e.g. 17, 30, 35, 50, 120, 136',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // Quantity and Rate
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _rateCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Rate (₹)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _onSave,
                    child: const Text('Apply Mapping'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
