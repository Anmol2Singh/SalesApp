import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/inventory_item.dart';
import '../../../core/providers/supabase_provider.dart';

import '../../../core/models/supplementary_item.dart';

final inventoryProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('inventory_items')
      .select()
      .order('item_name');
  return data.map((json) => InventoryItem.fromJson(json)).toList();
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

