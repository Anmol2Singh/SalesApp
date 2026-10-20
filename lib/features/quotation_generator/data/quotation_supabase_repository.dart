// lib/features/quotation_generator/data/quotation_supabase_repository.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/quotation_generator_flags.dart';
import '../models/generator_company_settings.dart';
import '../models/generator_quotation.dart';
import '../services/quote_number_service.dart';
import '../models/deal_quotation_item.dart';
import '../models/qg_proposal_draft.dart';
import 'catalog_repository.dart';

class QuotationSupabaseRepository {
  final SupabaseClient _supabase;

  // In-memory cache for offline resilience and fast loads
  GeneratorCompanySettings? _cachedSettings;

  QuotationSupabaseRepository(this._supabase);

  // ─── SETTINGS & CATALOG OVER SUPABASE ──────────────────────────────────────

  Future<GeneratorCompanySettings> getSettings() async {
    // 1. Try reading from qg_settings in Supabase
    try {
      final qgRes = await _supabase
          .from('qg_settings')
          .select('value')
          .eq('key', 'generator_company_settings')
          .maybeSingle();

      if (qgRes != null && qgRes['value'] is Map) {
        final settingsMap = Map<String, dynamic>.from(qgRes['value'] as Map);
        final settings = GeneratorCompanySettings.fromJson(settingsMap);
        if (settings.models.isNotEmpty) {
          _cachedSettings = settings;
          return settings;
        }
      }
    } catch (e) {
      debugPrint('QuotationSupabaseRepository.getSettings qg_settings error: $e');
    }

    // 2. Fallback to pdf_templates
    try {
      final res = await _supabase
          .from('pdf_templates')
          .select('id, template_config')
          .eq('document_type', 'quotation')
          .maybeSingle();

      if (res != null && res['template_config'] != null) {
        final config = res['template_config'];
        Map<String, dynamic> map;
        if (config is String) {
          map = jsonDecode(config) as Map<String, dynamic>;
        } else if (config is Map) {
          map = Map<String, dynamic>.from(config);
        } else {
          map = {};
        }

        if (map.isNotEmpty) {
          final settingsMap = map['generator_company_settings'] is Map
              ? Map<String, dynamic>.from(map['generator_company_settings'] as Map)
              : map;

          final settings = GeneratorCompanySettings.fromJson(settingsMap);
          if (settings.models.isEmpty) {
            final bundledHp = await CatalogRepository.loadBundledModels();
            final bundledPool = await CatalogRepository.loadBundledPoolModels();
            final bundledAio = await CatalogRepository.loadBundledAllInOneModels();
            final filled = settings.copyWith(
              models: bundledHp,
              poolModels: bundledPool,
              allInOneModels: bundledAio,
            );
            _cachedSettings = filled;
            // Seed to qg_settings
            await saveSettings(filled);
            return filled;
          }
          _cachedSettings = settings;
          await saveSettings(settings);
          return settings;
        }
      }
    } catch (e) {
      debugPrint('QuotationSupabaseRepository.getSettings Supabase error: $e');
    }

    if (_cachedSettings != null) return _cachedSettings!;

    // Seed default settings from bundled JSON and persist to Supabase qg_settings
    final bundledHp = await CatalogRepository.loadBundledModels();
    final bundledPool = await CatalogRepository.loadBundledPoolModels();
    final bundledAio = await CatalogRepository.loadBundledAllInOneModels();
    final initial = GeneratorCompanySettings(
      models: bundledHp,
      poolModels: bundledPool,
      allInOneModels: bundledAio,
    );
    _cachedSettings = initial;

    try {
      await saveSettings(initial);
    } catch (e) {
      debugPrint('Could not initial-seed Supabase qg_settings: $e');
    }

    return initial;
  }

  Future<void> saveSettings(GeneratorCompanySettings settings) async {
    _cachedSettings = settings;
    try {
      await _supabase.from('qg_settings').upsert({
        'key': 'generator_company_settings',
        'value': settings.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('✓ GeneratorCompanySettings saved to Supabase qg_settings');
    } catch (e) {
      debugPrint('QuotationSupabaseRepository.saveSettings error: $e');
    }
  }

  Future<int> getAndIncrementNextRunningNumber() async {
    int nextNumber = 1;
    try {
      final res = await _supabase
          .from('quotations')
          .select('quotation_number')
          .order('created_at', ascending: false)
          .limit(100);

      int maxFound = 0;
      for (final row in res) {
        final qNum = row['quotation_number'] as String?;
        if (qNum != null) {
          final match = RegExp(r'(\d+)$').firstMatch(qNum.trim());
          if (match != null) {
            final n = int.tryParse(match.group(1)!) ?? 0;
            if (n > maxFound) maxFound = n;
          }
        }
      }

      final settings = await getSettings();
      nextNumber = maxFound >= settings.nextRunningNumber
          ? maxFound + 1
          : settings.nextRunningNumber;

      // Update settings with the next running number in Supabase
      if (!kDisableUnsafeExistingWrites) {
        try {
          await saveSettings(settings.copyWith(nextRunningNumber: nextNumber + 1));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('QuotationSupabaseRepository.getAndIncrementNextRunningNumber error: $e');
      final settings = await getSettings();
      nextNumber = settings.nextRunningNumber;
    }

    return nextNumber;
  }

  // ─── QUOTATIONS OVER SUPABASE ──────────────────────────────────────────────

  Future<List<GeneratorQuotation>> getAllQuotations({
    String? currentUserId,
    String? currentUserName,
    bool canViewAll = true,
  }) async {
    try {
      final response = await _supabase
          .from('quotations')
          .select()
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final List<GeneratorQuotation> list = [];
      for (final row in response) {
        try {
          final rowMap = Map<String, dynamic>.from(row as Map);
          final specs = rowMap['product_specs'];

          if (!canViewAll) {
            final qCreatedBy = rowMap['created_by'] as String?;
            final qSalesman = (rowMap['salesman'] as String?)?.trim();
            final uId = currentUserId?.trim();
            final uName = currentUserName?.trim().toLowerCase();

            bool matches = false;
            if (uId != null && uId.isNotEmpty && qCreatedBy == uId) {
              matches = true;
            }
            if (!matches && uName != null && uName.isNotEmpty && qSalesman != null && qSalesman.toLowerCase() == uName) {
              matches = true;
            }
            if (!matches && specs is Map && specs['generator_quotation'] != null) {
              final gqSalesman = (specs['generator_quotation']['salesman'] as String?)?.trim().toLowerCase();
              if (uName != null && uName.isNotEmpty && gqSalesman != null && gqSalesman == uName) {
                matches = true;
              }
            }
            if (!matches) continue;
          }

          if (specs is Map && specs['generator_quotation'] != null) {
            final gqMap = Map<String, dynamic>.from(specs['generator_quotation'] as Map);
            list.add(GeneratorQuotation.fromJson(gqMap));
          } else {
            // Convert general Supabase quotation row into a GeneratorQuotation
            final gq = _mapStandardRowToGeneratorQuotation(rowMap);
            if (gq != null) list.add(gq);
          }
        } catch (e) {
          debugPrint('Error parsing quotation row: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('QuotationSupabaseRepository.getAllQuotations error: $e');
      return [];
    }
  }

  Future<GeneratorQuotation?> getQuotation(String id) async {
    try {
      final row = await _supabase
          .from('quotations')
          .select()
          .eq('id', id)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (row == null) return null;
      final rowMap = Map<String, dynamic>.from(row);
      final specs = rowMap['product_specs'];

      if (specs is Map && specs['generator_quotation'] != null) {
        return GeneratorQuotation.fromJson(Map<String, dynamic>.from(specs['generator_quotation'] as Map));
      }
      return _mapStandardRowToGeneratorQuotation(rowMap);
    } catch (e) {
      debugPrint('QuotationSupabaseRepository.getQuotation error: $e');
      return null;
    }
  }

  Future<void> saveQuotation(GeneratorQuotation quotation, {Uint8List? pdfBytes}) async {
    debugPrint('[CONTAINMENT GUARD] saveQuotation: Unsafe writes to core "quotations" table are retired.');
  }

  Future<void> deleteQuotation(String id) async {
    debugPrint('[CONTAINMENT GUARD] deleteQuotation: Writes to legacy "quotations" table are retired.');
  }

  Future<GeneratorQuotation> duplicateQuotation(GeneratorQuotation q) async {
    final settings = await getSettings();
    final nextNum = await getAndIncrementNextRunningNumber();
    final now = DateTime.now();
    final newRef = QuoteNumberService.formatQuoteRef(
      prefix: settings.quotePrefix,
      date: now,
      runningNumber: nextNum,
    );

    final duplicated = q.copyWith(
      id: const Uuid().v4(),
      quoteRefNo: newRef,
      date: now,
      status: 'Draft',
      createdAt: now,
      updatedAt: now,
    );

    await saveQuotation(duplicated);
    return duplicated;
  }

  // ─── HELPER: MAP LEGACY / APP QUOTATION ROW ────────────────────────────────

  GeneratorQuotation? _mapStandardRowToGeneratorQuotation(Map<String, dynamic> row) {
    try {
      final id = row['id'] as String? ?? const Uuid().v4();
      final qNum = row['quotation_number'] as String? ?? 'IZY/QT/0001';
      final cName = row['customer_name'] as String? ?? 'Valued Customer';
      final cPhone = row['customer_phone'] as String? ?? '';
      final cAddr = row['billing_address'] as String? ?? '';
      final subtotal = (row['subtotal'] as num?)?.toDouble() ?? 0.0;
      final grandTotal = (row['grand_total'] as num?)?.toDouble() ?? subtotal;
      final cgstAmt = (row['cgst_amount'] as num?)?.toDouble() ?? 0.0;
      final sgstAmt = (row['sgst_amount'] as num?)?.toDouble() ?? 0.0;
      final igstAmt = (row['igst_amount'] as num?)?.toDouble() ?? 0.0;
      final cgstRate = (row['cgst_rate'] as num?)?.toDouble() ?? 9.0;
      final sgstRate = (row['sgst_rate'] as num?)?.toDouble() ?? 9.0;
      final createdAt = row['created_at'] != null ? DateTime.parse(row['created_at']) : DateTime.now();
      final updatedAt = row['updated_at'] != null ? DateTime.parse(row['updated_at']) : createdAt;
      final rawStatus = row['status'] as String?;
      final status = (rawStatus != null && rawStatus.trim().isNotEmpty)
          ? rawStatus.trim()
          : 'Draft';
      final orderDate = row['order_date'] != null ? (DateTime.tryParse(row['order_date']) ?? createdAt) : createdAt;

      // Extract line items
      List<Map<String, dynamic>> rawLineItems = [];
      if (row['line_items'] is List) {
        rawLineItems = (row['line_items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      // Supplementary terms
      List<Map<String, dynamic>> suppTerms = [];
      if (row['supplementary_terms'] is List) {
        suppTerms = (row['supplementary_terms'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      // Payment terms
      List<Map<String, dynamic>> payTerms = [];
      if (row['payment_terms'] is List) {
        payTerms = (row['payment_terms'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      final prodName = row['product_name'] as String? ?? row['product_id'] as String? ?? '';

      final dealItem = DealQuotationItem(
        id: id,
        quotationNumber: qNum,
        status: status,
        revision: (row['revision'] as num?)?.toInt() ?? 1,
        orderDate: orderDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
        customerName: cName,
        customerPhone: cPhone,
        customerAddress: cAddr,
        customerGst: row['customer_gstin'] as String?,
        salesmanName: row['salesman'] as String? ?? 'Insiya Sales',
        salesmanPhone: '+91 9292922992',
        subtotal: subtotal,
        supplementarySubtotal: (row['supplementary_subtotal'] as num?)?.toDouble() ?? 0.0,
        cgstAmount: cgstAmt,
        sgstAmount: sgstAmt,
        igstAmount: igstAmt,
        grandTotal: grandTotal,
        cgstRate: cgstRate,
        sgstRate: sgstRate,
        igstRate: igstAmt > 0 ? (cgstRate + sgstRate) : 0.0,
        lineItems: rawLineItems,
        supplementaryTerms: suppTerms,
        paymentTerms: payTerms,
        termsText: row['terms_text'] as String?,
        pipelineId: row['pipeline_id'] as String?,
        productId: row['product_id'] as String?,
        productName: prodName.isNotEmpty ? prodName : 'Heat Pump',
      );

      final draft = QgProposalDraft.fromDealQuotation(dealItem);
      return draft.toGeneratorQuotation();
    } catch (e) {
      debugPrint('_mapStandardRowToGeneratorQuotation error: $e');
      return null;
    }
  }
}
