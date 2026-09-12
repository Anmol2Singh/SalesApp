// lib/core/widgets/searchable_dropdown.dart

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SearchableDropdown<T> extends StatelessWidget {
  final String label;
  final String? hint;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final String? Function(T item)? itemSubtitle;
  final Widget Function(T item)? itemLeading;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final bool isClearable;
  final InputDecoration? decoration;

  const SearchableDropdown({
    super.key,
    required this.label,
    this.hint,
    required this.value,
    required this.items,
    required this.itemLabel,
    this.itemSubtitle,
    this.itemLeading,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.isClearable = false,
    this.decoration,
  });

  void _openSelectionDialog(BuildContext context) {
    if (!enabled) return;

    final isWide = MediaQuery.of(context).size.width >= 600;

    if (isWide) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
            child: _SearchableDropdownModalContent<T>(
              title: label,
              items: items,
              selectedItem: value,
              itemLabel: itemLabel,
              itemSubtitle: itemSubtitle,
              itemLeading: itemLeading,
              onSelected: (selected) {
                Navigator.of(ctx).pop();
                onChanged(selected);
              },
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _SearchableDropdownModalContent<T>(
            title: label,
            items: items,
            selectedItem: value,
            itemLabel: itemLabel,
            itemSubtitle: itemSubtitle,
            itemLeading: itemLeading,
            onSelected: (selected) {
              Navigator.of(ctx).pop();
              onChanged(selected);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayText = value != null ? itemLabel(value as T) : '';

    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (state) {
        final hasError = state.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: enabled ? () => _openSelectionDialog(context) : null,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: (decoration ?? const InputDecoration()).copyWith(
                  labelText: label,
                  hintText: hint ?? 'Select $label',
                  errorText: hasError ? state.errorText : null,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isClearable && value != null && enabled)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            state.didChange(null);
                            onChanged(null);
                          },
                        ),
                      const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                isEmpty: value == null,
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: enabled
                        ? (value != null ? AppColors.textPrimary : AppColors.textSecondary)
                        : Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchableDropdownModalContent<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final T? selectedItem;
  final String Function(T item) itemLabel;
  final String? Function(T item)? itemSubtitle;
  final Widget Function(T item)? itemLeading;
  final ValueChanged<T?> onSelected;

  const _SearchableDropdownModalContent({
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.itemLabel,
    this.itemSubtitle,
    this.itemLeading,
    required this.onSelected,
  });

  @override
  State<_SearchableDropdownModalContent<T>> createState() => _SearchableDropdownModalContentState<T>();
}

class _SearchableDropdownModalContentState<T> extends State<_SearchableDropdownModalContent<T>> {
  final _searchController = TextEditingController();
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final lowerQuery = query.toLowerCase().trim();
    setState(() {
      if (lowerQuery.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final label = widget.itemLabel(item).toLowerCase();
          final subtitle = widget.itemSubtitle?.call(item)?.toLowerCase() ?? '';
          return label.contains(lowerQuery) || subtitle.contains(lowerQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Select ${widget.title}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                tooltip: 'Close',
                splashRadius: 20,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        Expanded(
          child: _filteredItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No matching options found',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _filteredItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    final isSelected = widget.selectedItem == item;
                    final label = widget.itemLabel(item);
                    final subtitle = widget.itemSubtitle?.call(item);

                    return ListTile(
                      leading: widget.itemLeading?.call(item),
                      title: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: subtitle != null
                          ? Text(
                              subtitle,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            )
                          : null,
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                          : null,
                      onTap: () => widget.onSelected(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
