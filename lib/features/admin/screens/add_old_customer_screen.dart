import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_role.dart';
import '../../../core/models/customer.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/excel_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customers/providers/customers_provider.dart';

class _ProductItemEntry {
  final TextEditingController nameController;
  final List<TextEditingController> itemControllers;

  _ProductItemEntry({
    required this.nameController,
    required this.itemControllers,
  });

  void dispose() {
    nameController.dispose();
    for (final c in itemControllers) {
      c.dispose();
    }
  }
}

class AddOldCustomerScreen extends ConsumerStatefulWidget {
  const AddOldCustomerScreen({super.key});

  @override
  ConsumerState<AddOldCustomerScreen> createState() => _AddOldCustomerScreenState();
}

class _AddOldCustomerScreenState extends ConsumerState<AddOldCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  final _companyController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _notesController = TextEditingController();

  final List<_ProductItemEntry> _products = [];
  List<Map<String, dynamic>> _catalogProducts = [];
  List<String> _catalogProductNames = [];
  List<Map<String, dynamic>> _inventoryItems = [];
  List<String> _inventoryItemNames = [];
  bool _isSaving = false;
  bool _isProcessingExcel = false;

  @override
  void initState() {
    super.initState();
    _addNewProduct();
    _loadCatalogAndInventory();
  }

  Future<void> _downloadTemplate() async {
    try {
      await ExcelService.downloadOldCustomerTemplate(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading template: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportOldCustomers() async {
    setState(() => _isProcessingExcel = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('customers')
          .select('*')
          .ilike('notes', '%[OLD_CUSTOMER_DATA:%')
          .order('created_at', ascending: false);

      final list = (response as List? ?? []).map((json) {
        return Customer.fromJson(json as Map<String, dynamic>);
      }).toList();

      if (list.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No Old Customers found to export.'),
              backgroundColor: AppColors.info,
            ),
          );
        }
        return;
      }

      if (mounted) {
        await ExcelService.exportOldCustomers(context, list);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting old customers: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingExcel = false);
    }
  }

  Future<void> _importFromExcel() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (files.isEmpty || files.first.path == null) return;

      final file = File(files.first.path!);
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to read selected Excel file.'), backgroundColor: AppColors.error),
          );
        }
        return;
      }

      final parsedRows = ExcelService.parseOldCustomersExcel(bytes);
      if (parsedRows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid rows found in Excel. Please check column headers or use the provided template.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      // Group records by phone (or customer name if phone is empty)
      final Map<String, Map<String, dynamic>> consolidated = {};
      for (final r in parsedRows) {
        final phoneVal = (r['phone'] as String? ?? '').trim();
        final nameVal = (r['customer_name'] as String? ?? '').trim();
        final key = phoneVal.isNotEmpty ? phoneVal : nameVal.toLowerCase();

        if (key.isEmpty) continue;

        final pName = (r['product_name'] as String? ?? '').trim();
        final pItems = (r['items'] as List<String>? ?? []);

        if (!consolidated.containsKey(key)) {
          consolidated[key] = {
            'customer_name': nameVal,
            'contact_person': r['contact_person'],
            'phone': phoneVal,
            'email': r['email'],
            'address': r['address'],
            'gst_number': r['gst_number'],
            'notes': r['notes'],
            'products': <Map<String, dynamic>>[],
          };
        }

        if (pName.isNotEmpty) {
          // Normalize to sell product catalog name if matching
          final matchedProd = _catalogProductNames.firstWhere(
            (n) => n.trim().toLowerCase() == pName.toLowerCase(),
            orElse: () => pName,
          );

          // Normalize items to inventory item names if matching
          final normalizedItems = pItems.map((it) {
            return _inventoryItemNames.firstWhere(
              (inv) => inv.trim().toLowerCase() == it.trim().toLowerCase(),
              orElse: () => it.trim(),
            );
          }).where((it) => it.isNotEmpty).toList();

          final List<Map<String, dynamic>> prods = consolidated[key]!['products'];
          final existingProdIdx = prods.indexWhere((p) => (p['name'] as String? ?? '').toLowerCase() == matchedProd.toLowerCase());
          if (existingProdIdx >= 0) {
            final existingItems = List<String>.from(prods[existingProdIdx]['items'] as List? ?? []);
            for (final it in normalizedItems) {
              if (!existingItems.contains(it)) existingItems.add(it);
            }
            prods[existingProdIdx]['items'] = existingItems;
          } else {
            prods.add({
              'name': matchedProd,
              'items': normalizedItems,
            });
          }
        }
      }

      if (consolidated.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid customer data to import.'), backgroundColor: AppColors.warning),
          );
        }
        return;
      }

      // Show confirmation dialog before inserting
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.file_upload_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Import ${consolidated.length} Customers?'),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found ${consolidated.length} unique customer(s) across ${parsedRows.length} Excel rows.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                const Text(
                  'They will be added as Old Customers with their respective products and items.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: consolidated.length.clamp(0, 10),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = consolidated.values.elementAt(i);
                      final prods = (c['products'] as List).map((p) => p['name']).join(', ');
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(c['customer_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Phone: ${c['phone']} • Products: ${prods.isNotEmpty ? prods : 'None'}', style: const TextStyle(fontSize: 11)),
                      );
                    },
                  ),
                ),
                if (consolidated.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('+ ${consolidated.length - 10} more customer(s)...', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import Now'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() => _isProcessingExcel = true);
      final supabase = ref.read(supabaseClientProvider);
      final profile = ref.read(currentProfileProvider);
      int importedCount = 0;

      for (final entry in consolidated.values) {
        final cName = (entry['customer_name'] as String? ?? '').trim();
        final cContact = (entry['contact_person'] as String? ?? '').trim();
        final cPhone = (entry['phone'] as String? ?? '').trim();
        final cEmail = (entry['email'] as String? ?? '').trim();
        final cAddress = (entry['address'] as String? ?? '').trim();
        final cGst = (entry['gst_number'] as String? ?? '').trim();
        final cNotes = (entry['notes'] as String? ?? '').trim();
        final prods = entry['products'] as List;

        final oldCustMeta = {
          'products': prods,
        };
        final metaJson = '[OLD_CUSTOMER_DATA:${jsonEncode(oldCustMeta)}]';
        final fullNotes = cNotes.isNotEmpty ? '$cNotes\n$metaJson' : metaJson;

        if (cPhone.isNotEmpty) {
          final existing = await supabase
              .from('customers')
              .select('id, notes')
              .eq('phone', cPhone)
              .maybeSingle();

          if (existing != null) {
            final existingId = existing['id'] as String;
            final existingNotes = existing['notes'] as String? ?? '';
            String updatedNotes = fullNotes;
            if (existingNotes.contains('[OLD_CUSTOMER_DATA:')) {
              try {
                final sIdx = existingNotes.indexOf('[OLD_CUSTOMER_DATA:') + '[OLD_CUSTOMER_DATA:'.length;
                final eIdx = existingNotes.indexOf(']', sIdx);
                if (eIdx > sIdx) {
                  final prevDecoded = jsonDecode(existingNotes.substring(sIdx, eIdx)) as Map<String, dynamic>;
                  final prevProds = List<Map<String, dynamic>>.from(prevDecoded['products'] as List? ?? []);
                  for (final newP in prods) {
                    final idx = prevProds.indexWhere((p) => (p['name'] as String? ?? '').toLowerCase() == (newP['name'] as String? ?? '').toLowerCase());
                    if (idx >= 0) {
                      final prevItems = List<String>.from(prevProds[idx]['items'] as List? ?? []);
                      for (final it in (newP['items'] as List? ?? [])) {
                        if (!prevItems.contains(it.toString())) prevItems.add(it.toString());
                      }
                      prevProds[idx]['items'] = prevItems;
                    } else {
                      prevProds.add(Map<String, dynamic>.from(newP as Map));
                    }
                  }
                  final mergedMeta = '[OLD_CUSTOMER_DATA:${jsonEncode({'products': prevProds})}]';
                  final prefixNotes = existingNotes.substring(0, existingNotes.indexOf('[OLD_CUSTOMER_DATA:')).trim();
                  updatedNotes = prefixNotes.isNotEmpty ? '$prefixNotes\n$mergedMeta' : mergedMeta;
                }
              } catch (_) {}
            }
            await supabase.from('customers').update({
              'notes': updatedNotes,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', existingId);
            importedCount++;
            continue;
          }
        }

        final insertData = <String, dynamic>{
          'customer_name': cName,
          'company_name': cName,
          if (cContact.isNotEmpty) 'contact_person': cContact,
          'phone': cPhone,
          if (cEmail.isNotEmpty) 'email': cEmail,
          'address': cAddress,
          if (cGst.isNotEmpty) 'gst_number': cGst,
          'notes': fullNotes,
          'created_by': profile?.id ?? 'admin',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        await supabase.from('customers').insert(insertData);
        importedCount++;
      }

      ref.invalidate(customersNotifierProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Successfully imported $importedCount Old Customers from Excel!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing Excel: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingExcel = false);
    }
  }


  void _addNewProduct() {
    setState(() {
      _products.add(
        _ProductItemEntry(
          nameController: TextEditingController(),
          itemControllers: [
            TextEditingController(),
          ],
        ),
      );
    });
  }

  void _removeProduct(int index) {
    if (_products.length <= 1) return;
    setState(() {
      final removed = _products.removeAt(index);
      removed.dispose();
    });
  }

  void _addItemToProduct(int productIndex) {
    setState(() {
      _products[productIndex].itemControllers.add(TextEditingController());
    });
  }

  void _removeItemFromProduct(int productIndex, int itemIndex) {
    setState(() {
      final removed = _products[productIndex].itemControllers.removeAt(itemIndex);
      removed.dispose();
    });
  }

  Future<void> _loadCatalogAndInventory() async {
    try {
      final supabase = ref.read(supabaseClientProvider);

      // 1. Load active sell products
      final prodResponse = await supabase
          .from('products')
          .select('id, name, category')
          .eq('is_active', true)
          .order('name');
      final names = <String>[];
      final prods = <Map<String, dynamic>>[];
      for (final r in (prodResponse as List? ?? [])) {
        final n = (r['name'] as String?)?.trim();
        if (n != null && n.isNotEmpty && !names.contains(n)) {
          names.add(n);
          prods.add({
            'id': r['id']?.toString() ?? '',
            'name': n,
            'category': (r['category'] as String?) ?? 'Sell Product',
          });
        }
      }

      // 2. Load inventory items
      final invResponse = await supabase
          .from('inventory_items')
          .select('id, item_name, hsn_sac, uom')
          .order('item_name');
      final invNames = <String>[];
      final invs = <Map<String, dynamic>>[];
      for (final r in (invResponse as List? ?? [])) {
        final n = (r['item_name'] as String?)?.trim();
        if (n != null && n.isNotEmpty && !invNames.contains(n)) {
          invNames.add(n);
          invs.add({
            'id': r['id']?.toString() ?? '',
            'name': n,
            'hsn_sac': r['hsn_sac'] as String?,
            'uom': r['uom'] as String?,
          });
        }
      }

      if (mounted) {
        setState(() {
          _catalogProducts = prods;
          _catalogProductNames = names;
          _inventoryItems = invs;
          _inventoryItemNames = invNames;
        });
      }
    } catch (_) {}
  }

  void _openProductPicker(int productIndex) {
    if (_catalogProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading sell products list, please wait...')),
      );
      return;
    }

    final productEntry = _products[productIndex];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _catalogProducts.where((p) {
              final q = searchQuery.toLowerCase();
              final name = (p['name'] as String).toLowerCase();
              final cat = (p['category'] as String).toLowerCase();
              return name.contains(q) || cat.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6D28D9).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF6D28D9), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Sell Product',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  '${filtered.length} products available',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search sell products by name or category...',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF6D28D9)),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setModalState(() => searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() => searchQuery = val);
                      },
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off, size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(
                                  'No sell products match "$searchQuery"',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                            itemBuilder: (context, idx) {
                              final p = filtered[idx];
                              final isSelected = productEntry.nameController.text.trim().toLowerCase() ==
                                  (p['name'] as String).trim().toLowerCase();

                              return ListTile(
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF6D28D9).withOpacity(0.15)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    size: 20,
                                    color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF64748B),
                                  ),
                                ),
                                title: Text(
                                  p['name'] as String,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14,
                                    color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF1E293B),
                                  ),
                                ),
                                subtitle: Text(
                                  p['category'] as String,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: Color(0xFF6D28D9), size: 20)
                                    : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                onTap: () {
                                  setState(() {
                                    productEntry.nameController.text = p['name'] as String;
                                  });
                                  Navigator.pop(ctx);
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

  void _openInventoryItemPicker(int productIndex, int itemIndex) {
    if (_inventoryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading inventory items, please wait...')),
      );
      return;
    }

    final productEntry = _products[productIndex];
    final itemCtrl = productEntry.itemControllers[itemIndex];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _inventoryItems.where((inv) {
              final q = searchQuery.toLowerCase();
              final name = (inv['name'] as String).toLowerCase();
              final hsn = (inv['hsn_sac'] as String? ?? '').toLowerCase();
              return name.contains(q) || hsn.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.precision_manufacturing_outlined, color: Color(0xFF059669), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Item from Inventory',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  '${filtered.length} inventory items available',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search inventory items by name or HSN...',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF059669)),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setModalState(() => searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() => searchQuery = val);
                      },
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off, size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(
                                  'No inventory items match "$searchQuery"',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                            itemBuilder: (context, idx) {
                              final item = filtered[idx];
                              final isSelected = itemCtrl.text.trim().toLowerCase() ==
                                  (item['name'] as String).trim().toLowerCase();

                              return ListTile(
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF059669).withOpacity(0.15)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.build_outlined,
                                    size: 20,
                                    color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B),
                                  ),
                                ),
                                title: Text(
                                  item['name'] as String,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14,
                                    color: isSelected ? const Color(0xFF059669) : const Color(0xFF1E293B),
                                  ),
                                ),
                                subtitle: Text(
                                  'HSN: ${item['hsn_sac'] ?? "—"} • UOM: ${item['uom'] ?? "NOS"}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: Color(0xFF059669), size: 20)
                                    : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                onTap: () {
                                  setState(() {
                                    itemCtrl.text = item['name'] as String;
                                  });
                                  Navigator.pop(ctx);
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
  void dispose() {
    _companyController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _notesController.dispose();
    for (final p in _products) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate products and items strictly
    bool hasValidProduct = false;
    for (final p in _products) {
      final pName = p.nameController.text.trim();
      if (pName.isNotEmpty) {
        if (_catalogProductNames.isNotEmpty &&
            !_catalogProductNames.any((n) => n.trim().toLowerCase() == pName.toLowerCase())) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$pName" is not in the Sell Products list. Please select from the list.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }

        for (final it in p.itemControllers) {
          final itName = it.text.trim();
          if (itName.isNotEmpty &&
              _inventoryItemNames.isNotEmpty &&
              !_inventoryItemNames.any((n) => n.trim().toLowerCase() == itName.toLowerCase())) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"$itName" is not in the Inventory. Please select from the inventory list.'),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
        }

        hasValidProduct = true;
      }
    }

    if (!hasValidProduct) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one Product from the Sell Products list.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final supabase = ref.read(supabaseClientProvider);
    final profile = ref.read(currentProfileProvider);

    try {
      final productsPayload = <Map<String, dynamic>>[];
      for (final p in _products) {
        final pName = p.nameController.text.trim();
        if (pName.isNotEmpty) {
          final itemsList = p.itemControllers
              .map((c) => c.text.trim())
              .where((txt) => txt.isNotEmpty)
              .toList();
          productsPayload.add({
            'name': pName,
            'items': itemsList,
          });
        }
      }

      final oldCustomerData = {
        'products': productsPayload,
      };

      final metadataJson = '[OLD_CUSTOMER_DATA:${jsonEncode(oldCustomerData)}]';
      final rawNotes = _notesController.text.trim();
      final fullNotes = rawNotes.isNotEmpty ? '$rawNotes\n$metadataJson' : metadataJson;

      final cleanName = _companyController.text.trim();
      final cleanContact = _contactPersonController.text.trim();
      final cleanPhone = _phoneController.text.trim();
      final cleanEmail = _emailController.text.trim();
      final cleanAddress = _addressController.text.trim();
      final cleanGst = _gstController.text.trim().toUpperCase();

      final insertData = <String, dynamic>{
        'customer_name': cleanName,
        'company_name': cleanName,
        if (cleanContact.isNotEmpty) 'contact_person': cleanContact,
        'phone': cleanPhone,
        if (cleanEmail.isNotEmpty) 'email': cleanEmail,
        'address': cleanAddress,
        if (cleanGst.isNotEmpty) 'gst_number': cleanGst,
        'notes': fullNotes,
        'created_by': profile?.id ?? 'admin',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('customers').insert(insertData);

      // Invalidate customer providers so the customer immediately appears in Customer List & Complaints
      ref.invalidate(customersNotifierProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Old Customer added successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding customer: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final isAdmin = profile?.primaryRole == UserRole.admin ||
        profile?.primaryRole == UserRole.manager ||
        (profile?.roles.contains(UserRole.admin) ?? false) ||
        (profile?.roles.contains(UserRole.manager) ?? false);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Old Customers')),
        body: const Center(
          child: Text(
            'Access Restricted: Only Admins can add old customers.',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Add Old Customers',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Export Old Customers (Excel)',
            onPressed: _isProcessingExcel ? null : _exportOldCustomers,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_outlined, color: Colors.white),
            tooltip: 'Import from Excel',
            onPressed: _isProcessingExcel ? null : _importFromExcel,
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined, color: Colors.white),
            tooltip: 'Download Excel Template',
            onPressed: _downloadTemplate,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info banner explaining the old customer behavior
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Old Customer Entry (Admin Only)',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '• Deal won\'t show in CRM deals screen.\n'
                              '• Name will appear in Customer list.\n'
                              '• Customer and respective product name will show in Complaints booking.\n'
                              '• Customer can login to app using mobile number & see their product on their dashboard.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFF1E3A8A),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Excel Quick Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.table_chart_outlined, color: Color(0xFF059669), size: 18),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Excel Bulk Management',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            icon: const Icon(Icons.download_outlined, size: 16, color: Color(0xFF6366F1)),
                            label: const Text('Template', style: TextStyle(fontSize: 12, color: Color(0xFF6366F1))),
                            onPressed: _downloadTemplate,
                          ),
                        ],
                      ),
                      if (_isProcessingExcel) ...[
                        const SizedBox(height: 10),
                        const LinearProgressIndicator(),
                      ] else ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF10B981)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.upload_file, size: 18, color: Color(0xFF059669)),
                                label: const Text(
                                  'Import Excel',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                                ),
                                onPressed: _importFromExcel,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF3B82F6)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF2563EB)),
                                label: const Text(
                                  'Export All',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                ),
                                onPressed: _exportOldCustomers,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Customer Details Card
                _buildSectionCard(
                  title: 'Customer Details',
                  icon: Icons.person_outline,
                  children: [
                    TextFormField(
                      controller: _companyController,
                      decoration: _inputDecoration('Customer / Company Name *', Icons.business),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter customer or company name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactPersonController,
                      decoration: _inputDecoration('Contact Person (Optional)', Icons.person),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: _inputDecoration('Mobile Number (For App Login & Complaints) *', Icons.phone),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter mobile number';
                        if (v.trim().length != 10) return 'Please enter a valid 10-digit mobile number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration('Email (Optional)', Icons.email_outlined),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: _inputDecoration('Installation / Site Address *', Icons.location_on_outlined),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter site/installation address' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _gstController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration('GSTIN (Optional)', Icons.receipt_long_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Product & Items Sections
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Purchased Products & Components',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addNewProduct,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6D28D9),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...List.generate(_products.length, (pIdx) => _buildProductCard(pIdx)),

                const SizedBox(height: 16),

                // Additional Notes
                _buildSectionCard(
                  title: 'Additional Notes (Optional)',
                  icon: Icons.notes,
                  children: [
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: _inputDecoration('Enter any historical installation or warranty notes...', null),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D28D9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save Old Customer',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(int productIndex) {
    final productEntry = _products[productIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D28D9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF6D28D9), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Product #${productIndex + 1}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              if (_products.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  tooltip: 'Remove Product',
                  onPressed: () => _removeProduct(productIndex),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Product Name (Strictly from Sell Products list & Searchable)
          TextFormField(
            controller: productEntry.nameController,
            readOnly: true,
            onTap: () => _openProductPicker(productIndex),
            decoration: _inputDecoration(
              'Product Name (Strictly from Sell Products) *',
              Icons.shopping_bag_outlined,
            ).copyWith(
              hintText: 'Tap to select Sell Product...',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (productEntry.nameController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                      tooltip: 'Clear',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          productEntry.nameController.clear();
                        });
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF6D28D9)),
                    tooltip: 'Search Sell Products',
                    onPressed: () => _openProductPicker(productIndex),
                  ),
                ],
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please select a Product from Sell Products list';
              }
              final match = _catalogProductNames.any((n) => n.trim().toLowerCase() == v.trim().toLowerCase());
              if (!match && _catalogProductNames.isNotEmpty) {
                return 'Product must be chosen strictly from Sell Products list';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Items / Components under this product (Strictly from Inventory)
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Items / Components (From Inventory):',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _addItemToProduct(productIndex);
                  final newIndex = productEntry.itemControllers.length - 1;
                  _openInventoryItemPicker(productIndex, newIndex);
                },
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Item', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6D28D9),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          ...List.generate(productEntry.itemControllers.length, (itemIndex) {
            final itemCtrl = productEntry.itemControllers[itemIndex];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    alignment: Alignment.center,
                    child: Text(
                      '${itemIndex + 1}.',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextFormField(
                      controller: itemCtrl,
                      readOnly: true,
                      onTap: () => _openInventoryItemPicker(productIndex, itemIndex),
                      decoration: InputDecoration(
                        hintText: 'Tap to select item from Inventory *',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(Icons.precision_manufacturing_outlined, size: 18, color: Color(0xFF059669)),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (itemCtrl.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                tooltip: 'Clear',
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(() {
                                    itemCtrl.clear();
                                  });
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.search, size: 18, color: Color(0xFF059669)),
                              tooltip: 'Search Inventory',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _openInventoryItemPicker(productIndex, itemIndex),
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF059669)),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please select an item from Inventory';
                        }
                        final match = _inventoryItemNames.any((n) => n.trim().toLowerCase() == v.trim().toLowerCase());
                        if (!match && _inventoryItemNames.isNotEmpty) {
                          return 'Must be strictly from Inventory';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (productEntry.itemControllers.length > 1) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                      tooltip: 'Remove',
                      onPressed: () => _removeItemFromProduct(productIndex, itemIndex),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF1E293B), size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 20, color: const Color(0xFF6D28D9)) : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
      ),
    );
  }
}
