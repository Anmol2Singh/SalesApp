import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';

class InventorySize {
  final String id;
  final String sizeName;
  final DateTime? createdAt;

  InventorySize({
    required this.id,
    required this.sizeName,
    this.createdAt,
  });

  factory InventorySize.fromJson(Map<String, dynamic> json) {
    return InventorySize(
      id: json['id'] as String,
      sizeName: json['size_name'] as String,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}

final inventorySizesProvider = FutureProvider<List<InventorySize>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final data = await supabase
      .from('inventory_sizes')
      .select()
      .order('size_name');
  return (data as List).map((json) => InventorySize.fromJson(json)).toList();
});
