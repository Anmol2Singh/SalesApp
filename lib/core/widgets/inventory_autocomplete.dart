import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);

    final items = inventoryAsync.value ?? [];

    return RawAutocomplete<InventoryItem>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<InventoryItem>.empty();
        }
        return items.where((option) {
          return option.itemName.toLowerCase().contains(textEditingValue.text.toLowerCase());
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
            suffixIcon: const Icon(Icons.search, size: 20),
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
                maxHeight: 200,
                maxWidth: MediaQuery.of(context).size.width - 60, // approximate padding
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
                              Text('₹${option.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
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
