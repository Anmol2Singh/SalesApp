// lib/features/customers/providers/customers_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';

// Paginated customer list
class CustomersNotifier extends StateNotifier<AsyncValue<List<Customer>>> {
  final SupabaseClient _supabase;
  final String? _userId;
  final bool _isAdmin;

  int _page = 0;
  static const int _pageSize = 20;
  bool _hasMore = true;
  String _sortBy = 'recent'; // 'recent', 'alphabetical'
  String _filterBy = ''; // '', 'active_deal', 'active_amc'
  String _searchQuery = '';

  bool _isLoading = false;

  CustomersNotifier(this._supabase, this._userId, this._isAdmin)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _page = 0;
      _hasMore = true;
      state = const AsyncValue.loading();
    }

    if (!_hasMore && !refresh) return;

    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    if (supabaseUrl.contains('your-project-ref')) {
      final mock = _getMockCustomers();
      state = AsyncValue.data(mock);
      _hasMore = false;
      return;
    }

    _isLoading = true;
    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      String selectStr = '*, profiles(full_name), sales_pipelines(id, product_id, current_step, status, created_at, products(name))';
      if (_filterBy == 'active_deal') {
        selectStr = '*, profiles(full_name), sales_pipelines!inner(id, product_id, current_step, status, created_at, products(name))';
      } else if (_filterBy == 'active_amc') {
        selectStr = '*, profiles(full_name), amc_contracts!inner(id, status, amc_number), sales_pipelines(id, product_id, current_step, status, created_at, products(name))';
      }

      dynamic response;
      try {
        var query = _supabase
            .from('customers')
            .select(selectStr)
            .isFilter('deleted_at', null);

        if (_filterBy == 'active_deal') {
          query = query.eq('sales_pipelines.status', 'in_progress');
        } else if (_filterBy == 'active_amc') {
          query = query.eq('amc_contracts.status', 'active');
        }

        // Non-admins see customers created by them OR assigned to them
        if (!_isAdmin && _userId != null) {
          query = query.or('created_by.eq.$_userId,assigned_to.eq.$_userId');
        }

        if (_searchQuery.isEmpty) {
          response = await query.order('created_at', ascending: false).range(from, to);
        } else {
          response = await query.order('created_at', ascending: false);
        }
      } catch (e) {
        // Fallback: simple select without relations if schema variance occurs
        var fallbackQuery = _supabase
            .from('customers')
            .select('*')
            .isFilter('deleted_at', null);
        
        if (!_isAdmin && _userId != null) {
          fallbackQuery = fallbackQuery.or('created_by.eq.$_userId,assigned_to.eq.$_userId');
        }

        if (_searchQuery.isEmpty) {
          response = await fallbackQuery.order('created_at', ascending: false).range(from, to);
        } else {
          response = await fallbackQuery.order('created_at', ascending: false);
        }
      }
      
      var customers = (response as List<dynamic>)
          .map((json) => Customer.fromJson(json as Map<String, dynamic>))
          .toList();

      // In-memory filter safety
      if (_filterBy == 'active_deal') {
        customers = customers.where((c) {
          final p = c.pipelines;
          return p != null && p.isNotEmpty && p.any((pipe) => pipe.status != PipelineStatus.completed);
        }).toList();
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        customers = customers.where((c) {
          final matchName = c.companyName.toLowerCase().contains(q) || (c.contactPerson?.toLowerCase().contains(q) ?? false);
          final matchPhone = c.phone?.toLowerCase().contains(q) ?? false;
          final matchEmail = c.email?.toLowerCase().contains(q) ?? false;
          final matchAddress = c.address?.toLowerCase().contains(q) ?? false;
          final matchSalesman = c.salesmanName?.toLowerCase().contains(q) ?? false;
          final matchProduct = c.pipelines?.any((p) => p.productName.toLowerCase().contains(q)) ?? false;
          return matchName || matchPhone || matchEmail || matchAddress || matchSalesman || matchProduct;
        }).toList();
        
        _hasMore = false; // Disable pagination when searching globally
      } else {
        if (customers.length < _pageSize) _hasMore = false;
      }

      // Sort
      if (_sortBy == 'alphabetical') {
        customers.sort((a, b) => a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase()));
      } else {
        customers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      _page++;

      if (refresh || _page == 1) {
        state = AsyncValue.data(customers);
      } else {
        state = AsyncValue.data([...state.value ?? [], ...customers]);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    await load(refresh: true);
  }

  Future<void> setFilterAndSort({required String filter, required String sort}) async {
    _filterBy = filter;
    _sortBy = sort;
    await load(refresh: true);
  }

  Future<void> refresh() => load(refresh: true);

  Future<void> assignCustomer({
    required String customerId,
    required String salesUserId,
    required String salesUserName,
    String transferDealsMode = 'all', // 'all', 'active_only', 'none'
  }) async {
    try {
      await _supabase.from('customers').update({
        'assigned_to': salesUserId,
        'assigned_to_name': salesUserName,
        'reassignment_requested': false,
        'reassignment_reason': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', customerId);
    } catch (_) {
      await _supabase.from('customers').update({
        'assigned_to': salesUserId,
        'assigned_to_name': salesUserName,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', customerId);
    }

    // Transfer deals according to chosen mode
    if (transferDealsMode == 'all') {
      try {
        await _supabase.from('sales_pipelines').update({
          'created_by': salesUserId,
          'assigned_to': salesUserId,
        }).eq('customer_id', customerId);
      } catch (_) {
        try {
          await _supabase.from('sales_pipelines').update({
            'created_by': salesUserId,
          }).eq('customer_id', customerId);
        } catch (_) {}
      }
    } else if (transferDealsMode == 'active_only') {
      try {
        await _supabase.from('sales_pipelines').update({
          'created_by': salesUserId,
          'assigned_to': salesUserId,
        }).eq('customer_id', customerId).eq('status', 'in_progress');
      } catch (_) {
        try {
          await _supabase.from('sales_pipelines').update({
            'created_by': salesUserId,
          }).eq('customer_id', customerId).eq('status', 'in_progress');
        } catch (_) {}
      }
    }

    try {
      await _supabase.from('notifications').insert({
        'user_id': salesUserId,
        'title': 'Customer Assigned 🤝',
        'body': 'You have been assigned as the account representative (Deals mode: $transferDealsMode).',
        'type': 'task_assigned',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    await refresh();
  }

  Future<void> requestCustomerTransfer({
    required String customerId,
    required String customerName,
    required String reason,
  }) async {
    // 1. Update customer record
    try {
      await _supabase.from('customers').update({
        'reassignment_requested': true,
        'reassignment_reason': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', customerId);
    } catch (_) {
      try {
        final current = await _supabase.from('customers').select('notes').eq('id', customerId).maybeSingle();
        final existingNotes = current?['notes'] as String? ?? '';
        final newNotes = '$existingNotes\n[REASSIGNMENT_REQUEST: $reason]'.trim();
        await _supabase.from('customers').update({'notes': newNotes}).eq('id', customerId);
      } catch (_) {}
    }

    // 2. Notify Admins
    try {
      final staffResponse = await _supabase.from('profiles').select('id, role, roles');
      final adminIds = <String>{};
      for (final s in (staffResponse as List? ?? [])) {
        final role = (s['role'] as String? ?? '').toLowerCase();
        final rolesList = (s['roles'] is List) ? (s['roles'] as List).map((e) => e.toString().toLowerCase()).toList() : [];
        if (role == 'admin' || role == 'manager' || role == 'sales_head' ||
            rolesList.contains('admin') || rolesList.contains('manager') || rolesList.contains('sales_head')) {
          if (s['id'] != null) adminIds.add(s['id'] as String);
        }
      }

      for (final aid in adminIds) {
        await _supabase.from('notifications').insert({
          'user_id': aid,
          'title': 'Customer Reassignment Requested ⚠️',
          'body': 'Sales rep requested reassignment for customer "$customerName". Reason: $reason',
          'type': 'reassignment_request',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    await refresh();
  }

  Future<void> deactivateCustomer(String customerId) async {
    try {
      final custData = await _supabase
          .from('customers')
          .select('phone, email, customer_name, company_name')
          .eq('id', customerId)
          .maybeSingle();

      await _supabase.from('customers').update({
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', customerId);

      // Synchronously remove or deactivate from customer_profiles
      try { await _supabase.from('customer_profiles').delete().eq('id', customerId); } catch (_) {}
      if (custData != null) {
        final phone = custData['phone']?.toString();
        final email = custData['email']?.toString();
        if (phone != null && phone.isNotEmpty) {
          final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');
          try { await _supabase.from('customer_profiles').delete().eq('phone', phone); } catch (_) {}
          if (cleanDigits.isNotEmpty) {
            try { await _supabase.from('customer_profiles').delete().eq('phone', cleanDigits); } catch (_) {}
          }
        }
        if (email != null && email.isNotEmpty) {
          try { await _supabase.from('customer_profiles').delete().eq('email', email); } catch (_) {}
        }
      }
    } catch (_) {}
    await refresh();
  }

  Future<void> permanentlyDeleteCustomer(String customerId) async {
    // 1. Fetch customer details for comprehensive cleanup
    String customerPhone = '';
    String customerEmail = '';
    String customerName = '';
    try {
      final custData = await _supabase
          .from('customers')
          .select('phone, email, company_name, customer_name, contact_person')
          .eq('id', customerId)
          .maybeSingle();
      if (custData != null) {
        customerPhone = custData['phone']?.toString() ?? '';
        customerEmail = custData['email']?.toString() ?? '';
        customerName = custData['company_name']?.toString() ??
            custData['customer_name']?.toString() ??
            custData['contact_person']?.toString() ??
            '';
      }
    } catch (_) {}

    // 2. Fetch pipelines for this customer
    List<String> pipelineIds = [];
    try {
      final pipeRes = await _supabase
          .from('sales_pipelines')
          .select('id')
          .eq('customer_id', customerId);
      pipelineIds = (pipeRes as List).map((e) => e['id'].toString()).toList();
    } catch (_) {}

    // 3. Fetch any CRM leads converted to this customer
    List<String> leadIds = [];
    try {
      final leadsRes = await _supabase
          .from('crm_leads')
          .select('id')
          .eq('converted_to_customer_id', customerId);
      leadIds = (leadsRes as List).map((e) => e['id'].toString()).toList();
    } catch (_) {}

    // 4. Fetch AMC contracts for this customer or its pipelines
    List<String> amcIds = [];
    try {
      final amcRes = await _supabase
          .from('amc_contracts')
          .select('id')
          .eq('customer_id', customerId);
      amcIds.addAll((amcRes as List).map((e) => e['id'].toString()));
    } catch (_) {}
    if (pipelineIds.isNotEmpty) {
      for (final pid in pipelineIds) {
        try {
          final amcPipeRes = await _supabase
              .from('amc_contracts')
              .select('id')
              .eq('pipeline_id', pid);
          amcIds.addAll((amcPipeRes as List).map((e) => e['id'].toString()));
        } catch (_) {}
      }
    }
    amcIds = amcIds.toSet().toList();

    // 5. Clean up AMC service visits and AMC audit logs
    for (final aid in amcIds) {
      try { await _supabase.from('amc_service_visits').delete().eq('amc_contract_id', aid); } catch (_) {}
      try { await _supabase.from('step_audit_log').delete().eq('amc_contract_id', aid); } catch (_) {}
    }
    try { await _supabase.from('service_visits').delete().eq('customer_id', customerId); } catch (_) {}

    // 6. Delete all quotations linked by pipeline, customer_id, lead_id, or contact info
    try { await _supabase.from('quotations').delete().eq('customer_id', customerId); } catch (_) {}
    for (final pid in pipelineIds) {
      try { await _supabase.from('quotations').delete().eq('pipeline_id', pid); } catch (_) {}
    }
    for (final lid in leadIds) {
      try { await _supabase.from('quotations').delete().eq('lead_id', lid); } catch (_) {}
    }
    if (customerPhone.isNotEmpty) {
      final cleanDigits = customerPhone.replaceAll(RegExp(r'\D'), '');
      try { await _supabase.from('quotations').delete().eq('customer_phone', customerPhone); } catch (_) {}
      if (cleanDigits.isNotEmpty && cleanDigits != customerPhone) {
        try { await _supabase.from('quotations').delete().eq('customer_phone', cleanDigits); } catch (_) {}
      }
    }
    if (customerName.isNotEmpty) {
      try { await _supabase.from('quotations').delete().eq('customer_name', customerName); } catch (_) {}
    }

    // 7. Delete child records for all pipelines
    if (pipelineIds.isNotEmpty) {
      for (final pid in pipelineIds) {
        try { await _supabase.from('step_audit_log').delete().eq('pipeline_id', pid); } catch (_) {}
        try { await _supabase.from('deal_audit_log').delete().eq('pipeline_id', pid); } catch (_) {}
        try { await _supabase.from('stage_signatures').delete().eq('pipeline_id', pid); } catch (_) {}
        try { await _supabase.from('proforma_invoices').delete().eq('pipeline_id', pid); } catch (_) {}
        try { await _supabase.from('tax_invoices').delete().eq('pipeline_id', pid); } catch (_) {}
        try { await _supabase.from('factory_orders').delete().eq('pipeline_id', pid); } catch (_) {}
        try { await _supabase.from('purchase_orders').delete().eq('pipeline_id', pid); } catch (_) {}
        try { await _supabase.from('sales_orders').delete().eq('pipeline_id', pid); } catch (_) {}
        try { await _supabase.from('boqs').delete().eq('pipeline_id', pid); } catch (_) {}
        try { await _supabase.from('warranty_cards').delete().eq('pipeline_id', pid); } catch (_) {}
        try { await _supabase.from('amc_contracts').delete().eq('pipeline_id', pid); } catch (_) {}
      }
    }

    // 8. Delete customer-level child records
    try { await _supabase.from('bookings').delete().eq('customer_id', customerId); } catch (_) {}
    try { await _supabase.from('complaint_part_orders').delete().eq('customer_id', customerId); } catch (_) {}
    try { await _supabase.from('complaints').delete().eq('customer_id', customerId); } catch (_) {}
    try { await _supabase.from('amc_contracts').delete().eq('customer_id', customerId); } catch (_) {}
    try { await _supabase.from('warranty_cards').delete().eq('customer_id', customerId); } catch (_) {}
    try { await _supabase.from('product_inquiries').delete().eq('customer_id', customerId); } catch (_) {}

    // 9. Synchronize delete with customer_profiles
    try { await _supabase.from('customer_profiles').delete().eq('id', customerId); } catch (_) {}
    if (customerPhone.isNotEmpty) {
      final cleanDigits = customerPhone.replaceAll(RegExp(r'\D'), '');
      try { await _supabase.from('customer_profiles').delete().eq('phone', customerPhone); } catch (_) {}
      if (cleanDigits.isNotEmpty && cleanDigits != customerPhone) {
        try { await _supabase.from('customer_profiles').delete().eq('phone', cleanDigits); } catch (_) {}
        try { await _supabase.from('customer_profiles').delete().ilike('phone', '%$cleanDigits%'); } catch (_) {}
      }
    }
    if (customerEmail.isNotEmpty) {
      try { await _supabase.from('customer_profiles').delete().eq('email', customerEmail); } catch (_) {}
    }
    if (customerName.isNotEmpty) {
      try { await _supabase.from('customer_profiles').delete().eq('full_name', customerName); } catch (_) {}
    }

    // 10. Delete pipelines
    if (pipelineIds.isNotEmpty) {
      try {
        await _supabase.from('sales_pipelines').delete().eq('customer_id', customerId);
      } catch (_) {
        for (final pid in pipelineIds) {
          try { await _supabase.from('sales_pipelines').delete().eq('id', pid); } catch (_) {}
        }
      }
    }

    // 11. Delete or soft-delete customer record
    try {
      await _supabase.from('customers').delete().eq('id', customerId);
    } catch (_) {
      // In case any lingering database constraint still prevents hard delete, soft-delete immediately
      try {
        await _supabase.from('customers').update({
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', customerId);
      } catch (_) {}
    }

    await refresh();
  }

  bool get hasMore => _hasMore;
  String get filterBy => _filterBy;
  String get sortBy => _sortBy;
}

final customersNotifierProvider =
    StateNotifierProvider<CustomersNotifier, AsyncValue<List<Customer>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  final canViewAll = (profile?.primaryRole.canViewAllCustomers ?? false) ||
      (profile?.roles.contains(UserRole.admin) ?? false) ||
      (profile?.roles.contains(UserRole.salesHead) ?? false);
  return CustomersNotifier(
    supabase,
    profile?.id,
    canViewAll,
  );
});

// Fuzzy customer search (for dedupe check before creating new)
final customerSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, query) async {
  if (query.isEmpty) return [];

  final supabase = ref.watch(supabaseClientProvider);
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  if (supabaseUrl.contains('your-project-ref')) {
    return [];
  }

  final response = await supabase.rpc(
    'search_customers',
    params: {
      'search_term': query,
      'requesting_user_id': supabase.auth.currentUser?.id ?? '',
    },
  );

  return List<Map<String, dynamic>>.from(response as List);
});

// Checks if a customer has a duplicate candidate in the DB
final customerDuplicateCandidateProvider = FutureProvider.family<bool, Customer>((ref, customer) async {
  final name = customer.companyName;
  if (name.length < 3) return false;
  try {
    final list = await ref.read(customerSearchProvider(name).future);
    return list.any((item) => item['id'] != customer.id && (item['similarity_score'] as num? ?? 0.0) >= 0.4);
  } catch (_) {
    return false;
  }
});

// Single customer detail with all pipelines
final customerDetailProvider =
    FutureProvider.family<Customer, String>((ref, customerId) async {
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  if (supabaseUrl.contains('your-project-ref')) {
    final mockList = _getMockCustomers();
    return mockList.firstWhere(
      (c) => c.id == customerId,
      orElse: () => mockList.first,
    );
  }

  final response = await supabase.from('customers').select('''
        *,
        sales_pipelines(
          id, product_id, current_step, status, created_at, created_by,
          products(id, name, category),
          quotations(pdf_url),
          boqs(pdf_url),
          factory_orders(pdf_url),
          purchase_orders(pdf_url)
        )
      ''').eq('id', customerId).isFilter('deleted_at', null).single();

  return Customer.fromJson(response);
});

// Create customer
final createCustomerProvider =
    FutureProvider.family<Customer, Map<String, dynamic>>((ref, data) async {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser!.id;

  final response = await supabase
      .from('customers')
      .insert({
        ...data,
        'created_by': userId,
      })
      .select()
      .single();

  return Customer.fromJson(response);
});

List<Customer> _getMockCustomers() {
  final now = DateTime.now();
  return [
    Customer(
      id: 'c1',
      companyName: 'Apex Industries',
      contactPerson: 'Rahul Sharma',
      phone: '+91 98765 43210',
      email: 'rahul@apex.com',
      address: 'Industrial Area Phase 1, New Delhi',
      gstNumber: '07AAAAA1111A1Z1',
      createdBy: 'u1',
      createdAt: now,
      updatedAt: now,
      pipelines: const [],
    ),
    Customer(
      id: 'c2',
      companyName: 'Vertex Solutions',
      contactPerson: 'Priya Patel',
      phone: '+91 87654 32109',
      email: 'priya@vertex.com',
      address: 'GIDC Industrial Estate, Vadodara',
      gstNumber: '24BBBBB2222B2Z2',
      createdBy: 'u1',
      createdAt: now,
      updatedAt: now,
      pipelines: const [],
    ),
  ];
}
