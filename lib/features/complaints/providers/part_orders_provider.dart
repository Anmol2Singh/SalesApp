// lib/features/complaints/providers/part_orders_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/complaint_part_order.dart';
import '../../../core/providers/supabase_provider.dart';

final partOrdersForComplaintProvider = FutureProvider.family<List<ComplaintPartOrder>, String>((ref, complaintId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final res = await supabase
      .from('complaint_part_orders')
      .select()
      .eq('complaint_id', complaintId)
      .order('created_at', ascending: false);

  return (res as List).map((e) => ComplaintPartOrder.fromJson(e)).toList();
});

class PartOrdersService {
  final Ref ref;
  PartOrdersService(this.ref);

  static List<Map<String, dynamic>> mergeDuplicateItems(List<Map<String, dynamic>> rawItems) {
    final Map<String, Map<String, dynamic>> merged = {};
    for (final item in rawItems) {
      final name = (item['item_name'] ?? '').toString().trim().toLowerCase();
      final key = '${item['inventory_id'] ?? name}_${item['is_warranty']}';
      if (merged.containsKey(key)) {
        final cur = merged[key]!;
        final oldQty = (cur['quantity'] as num?)?.toInt() ?? 1;
        final addQty = (item['quantity'] as num?)?.toInt() ?? 1;
        final newQty = oldQty + addQty;
        final unitPrice = (cur['unit_price'] as num?)?.toDouble() ?? 0.0;
        cur['quantity'] = newQty;
        cur['total_price'] = unitPrice * newQty;
      } else {
        merged[key] = Map<String, dynamic>.from(item);
      }
    }
    return merged.values.toList();
  }

  Future<void> createPartOrder({
    required String complaintId,
    required String? customerId,
    required String? customerName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required bool isWarranty,
    required String? createdBy,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    final mergedItems = mergeDuplicateItems(items);
    final finalAmount = mergedItems.fold<double>(
      0.0,
      (sum, i) => sum + ((i['total_price'] as num?)?.toDouble() ?? 0.0),
    );
    final paymentStatus = finalAmount <= 0 ? 'not_required' : 'pending';

    final res = await supabase.from('complaint_part_orders').insert({
      'complaint_id': complaintId,
      'customer_id': customerId,
      'customer_name': customerName,
      'items': mergedItems,
      'total_amount': finalAmount,
      'is_warranty': finalAmount <= 0 || isWarranty,
      'payment_status': paymentStatus,
      'created_by': createdBy,
    }).select().single();

    // If free warranty or 0 amount, record as replaced_items immediately
    if (finalAmount <= 0) {
      await _recordReplacedItems(complaintId, mergedItems);
    }

    ref.invalidate(partOrdersForComplaintProvider(complaintId));
  }

  Future<void> markOrderPaid({
    required String orderId,
    required String complaintId,
    required String paymentRef,
    required List<Map<String, dynamic>> items,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('complaint_part_orders').update({
      'payment_status': 'paid',
      'paid_at': DateTime.now().toIso8601String(),
      'payment_reference': paymentRef,
    }).eq('id', orderId);

    // Record replaced items in complaint
    await _recordReplacedItems(complaintId, items);

    ref.invalidate(partOrdersForComplaintProvider(complaintId));
  }

  Future<void> _recordReplacedItems(String complaintId, List<Map<String, dynamic>> newItems) async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final complaintRes = await supabase
          .from('complaints')
          .select('replaced_items')
          .eq('id', complaintId)
          .maybeSingle();

      List<dynamic> current = [];
      if (complaintRes != null && complaintRes['replaced_items'] != null) {
        current = List<dynamic>.from(complaintRes['replaced_items'] as List);
      }

      current.addAll(newItems.map((item) => {
        ...item,
        'replaced_at': DateTime.now().toIso8601String(),
      }));

      await supabase.from('complaints').update({
        'replaced_items': current,
      }).eq('id', complaintId);
    } catch (_) {}
  }
}

final partOrdersServiceProvider = Provider<PartOrdersService>((ref) {
  return PartOrdersService(ref);
});
