// lib/features/customers/providers/customers_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/models/customer.dart';
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

        // Non-admins see only their own customers
        if (!_isAdmin && _userId != null) {
          query = query.eq('created_by', _userId);
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
          fallbackQuery = fallbackQuery.eq('created_by', _userId);
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
  }) async {
    await _supabase.from('customers').update({
      'assigned_to': salesUserId,
      'assigned_to_name': salesUserName,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', customerId);

    try {
      await _supabase.from('notifications').insert({
        'user_id': salesUserId,
        'title': 'Customer Assigned',
        'body': 'You have been assigned as the account representative.',
        'type': 'task_assigned',
      });
    } catch (_) {}

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
  return CustomersNotifier(
    supabase,
    profile?.id,
    profile?.primaryRole.canViewAllCustomers ?? false,
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
