// lib/features/quotation_generator/ui/widgets/manage_tank_options_dialog.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/tank_spec_options_service.dart';

class ManageTankOptionsDialog extends StatefulWidget {
  final String category;
  final String title;
  final String currentSelected;
  final ValueChanged<String>? onSelectedChanged;

  const ManageTankOptionsDialog({
    super.key,
    required this.category,
    required this.title,
    required this.currentSelected,
    this.onSelectedChanged,
  });

  static Future<List<String>?> show(
    BuildContext context, {
    required String category,
    required String title,
    required String currentSelected,
    ValueChanged<String>? onSelectedChanged,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => ManageTankOptionsDialog(
        category: category,
        title: title,
        currentSelected: currentSelected,
        onSelectedChanged: onSelectedChanged,
      ),
    );
  }

  @override
  State<ManageTankOptionsDialog> createState() => _ManageTankOptionsDialogState();
}

class _ManageTankOptionsDialogState extends State<ManageTankOptionsDialog> {
  final _addController = TextEditingController();
  List<String> _options = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() => _isLoading = true);
    try {
      final opts = await TankSpecOptionsService.getOptions(widget.category);
      if (mounted) {
        setState(() {
          _options = opts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load options: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAdd() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;

    if (_options.any((o) => o.toLowerCase() == text.toLowerCase())) {
      setState(() => _errorMessage = '"$text" already exists.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final updated = await TankSpecOptionsService.addOption(widget.category, text);
      _addController.clear();
      if (mounted) {
        setState(() {
          _options = updated;
          _isProcessing = false;
        });
        widget.onSelectedChanged?.call(text);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Add error: $e';
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleDelete(String item) async {
    if (_options.length <= 1) {
      setState(() => _errorMessage = 'At least one option must remain in the list.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Option?'),
        content: Text('Are you sure you want to remove "$item" from ${widget.title.toLowerCase()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final updated = await TankSpecOptionsService.deleteOption(widget.category, item);
      if (mounted) {
        setState(() {
          _options = updated;
          _isProcessing = false;
        });
        if (widget.currentSelected == item && updated.isNotEmpty) {
          widget.onSelectedChanged?.call(updated.first);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Delete error: $e';
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 540),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        widget.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context, _options),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Add custom options or remove unused ones. Changes are saved to database company-wide.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),

              // Add Input Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addController,
                      decoration: InputDecoration(
                        labelText: 'Add New Option',
                        hintText: widget.category.contains('thickness') ? 'e.g. 7mm' : 'e.g. Custom Type',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onSubmitted: (_) => _handleAdd(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isProcessing ? null : _handleAdd,
                    icon: _isProcessing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),

              const Text(
                'Current Options:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),

              // Options list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _options.isEmpty
                        ? const Center(child: Text('No options available.', style: TextStyle(color: AppColors.textSecondary)))
                        : ListView.separated(
                            itemCount: _options.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = _options[index];
                              final isSelected = item == widget.currentSelected;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.grey.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (isSelected)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 6),
                                        child: Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                                      ),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          fontSize: 13,
                                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                        ),
                                        softWrap: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                      tooltip: 'Delete $item',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: _isProcessing ? null : () => _handleDelete(item),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context, _options),
                  child: const Text('Done', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
