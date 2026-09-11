import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/supabase_provider.dart';
import '../providers/inventory_provider.dart';
import 'manage_sizes_screen.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Inventory Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Icons.straighten, size: 18, color: Colors.white),
            label: const Text('Manage Size', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageSizesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Excel',
            onPressed: () => _importExcel(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Excel',
            onPressed: () {
              final items = inventoryAsync.valueOrNull;
              if (items != null && items.isNotEmpty) {
                _exportExcel(context, ref, items);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No items to export.')),
                );
              }
            },
          ),
        ],
      ),
      body: inventoryAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No inventory items found.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (item.hsnSac != null && item.hsnSac!.isNotEmpty)
                                _buildBadge('HSN: ${item.hsnSac}'),
                              if (item.hsnSac != null && item.hsnSac!.isNotEmpty)
                                const SizedBox(width: 8),
                              if (item.uom != null && item.uom!.isNotEmpty)
                                _buildBadge('Unit: ${item.uom}'),
                              const SizedBox(width: 8),
                              _buildBadge('Warranty: ${item.warrantyMonths}m', color: const Color(0xFFFFFBEB), textColor: const Color(0xFFB45309)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey),
                              onPressed: () => _showEditItemDialog(context, ref, item),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              onPressed: () => _confirmDelete(context, ref, item),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Item', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBadge(String text, {Color? color, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? AppColors.primarySurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor ?? AppColors.primary,
        ),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final hsnController = TextEditingController();
    final unitController = TextEditingController(text: 'NOS');
    final priceController = TextEditingController(text: '0');
    final warrantyController = TextEditingController(text: '12');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.inventory_2, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('New Inventory Item', style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Item Name *', prefixIcon: Icon(Icons.label_outline)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: hsnController,
                      decoration: const InputDecoration(labelText: 'HSN / SAC Code', prefixIcon: Icon(Icons.numbers)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(labelText: 'Unit (UOM) *', prefixIcon: Icon(Icons.scale)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Default Price (₹)', prefixIcon: Icon(Icons.currency_rupee)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: warrantyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Warranty Period (Months)', 
                        prefixIcon: Icon(Icons.verified_user_outlined),
                        helperText: 'e.g. 12 or 24 months from customer purchase date',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item name is required.')));
                            return;
                          }

                          setModalState(() => isSaving = true);
                          try {
                            // Duplicate check
                            final items = ref.read(inventoryProvider).valueOrNull ?? [];
                            final exists = items.any((i) => i.itemName.toLowerCase() == name.toLowerCase());
                            if (exists) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('An item with this name already exists.'), backgroundColor: AppColors.error),
                                );
                                setModalState(() => isSaving = false);
                              }
                              return;
                            }

                            final supabase = ref.read(supabaseClientProvider);
                            await supabase.from('inventory_items').insert({
                              'item_name': name,
                              'hsn_sac': hsnController.text.trim(),
                              'uom': unitController.text.trim(),
                              'price': double.tryParse(priceController.text) ?? 0.0,
                              'warranty_months': int.tryParse(warrantyController.text.trim()) ?? 12,
                            });
                            ref.invalidate(inventoryProvider);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Item added successfully!'), backgroundColor: AppColors.success),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          } finally {
                            if (ctx.mounted) setModalState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditItemDialog(BuildContext context, WidgetRef ref, dynamic item) {
    final nameController = TextEditingController(text: item.itemName);
    final hsnController = TextEditingController(text: item.hsnSac ?? '');
    final unitController = TextEditingController(text: item.uom ?? 'NOS');
    final priceController = TextEditingController(text: item.price.toString());
    final warrantyController = TextEditingController(text: '${item.warrantyMonths}');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Edit Inventory Item', style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Item Name *', prefixIcon: Icon(Icons.label_outline)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: hsnController,
                      decoration: const InputDecoration(labelText: 'HSN / SAC Code', prefixIcon: Icon(Icons.numbers)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(labelText: 'Unit (UOM) *', prefixIcon: Icon(Icons.scale)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Default Price (₹)', prefixIcon: Icon(Icons.currency_rupee)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: warrantyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Warranty Period (Months)', 
                        prefixIcon: Icon(Icons.verified_user_outlined),
                        helperText: 'e.g. 12 or 24 months from customer purchase date',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item name is required.')));
                            return;
                          }

                          setModalState(() => isSaving = true);
                          try {
                            final supabase = ref.read(supabaseClientProvider);
                            await supabase.from('inventory_items').update({
                              'item_name': name,
                              'hsn_sac': hsnController.text.trim(),
                              'uom': unitController.text.trim(),
                              'price': double.tryParse(priceController.text) ?? 0.0,
                              'warranty_months': int.tryParse(warrantyController.text.trim()) ?? 12,
                            }).eq('id', item.id);
                            ref.invalidate(inventoryProvider);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Item updated successfully!'), backgroundColor: AppColors.success),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          } finally {
                            if (ctx.mounted) setModalState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, dynamic item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.itemName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final supabase = ref.read(supabaseClientProvider);
                await supabase.from('inventory_items').delete().eq('id', item.id);
                ref.invalidate(inventoryProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item deleted successfully'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportExcel(BuildContext context, WidgetRef ref, List<dynamic> items) async {
    try {
      var excel = Excel.createExcel();
      var sheetObject = excel['Inventory'];
      excel.setDefaultSheet('Inventory');
      
      List<String> dataList = ['Item Name', 'HSN / SAC Code', 'Unit (UOM)', 'Price (₹)'];
      sheetObject.appendRow(dataList.map((e) => TextCellValue(e)).toList());
      
      for (var item in items) {
        sheetObject.appendRow([
          TextCellValue(item.itemName),
          TextCellValue(item.hsnSac ?? ''),
          TextCellValue(item.uom ?? ''),
          DoubleCellValue(item.price),
        ]);
      }
      
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file.');
      
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/InventoryExport.xlsx';
      final file = File(path);
      await file.writeAsBytes(bytes);
      
      if (context.mounted) {
        await Share.shareXFiles([XFile(path)], text: 'Inventory Export');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _importExcel(BuildContext context, WidgetRef ref) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (files.isEmpty || files.single.path == null) {
        return; // User canceled
      }
      
      final file = File(files.single.path!);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      
      final supabase = ref.read(supabaseClientProvider);
      final existingItems = ref.read(inventoryProvider).valueOrNull ?? [];
      final existingNames = existingItems.map((e) => e.itemName.toLowerCase()).toSet();
      
      int importedCount = 0;
      int skippedCount = 0;
      
      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null) continue;
        
        bool isFirstRow = true;
        for (var row in sheet.rows) {
          if (isFirstRow) {
            isFirstRow = false;
            continue; // Skip header
          }
          
          if (row.isEmpty) continue;
          
          final itemNameCell = row.length > 0 ? row[0]?.value : null;
          final hsnCell = row.length > 1 ? row[1]?.value : null;
          final unitCell = row.length > 2 ? row[2]?.value : null;
          final priceCell = row.length > 3 ? row[3]?.value : null;
          
          final itemName = itemNameCell?.toString().trim();
          if (itemName == null || itemName.isEmpty) continue;
          
          if (existingNames.contains(itemName.toLowerCase())) {
            skippedCount++;
            continue;
          }
          
          final hsn = hsnCell?.toString().trim() ?? '';
          final unit = unitCell?.toString().trim() ?? 'NOS';
          
          double price = 0.0;
          if (priceCell != null) {
            if (priceCell is DoubleCellValue) {
              price = priceCell.value;
            } else if (priceCell is IntCellValue) {
              price = priceCell.value.toDouble();
            } else {
              price = double.tryParse(priceCell.toString()) ?? 0.0;
            }
          }
          
          await supabase.from('inventory_items').insert({
            'item_name': itemName,
            'hsn_sac': hsn,
            'uom': unit,
            'price': price,
          });
          
          existingNames.add(itemName.toLowerCase());
          importedCount++;
        }
      }
      
      if (importedCount > 0) {
        ref.invalidate(inventoryProvider);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $importedCount items. Skipped $skippedCount duplicates.'),
            backgroundColor: importedCount > 0 ? AppColors.success : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
