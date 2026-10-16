import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/providers/supabase_provider.dart';

import '../../../core/models/supplementary_item.dart';

final inventoryProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  try {
    // 1. Fetch active products to ensure all configured capacities are present in inventory_items
    final prodsData = await supabase.from('products').select('name, base_specs');
    final existingItems = await supabase.from('inventory_items').select('item_name');
    final existingNames = <String>{};
    for (final row in (existingItems as List)) {
      final n = row['item_name']?.toString().trim();
      if (n != null && n.isNotEmpty) existingNames.add(n.toLowerCase());
    }

    final List<Map<String, dynamic>> missing = [];
    for (final prod in (prodsData as List)) {
      final pName = (prod['name'] as String?)?.trim();
      if (pName == null || pName.isEmpty) continue;
      final specs = prod['base_specs'] as Map<String, dynamic>?;
      if (specs != null && specs['capacities'] is List) {
        for (final cap in specs['capacities'] as List) {
          final capStr = cap.toString().trim();
          if (capStr.isNotEmpty) {
            final expectedName = '$pName - $capStr';
            if (!existingNames.contains(expectedName.toLowerCase())) {
              missing.add({
                'item_name': expectedName,
                'price': 0.0,
                'uom': 'NOS',
                'created_at': DateTime.now().toIso8601String(),
              });
              existingNames.add(expectedName.toLowerCase());
            }
          }
        }
      }
    }

    if (missing.isNotEmpty) {
      await supabase.from('inventory_items').insert(missing);
    }
  } catch (_) {
    // Gracefully proceed if offline or table has constraint
  }

  final data = await supabase
      .from('inventory_items')
      .select()
      .order('item_name');
  return (data as List).map((json) => InventoryItem.fromJson(json)).toList();
});

final supplementaryItemsProvider = FutureProvider<List<SupplementaryItem>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    final data = await supabase
        .from('supplementary_items')
        .select()
        .order('name');
    return (data as List).map((json) => SupplementaryItem.fromJson(json)).toList();
  } catch (e) {
    return [];
  }
});

class SupplementaryItemsService {
  final SupabaseClient _supabase;
  final Ref _ref;

  SupplementaryItemsService(this._supabase, this._ref);

  Future<void> addItem({
    required String name,
    required double rate,
    required double gstPercent,
  }) async {
    await _supabase.from('supplementary_items').insert({
      'name': name.trim(),
      'rate': rate,
      'gst_percent': gstPercent,
    });
    _ref.invalidate(supplementaryItemsProvider);
  }

  Future<void> updateItem({
    required String id,
    required String name,
    required double rate,
    required double gstPercent,
  }) async {
    await _supabase.from('supplementary_items').update({
      'name': name.trim(),
      'rate': rate,
      'gst_percent': gstPercent,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    _ref.invalidate(supplementaryItemsProvider);
  }

  Future<void> deleteItem(String id) async {
    await _supabase.from('supplementary_items').delete().eq('id', id);
    _ref.invalidate(supplementaryItemsProvider);
  }
}

final supplementaryItemsServiceProvider = Provider<SupplementaryItemsService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SupplementaryItemsService(supabase, ref);
});

