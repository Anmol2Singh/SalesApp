// lib/features/amc/providers/amc_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/amc_contract.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';

// Paginated AMC list with status filter
class AmcNotifier extends StateNotifier<AsyncValue<List<AmcContract>>> {
  final SupabaseClient _supabase;
  final String? _userId;
  final bool _isAdmin;

  int _page = 0;
  static const int _pageSize = 20;
  bool _hasMore = true;
  String _statusFilter = '';

  AmcNotifier(this._supabase, this._userId, this._isAdmin)
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

    const supabaseUrl = AppConfig.supabaseUrl;
    if (supabaseUrl.contains('your-project-ref')) {
      state = const AsyncValue.data([]);
      _hasMore = false;
      return;
    }

    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      var query = _supabase.from('amc_contracts').select('''
            *,
            customers(id, customer_name, contact_person, phone),
            products(id, name, category),
            profiles!amc_contracts_created_by_fkey(id, full_name),
            amc_service_visits(id, visit_number, scheduled_date, completed_date, status)
          ''');

      if (!_isAdmin && _userId != null) {
        query = query.eq('created_by', _userId);
      }

      if (_statusFilter.isNotEmpty) {
        query = query.eq('status', _statusFilter);
      }

      final response =
          await query.order('updated_at', ascending: false).range(from, to);

      final contracts = (response as List<dynamic>)
          .map((json) => AmcContract.fromJson(json as Map<String, dynamic>))
          .toList();

      if (contracts.length < _pageSize) _hasMore = false;
      _page++;

      final existing = refresh ? <AmcContract>[] : (state.value ?? []);
      state = AsyncValue.data([...existing, ...contracts]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => load(refresh: true);

  void setStatusFilter(String status) {
    _statusFilter = status;
    load(refresh: true);
  }

  bool get hasMore => _hasMore;
}

final amcNotifierProvider =
    StateNotifierProvider<AmcNotifier, AsyncValue<List<AmcContract>>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final profile = ref.watch(currentProfileProvider);
  return AmcNotifier(
    supabase,
    profile?.id,
    profile?.primaryRole.canViewAllPipelines ?? false,
  );
});

// Single AMC detail with service visits
final amcDetailProvider =
    FutureProvider.family<AmcContract, String>((ref, amcId) async {
  final supabase = ref.watch(supabaseClientProvider);

  final response = await supabase.from('amc_contracts').select('''
        *,
        customers(*),
        products(*),
        profiles!amc_contracts_created_by_fkey(id, full_name, email, phone, role),
        amc_service_visits(*, profiles(full_name))
      ''').eq('id', amcId).single();

  return AmcContract.fromJson(response);
});

// Check if AMC exists for a customer+product combo
final amcForCustomerProductProvider = FutureProvider.family<AmcContract?,
    ({String customerId, String productId})>((ref, params) async {
  final supabase = ref.watch(supabaseClientProvider);

  const supabaseUrl = AppConfig.supabaseUrl;
  if (supabaseUrl.contains('your-project-ref')) {
    return null;
  }

  final response = await supabase
      .from('amc_contracts')
      .select('*')
      .eq('customer_id', params.customerId)
      .eq('product_id', params.productId)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();

  if (response == null) return null;
  return AmcContract.fromJson(response);
});

// AMCs for a specific customer (used in customer detail)
final amcForCustomerProvider =
    FutureProvider.family<List<AmcContract>, String>((ref, customerId) async {
  final supabase = ref.watch(supabaseClientProvider);

  const supabaseUrl = AppConfig.supabaseUrl;
  if (supabaseUrl.contains('your-project-ref')) {
    return [];
  }

  final response = await supabase.from('amc_contracts').select('''
        *,
        products(id, name, category),
        amc_service_visits(id, visit_number, scheduled_date, completed_date, status)
      ''').eq('customer_id', customerId).order('created_at', ascending: false);

  return (response as List<dynamic>)
      .map((json) => AmcContract.fromJson(json as Map<String, dynamic>))
      .toList();
});

// AMC expiring soon count for dashboard
final amcExpiringSoonCountProvider = FutureProvider<int>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);

  const supabaseUrl = AppConfig.supabaseUrl;
  if (supabaseUrl.contains('your-project-ref')) {
    return 0;
  }

  final response = await supabase
      .from('amc_contracts')
      .select('id')
      .eq('status', 'expiring_soon');

  return (response as List).length;
});

// Admin toggle: whether "Opt for AMC" button is visible in customer login
class AmcOptEnabledNotifier extends StateNotifier<bool> {
  static const String _key = 'amc_opt_enabled';
  final SupabaseClient? _supabase;

  AmcOptEnabledNotifier([this._supabase]) : super(true) {
    _load();
  }

  Future<void> _load() async {
    // 1. Initial cached value
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getBool(_key);
      if (val != null) {
        state = val;
      }
    } catch (_) {}

    // 2. Fetch authoritative setting from Supabase
    try {
      final client = _supabase ?? Supabase.instance.client;
      final res = await client
          .from('pdf_templates')
          .select('id, template_config')
          .eq('document_type', 'amc_contract')
          .maybeSingle();

      if (res != null && res['template_config'] is Map) {
        final cfg = res['template_config'] as Map;
        if (cfg.containsKey('amc_opt_enabled')) {
          final dbVal = cfg['amc_opt_enabled'] == true;
          state = dbVal;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_key, dbVal);
        }
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (_) {}

    try {
      final client = _supabase ?? Supabase.instance.client;
      final res = await client
          .from('pdf_templates')
          .select('id, template_config')
          .eq('document_type', 'amc_contract')
          .maybeSingle();

      Map<String, dynamic> cfg = {};
      if (res != null && res['template_config'] is Map) {
        cfg = Map<String, dynamic>.from(res['template_config'] as Map);
      }
      cfg['amc_opt_enabled'] = enabled;

      if (res != null) {
        await client.from('pdf_templates').update({
          'template_config': cfg,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', res['id']);
      } else {
        await client.from('pdf_templates').insert({
          'document_type': 'amc_contract',
          'template_name': 'AMC Contract Template',
          'template_config': cfg,
        });
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

final amcOptEnabledProvider =
    StateNotifierProvider<AmcOptEnabledNotifier, bool>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AmcOptEnabledNotifier(supabase);
});
