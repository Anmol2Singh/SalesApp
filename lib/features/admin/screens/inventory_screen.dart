import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/product.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/providers/supabase_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/manage_boq_items_provider.dart';
import 'product_catalog_screen.dart';
import '../../../core/services/excel_service.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _itemSearchController = TextEditingController();
  final TextEditingController _productSearchController = TextEditingController();

  String _itemSearchQuery = '';
  String _productSearchQuery = '';
  bool _itemsSortAscending = true;
  final Set<String> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _itemSearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final isProductsTab = _tabController.index == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Inventory & Products',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: isProductsTab
            ? [
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  tooltip: 'Export Products',
                  onPressed: () {
                    final products = ref.read(productsProvider).valueOrNull ?? [];
                    if (products.isNotEmpty) {
                      ExcelService.exportProducts(context, products);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No products to export.')),
                      );
                    }
                  },
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
                  label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: () => _showAddProductDialog(context),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  tooltip: 'Import Excel',
                  onPressed: () => _importExcel(context, ref),
                ),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  tooltip: 'Export Excel',
                  onPressed: () {
                    final items = inventoryAsync.valueOrNull ?? [];
                    if (items.isNotEmpty) {
                      final products = ref.read(productsProvider).valueOrNull ?? [];
                      ExcelService.exportInventoryItems(context, items, products: products);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No items to export.')),
                      );
                    }
                  },
                ),
              ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(
              icon: Icon(Icons.sell_outlined, size: 20),
              text: 'Sell Products',
            ),
            Tab(
              icon: Icon(Icons.inventory_2_outlined, size: 20),
              text: 'Items',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSellProductsTab(),
          _buildItemsTab(inventoryAsync),
        ],
      ),
      floatingActionButton: isProductsTab
          ? FloatingActionButton.extended(
              onPressed: () => _showAddProductDialog(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Product',
                style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: () => _showAddItemDialog(context, ref),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Item',
                style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold),
              ),
            ),
    );
  }

  // ==========================================
  // TAB 1: SELL PRODUCTS
  // ==========================================
  Widget _buildSellProductsTab() {
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      data: (products) {
        final filteredProducts = products.where((p) {
          if (_productSearchQuery.isEmpty) return true;
          final q = _productSearchQuery.toLowerCase();
          final nameMatch = p.name.toLowerCase().contains(q);
          final catMatch = (p.category ?? '').toLowerCase().contains(q);
          return nameMatch || catMatch;
        }).toList();

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: Colors.white,
              child: TextField(
                controller: _productSearchController,
                decoration: InputDecoration(
                  hintText: 'Search products by name or category...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  suffixIcon: _productSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _productSearchController.clear();
                            setState(() => _productSearchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (val) => setState(() => _productSearchQuery = val.trim()),
              ),
            ),
            Expanded(
              child: filteredProducts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_outlined, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _productSearchQuery.isEmpty
                                ? 'No sellable products found.'
                                : 'No products matching "$_productSearchQuery"',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: () => _showAddProductDialog(context),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Add Product', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: filteredProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return _buildProductCard(product);
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error loading products: $e')),
    );
  }

  Widget _buildProductCard(Product product) {
    final capacities = product.baseSpecs.capacities;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
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
          // Header: Name, Category, Menu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.solar_power, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (product.category != null && product.category!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.category!,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: product.isActive ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: product.isActive ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.blueGrey),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showEditProductDialog(context, product);
                    } else if (val == 'delete') {
                      _confirmDeleteProduct(context, product);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Edit Name / Category'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Delete Product', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Capacities Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.straighten, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Capacities & Sizes (${capacities.length})',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => _showManageCapacityDialog(context, product),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.tune, size: 14, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'Manage Capacity',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (capacities.isEmpty)
                  Text(
                    'No capacities configured yet. Tap "Manage Capacity" to add size/capacity options.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey.shade500),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: capacities.map((cap) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          cap,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Items Treated as Products Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.link, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Items Treated as Products (${product.baseSpecs.linkedItems.length})',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => _showLinkItemsDialog(context, product),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 14, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'Add Items',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (product.baseSpecs.linkedItems.isEmpty)
                  Text(
                    'No items linked. Tap "Add Items" to treat inventory items as this product.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey.shade500),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: product.baseSpecs.linkedItems.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _removeLinkedItem(context, product, item),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: ITEMS (EXISTING INVENTORY)
  // ==========================================
  Widget _buildItemsTab(AsyncValue<List<dynamic>> inventoryAsync) {
    return inventoryAsync.when(
      data: (items) {
        final typedItems = List<InventoryItem>.from(items);
        final filteredItems = typedItems.where((item) {
          if (_itemSearchQuery.isEmpty) return true;
          final q = _itemSearchQuery.toLowerCase();
          final nameMatch = item.itemName.toLowerCase().contains(q);
          final hsnMatch = (item.hsnSac ?? '').toLowerCase().contains(q);
          return nameMatch || hsnMatch;
        }).toList();

        filteredItems.sort((a, b) => _itemsSortAscending
            ? a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase())
            : b.itemName.toLowerCase().compareTo(a.itemName.toLowerCase()));

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _itemSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search items by name or HSN code...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: _itemSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _itemSearchController.clear();
                                  setState(() => _itemSearchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onChanged: (val) => setState(() => _itemSearchQuery = val.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Tooltip(
                      message: _itemsSortAscending ? 'Sort: A-Z (Click for Z-A)' : 'Sort: Z-A (Click for A-Z)',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _itemsSortAscending = !_itemsSortAscending),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _itemsSortAscending ? Icons.arrow_downward : Icons.arrow_upward,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _itemsSortAscending ? 'A-Z' : 'Z-A',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedItemIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFEFF6FF),
                child: Row(
                  children: [
                    Text(
                      '${_selectedItemIds.length} selected',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () {
                        setState(() {
                          if (_selectedItemIds.length == filteredItems.length) {
                            _selectedItemIds.clear();
                          } else {
                            _selectedItemIds.addAll(filteredItems.map((e) => e.id));
                          }
                        });
                      },
                      child: Text(
                        _selectedItemIds.length == filteredItems.length ? 'Deselect All' : 'Select All',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.delete, size: 14, color: Colors.white),
                      label: Text('Delete (${_selectedItemIds.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _confirmBulkDelete(context, ref, typedItems),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _itemSearchQuery.isEmpty
                                ? 'No inventory items found.'
                                : 'No items matching "$_itemSearchQuery"',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: () => _showAddItemDialog(context, ref),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Add Item', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = _selectedItemIds.contains(item.id);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200, width: isSelected ? 1.5 : 1.0),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: isSelected,
                                activeColor: AppColors.primary,
                                visualDensity: VisualDensity.compact,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedItemIds.add(item.id);
                                    } else {
                                      _selectedItemIds.remove(item.id);
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 4),
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
                                        _buildBadge(
                                          'Warranty: ${item.warrantyMonths}m',
                                          color: const Color(0xFFFFFBEB),
                                          textColor: const Color(0xFFB45309),
                                        ),
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
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  void _confirmBulkDelete(BuildContext context, WidgetRef ref, List<InventoryItem> allItems) {
    if (_selectedItemIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${_selectedItemIds.length} Items'),
        content: Text('Are you sure you want to delete ${_selectedItemIds.length} selected items? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final supabase = ref.read(supabaseClientProvider);
                final idsToDelete = _selectedItemIds.toList();
                final deletedNames = allItems
                    .where((it) => _selectedItemIds.contains(it.id))
                    .map((it) => it.itemName.toLowerCase())
                    .toSet();

                // 1. Delete from inventory_items
                await supabase.from('inventory_items').delete().inFilter('id', idsToDelete);

                // 2. Clean up from linked_items in products
                final allProducts = ref.read(productsProvider).valueOrNull ?? [];
                for (final p in allProducts) {
                  final updated = List<String>.from(p.baseSpecs.linkedItems)
                    ..removeWhere((name) => deletedNames.contains(name.toLowerCase()));
                  if (updated.length != p.baseSpecs.linkedItems.length) {
                    final rawSpecs = Map<String, dynamic>.from(p.baseSpecs.raw);
                    rawSpecs['linked_items'] = updated;
                    await supabase.from('products').update({
                      'base_specs': rawSpecs,
                      'updated_at': DateTime.now().toIso8601String(),
                    }).eq('id', p.id);
                  }
                }

                setState(() {
                  _selectedItemIds.clear();
                });

                ref.invalidate(inventoryProvider);
                ref.invalidate(productsProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deleted ${idsToDelete.length} items successfully.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting items: $e'), backgroundColor: AppColors.error),
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

  // ==========================================
  // PRODUCT ACTIONS & DIALOGS
  // ==========================================
  void _showAddProductDialog(BuildContext context) {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_shopping_cart, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Add New Product', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    hintText: 'e.g. Commercial Heat Pump',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    hintText: 'e.g. HVAC, Access Control, SWH',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => isSaving = true);
                      try {
                        final supabase = ref.read(supabaseClientProvider);
                        await supabase.from('products').insert({
                          'name': nameController.text.trim(),
                          'category': categoryController.text.trim(),
                          'base_specs': {
                            'quotation_fields': [],
                            'boq_required_fields': [],
                            'capacities': [],
                          },
                          'is_active': true,
                        });
                        ref.invalidate(productsProvider);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Product added successfully!'), backgroundColor: AppColors.success),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error adding product: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setModalState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, Product product) {
    final nameController = TextEditingController(text: product.name);
    final categoryController = TextEditingController(text: product.category ?? '');
    bool isActive = product.isActive;
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Product', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Product Name *', prefixIcon: Icon(Icons.label_outline)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category *', prefixIcon: Icon(Icons.category_outlined)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Product is Active', style: TextStyle(fontFamily: 'Inter', fontSize: 14)),
                  value: isActive,
                  onChanged: (val) => setModalState(() => isActive = val),
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
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => isSaving = true);
                      try {
                        final supabase = ref.read(supabaseClientProvider);
                        await supabase.from('products').update({
                          'name': nameController.text.trim(),
                          'category': categoryController.text.trim(),
                          'is_active': isActive,
                          'updated_at': DateTime.now().toIso8601String(),
                        }).eq('id', product.id);

                        ref.invalidate(productsProvider);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Product updated successfully'), backgroundColor: AppColors.success),
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
        ),
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final supabase = ref.read(supabaseClientProvider);
                await supabase.from('products').update({
                  'deleted_at': DateTime.now().toIso8601String(),
                }).eq('id', product.id);
                ref.invalidate(productsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product removed successfully'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting product: $e'), backgroundColor: AppColors.error),
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

  // ==========================================
  // MANAGE CAPACITY DIALOG
  // ==========================================
  void _showManageCapacityDialog(BuildContext context, Product product) {
    final initialCapacities = List<String>.from(product.baseSpecs.capacities);
    final currentCapacities = List<String>.from(product.baseSpecs.capacities);
    final Map<String, String> renamedCapacities = {};
    final Set<String> deletedCapacities = {};
    final capacityInputController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.tune, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Capacities for ${product.name}',
                  style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Define capacities or ratings (e.g. 500 LPD, 1000 LPD, 5 kW, 10 kW).\nEach capacity is automatically linked as an item in the Items tab for price management.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: capacityInputController,
                          decoration: InputDecoration(
                            hintText: 'e.g. 500 LPD or 10 kW',
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onSubmitted: (val) {
                            final trimmed = val.trim();
                            if (trimmed.isNotEmpty && !currentCapacities.contains(trimmed)) {
                              setModalState(() {
                                currentCapacities.add(trimmed);
                                capacityInputController.clear();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final trimmed = capacityInputController.text.trim();
                          if (trimmed.isNotEmpty && !currentCapacities.contains(trimmed)) {
                            setModalState(() {
                              currentCapacities.add(trimmed);
                              capacityInputController.clear();
                            });
                          }
                        },
                        child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Active Capacities:',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  if (currentCapacities.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Text(
                          'No capacities added yet.',
                          style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: currentCapacities.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final cap = currentCapacities[idx];
                          return ListTile(
                            dense: true,
                            title: Text(cap, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              'Item Name: ${product.name} - $cap',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textSecondary),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                  tooltip: 'Edit Capacity',
                                  onPressed: () async {
                                    final editController = TextEditingController(text: cap);
                                    final updated = await showDialog<String>(
                                      context: ctx,
                                      builder: (editCtx) => AlertDialog(
                                        title: const Text('Edit Capacity'),
                                        content: TextField(
                                          controller: editController,
                                          autofocus: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Capacity / Rating',
                                            hintText: 'e.g. 500 LPD',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(editCtx),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              final text = editController.text.trim();
                                              if (text.isNotEmpty) Navigator.pop(editCtx, text);
                                            },
                                            child: const Text('Update'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (updated != null && updated.isNotEmpty && updated != cap) {
                                      setModalState(() {
                                        if (initialCapacities.contains(cap)) {
                                          renamedCapacities[cap] = updated;
                                        }
                                        currentCapacities[idx] = updated;
                                      });
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                  tooltip: 'Delete Capacity & remove from Items',
                                  onPressed: () {
                                    setModalState(() {
                                      final removed = currentCapacities.removeAt(idx);
                                      if (initialCapacities.contains(removed)) {
                                        deletedCapacities.add(removed);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      try {
                        final supabase = ref.read(supabaseClientProvider);

                        // 1. Process deletions in inventory_items
                        for (final delCap in deletedCapacities) {
                          final itemName = '${product.name} - $delCap';
                          await supabase.from('inventory_items').delete().eq('item_name', itemName);
                        }

                        // 2. Process renames in inventory_items
                        for (final entry in renamedCapacities.entries) {
                          final oldName = '${product.name} - ${entry.key}';
                          final newName = '${product.name} - ${entry.value}';
                          await supabase.from('inventory_items').update({'item_name': newName}).eq('item_name', oldName);
                        }

                        // 3. Process new additions / ensures in inventory_items
                        for (final cap in currentCapacities) {
                          final itemName = '${product.name} - $cap';
                          final existing = await supabase.from('inventory_items').select('id').eq('item_name', itemName).maybeSingle();
                          if (existing == null) {
                            await supabase.from('inventory_items').insert({
                              'item_name': itemName,
                              'price': 0.0,
                              'uom': 'NOS',
                              'created_at': DateTime.now().toIso8601String(),
                            });
                          }
                        }

                        // 4. Update product base_specs
                        final rawSpecs = Map<String, dynamic>.from(product.baseSpecs.raw);
                        rawSpecs['capacities'] = currentCapacities;

                        await supabase.from('products').update({
                          'base_specs': rawSpecs,
                          'updated_at': DateTime.now().toIso8601String(),
                        }).eq('id', product.id);

                        ref.invalidate(productsProvider);
                        ref.invalidate(inventoryProvider);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Capacities & matching Items synchronized successfully!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error updating capacities: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setModalState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Capacities', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // LINK ITEMS TO PRODUCT DIALOG (TREAT AS PRODUCT)
  // ==========================================
  void _showLinkItemsDialog(BuildContext context, Product product) async {
    // 1. Collect all capacities across ALL products to exclude capacity items
    final allProducts = ref.read(productsProvider).valueOrNull ?? [];
    final excludedNames = <String>{};
    for (final p in allProducts) {
      for (final cap in p.baseSpecs.capacities) {
        final c = cap.trim().toLowerCase();
        excludedNames.add(c);
        excludedNames.add('${p.name.trim().toLowerCase()} - $c');
        excludedNames.add('${p.name.trim().toLowerCase()} -$c');
        excludedNames.add('${p.name.trim().toLowerCase()}-$c');
      }
      // Exclude items already added to any other sell product
      if (p.id != product.id) {
        for (final li in p.baseSpecs.linkedItems) {
          excludedNames.add(li.trim().toLowerCase());
        }
      }
    }

    // 2. Fetch inventory items
    final inventoryAsync = ref.read(inventoryProvider);
    List<InventoryItem> allItems = [];
    if (inventoryAsync.hasValue) {
      allItems = inventoryAsync.value!;
    } else {
      allItems = await ref.read(inventoryProvider.future);
    }

    // 3. Filter out items created using capacity of any product
    final availableItems = allItems.where((item) {
      final nameLower = item.itemName.trim().toLowerCase();
      if (excludedNames.contains(nameLower)) return false;
      for (final p in allProducts) {
        final prefix = '${p.name.trim().toLowerCase()} - ';
        if (nameLower.startsWith(prefix)) {
          final remainder = nameLower.substring(prefix.length).trim();
          if (p.baseSpecs.capacities.any((c) => c.trim().toLowerCase() == remainder)) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    availableItems.sort((a, b) => a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()));

    // 4. Current selected items
    final selectedItems = Set<String>.from(product.baseSpecs.linkedItems);
    String searchQuery = '';
    bool isSaving = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtered = availableItems.where((item) {
            if (searchQuery.isEmpty) return true;
            return item.itemName.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.link, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Link Items to ${product.name}',
                        style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select items treated as this product (${selectedItems.length} selected)',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 500,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (val) => setModalState(() => searchQuery = val.trim()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Items (${filtered.length})',
                        style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (filtered.isNotEmpty)
                        Row(
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () {
                                setModalState(() {
                                  for (final it in filtered) {
                                    selectedItems.add(it.itemName);
                                  }
                                });
                              },
                              child: const Text('Select All', style: TextStyle(fontSize: 12)),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              onPressed: () {
                                setModalState(() {
                                  for (final it in filtered) {
                                    selectedItems.remove(it.itemName);
                                  }
                                });
                              },
                              child: const Text('Clear', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching items found.',
                              style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final item = filtered[idx];
                              final isSelected = selectedItems.contains(item.itemName);
                              return CheckboxListTile(
                                dense: true,
                                value: isSelected,
                                title: Text(
                                  item.itemName,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: item.price > 0
                                    ? Text(
                                        '₹${item.price.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      )
                                    : null,
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      selectedItems.add(item.itemName);
                                    } else {
                                      selectedItems.remove(item.itemName);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: isSaving
                    ? null
                    : () async {
                        setModalState(() => isSaving = true);
                        try {
                          final supabase = ref.read(supabaseClientProvider);
                          final rawSpecs = Map<String, dynamic>.from(product.baseSpecs.raw);
                          rawSpecs['linked_items'] = selectedItems.toList();

                          await supabase.from('products').update({
                            'base_specs': rawSpecs,
                            'updated_at': DateTime.now().toIso8601String(),
                          }).eq('id', product.id);

                          ref.invalidate(productsProvider);

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Linked items updated successfully!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error linking items: $e'), backgroundColor: AppColors.error),
                            );
                          }
                        } finally {
                          if (ctx.mounted) setModalState(() => isSaving = false);
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Items', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _removeLinkedItem(BuildContext context, Product product, String itemName) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final rawSpecs = Map<String, dynamic>.from(product.baseSpecs.raw);
      final list = List<String>.from(product.baseSpecs.linkedItems)..remove(itemName);
      rawSpecs['linked_items'] = list;

      await supabase.from('products').update({
        'base_specs': rawSpecs,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', product.id);

      ref.invalidate(productsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "$itemName" from ${product.name}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing item: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ==========================================
  // SUB-SYSTEMS MODAL (BOQ ITEMS LINKED TO PRODUCT)
  // ==========================================
  void _showSubSystemsModal(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_tree_outlined, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sub-Systems for ${product.name}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            'Accessories & items customer purchases with this product',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Sub-Systems List
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final boqItemsAsync = ref.watch(productBoqItemsProvider(product.id));

                    return boqItemsAsync.when(
                      data: (items) {
                        if (items.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.format_list_bulleted, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No sub-systems configured for ${product.name}.',
                                  style: const TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tap "+ Add Sub-System" below to add from inventory.',
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final item = items[idx];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.itemName,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            _buildBadge('Unit: ${item.defaultUnit}'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                    tooltip: 'Remove Sub-System',
                                    onPressed: () async {
                                      try {
                                        final supabase = ref.read(supabaseClientProvider);
                                        await supabase.from('product_boq_items').delete().eq('id', item.id);
                                        ref.invalidate(productBoqItemsProvider(product.id));
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      error: (e, _) => Center(child: Text('Error loading sub-systems: $e')),
                    );
                  },
                ),
              ),

              // Bottom Add Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Add Sub-System from Inventory',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    onPressed: () => _showInventorySearchPicker(context, product.id),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInventorySearchPicker(BuildContext context, String productId) {
    final inventoryAsync = ref.read(inventoryProvider);
    final allItems = inventoryAsync.valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (pickerCtx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = allItems.where((item) {
              return item.itemName.toLowerCase().contains(searchQuery.toLowerCase());
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
                        'Select Item from Inventory',
                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(pickerCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search inventory items...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setPickerState(() => searchQuery = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              searchQuery.isEmpty ? 'No inventory items available.' : 'No items match "$searchQuery"',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final invItem = filtered[idx];
                              return ListTile(
                                title: Text(invItem.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('Unit: ${invItem.uom ?? "NOS"} | Price: ₹${invItem.price}'),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(pickerCtx);
                                    _promptAddBoqDetailsAndSave(
                                      context,
                                      productId,
                                      invItem.itemName,
                                      invItem.id,
                                      invItem.uom ?? 'NOS',
                                    );
                                  },
                                  child: const Text('Add', style: TextStyle(color: Colors.white)),
                                ),
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

  void _promptAddBoqDetailsAndSave(
    BuildContext context,
    String productId,
    String itemName,
    String inventoryItemId,
    String defaultUom,
  ) {
    final unitController = TextEditingController(text: defaultUom);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Configure "$itemName"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: unitController,
              decoration: const InputDecoration(labelText: 'Default Unit (e.g. NOS, MTR, SET)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final supabase = ref.read(supabaseClientProvider);
                await supabase.from('product_boq_items').insert({
                  'product_id': productId,
                  'item_name': itemName,
                  'inventory_item_id': inventoryItemId,
                  'default_unit': unitController.text.trim().isEmpty ? 'NOS' : unitController.text.trim(),
                });
                ref.invalidate(productBoqItemsProvider(productId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item added to product!'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding item: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Add to Product', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // INVENTORY ITEMS DIALOGS & ACTIONS
  // ==========================================
  void _showAddItemDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final hsnController = TextEditingController();
    final unitController = TextEditingController(text: 'NOS');
    final priceController = TextEditingController(text: '0');
    final warrantyController = TextEditingController(text: '12');
    final allProducts = ref.read(productsProvider).valueOrNull ?? [];
    String? selectedProductName;
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
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      value: selectedProductName,
                      decoration: const InputDecoration(
                        labelText: 'Under Product (Optional)',
                        prefixIcon: Icon(Icons.sell_outlined),
                        helperText: 'Select sell product if treated as product name',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None (Standard Item)', style: TextStyle(color: Colors.grey)),
                        ),
                        ...allProducts.map((p) => DropdownMenuItem<String?>(
                          value: p.name,
                          child: Text(p.name),
                        )),
                      ],
                      onChanged: (newVal) async {
                        if (newVal != null && newVal != selectedProductName) {
                          final confirmed = await showDialog<bool>(
                            context: ctx,
                            builder: (alertCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: AppColors.primary),
                                  SizedBox(width: 8),
                                  Text('Treat as Product?'),
                                ],
                              ),
                              content: const Text(
                                "it will be treated as product name, if it's just a side/extra item don't select this",
                                style: TextStyle(fontFamily: 'Inter', fontSize: 14),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(alertCtx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                  onPressed: () => Navigator.pop(alertCtx, true),
                                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            setModalState(() => selectedProductName = newVal);
                          } else {
                            setModalState(() {});
                          }
                        } else if (newVal == null) {
                          setModalState(() => selectedProductName = null);
                        }
                      },
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

                            // If Under Product is selected, link item to that product
                            if (selectedProductName != null) {
                              final matchedProd = allProducts.firstWhereOrNull((p) => p.name == selectedProductName);
                              if (matchedProd != null) {
                                final updatedLinked = List<String>.from(matchedProd.baseSpecs.linkedItems);
                                if (!updatedLinked.contains(name)) {
                                  updatedLinked.add(name);
                                  final rawSpecs = Map<String, dynamic>.from(matchedProd.baseSpecs.raw);
                                  rawSpecs['linked_items'] = updatedLinked;
                                  await supabase.from('products').update({
                                    'base_specs': rawSpecs,
                                    'updated_at': DateTime.now().toIso8601String(),
                                  }).eq('id', matchedProd.id);
                                  ref.invalidate(productsProvider);
                                }
                              }
                            }

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
    final allProducts = ref.read(productsProvider).valueOrNull ?? [];
    Product? initialProduct;
    for (final p in allProducts) {
      if (p.baseSpecs.linkedItems.contains(item.itemName)) {
        initialProduct = p;
        break;
      }
    }
    String? selectedProductName = initialProduct?.name;
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
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      value: selectedProductName,
                      decoration: const InputDecoration(
                        labelText: 'Under Product (Optional)',
                        prefixIcon: Icon(Icons.sell_outlined),
                        helperText: 'Select sell product if treated as product name',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None (Standard Item)', style: TextStyle(color: Colors.grey)),
                        ),
                        ...allProducts.map((p) => DropdownMenuItem<String?>(
                          value: p.name,
                          child: Text(p.name),
                        )),
                      ],
                      onChanged: (newVal) async {
                        if (newVal != null && newVal != selectedProductName) {
                          final confirmed = await showDialog<bool>(
                            context: ctx,
                            builder: (alertCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: AppColors.primary),
                                  SizedBox(width: 8),
                                  Text('Treat as Product?'),
                                ],
                              ),
                              content: const Text(
                                "it will be treated as product name, if it's just a side/extra item don't select this",
                                style: TextStyle(fontFamily: 'Inter', fontSize: 14),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(alertCtx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                  onPressed: () => Navigator.pop(alertCtx, true),
                                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            setModalState(() => selectedProductName = newVal);
                          } else {
                            setModalState(() {});
                          }
                        } else if (newVal == null) {
                          setModalState(() => selectedProductName = null);
                        }
                      },
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

                            // Update linked_items in products if changed or renamed
                            final oldName = item.itemName as String;
                            if (selectedProductName != initialProduct?.name || name != oldName) {
                              // 1. If old product existed, remove old name
                              if (initialProduct != null) {
                                final updatedOld = List<String>.from(initialProduct.baseSpecs.linkedItems)
                                  ..remove(oldName)
                                  ..remove(name);
                                final rawOld = Map<String, dynamic>.from(initialProduct.baseSpecs.raw);
                                rawOld['linked_items'] = updatedOld;
                                await supabase.from('products').update({
                                  'base_specs': rawOld,
                                  'updated_at': DateTime.now().toIso8601String(),
                                }).eq('id', initialProduct.id);
                              }
                              // 2. If new product selected, add name
                              if (selectedProductName != null) {
                                final newProd = allProducts.firstWhereOrNull((p) => p.name == selectedProductName);
                                if (newProd != null) {
                                  final updatedNew = List<String>.from(newProd.baseSpecs.linkedItems)
                                    ..remove(oldName);
                                  if (!updatedNew.contains(name)) updatedNew.add(name);
                                  final rawNew = Map<String, dynamic>.from(newProd.baseSpecs.raw);
                                  rawNew['linked_items'] = updatedNew;
                                  await supabase.from('products').update({
                                    'base_specs': rawNew,
                                    'updated_at': DateTime.now().toIso8601String(),
                                  }).eq('id', newProd.id);
                                }
                              }
                              ref.invalidate(productsProvider);
                            }

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

  Future<void> _importExcel(BuildContext context, WidgetRef ref) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (files.isEmpty || files.single.path == null) {
        return;
      }

      final file = File(files.single.path!);
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final supabase = ref.read(supabaseClientProvider);
      final existingItems = ref.read(inventoryProvider).valueOrNull ?? [];
      final existingNames = existingItems.map((e) => e.itemName.toLowerCase()).toSet();

      final existingProducts = ref.read(productsProvider).valueOrNull ?? [];
      final Map<String, Product> productByName = {};
      final Map<String, List<String>> productLinkedItems = {};
      final Map<String, Map<String, dynamic>> productRawSpecs = {};

      for (final p in existingProducts) {
        productByName[p.name.trim().toLowerCase()] = p;
        productLinkedItems[p.id] = List<String>.from(p.baseSpecs.linkedItems);
        productRawSpecs[p.id] = Map<String, dynamic>.from(p.baseSpecs.raw);
      }

      final Set<String> modifiedProductIds = {};
      int importedCount = 0;
      int skippedCount = 0;

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null) continue;

        int nameCol = 0;
        int underProductCol = -1;
        int hsnCol = 1;
        int unitCol = 2;
        int priceCol = 3;
        int warrantyCol = 4;

        bool isFirstRow = true;
        for (var row in sheet.rows) {
          if (isFirstRow) {
            isFirstRow = false;
            // Parse headers to locate columns dynamically if headers exist
            for (int i = 0; i < row.length; i++) {
              final header = row[i]?.value?.toString().toLowerCase().trim() ?? '';
              if (header.contains('under product') || header.contains('product category')) {
                underProductCol = i;
              } else if (header.contains('item') || header.contains('name')) {
                nameCol = i;
              } else if (header.contains('hsn') || header.contains('sac')) {
                hsnCol = i;
              } else if (header.contains('unit') || header.contains('uom')) {
                unitCol = i;
              } else if (header.contains('price') || header.contains('cost') || header.contains('₹')) {
                priceCol = i;
              } else if (header.contains('warranty')) {
                warrantyCol = i;
              }
            }
            continue;
          }

          if (row.isEmpty) continue;

          final itemNameCell = row.length > nameCol ? row[nameCol]?.value : null;
          final underProductCell = underProductCol >= 0 && row.length > underProductCol ? row[underProductCol]?.value : null;
          final hsnCell = row.length > hsnCol ? row[hsnCol]?.value : null;
          final unitCell = row.length > unitCol ? row[unitCol]?.value : null;
          final priceCell = row.length > priceCol ? row[priceCol]?.value : null;
          final warrantyCell = row.length > warrantyCol ? row[warrantyCol]?.value : null;

          final itemName = itemNameCell?.toString().trim();
          if (itemName == null || itemName.isEmpty) continue;

          final underProductName = underProductCell?.toString().trim();
          final hasUnderProduct = underProductName != null && underProductName.isNotEmpty && underProductName != '-';

          // If under product category is specified, check if it matches a sell product
          if (hasUnderProduct) {
            final matchedProd = productByName[underProductName.toLowerCase()];
            if (matchedProd != null) {
              final list = productLinkedItems[matchedProd.id]!;
              if (!list.any((x) => x.toLowerCase() == itemName.toLowerCase())) {
                list.add(itemName);
                modifiedProductIds.add(matchedProd.id);
              }
            }
          }

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
              price = double.tryParse(priceCell.toString().replaceAll('₹', '').replaceAll(',', '').trim()) ?? 0.0;
            }
          }

          int warranty = 12;
          if (warrantyCell != null) {
            if (warrantyCell is IntCellValue) {
              warranty = warrantyCell.value;
            } else if (warrantyCell is DoubleCellValue) {
              warranty = warrantyCell.value.toInt();
            } else {
              warranty = int.tryParse(warrantyCell.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 12;
            }
          }

          await supabase.from('inventory_items').insert({
            'item_name': itemName,
            'hsn_sac': hsn,
            'uom': unit,
            'price': price,
            'warranty_months': warranty,
          });

          existingNames.add(itemName.toLowerCase());
          importedCount++;
        }
      }

      // Persist any updated product linked_items
      for (final prodId in modifiedProductIds) {
        final raw = productRawSpecs[prodId] ?? {};
        raw['linked_items'] = productLinkedItems[prodId] ?? [];
        await supabase.from('products').update({
          'base_specs': raw,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', prodId);
      }

      if (modifiedProductIds.isNotEmpty) {
        ref.invalidate(productsProvider);
      }

      if (importedCount > 0) {
        ref.invalidate(inventoryProvider);
      }

      if (context.mounted) {
        final linkedMsg = modifiedProductIds.isNotEmpty ? ' Linked to ${modifiedProductIds.length} products.' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $importedCount items. Skipped $skippedCount duplicates.$linkedMsg'),
            backgroundColor: (importedCount > 0 || modifiedProductIds.isNotEmpty) ? AppColors.success : Colors.orange,
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
