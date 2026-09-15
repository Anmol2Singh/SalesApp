// lib/features/pipelines/providers/pipelines_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/models/pipeline.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/profile.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';

// Paginated pipeline list
class PipelinesNotifier extends StateNotifier<AsyncValue<List<SalesPipeline>>> {
  final SupabaseClient _supabase;
  final String? _userId;
  final bool _isAdmin;

  int _page = 0;
  static const int _pageSize = 20;
  bool _hasMore = true;
  String _stepFilter = '';
  String _statusFilter = '';

  PipelinesNotifier(this._supabase, this._userId, this._isAdmin)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      _page = 0;
      _hasMore = true;
      state = const AsyncValue.loading();
    }
    if (!_hasMore && !refresh) return;

    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    if (supabaseUrl.contains('your-project-ref')) {
      final mock = _getMockPipelines();
      state = AsyncValue.data(mock);
      _hasMore = false;
      return;
    }

    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      var query = _supabase.from('sales_pipelines').select('''
            *,
            customers(*),
            products(id, name, category),
            profiles!sales_pipelines_created_by_fkey(id, full_name),
            quotations(id, status),
            sales_orders(id, status),
            boqs(id, status),
            factory_orders(id, status),
            purchase_orders(id, status)
          ''').isFilter('deleted_at', null);

      if (!_isAdmin && _userId != null) {
        List<String> assignedCustomerIds = [];
        try {
          final custRes = await _supabase
              .from('customers')
              .select('id')
              .eq('assigned_to', _userId);
          assignedCustomerIds = (custRes as List)
              .map((c) => c['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
        } catch (_) {}

        if (assignedCustomerIds.isNotEmpty) {
          final idList = assignedCustomerIds.join(',');
          query = query.or('created_by.eq.$_userId,customer_id.in.($idList)');
        } else {
          query = query.eq('created_by', _userId);
        }
      }

      if (_stepFilter.isNotEmpty) {
        query = query.eq('current_step', _stepFilter);
      }

      if (_statusFilter.isNotEmpty) {
        query = query.eq('status', _statusFilter);
      }

      final response =
          await query.order('updated_at', ascending: false).range(from, to);
      final pipelines = (response as List<dynamic>)
          .map((json) => SalesPipeline.fromJson(json as Map<String, dynamic>))
          .toList();

      if (pipelines.length < _pageSize) _hasMore = false;
      _page++;

      final existing = refresh ? <SalesPipeline>[] : (state.value ?? []);
      state = AsyncValue.data([...existing, ...pipelines]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => load(refresh: true);

  void setFilters({String step = '', String status = ''}) {
    _stepFilter = step;
    _statusFilter = status;
    load(refresh: true);
  }
}

final pipelinesNotifierProvider =
    StateNotifierProvider<PipelinesNotifier, AsyncValue<List<SalesPipeline>>>(
        (ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  return PipelinesNotifier(
    supabase,
    profile?.id,
    profile?.primaryRole.canViewAllPipelines ?? false,
  );
});

// Single pipeline detail
final pipelineDetailProvider =
    FutureProvider.family<SalesPipeline, String>((ref, pipelineId) async {
  final supabase = ref.watch(supabaseClientProvider);

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  if (supabaseUrl.contains('your-project-ref')) {
    final mockList = _getMockPipelines();
    return mockList.firstWhere(
      (p) => p.id == pipelineId,
      orElse: () => mockList.first,
    );
  }

  final response = await supabase.from('sales_pipelines').select('''
        *,
        customers(*),
        products(*),
        profiles!sales_pipelines_created_by_fkey(id, full_name, email, phone, role),
        quotations(*),
        sales_orders(*),
        boqs(*),
        factory_orders(*),
        purchase_orders(*)
      ''').eq('id', pipelineId).isFilter('deleted_at', null).single();

  return SalesPipeline.fromJson(response);
});

// Pipeline audit log
final pipelineAuditLogProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, pipelineId) async {
  final supabase = ref.watch(supabaseClientProvider);

  final response = await supabase
      .from('step_audit_log')
      .select('*, profiles(full_name)')
      .eq('pipeline_id', pipelineId)
      .order('performed_at', ascending: false)
      .limit(50);

  return List<Map<String, dynamic>>.from(response as List);
});

List<SalesPipeline> _getMockPipelines() {
  final now = DateTime.now();
  final customer1 = Customer(
    id: 'c1',
    companyName: 'Apex Industries',
    contactPerson: 'Rahul Sharma',
    phone: '+91 98765 43210',
    email: 'rahul@apex.com',
    createdBy: 'u1',
    createdAt: now,
    updatedAt: now,
  );
  final customer2 = Customer(
    id: 'c2',
    companyName: 'Vertex Solutions',
    contactPerson: 'Priya Patel',
    phone: '+91 87654 32109',
    email: 'priya@vertex.com',
    createdBy: 'u1',
    createdAt: now,
    updatedAt: now,
  );

  final product1 = Product(
    id: 'p1',
    name: 'Boom Barrier (Heavy Duty)',
    category: 'Security',
    baseSpecs:
        const ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
  final product2 = Product(
    id: 'p2',
    name: 'IZYHEAT Commercial Heat Pump',
    category: 'Heating',
    baseSpecs:
        const ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );

  final profile = Profile(
    id: 'u1',
    fullName: 'Anmol Gupta',
    email: 'anmol@izyheat.com',
    roles: [UserRole.sales],
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );

  return [
    SalesPipeline(
      id: 'pipe1',
      customerId: 'c1',
      productId: 'p1',
      createdBy: 'u1',
      currentStep: PipelineStep.factoryOrder,
      status: PipelineStatus.inProgress,
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now,
      customer: customer1,
      product: product1,
      createdByProfile: profile,
    ),
    SalesPipeline(
      id: 'pipe2',
      customerId: 'c2',
      productId: 'p2',
      createdBy: 'u1',
      currentStep: PipelineStep.quotation,
      status: PipelineStatus.inProgress,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now,
      customer: customer2,
      product: product2,
      createdByProfile: profile,
    ),
  ];
}

final workflowStepsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, productId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('workflow_definitions')
      .select('steps')
      .eq('product_id', productId)
      .maybeSingle();

  if (response != null && response['steps'] != null) {
    final list = response['steps'] as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // Default steps
  return [
    {'id': 'quotation', 'name': 'Quotation', 'owner_role': 'sales', 'pdf_generation': true},
    {'id': 'sales_order', 'name': 'Sales Order', 'owner_role': 'sales_head', 'pdf_generation': true},
    {'id': 'boq', 'name': 'BOQ', 'owner_role': 'factory', 'pdf_generation': false},
    {'id': 'factory_order', 'name': 'Factory Order', 'owner_role': 'factory', 'pdf_generation': false},
    {'id': 'purchase_order', 'name': 'Purchase Order', 'owner_role': 'purchase', 'pdf_generation': false},
  ];
});
