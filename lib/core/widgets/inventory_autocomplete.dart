import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../features/admin/providers/inventory_provider.dart';
import '../models/inventory_item.dart';
import '../theme/app_theme.dart';

class InventoryAutocomplete extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final void Function(InventoryItem item) onItemSelected;
  final VoidCallback onChanged;
  final String labelText;

  const InventoryAutocomplete({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onItemSelected,
    required this.onChanged,
    this.labelText = 'Description *',
  });

  /// Formats rate / price in Indian number system with commas,
  /// showing decimals only if fractional part exists.
  static String formatIndianPrice(double value) {
    final hasDecimal = (value % 1) != 0;
    final formatter = NumberFormat(hasDecimal ? '#,##,##0.##' : '#,##,##0', 'en_IN');
    return formatter.format(value);
  }

  @override
  ConsumerState<InventoryAutocomplete> createState() => _InventoryAutocompleteState();
}

class _InventoryAutocompleteState extends ConsumerState<InventoryAutocomplete> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _openSearchSheet(BuildContext context, List<InventoryItem> items) {
    if (!widget.enabled) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = items.where((item) {
              final q = query.toLowerCase();
              return item.itemName.toLowerCase().contains(q) ||
                  (item.hsnSac != null && item.hsnSac!.toLowerCase().contains(q));
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Inventory Item',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search by item name or HSN...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setModalState(() => query = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              query.isEmpty
                                  ? 'No inventory items available.'
                                  : 'No items match "$query"',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final item = filtered[idx];
                              return ListTile(
                                title: Text(
                                  item.itemName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                subtitle: Text(
                                  'HSN: ${item.hsnSac ?? "—"} | UOM: ${item.uom ?? "NOS"}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  '₹${InventoryAutocomplete.formatIndianPrice(item.price)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 13,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  widget.controller.text = item.itemName;
                                  widget.onItemSelected(item);
                                  widget.onChanged();
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final items = inventoryAsync.value ?? [];

    return RawAutocomplete<InventoryItem>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return items;
        }
        return items.where((option) {
          final q = textEditingValue.text.toLowerCase();
          return option.itemName.toLowerCase().contains(q) ||
              (option.hsnSac != null && option.hsnSac!.toLowerCase().contains(q));
        });
      },
      displayStringForOption: (InventoryItem option) => option.itemName,
      onSelected: (InventoryItem selection) {
        widget.onItemSelected(selection);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          enabled: widget.enabled,
          textInputAction: TextInputAction.next,
          onChanged: (_) => widget.onChanged(),
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: 'Search inventory or type custom...',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search, size: 20, color: AppColors.primary),
              tooltip: 'Browse inventory items',
              onPressed: () => _openSearchSheet(context, items),
            ),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 220,
                maxWidth: MediaQuery.of(context).size.width - 60,
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(option.itemName, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('HSN: ${option.hsnSac ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              Text('Unit: ${option.uom ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const Spacer(),
                              Text('₹${InventoryAutocomplete.formatIndianPrice(option.price)}', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
