// lib/features/quotation_generator/ui/widgets/searchable_tank_dropdown.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/tank_spec_options_service.dart';
import 'manage_tank_options_dialog.dart';

/// A searchable dropdown form field for tank specifications (Material, Insulation, Shell, Dish).
///
/// Features:
/// - Clean form field appearance matching outline input decoration.
/// - Suffix tune icon for quick list management and dropdown chevron.
/// - Tapping opens a responsive searchable dialog with autofocus search input.
/// - Real-time client-side substring filtering (case-insensitive).
/// - Keyboard 'Enter' to instantly select the top match.
/// - Inline "+ Add [query]" button if search query doesn't exist yet.
/// - Direct access to ManageTankOptionsDialog to delete or reorder options.
class SearchableTankDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final String category;
  final ValueChanged<String> onChanged;
  final ValueChanged<List<String>>? onOptionsChanged;
  final bool enabled;
  final bool canManage;

  const SearchableTankDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.category,
    required this.onChanged,
    this.onOptionsChanged,
    this.enabled = true,
    this.canManage = false,
  });

  Future<void> _openSearchPicker(BuildContext context) async {
    if (!enabled) return;

    await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _SearchPickerContent(
        label: label,
        currentSelected: value,
        options: options,
        category: category,
        canManage: canManage,
        onSelected: (val) {
          onChanged(val);
        },
        onOptionsChanged: onOptionsChanged,
      ),
    );
  }

  Future<void> _openManageDialog(BuildContext context) async {
    if (!enabled || !canManage) return;

    final updated = await ManageTankOptionsDialog.show(
      context,
      category: category,
      title: 'Manage $label',
      currentSelected: value,
      onSelectedChanged: onChanged,
    );

    if (updated != null && onOptionsChanged != null) {
      onOptionsChanged!(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveValue = value.trim();
    final displayText = effectiveValue.isNotEmpty ? effectiveValue : 'Select $label';

    return InkWell(
      onTap: enabled ? () => _openSearchPicker(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        isFocused: false,
        isEmpty: effectiveValue.isEmpty,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          enabled: enabled,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (enabled && canManage)
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                  tooltip: 'Manage $label list',
                  splashRadius: 18,
                  onPressed: () => _openManageDialog(context),
                ),
              const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
              const SizedBox(width: 8),
            ],
          ),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 14,
            color: effectiveValue.isNotEmpty
                ? (enabled ? null : AppColors.textSecondary)
                : AppColors.textSecondary,
            fontWeight: effectiveValue.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _SearchPickerContent extends StatefulWidget {
  final String label;
  final String currentSelected;
  final List<String> options;
  final String category;
  final bool canManage;
  final ValueChanged<String> onSelected;
  final ValueChanged<List<String>>? onOptionsChanged;

  const _SearchPickerContent({
    required this.label,
    required this.currentSelected,
    required this.options,
    required this.category,
    this.canManage = false,
    required this.onSelected,
    this.onOptionsChanged,
  });

  @override
  State<_SearchPickerContent> createState() => _SearchPickerContentState();
}

class _SearchPickerContentState extends State<_SearchPickerContent> {
  final TextEditingController _searchController = TextEditingController();
  late List<String> _currentOptions;
  String _selectedItem = '';
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.currentSelected;
    _currentOptions = List<String>.from(widget.options);
    if (_selectedItem.isNotEmpty && !_currentOptions.contains(_selectedItem)) {
      _currentOptions.add(_selectedItem);
    }
    _refreshFromDatabase();
  }

  Future<void> _refreshFromDatabase() async {
    try {
      final dbOptions = await TankSpecOptionsService.getOptions(widget.category);
      if (mounted && dbOptions.isNotEmpty) {
        setState(() {
          final set = <String>{...dbOptions};
          if (_selectedItem.isNotEmpty) set.add(_selectedItem);
          _currentOptions = set.toList();
        });
        widget.onOptionsChanged?.call(_currentOptions);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredOptions {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _currentOptions;
    return _currentOptions.where((opt) => opt.toLowerCase().contains(q)).toList();
  }

  Future<void> _quickAdd(String label) async {
    final clean = label.trim();
    if (clean.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      final updated = await TankSpecOptionsService.addOption(widget.category, clean);
      if (mounted) {
        setState(() {
          _currentOptions = updated;
          _selectedItem = clean;
          _searchController.clear();
        });
        widget.onOptionsChanged?.call(updated);
        widget.onSelected(clean);
        Navigator.of(context).pop(clean);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding option: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _openManageDialog() async {
    final updated = await ManageTankOptionsDialog.show(
      context,
      category: widget.category,
      title: 'Manage ${widget.label}',
      currentSelected: _selectedItem,
      onSelectedChanged: (val) {
        setState(() => _selectedItem = val);
        widget.onSelected(val);
      },
    );

    if (updated != null && mounted) {
      setState(() {
        _currentOptions = updated;
        if (!updated.contains(_selectedItem) && updated.isNotEmpty) {
          _selectedItem = updated.first;
          widget.onSelected(_selectedItem);
        }
      });
      widget.onOptionsChanged?.call(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOptions;
    final query = _searchController.text.trim();
    final isExactMatch = _currentOptions.any((opt) => opt.toLowerCase() == query.toLowerCase());

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select ${widget.label}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Close',
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search input field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search ${widget.label}...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          splashRadius: 16,
                          onPressed: () {
                            setState(() => _searchController.clear());
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (val) {
                  if (filtered.isNotEmpty) {
                    widget.onSelected(filtered.first);
                    Navigator.of(context).pop(filtered.first);
                  } else if (val.trim().isNotEmpty && !isExactMatch && widget.canManage) {
                    _quickAdd(val);
                  }
                },
              ),
            ),

            // Options List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 42, color: AppColors.textSecondary.withOpacity(0.5)),
                            const SizedBox(height: 8),
                            Text(
                              query.isEmpty ? 'No options available' : 'No option matching "$query"',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            if (query.isNotEmpty && !isExactMatch && widget.canManage) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: _isAdding
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.add, size: 16),
                                label: Text('Add "$query" to list'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _isAdding ? null : () => _quickAdd(query),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        final isSelected = option == _selectedItem;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            title: Text(
                              option,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppColors.primary : null,
                                fontSize: 14,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                                : null,
                            onTap: () {
                              setState(() => _selectedItem = option);
                              widget.onSelected(option);
                              Navigator.of(context).pop(option);
                            },
                          ),
                        );
                      },
                    ),
            ),

            const Divider(height: 1),

            // Footer: Total count & Manage List button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentOptions.length} option${_currentOptions.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (widget.canManage)
                    TextButton.icon(
                      icon: const Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
                      label: Text(
                        'Manage ${widget.label} list',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: _openManageDialog,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

