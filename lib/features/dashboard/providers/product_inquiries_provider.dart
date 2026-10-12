// lib/features/dashboard/providers/product_inquiries_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/notification_backend_helper.dart';
import '../../pipelines/providers/pipelines_provider.dart';
import '../../customers/providers/customers_provider.dart';

class ProductInterestItem {
  final String id;
  final String customerName;
  final String customerPhone;
  final String? productId;
  final String productName;
  final String modelNumber;
  final DateTime createdAt;
  final String status;

  ProductInterestItem({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    this.productId,
    required this.productName,
    required this.modelNumber,
    required this.createdAt,
    required this.status,
  });

  ProductInterestItem copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? productId,
    String? productName,
    String? modelNumber,
    DateTime? createdAt,
    String? status,
  }) {
    return ProductInterestItem(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      productId: productId ?? this.productId,
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
          final id = item['id']?.toString() ?? '';
          if (id.startsWith('fallback')) continue;
          loaded.add(ProductInterestItem(
            id: id,
            customerName: item['customer_name']?.toString() ?? 'Valued Customer',
            customerPhone: item['customer_phone']?.toString() ?? '',
            productId: item['product_id']?.toString(),
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
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 3));

    for (final item in (res as List? ?? [])) {
      final id = item['inquiry_id']?.toString() ?? item['id']?.toString() ?? '';
      if (!loaded.any((e) => e.id == id && id.isNotEmpty)) {
        loaded.add(ProductInterestItem(
          id: id,
          customerName: item['customer_name']?.toString() ?? 'Valued Customer',
          customerPhone: item['customer_phone']?.toString() ?? '',
          productId: item['product_id']?.toString(),
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
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 3));

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
          productId: null,
          productName: prodName,
          modelNumber: '',
          createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now(),
          status: item['status']?.toString() ?? 'new',
        ));
      }
    }
  } catch (_) {}

  // Filter out any cancelled or fake fallback requests completely
  loaded.removeWhere((e) => e.status.toLowerCase() == 'cancelled' || e.id.startsWith('fallback'));
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

  Future<void> markUnavailable(ProductInterestItem item) async {
    // 1. Update in local SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_product_inquiries');
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        for (final entry in list) {
          if (entry is Map && (entry['id'] == item.id || entry['inquiry_id'] == item.id)) {
            entry['status'] = 'product_unavailable';
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
          .update({'status': 'product_unavailable'})
          .or('inquiry_id.eq.${item.id},id.eq.${item.id}');
    } catch (_) {}

    // 3. Update status in Supabase crm_leads
    try {
      await supabase
          .from('crm_leads')
          .update({'status': 'product_unavailable'})
          .eq('id', item.id);
    } catch (_) {}

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

  Future<({bool success, bool isUnavailable, String message, String? pipelineId})> acceptAndCreateDeal(
    ProductInterestItem item,
  ) async {
    final supabase = ref.read(supabaseClientProvider);
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      return (success: false, isUnavailable: false, message: 'User authentication required', pipelineId: null);
    }

    // 1. Verify Product: Look up product in products table
    Map<String, dynamic>? productRow;
    if (item.productId != null && item.productId!.trim().isNotEmpty) {
      try {
        final res = await supabase
            .from('products')
            .select('id, name, category, is_active, deleted_at')
            .eq('id', item.productId!)
            .maybeSingle();
        if (res != null) productRow = res;
      } catch (_) {}
    }

    if (productRow == null && item.productName.trim().isNotEmpty) {
      try {
        final res = await supabase
            .from('products')
            .select('id, name, category, is_active, deleted_at')
            .ilike('name', '%${item.productName.trim()}%')
            .limit(1);
        if (res.isNotEmpty) productRow = res.first;
      } catch (_) {}
    }

    // Check if product is inactive, deleted, or unavailable
    final bool isDeleted = productRow == null || productRow['deleted_at'] != null;
    final bool isInactive = productRow != null && productRow['is_active'] == false;

    if (isDeleted || isInactive) {
      await markUnavailable(item);
      return (
        success: false,
        isUnavailable: true,
        message: 'Product "${item.productName}" is inactive or deleted. Marked request as Product Unavailable.',
        pipelineId: null,
      );
    }

    final String finalProductId = productRow['id'] as String;

    // 2. Resolve Customer in customers table
    final cleanPhone = item.customerPhone.replaceAll(RegExp(r'[^0-9+]'), '').trim();
    String? customerId;

    try {
      if (cleanPhone.isNotEmpty) {
        final existingCust = await supabase
            .from('customers')
            .select('id')
            .eq('phone', cleanPhone)
            .limit(1);
        if (existingCust.isNotEmpty) {
          customerId = existingCust.first['id'] as String;
        } else {
          final digits = cleanPhone.replaceAll(RegExp(r'[^0-9]'), '');
          final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
          if (last10.isNotEmpty) {
            final existingLike = await supabase
                .from('customers')
                .select('id')
                .ilike('phone', '%$last10')
                .limit(1);
            if (existingLike.isNotEmpty) {
              customerId = existingLike.first['id'] as String;
            }
          }
        }
      }

      if (customerId == null) {
        final custName = item.customerName.trim().isNotEmpty ? item.customerName.trim() : 'Valued Customer';
        final newCust = await supabase.from('customers').insert({
          'customer_name': custName,
          'company_name': custName,
          'contact_person': custName,
          'phone': cleanPhone.isNotEmpty ? cleanPhone : '+91 9876543210',
          'created_by': currentUserId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).select().single();
        customerId = newCust['id'] as String;
      }
    } catch (e) {
      return (success: false, isUnavailable: false, message: 'Failed to resolve customer: $e', pipelineId: null);
    }

    // 3. Resolve workflow steps
    List<dynamic> steps = [
      {'id': 'quotation', 'name': 'Quotation', 'owner_role': 'sales', 'pdf_generation': true},
      {'id': 'sales_order', 'name': 'Sales Order', 'owner_role': 'sales_head', 'pdf_generation': true},
      {'id': 'boq', 'name': 'BOQ', 'owner_role': 'factory', 'pdf_generation': false},
      {'id': 'factory_order', 'name': 'Factory Order', 'owner_role': 'factory', 'pdf_generation': false},
      {'id': 'purchase_order', 'name': 'Purchase Order', 'owner_role': 'purchase', 'pdf_generation': false},
    ];

    try {
      final wfRes = await supabase
          .from('workflow_definitions')
          .select('steps')
          .eq('product_id', finalProductId)
          .maybeSingle();
      if (wfRes != null && wfRes['steps'] is List) {
        steps = wfRes['steps'] as List;
      }
    } catch (_) {}

    // 4. Create Deal in sales_pipelines
    String pipelineId;
    try {
      final pipelineRes = await supabase.from('sales_pipelines').insert({
        'customer_id': customerId,
        'product_id': finalProductId,
        'created_by': currentUserId,
        'current_step': 'quotation',
        'status': 'in_progress',
        'steps_config': steps,
        'notes': 'Created from Customer Product Interest (${item.productName}${item.modelNumber.isNotEmpty ? " - ${item.modelNumber}" : ""})',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();
      pipelineId = pipelineRes['id'] as String;
    } catch (e) {
      return (success: false, isUnavailable: false, message: 'Failed to create deal: $e', pipelineId: null);
    }

    // 5. Audit log
    try {
      await supabase.from('step_audit_log').insert({
        'pipeline_id': pipelineId,
        'step_name': 'pipeline',
        'action': 'created',
        'performed_by': currentUserId,
      });
    } catch (_) {}

    // 6. Notify roles
    try {
      NotificationBackendHelper.notifyRoles(
        supabase: supabase,
        roles: const ['boq', 'factory', 'purchase', 'sales', 'admin'],
        title: 'New Deal Created from Product Interest',
        body: 'Deal created for ${item.customerName} - ${item.productName}',
        type: 'assigned',
        relatedPipelineId: pipelineId,
      );
    } catch (_) {}

    // 7. Update status to 'accepted' in local cache, product_inquiries, and crm_leads
    await acceptInquiry(item);

    ref.invalidate(pipelinesNotifierProvider);
    ref.invalidate(customersNotifierProvider);
    ref.invalidate(productInquiriesProvider);

    return (
      success: true,
      isUnavailable: false,
      message: '✅ Product request accepted & Deal created successfully!',
      pipelineId: pipelineId,
    );
  }
}

final productInquiriesServiceProvider = Provider<ProductInquiriesService>((ref) {
  return ProductInquiriesService(ref);
});
