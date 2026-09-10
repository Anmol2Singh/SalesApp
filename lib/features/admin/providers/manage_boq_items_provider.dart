import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

class ProductBoqItem {
  final String id;
  final String productId;
  final String itemName;
  final String? inventoryItemId;
  final String? defaultSize;
  final String defaultUnit;
  final DateTime? createdAt;

  ProductBoqItem({
    required this.id,
    required this.productId,
    required this.itemName,
    this.inventoryItemId,
    this.defaultSize,
    required this.defaultUnit,
    this.createdAt,
  });

  factory ProductBoqItem.fromJson(Map<String, dynamic> json) {
    return ProductBoqItem(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      itemName: json['item_name'] as String,
      inventoryItemId: json['inventory_item_id'] as String?,
      defaultSize: json['default_size'] as String?,
      defaultUnit: json['default_unit'] as String? ?? 'NOS',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}

final productBoqItemsProvider = FutureProvider.family<List<ProductBoqItem>, String>((ref, productId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('product_boq_items')
      .select()
      .eq('product_id', productId)
      .order('created_at', ascending: true);

  return (data as List).map((json) => ProductBoqItem.fromJson(json)).toList();
});
