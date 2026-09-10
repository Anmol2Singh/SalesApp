import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/providers/supabase_provider.dart';

final inventoryProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('inventory_items')
      .select()
      .order('item_name');
  return data.map((json) => InventoryItem.fromJson(json)).toList();
});
