// lib/core/providers/company_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_company.dart';
import 'supabase_provider.dart';
import '../../features/admin/screens/product_catalog_screen.dart';

final appCompaniesProvider = FutureProvider<List<AppCompany>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final List<AppCompany> companies = [];

  try {
    final response = await supabase
        .from('app_companies')
        .select()
        .order('name');

    final rows = response as List;
    if (rows.isNotEmpty) {
      for (final r in rows) {
        companies.add(AppCompany.fromJson(Map<String, dynamic>.from(r as Map)));
      }
    }
  } catch (e) {
    debugPrint('appCompaniesProvider fetch error: $e');
  }

  // If table is empty or failed, fallback to defaults
  if (companies.isEmpty) {
    companies.addAll(AppCompany.defaultCompanies);
    // Seed them to the database in background if possible
    try {
      await supabase.from('app_companies').upsert(
        AppCompany.defaultCompanies.map((c) => c.toJson()).toList(),
      );
    } catch (_) {}
  }

  // Cache to SharedPreferences
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cached_app_companies',
      jsonEncode(companies.map((c) => c.toJson()).toList()),
    );
  } catch (_) {}

  return companies;
});

final defaultCompanyProvider = Provider<AppCompany>((ref) {
  final asyncVal = ref.watch(appCompaniesProvider);
  return asyncVal.maybeWhen(
    data: (list) => list.firstWhere(
      (c) => c.isDefault,
      orElse: () => list.isNotEmpty ? list.first : AppCompany.defaultInsiyaSolar,
    ),
    orElse: () => AppCompany.defaultInsiyaSolar,
  );
});

final companyForProductProvider = Provider.family<AppCompany, String?>((ref, productIdOrName) {
  final defaultComp = ref.watch(defaultCompanyProvider);
  final companiesAsync = ref.watch(appCompaniesProvider);
  final companies = companiesAsync.valueOrNull ?? AppCompany.defaultCompanies;

  if (productIdOrName == null || productIdOrName.isEmpty) return defaultComp;

  final q = productIdOrName.trim().toLowerCase();
  final isBoomBarrier = q.contains('boom') || q.contains('barrier');

  // If query itself refers to Boom Barrier, resolve immediately to Trading / Sefdor company
  if (isBoomBarrier) {
    final trading = companies.firstWhereOrNull((c) =>
        c.id == 'insiya-trading' ||
        c.name.toLowerCase().contains('trading') ||
        c.name.toLowerCase().contains('sefdor'));
    return (trading ?? AppCompany.defaultInsiyaTrading).copyWith(
      logoUrl: (trading?.logoUrl != null && !trading!.logoUrl!.contains('logo.png'))
          ? trading.logoUrl
          : 'assets/images/boom_barrier/sefdor_logo.png',
    );
  }

  final productsAsync = ref.watch(productsProvider);
  final products = productsAsync.valueOrNull ?? [];
  final product = products.firstWhereOrNull((p) =>
      p.id == productIdOrName ||
      p.name.toLowerCase() == q ||
      p.name.toLowerCase().contains(q));

  if (product != null) {
    if (product.companyId != null && product.companyId!.isNotEmpty) {
      final matched = companies.firstWhereOrNull((c) => c.id == product.companyId);
      if (matched != null) return matched;
    }

    final pName = product.name.toLowerCase();
    if (pName.contains('boom') || pName.contains('barrier')) {
      final trading = companies.firstWhereOrNull((c) =>
          c.id == 'insiya-trading' ||
          c.name.toLowerCase().contains('trading') ||
          c.name.toLowerCase().contains('sefdor'));
      return (trading ?? AppCompany.defaultInsiyaTrading).copyWith(
        logoUrl: (trading?.logoUrl != null && !trading!.logoUrl!.contains('logo.png'))
            ? trading.logoUrl
            : 'assets/images/boom_barrier/sefdor_logo.png',
      );
    }
  }

  return defaultComp;
});

class AppCompanyService {
  final SupabaseClient _supabase;
  final Ref _ref;

  AppCompanyService(this._supabase, this._ref);

  Future<void> saveCompany(AppCompany company) async {
    // 1. If marking as default, unset other defaults first
    if (company.isDefault) {
      try {
        await _supabase.from('app_companies').update({'is_default': false}).neq('id', company.id);
      } catch (_) {}
    }

    // 2. Upsert to app_companies
    await _supabase.from('app_companies').upsert(company.toJson());

    // 3. Sync to company_settings & pdf_templates if this is default company or insiya-solar
    if (company.isDefault || company.id == 'insiya-solar') {
      try {
        await _supabase.from('company_settings').upsert({
          'id': 'default',
          'company_name': company.name,
          'address': company.address,
          'phone': company.phone,
          'email': company.email,
          'gstin': company.gstin,
          if (company.logoUrl != null) 'logo_url': company.logoUrl,
        });

        final templates = await _supabase.from('pdf_templates').select();
        for (final t in templates as List) {
          final config = Map<String, dynamic>.from(t['template_config'] as Map? ?? {});
          config['company_name'] = company.name;
          config['company_address'] = company.address;
          config['company_phone'] = company.phone;
          config['company_email'] = company.email;
          config['company_gst'] = company.gstin;
          if (company.logoUrl != null) config['logo_url'] = company.logoUrl;
          await _supabase.from('pdf_templates').update({'template_config': config}).eq('id', t['id']);
        }
      } catch (_) {}
    }

    // 4. Invalidate provider
    _ref.invalidate(appCompaniesProvider);
  }

  Future<void> setDefaultCompany(String companyId) async {
    await _supabase.from('app_companies').update({'is_default': false}).neq('id', companyId);
    await _supabase.from('app_companies').update({'is_default': true}).eq('id', companyId);

    // Sync to legacy company_settings
    try {
      final compData = await _supabase.from('app_companies').select().eq('id', companyId).maybeSingle();
      if (compData != null) {
        final comp = AppCompany.fromJson(compData);
        await _supabase.from('company_settings').upsert({
          'id': 'default',
          'company_name': comp.name,
          'address': comp.address,
          'phone': comp.phone,
          'email': comp.email,
          'gstin': comp.gstin,
          if (comp.logoUrl != null) 'logo_url': comp.logoUrl,
        });
      }
    } catch (_) {}

    _ref.invalidate(appCompaniesProvider);
  }

  Future<void> deleteCompany(String companyId) async {
    if (companyId == 'insiya-solar' || companyId == 'insiya-trading') {
      throw Exception('Built-in company profiles cannot be deleted.');
    }
    await _supabase.from('app_companies').delete().eq('id', companyId);
    _ref.invalidate(appCompaniesProvider);
  }

  Future<void> assignProductCompany(String productId, String companyId) async {
    // 1. Fetch current product base_specs
    final prodData = await _supabase.from('products').select('base_specs').eq('id', productId).single();
    final specs = Map<String, dynamic>.from((prodData['base_specs'] as Map?) ?? {});
    specs['company_id'] = companyId;

    // 2. Update column and base_specs
    await _supabase.from('products').update({
      'company_id': companyId,
      'base_specs': specs,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', productId);

    _ref.invalidate(productsProvider);
  }
}

final appCompanyServiceProvider = Provider<AppCompanyService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AppCompanyService(supabase, ref);
});

extension IterableExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
