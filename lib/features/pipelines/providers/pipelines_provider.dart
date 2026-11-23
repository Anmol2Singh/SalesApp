// lib/features/pipelines/providers/pipelines_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
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
  final Profile? _profile;

  int _page = 0;
  static const int _pageSize = 100;
  bool _hasMore = true;
  bool _isLoading = false;

  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  String _stepFilter = '';
  String _statusFilter = '';
  RealtimeChannel? _realtimeChannel;
  Timer? _pollingTimer;

  PipelinesNotifier(this._supabase, this._profile)
      : super(const AsyncValue.loading()) {
    load();
    _initRealtime();
    _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) load(refresh: true, isSilent: true);
    });
  }

  void _initRealtime() {
    try {
      _realtimeChannel = _supabase
          .channel('public:sales_pipelines_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'sales_pipelines',
            callback: (_) => load(refresh: true, isSilent: true),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'boqs',
            callback: (_) => load(refresh: true, isSilent: true),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'factory_orders',
            callback: (_) => load(refresh: true, isSilent: true),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'purchase_orders',
            callback: (_) => load(refresh: true, isSilent: true),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'sales_orders',
            callback: (_) => load(refresh: true, isSilent: true),
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime channel subscription error: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    if (_realtimeChannel != null) {
      try {
        _supabase.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> load({bool refresh = false, bool isSilent = false}) async {
    if (_isLoading && !refresh) return;
    if (refresh) {
      _page = 0;
      _hasMore = true;
      if (!isSilent && !state.hasValue) {
        state = const AsyncValue.loading();
      }
    }
    if (!_hasMore && !refresh) return;

    _isLoading = true;

    const supabaseUrl = AppConfig.supabaseUrl;
    if (supabaseUrl.contains('your-project-ref')) {
      final mock = _getMockPipelines();
      state = AsyncValue.data(mock);
      _hasMore = false;
      _isLoading = false;
      return;
    }

    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      var query = _supabase.from('sales_pipelines').select('''
            *,
            customers(*),
            products(*),
            profiles!sales_pipelines_created_by_fkey(id, full_name),
            quotations(*),
            sales_orders(id, status),
            boqs(id, status),
            factory_orders(id, status),
            purchase_orders(id, status)
          ''').isFilter('deleted_at', null);

      final profile = _profile;
      final roles = (profile != null && profile.roles.isNotEmpty)
          ? profile.roles
          : (profile != null ? [profile.primaryRole] : <UserRole>[]);
      final canViewAll = roles.contains(UserRole.admin) ||
          roles.contains(UserRole.manager) ||
          roles.contains(UserRole.salesHead);

      if (!canViewAll && profile != null) {
        final hasBoqOrService = roles.contains(UserRole.boq) ||
            roles.contains(UserRole.serviceHead) ||
            roles.contains(UserRole.installation) ||
            roles.contains(UserRole.complaints);
        final hasFactory = roles.contains(UserRole.factory);
        final hasPurchase = roles.contains(UserRole.purchase);
        final hasSales = roles.contains(UserRole.sales);

        if (hasBoqOrService) {
          query = query.or('current_step.in.(boq,factory_order,purchase_order),status.eq.completed');
        } else if (hasFactory) {
          query = query.or('current_step.in.(factory_order,purchase_order),status.eq.completed');
        } else if (hasPurchase) {
          query = query.or('current_step.eq.purchase_order,status.eq.completed');
        } else if (hasSales) {
          List<String> assignedCustomerIds = [];
          try {
            final custRes = await _supabase
                .from('customers')
                .select('id')
                .eq('assigned_to', profile.id);
            assignedCustomerIds = (custRes as List)
                .map((c) => c['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();
          } catch (_) {}

          if (assignedCustomerIds.isNotEmpty) {
            final idList = assignedCustomerIds.join(',');
            query = query.or('created_by.eq.${profile.id},customer_id.in.($idList)');
          } else {
            query = query.eq('created_by', profile.id);
          }
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

      if (!mounted) return;
      // Requirement 2: Deduplicate by ID so deals never repeat automatically
      final existing = refresh ? <SalesPipeline>[] : (state.value ?? []);
      final Map<String, SalesPipeline> dealMap = {};
      for (final p in existing) {
        dealMap[p.id] = p;
      }
      for (final p in pipelines) {
        dealMap[p.id] = p;
      }
      state = AsyncValue.data(dealMap.values.toList());
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refresh() => load(refresh: true, isSilent: true);

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
    profile,
  );
});

class DealCounts {
  final int needsAction;
  final int active;
  final int completed;

  const DealCounts({
    required this.needsAction,
    required this.active,
    required this.completed,
  });
}

/// Global accurate counts provider for deal tabs
final dealCountsProvider = FutureProvider<DealCounts>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) {
    return const DealCounts(needsAction: 0, active: 0, completed: 0);
  }

  final roles = profile.roles.isNotEmpty ? profile.roles : [profile.primaryRole];
  final canViewAll = roles.contains(UserRole.admin) ||
      roles.contains(UserRole.manager) ||
      roles.contains(UserRole.salesHead);

  try {
    if (canViewAll) {
      // 1. Direct exact count queries on Supabase - lightning fast, exact, unlimited scale
      final activeRes = await supabase
          .from('sales_pipelines')
          .select()
          .isFilter('deleted_at', null)
          .neq('status', 'completed')
          .count(CountOption.exact);

      final completedRes = await supabase
          .from('sales_pipelines')
          .select()
          .isFilter('deleted_at', null)
          .eq('status', 'completed')
          .count(CountOption.exact);

      int needsAction = 0;
      try {
        final naRes = await supabase
            .from('quotations')
            .select()
            .eq('status', 'pending_approval')
            .count(CountOption.exact);
        needsAction = naRes.count;
      } catch (_) {}

      return DealCounts(
        needsAction: needsAction,
        active: activeRes.count,
        completed: completedRes.count,
      );
    }

    // 2. Scoped query for non-admin/assigned roles (Service Head, Factory, Purchase, Sales, etc.)
    final rows = await supabase
        .from('sales_pipelines')
        .select('''
          id,
          status,
          current_step,
          created_by,
          customer_id,
          customers(assigned_to),
          quotations(id, status)
        ''')
        .isFilter('deleted_at', null);

    final hasBoqOrServiceRole = roles.contains(UserRole.boq) ||
        roles.contains(UserRole.serviceHead) ||
        roles.contains(UserRole.installation) ||
        roles.contains(UserRole.complaints);
    final hasFactoryRole = roles.contains(UserRole.factory);
    final hasPurchaseRole = roles.contains(UserRole.purchase);
    final hasSalesRole = roles.contains(UserRole.sales);

    int needsAction = 0;
    int active = 0;
    int completed = 0;

    for (final r in (rows as List)) {
      final statusStr = r['status']?.toString() ?? 'in_progress';
      final isCompletedStatus = statusStr == 'completed';
      final currentStepStr = r['current_step']?.toString() ?? 'quotation';
      final step = PipelineStep.fromString(currentStepStr);
      final isCompleted = isCompletedStatus || step == PipelineStep.completed;

      final createdBy = r['created_by']?.toString() ?? '';
      final custMap = r['customers'] is Map ? r['customers'] as Map : null;
      final assignedTo = custMap?['assigned_to']?.toString();

      // Check visibility matching RoleAccess.isDealVisibleForUser
      bool isVisible = false;
      if (isCompleted &&
          (hasBoqOrServiceRole || hasFactoryRole || hasPurchaseRole || hasSalesRole)) {
        isVisible = true;
      } else if (hasBoqOrServiceRole && step.stepIndex >= PipelineStep.boq.stepIndex) {
        isVisible = true;
      } else if (hasFactoryRole && step.stepIndex >= PipelineStep.factoryOrder.stepIndex) {
        isVisible = true;
      } else if (hasPurchaseRole && step.stepIndex >= PipelineStep.purchaseOrder.stepIndex) {
        isVisible = true;
      } else if (hasSalesRole && (createdBy == profile.id || assignedTo == profile.id)) {
        isVisible = true;
      }

      if (!isVisible) continue;

      final quote = r['quotations'] ?? r['quotation'];
      String? quoteStatus;
      if (quote is List && quote.isNotEmpty) {
        quoteStatus = (quote.first as Map)['status']?.toString();
      } else if (quote is Map) {
        quoteStatus = quote['status']?.toString();
      }

      if (quoteStatus == 'pending_approval' && hasSalesRole) {
        needsAction++;
      }
      if (isCompletedStatus) {
        completed++;
      } else {
        active++;
      }
    }

    return DealCounts(needsAction: needsAction, active: active, completed: completed);
  } catch (e) {
    debugPrint('dealCountsProvider error: $e');
    return const DealCounts(needsAction: 0, active: 0, completed: 0);
  }
});

// Single pipeline detail
final pipelineDetailProvider =
    FutureProvider.family<SalesPipeline, String>((ref, pipelineId) async {
  final supabase = ref.watch(supabaseClientProvider);

  const supabaseUrl = AppConfig.supabaseUrl;
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

/// Real-time stream provider on sales_pipelines table.
/// Subscribes directly to Supabase stream and invalidates/notifies active providers.
final dealsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase
      .from('sales_pipelines')
      .stream(primaryKey: ['id'])
      .map((data) {
        // Invalidate active pipeline lists silently when changes occur
        ref.read(pipelinesNotifierProvider.notifier).load(refresh: true, isSilent: true);
        return data;
      });
});

/// Real-time single deal stream provider
final singleDealStreamProvider =
    StreamProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, pipelineId) {
  final supabase = ref.watch(supabaseClientProvider);

  final channel = supabase.channel('realtime_deal_steps_$pipelineId');
  try {
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sales_pipelines',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: pipelineId,
          ),
          callback: (_) {
            ref.invalidate(pipelineDetailProvider(pipelineId));
            ref.invalidate(workflowStepsProvider(pipelineId));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'boqs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'pipeline_id',
            value: pipelineId,
          ),
          callback: (_) {
            ref.invalidate(pipelineDetailProvider(pipelineId));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'factory_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'pipeline_id',
            value: pipelineId,
          ),
          callback: (_) {
            ref.invalidate(pipelineDetailProvider(pipelineId));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'purchase_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'pipeline_id',
            value: pipelineId,
          ),
          callback: (_) {
            ref.invalidate(pipelineDetailProvider(pipelineId));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sales_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'pipeline_id',
            value: pipelineId,
          ),
          callback: (_) {
            ref.invalidate(pipelineDetailProvider(pipelineId));
          },
        )
        .subscribe();
  } catch (_) {}

  ref.onDispose(() {
    try {
      supabase.removeChannel(channel);
    } catch (_) {}
  });

  return supabase
      .from('sales_pipelines')
      .stream(primaryKey: ['id'])
      .eq('id', pipelineId)
      .map((events) {
        if (events.isNotEmpty) {
          ref.invalidate(pipelineDetailProvider(pipelineId));
          ref.invalidate(workflowStepsProvider(pipelineId));
          return events.first;
        }
        return null;
      });
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
