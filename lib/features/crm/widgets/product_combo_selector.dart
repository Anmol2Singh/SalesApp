// lib/features/crm/widgets/product_combo_selector.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

class ProductComboItem {
  final String displayName;
  final String productName;
  final String? capacity;
  final double price;
  final String uom;

  const ProductComboItem({
    required this.displayName,
    required this.productName,
    this.capacity,
    this.price = 0.0,
    this.uom = 'SET',
  });

  Map<String, dynamic> toComponentMap() => {
        'item_name': displayName,
        'product_name': productName,
        if (capacity != null && capacity!.isNotEmpty) 'capacity': capacity,
        'price': price,
        'uom': uom,
        'qty': 1,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductComboItem &&
          runtimeType == other.runtimeType &&
          displayName == other.displayName;

  @override
  int get hashCode => displayName.hashCode;

  static List<ProductComboItem>? _cachedCombos;

  static final List<ProductComboItem> defaultCombos = [
    const ProductComboItem(
        displayName: 'Boom Barrier - IZ-2026',
        productName: 'Boom Barrier',
        capacity: 'IZ-2026',
        price: 152500.0,
        uom: 'SET'),
    const ProductComboItem(
        displayName: 'Boom Barrier - IZ-2001',
        productName: 'Boom Barrier',
        capacity: 'IZ-2001',
        price: 40000.0,
        uom: 'NOS'),
    const ProductComboItem(
        displayName: 'Heat Pump - 4kW',
        productName: 'Heat Pump',
        capacity: '4kW',
        price: 110000.0,
        uom: 'SET'),
    const ProductComboItem(
        displayName: 'Heat Pump - 8kW',
        productName: 'Heat Pump',
        capacity: '8kW',
        price: 180000.0,
        uom: 'SET'),
    const ProductComboItem(
        displayName: 'Heat Pump - 10kW',
        productName: 'Heat Pump',
        capacity: '10kW',
        price: 230000.0,
        uom: 'SET'),
    const ProductComboItem(
        displayName: 'Heat Pump - 18kW',
        productName: 'Heat Pump',
        capacity: '18kW',
        price: 330000.0,
        uom: 'SET'),
    const ProductComboItem(
        displayName: 'Solar Water Heater - 200 Ltr',
        productName: 'Solar Water Heater',
        capacity: '200 Ltr',
        price: 60000.0,
        uom: 'NOS'),
    const ProductComboItem(
        displayName: 'Solar Water Heater - 500 Ltr',
        productName: 'Solar Water Heater',
        capacity: '500 Ltr',
        price: 120000.0,
        uom: 'NOS'),
    const ProductComboItem(
        displayName: 'Solar Water Heater - 1000 Ltr',
        productName: 'Solar Water Heater',
        capacity: '1000 Ltr',
        price: 210000.0,
        uom: 'NOS'),
    const ProductComboItem(
        displayName: 'Commercial 10kW',
        productName: 'Commercial 10kW',
        capacity: '10kW',
        price: 542800.0,
        uom: 'SET'),
  ];

  static Future<List<ProductComboItem>> loadCombos(SupabaseClient supabase) async {
    if (_cachedCombos != null && _cachedCombos!.isNotEmpty) {
      return _cachedCombos!;
    }

    try {
      final prodRes = await supabase.from('products').select('id, name, base_specs');
      final invRes = await supabase.from('inventory_items').select('id, item_name, price, uom').order('item_name');

      final List<Map<String, dynamic>> inventoryItems = (invRes as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

      final List<ProductComboItem> combos = [];

      for (final p in (prodRes as List? ?? [])) {
        final prodName = p['name'] as String? ?? '';
        final specs = p['base_specs'] as Map<String, dynamic>? ?? {};
        List<String> capacities = [];
        if (specs['capacities'] is List) {
          capacities = (specs['capacities'] as List).map((c) => c.toString()).toList();
        }
        if (capacities.isEmpty) {
          if (prodName.toLowerCase().contains('heat pump')) {
            capacities = ['4kW', '8kW', '10kW', '18kW'];
          } else if (prodName.toLowerCase().contains('water heater')) {
            capacities = ['100 Ltr', '200 Ltr', '300 Ltr', '500 Ltr', '1000 Ltr'];
          } else if (prodName.toLowerCase().contains('barrier')) {
            capacities = ['IZ-2001', 'IZ-2026'];
          } else {
            capacities = ['Standard'];
          }
        }

        for (final cap in capacities) {
          final displayName = '$prodName - $cap';
          double price = 0.0;
          String uom = 'SET';

          final cleanCap = cap.replaceAll(RegExp(r'\s+'), '').toLowerCase();
          final cleanProd = prodName.toLowerCase();

          for (final inv in inventoryItems) {
            final invName = (inv['item_name'] as String? ?? '').replaceAll(RegExp(r'\s+'), '').toLowerCase();
            if (invName.contains(cleanCap) || (invName.contains(cleanProd) && invName.contains(cleanCap))) {
              price = (inv['price'] as num?)?.toDouble() ?? 0.0;
              uom = inv['uom'] as String? ?? 'SET';
              break;
            }
          }

          combos.add(ProductComboItem(
            displayName: displayName,
            productName: prodName,
            capacity: cap,
            price: price,
            uom: uom,
          ));
        }
      }

      // Add standalone inventory items
      for (final inv in inventoryItems) {
        final invName = inv['item_name'] as String? ?? '';
        final price = (inv['price'] as num?)?.toDouble() ?? 0.0;
        final uom = inv['uom'] as String? ?? 'NOS';
        if (!combos.any((c) => c.displayName.toLowerCase() == invName.toLowerCase())) {
          combos.add(ProductComboItem(
            displayName: invName,
            productName: invName,
            price: price,
            uom: uom,
          ));
        }
      }

      if (combos.isNotEmpty) {
        _cachedCombos = combos;
        return combos;
      }
    } catch (_) {}

    return defaultCombos;
  }
}

/// Searchable modal bottom sheet to multi-select products/inventory items
class MultiProductPickerSheet extends StatefulWidget {
  final List<ProductComboItem> availableItems;
  final List<ProductComboItem> initialSelected;

  const MultiProductPickerSheet({
    super.key,
    required this.availableItems,
    required this.initialSelected,
  });

  static Future<List<ProductComboItem>?> show(
    BuildContext context, {
    required List<ProductComboItem> availableItems,
    required List<ProductComboItem> initialSelected,
  }) {
    return showModalBottomSheet<List<ProductComboItem>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MultiProductPickerSheet(
        availableItems: availableItems,
        initialSelected: initialSelected,
      ),
    );
  }

  @override
  State<MultiProductPickerSheet> createState() => _MultiProductPickerSheetState();
}

class _MultiProductPickerSheetState extends State<MultiProductPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<ProductComboItem> _selected;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _selected = List<ProductComboItem>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##,##0', 'en_IN');
    final filtered = widget.availableItems.where((item) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return item.displayName.toLowerCase().contains(q) ||
          item.productName.toLowerCase().contains(q) ||
          (item.capacity?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Products / Items',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        '${_selected.length} item(s) selected',
                        style: TextStyle(
                          fontSize: 12,
                          color: _selected.isNotEmpty ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selected.clear()),
                    child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, _selected),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search inventory or products...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => _filter = v.trim()),
            ),
          ),

          // List of items
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No matching items found', style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, index) {
                      final item = filtered[index];
                      final isChecked = _selected.contains(item);
                      return CheckboxListTile(
                        value: isChecked,
                        activeColor: AppColors.primary,
                        onChanged: (bool? val) {
                          setState(() {
                            if (val == true) {
                              if (!_selected.contains(item)) {
                                _selected.add(item);
                              }
                            } else {
                              _selected.remove(item);
                            }
                          });
                        },
                        title: Text(
                          item.displayName,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                            color: isChecked ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          item.price > 0
                              ? '₹${currency.format(item.price)} per ${item.uom}'
                              : 'Standard / Quote-based',
                          style: TextStyle(
                            fontSize: 12,
                            color: item.price > 0 ? Colors.green.shade700 : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isChecked ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 20,
                            color: isChecked ? AppColors.primary : Colors.grey.shade600,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom confirm bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Estimated Value',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        '₹${currency.format(_selected.fold<double>(0.0, (sum, i) => sum + i.price))}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _selected),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text('Done (${_selected.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Selector field with chips displaying chosen products and add/remove buttons
class MultiProductSelectorField extends StatelessWidget {
  final List<ProductComboItem> selectedItems;
  final List<ProductComboItem> availableItems;
  final ValueChanged<List<ProductComboItem>> onChanged;
  final String? errorText;

  const MultiProductSelectorField({
    super.key,
    required this.selectedItems,
    required this.availableItems,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##,##0', 'en_IN');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final picked = await MultiProductPickerSheet.show(
              context,
              availableItems: availableItems,
              initialSelected: selectedItems,
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: errorText != null
                    ? Colors.red
                    : (selectedItems.isNotEmpty ? AppColors.primary : AppColors.border),
                width: selectedItems.isNotEmpty ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.solar_power_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedItems.isEmpty
                        ? 'Select Product(s) *'
                        : '${selectedItems.length} product(s) selected',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: selectedItems.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                      color: selectedItems.isNotEmpty ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selectedItems.isEmpty ? Icons.add : Icons.edit,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        selectedItems.isEmpty ? 'Select' : 'Edit',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],

        // Selected Chips
        if (selectedItems.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedItems.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.displayName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    if (item.price > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(₹${currency.format(item.price)})',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        final updated = List<ProductComboItem>.from(selectedItems)..remove(item);
                        onChanged(updated);
                      },
                      child: const Icon(Icons.cancel, size: 16, color: AppColors.primary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
