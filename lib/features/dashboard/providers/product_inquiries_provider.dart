// lib/features/dashboard/providers/product_inquiries_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/supabase_provider.dart';

class ProductInterestItem {
  final String id;
  final String customerName;
  final String customerPhone;
  final String productName;
  final String modelNumber;
  final DateTime createdAt;
  final String status;

  ProductInterestItem({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.productName,
    required this.modelNumber,
    required this.createdAt,
    required this.status,
  });

  ProductInterestItem copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? productName,
    String? modelNumber,
    DateTime? createdAt,
    String? status,
  }) {
    return ProductInterestItem(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      productName: productName ?? this.productName,
      modelNumber: modelNumber ?? this.modelNumber,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}

final productInquiriesProvider = FutureProvider<List<ProductInterestItem>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final List<ProductInterestItem> loaded = [];

  // 1. Load from SharedPreferences cache
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cached_product_inquiries');
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List;
      for (final item in list) {
        if (item is Map) {
          loaded.add(ProductInterestItem(
            id: item['id']?.toString() ?? '',
            customerName: item['customer_name']?.toString() ?? 'Valued Customer',
            customerPhone: item['customer_phone']?.toString() ?? '',
            productName: item['product_name']?.toString() ?? 'Solar System',
            modelNumber: item['model_number']?.toString() ?? '',
            createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now(),
            status: item['status']?.toString() ?? 'pending',
          ));
        }
      }
    }
  } catch (_) {}

  // 2. Load from Supabase product_inquiries
  try {
    final res = await supabase
        .from('product_inquiries')
        .select()
        .order('created_at', ascending: false);

    for (final item in (res as List? ?? [])) {
      final id = item['inquiry_id']?.toString() ?? item['id']?.toString() ?? '';
      if (!loaded.any((e) => e.id == id && id.isNotEmpty)) {
        loaded.add(ProductInterestItem(
          id: id,
          customerName: item['customer_name']?.toString() ?? 'Valued Customer',
          customerPhone: item['customer_phone']?.toString() ?? '',
          productName: item['product_name']?.toString() ?? 'Solar System',
          modelNumber: item['model_number']?.toString() ?? '',
          createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now(),
          status: item['status']?.toString() ?? 'pending',
        ));
      }
    }
  } catch (_) {}

  // 3. Load from Supabase crm_leads where source is Customer Product Interest
  try {
    final res = await supabase
        .from('crm_leads')
        .select()
        .eq('source', 'Customer Product Interest')
        .order('created_at', ascending: false);

    for (final item in (res as List? ?? [])) {
      final id = item['id']?.toString() ?? '';
      final req = item['requirement']?.toString() ?? '';
      String prodName = 'Solar Equipment';
      if (req.contains('product:')) {
        prodName = req.split('product:').last.trim();
      } else if (req.contains('buying')) {
        prodName = req.split('buying').last.trim();
      }

      if (!loaded.any((e) => e.id == id && id.isNotEmpty)) {
        loaded.add(ProductInterestItem(
          id: id,
          customerName: item['name']?.toString() ?? 'Customer',
          customerPhone: item['phone']?.toString() ?? '',
          productName: prodName,
          modelNumber: '',
          createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now(),
          status: item['status']?.toString() ?? 'new',
        ));
      }
    }
  } catch (_) {}

  // Filter out any cancelled requests completely
  loaded.removeWhere((e) => e.status.toLowerCase() == 'cancelled');
  loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return loaded;
});

class ProductInquiriesService {
  final Ref ref;
  ProductInquiriesService(this.ref);

  Future<void> cancelInquiry(ProductInterestItem item) async {
    // 1. Remove from local SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_product_inquiries');
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        list.removeWhere((e) => e is Map && (e['id'] == item.id || e['inquiry_id'] == item.id));
        await prefs.setString('cached_product_inquiries', jsonEncode(list));
      }
    } catch (_) {}

    // 2. Delete / update in Supabase product_inquiries
    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase
          .from('product_inquiries')
          .delete()
          .or('inquiry_id.eq.${item.id},id.eq.${item.id}');
    } catch (_) {
      try {
        await supabase
            .from('product_inquiries')
            .update({'status': 'cancelled'})
            .or('inquiry_id.eq.${item.id},id.eq.${item.id}');
      } catch (_) {}
    }

    // 3. Delete / update in Supabase crm_leads
    try {
      await supabase.from('crm_leads').delete().eq('id', item.id);
    } catch (_) {
      try {
        await supabase.from('crm_leads').update({'status': 'cancelled'}).eq('id', item.id);
      } catch (_) {}
    }

    ref.invalidate(productInquiriesProvider);
  }

  Future<void> acceptInquiry(ProductInterestItem item) async {
    // 1. Update in local SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_product_inquiries');
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        for (final entry in list) {
          if (entry is Map && (entry['id'] == item.id || entry['inquiry_id'] == item.id)) {
            entry['status'] = 'accepted';
          }
        }
        await prefs.setString('cached_product_inquiries', jsonEncode(list));
      }
    } catch (_) {}

    // 2. Update status in Supabase product_inquiries
    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase
          .from('product_inquiries')
          .update({'status': 'accepted'})
          .or('inquiry_id.eq.${item.id},id.eq.${item.id}');
    } catch (_) {}

    // 3. Update status in Supabase crm_leads
    try {
      await supabase
          .from('crm_leads')
          .update({'status': 'contacted'})
          .eq('id', item.id);
    } catch (_) {}

    ref.invalidate(productInquiriesProvider);
  }
}

final productInquiriesServiceProvider = Provider<ProductInquiriesService>((ref) {
  return ProductInquiriesService(ref);
});
