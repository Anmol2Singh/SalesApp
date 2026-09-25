// lib/features/daily_tasks/providers/daily_tasks_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/models/user_role.dart';
import '../../../core/models/customer.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/daily_task_model.dart';

class DailyTaskFilter {
  final String dateFilter; // 'today', 'specific_day', 'this_week', 'this_month', 'this_year', 'custom', 'all'
  final DateTime? specificDate;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? customerId;
  final String? customerName;
  final String? selectedUserId; // for admins to filter by user
  final String searchQuery;
  final bool showDeleted;

  const DailyTaskFilter({
    this.dateFilter = 'today',
    this.specificDate,
    this.customStartDate,
    this.customEndDate,
    this.customerId,
    this.customerName,
    this.selectedUserId,
    this.searchQuery = '',
    this.showDeleted = false,
  });

  DailyTaskFilter copyWith({
    String? dateFilter,
    DateTime? specificDate,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? customerId,
    String? customerName,
    String? selectedUserId,
    String? searchQuery,
    bool? showDeleted,
    bool clearCustomer = false,
    bool clearUser = false,
    bool clearDate = false,
  }) {
    return DailyTaskFilter(
      dateFilter: dateFilter ?? this.dateFilter,
      specificDate: clearDate ? null : (specificDate ?? this.specificDate),
      customStartDate: clearDate ? null : (customStartDate ?? this.customStartDate),
      customEndDate: clearDate ? null : (customEndDate ?? this.customEndDate),
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      selectedUserId: clearUser ? null : (selectedUserId ?? this.selectedUserId),
      searchQuery: searchQuery ?? this.searchQuery,
      showDeleted: showDeleted ?? this.showDeleted,
    );
  }
}

final dailyTaskFilterProvider = StateProvider<DailyTaskFilter>((ref) {
  return const DailyTaskFilter(dateFilter: 'today');
});

// Provider for customers selectable by the logged in user
final taskSelectableCustomersProvider = FutureProvider<List<Customer>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) return [];

  final bool isAdmin = profile.roles.contains(UserRole.admin) || profile.roles.contains(UserRole.manager);
  final bool isSalesHead = profile.roles.contains(UserRole.salesHead);
  final bool isSalesPerson = profile.primaryRole == UserRole.sales && !isAdmin && !isSalesHead;

  try {
    var query = supabase.from('customers').select('*').isFilter('deleted_at', null);

    if (isSalesPerson) {
      // Sales persons only see customers created by them OR assigned to them
      query = query.or('created_by.eq.${profile.id},assigned_to.eq.${profile.id}');
    }

    final res = await query.order('customer_name', ascending: true);
    return (res as List).map((c) => Customer.fromJson(c as Map<String, dynamic>)).toList();
  } catch (e) {
    return [];
  }
});

// All staff profiles for user filter dropdown (for Admins & Sales Heads)
final taskUsersListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) return [];

  try {
    final res = await supabase
        .from('profiles')
        .select('id, full_name, email, role, roles')
        .eq('is_active', true)
        .order('full_name', ascending: true);

    final list = (res as List).cast<Map<String, dynamic>>();

    final bool isSalesHead = profile.roles.contains(UserRole.salesHead) &&
        !profile.roles.contains(UserRole.admin) &&
        !profile.roles.contains(UserRole.manager);

    if (isSalesHead) {
      // Sales head only sees sales people and self
      return list.where((u) {
        final role = u['role']?.toString() ?? '';
        final roles = (u['roles'] is List) ? (u['roles'] as List).map((e) => e.toString()).toList() : [];
        return u['id'] == profile.id ||
            role == 'sales' ||
            role == 'sales_head' ||
            roles.contains('sales') ||
            roles.contains('sales_head');
      }).toList();
    }

    return list;
  } catch (e) {
    return [];
  }
});

class DailyTasksNotifier extends StateNotifier<AsyncValue<List<DailyTask>>> {
  final Ref _ref;
  final SupabaseClient _supabase;

  DailyTasksNotifier(this._ref, this._supabase) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    state = const AsyncValue.loading();
    try {
      final profile = _ref.read(currentProfileProvider);
      if (profile == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final filter = _ref.read(dailyTaskFilterProvider);
      final bool isAdmin = profile.roles.contains(UserRole.admin) || profile.roles.contains(UserRole.manager);
      final bool isSalesHead = profile.roles.contains(UserRole.salesHead);

      var query = _supabase.from('daily_tasks').select('*');

      // Soft delete filter
      if (!filter.showDeleted) {
        query = query.eq('is_deleted', false);
      }

      // Role-based visibility
      if (isAdmin) {
        // Admins see everyone's tasks. If user filter applied, filter by that user
        if (filter.selectedUserId != null && filter.selectedUserId!.isNotEmpty) {
          query = query.eq('user_id', filter.selectedUserId!);
        }
      } else if (isSalesHead) {
        // Sales head sees all sales persons + own tasks
        if (filter.selectedUserId != null && filter.selectedUserId!.isNotEmpty) {
          query = query.eq('user_id', filter.selectedUserId!);
        } else {
          query = query.or('user_role.eq.sales,user_role.eq.sales_head,user_id.eq.${profile.id}');
        }
      } else {
        // Other roles only see their own tasks
        query = query.eq('user_id', profile.id);
      }

      // Customer filter
      if (filter.customerId != null && filter.customerId!.isNotEmpty) {
        query = query.eq('customer_id', filter.customerId!);
      }

      // Date filtering
      final now = DateTime.now();
      DateTime? startDate;
      DateTime? endDate;

      switch (filter.dateFilter) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          break;
        case 'specific_day':
          if (filter.specificDate != null) {
            final d = filter.specificDate!;
            startDate = DateTime(d.year, d.month, d.day, 0, 0, 0);
            endDate = DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
          }
          break;
        case 'this_week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day, 0, 0, 0);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          break;
        case 'this_month':
          startDate = DateTime(now.year, now.month, 1, 0, 0, 0);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
          break;
        case 'this_year':
          startDate = DateTime(now.year, 1, 1, 0, 0, 0);
          endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);
          break;
        case 'custom':
          if (filter.customStartDate != null && filter.customEndDate != null) {
            startDate = DateTime(
              filter.customStartDate!.year,
              filter.customStartDate!.month,
              filter.customStartDate!.day,
              0, 0, 0,
            );
            endDate = DateTime(
              filter.customEndDate!.year,
              filter.customEndDate!.month,
              filter.customEndDate!.day,
              23, 59, 59, 999,
            );
          }
          break;
        case 'all':
        default:
          break;
      }

      if (startDate != null) {
        query = query.gte('completed_at', startDate.toUtc().toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('completed_at', endDate.toUtc().toIso8601String());
      }

      final res = await query.order('completed_at', ascending: false);

      var tasks = (res as List)
          .map((item) => DailyTask.fromJson(item as Map<String, dynamic>))
          .toList();

      // Client side search filter for customer name or task description or user name
      if (filter.searchQuery.trim().isNotEmpty) {
        final q = filter.searchQuery.trim().toLowerCase();
        tasks = tasks.where((t) {
          return t.customerName.toLowerCase().contains(q) ||
              t.taskDescription.toLowerCase().contains(q) ||
              t.userName.toLowerCase().contains(q);
        }).toList();
      }

      state = AsyncValue.data(tasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createTask({
    required String customerId,
    required String customerName,
    required String taskDescription,
  }) async {
    final profile = _ref.read(currentProfileProvider);
    if (profile == null) throw Exception('User not authenticated');

    final now = DateTime.now();

    final taskData = {
      'customer_id': customerId.isNotEmpty ? customerId : null,
      'customer_name': customerName.trim(),
      'user_id': profile.id,
      'user_name': profile.fullName.trim().isNotEmpty ? profile.fullName.trim() : 'Staff Member',
      'user_role': profile.primaryRole.value,
      'task_description': taskDescription.trim(),
      'completed_at': now.toUtc().toIso8601String(),
      'is_edited': false,
      'is_deleted': false,
      'created_at': now.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
    };

    final res = await _supabase.from('daily_tasks').insert(taskData).select().single();
    final newTask = DailyTask.fromJson(res);

    // Refresh list
    state.whenData((current) {
      state = AsyncValue.data([newTask, ...current]);
    });
  }

  Future<void> updateTask(
    String id, {
    required String taskDescription,
    String? customerId,
    String? customerName,
  }) async {
    final now = DateTime.now();
    final updateData = <String, dynamic>{
      'task_description': taskDescription.trim(),
      'is_edited': true,
      'edited_at': now.toUtc().toIso8601String(),
      'updated_at': now.toUtc().toIso8601String(),
    };

    if (customerName != null && customerName.trim().isNotEmpty) {
      updateData['customer_name'] = customerName.trim();
    }
    if (customerId != null) {
      updateData['customer_id'] = customerId;
    }

    final res = await _supabase
        .from('daily_tasks')
        .update(updateData)
        .eq('id', id)
        .select()
        .single();

    final updated = DailyTask.fromJson(res);

    state.whenData((current) {
      state = AsyncValue.data(
        current.map((t) => t.id == id ? updated : t).toList(),
      );
    });
  }

  Future<void> deleteTask(String id) async {
    final profile = _ref.read(currentProfileProvider);
    final now = DateTime.now();

    final updateData = {
      'is_deleted': true,
      'deleted_at': now.toUtc().toIso8601String(),
      'deleted_by': profile?.id,
      'deleted_by_name': profile?.fullName,
      'updated_at': now.toUtc().toIso8601String(),
    };

    final res = await _supabase
        .from('daily_tasks')
        .update(updateData)
        .eq('id', id)
        .select()
        .single();

    final updated = DailyTask.fromJson(res);

    final showDeleted = _ref.read(dailyTaskFilterProvider).showDeleted;

    state.whenData((current) {
      if (showDeleted) {
        state = AsyncValue.data(current.map((t) => t.id == id ? updated : t).toList());
      } else {
        state = AsyncValue.data(current.where((t) => t.id != id).toList());
      }
    });
  }
}

final dailyTasksProvider =
    StateNotifierProvider<DailyTasksNotifier, AsyncValue<List<DailyTask>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return DailyTasksNotifier(ref, supabase);
});

// Family provider to fetch tasks for a specific customer (for customer detail screen)
final customerTasksProvider = FutureProvider.family<List<DailyTask>, String>((ref, customerId) async {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  if (profile == null || customerId.isEmpty) return [];

  final bool isAdmin = profile.roles.contains(UserRole.admin) || profile.roles.contains(UserRole.manager);

  var query = supabase
      .from('daily_tasks')
      .select('*')
      .eq('customer_id', customerId)
      .eq('is_deleted', false);

  if (!isAdmin) {
    // Non-admins see tasks performed by themselves for this customer
    query = query.eq('user_id', profile.id);
  }

  final res = await query.order('completed_at', ascending: false);
  return (res as List).map((json) => DailyTask.fromJson(json as Map<String, dynamic>)).toList();
});
