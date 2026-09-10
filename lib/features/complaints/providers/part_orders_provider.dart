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
    final paymentStatus = totalAmount <= 0 ? 'not_required' : 'pending';

    final res = await supabase.from('complaint_part_orders').insert({
      'complaint_id': complaintId,
      'customer_id': customerId,
      'customer_name': customerName,
      'items': items,
      'total_amount': totalAmount,
      'is_warranty': isWarranty,
      'payment_status': paymentStatus,
      'created_by': createdBy,
    }).select().single();

    // If free warranty or 0 amount, record as replaced_items immediately
    if (totalAmount <= 0) {
      await _recordReplacedItems(complaintId, items);
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
