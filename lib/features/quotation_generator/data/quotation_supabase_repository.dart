// lib/features/quotation_generator/data/quotation_supabase_repository.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/quotation_generator_flags.dart';
import '../config/quote_type.dart';
import '../models/generator_company_settings.dart';
import '../models/generator_quotation.dart';
import '../models/heat_pump_model.dart';
import '../models/price_item.dart';
import '../models/price_row.dart';
import '../models/tank_spec.dart';
import '../services/quote_number_service.dart';
import '../services/quotation_storage_service.dart';
import 'catalog_repository.dart';

class QuotationSupabaseRepository {
  final SupabaseClient _supabase;

  // In-memory cache for offline resilience and fast loads
  GeneratorCompanySettings? _cachedSettings;

  QuotationSupabaseRepository(this._supabase);

  // ─── SETTINGS & CATALOG OVER SUPABASE ──────────────────────────────────────

  Future<GeneratorCompanySettings> getSettings() async {
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
            return filled;
          }
          _cachedSettings = settings;
          return settings;
        }
      }
    } catch (e) {
      debugPrint('QuotationSupabaseRepository.getSettings Supabase error: $e');
    }

    if (_cachedSettings != null) return _cachedSettings!;

    // Seed default settings from bundled JSON and persist to Supabase
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
      debugPrint('Could not initial-seed Supabase pdf_templates: $e');
    }

    return initial;
  }

  Future<void> saveSettings(GeneratorCompanySettings settings) async {
    _cachedSettings = settings;
    if (kDisableUnsafeExistingWrites) {
      debugPrint('[CONTAINMENT GUARD] saveSettings: Writes to legacy "pdf_templates" table are disabled.');
      return;
    }
    try {
      final existing = await _supabase
          .from('pdf_templates')
          .select('id, template_config')
          .eq('document_type', 'quotation')
          .maybeSingle();

      Map<String, dynamic> mergedConfig = {};
      if (existing != null && existing['template_config'] is Map) {
        mergedConfig = Map<String, dynamic>.from(existing['template_config'] as Map);
      }

      // Merge generator settings
      mergedConfig['generator_company_settings'] = settings.toJson();
      // Also update top level company details for global PDF compatibility
      mergedConfig['company_name'] = settings.companyName;
      mergedConfig['company_address'] = settings.companyAddress;
      mergedConfig['company_phone'] = settings.companyPhone;
      mergedConfig['company_email'] = settings.companyEmail;
      mergedConfig['company_website'] = settings.companyWebsite;

      if (existing != null) {
        await _supabase.from('pdf_templates').update({
          'template_config': mergedConfig,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existing['id']);
      } else {
        await _supabase.from('pdf_templates').insert({
          'document_type': 'quotation',
          'template_config': mergedConfig,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('QuotationSupabaseRepository.saveSettings error: $e');
      rethrow;
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

  Future<List<GeneratorQuotation>> getAllQuotations() async {
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
    if (kDisableUnsafeExistingWrites) {
      debugPrint('[CONTAINMENT GUARD] saveQuotation: Unsafe writes to legacy "quotations" table are disabled.');
      return;
    }
    String? publicPdfUrl = quotation.pdfUrl;

    // Upload generated PDF to Supabase Storage if bytes provided
    if (pdfBytes != null) {
      try {
        final uploadedUrl = await QuotationStorageService.uploadQuotationPdf(
          supabase: _supabase,
          pdfBytes: pdfBytes,
          quotationNumber: quotation.quoteRefNo,
        );
        if (uploadedUrl != null) {
          publicPdfUrl = uploadedUrl;
        }
      } catch (e) {
        debugPrint('Error uploading PDF to Supabase Storage: $e');
      }
    }

    final updatedQuotation = quotation.copyWith(
      pdfUrl: publicPdfUrl,
      updatedAt: DateTime.now(),
    );

    // Map items to standard line_items column
    List<Map<String, dynamic>> lineItems = [];
    if (updatedQuotation.priceRows.isNotEmpty) {
      lineItems = updatedQuotation.priceRows.map((r) {
        return {
          'description': r.description,
          'hsn_sac': '84191920',
          'qty': r.qty,
          'uom': r.unitLabel ?? 'NOS',
          'unit_price': r.status == PriceRowStatus.priced ? r.rate.toDouble() : 0.0,
          'total': r.status == PriceRowStatus.priced ? r.amount.toDouble() : 0.0,
          'status': r.status.label,
          'gst_percent': updatedQuotation.gstPercent,
        };
      }).toList();
    } else {
      lineItems = [
        {
          'description': 'Air Source Heat Pump Model: ${updatedQuotation.model.modelName}',
          'hsn_sac': '84191920',
          'qty': updatedQuotation.heatPumpQty,
          'uom': 'SET',
          'unit_price': updatedQuotation.heatPumpAmountType == PriceRowType.included
              ? 0.0
              : updatedQuotation.heatPumpNumericPrice.toDouble(),
          'total': updatedQuotation.heatPumpAmountType == PriceRowType.included
              ? 0.0
              : (updatedQuotation.heatPumpNumericPrice * updatedQuotation.heatPumpQty).toDouble(),
          'gst_percent': updatedQuotation.gstPercent,
        },
        {
          'description': 'Hot Water Storage Tank (${updatedQuotation.tankCapacityLitres}L)',
          'hsn_sac': '841919',
          'qty': updatedQuotation.tankQty,
          'uom': 'NOS',
          'unit_price': updatedQuotation.tankRate.toDouble(),
          'total': (updatedQuotation.tankRate * updatedQuotation.tankQty).toDouble(),
          'gst_percent': updatedQuotation.gstPercent,
        },
        for (final extra in updatedQuotation.extraPriceRows)
          {
            'description': extra.description,
            'hsn_sac': '84191920',
            'qty': 1,
            'uom': 'LOT',
            'unit_price': extra.numericAmount.toDouble(),
            'total': extra.numericAmount.toDouble(),
            'gst_percent': updatedQuotation.gstPercent,
          },
      ];
    }

    // Map payment terms to standard payment_terms column
    final paymentTerms = [
      {
        'term': 'Advance',
        'percent': updatedQuotation.paymentSplitAdvance,
        'amount': updatedQuotation.grandTotal * (updatedQuotation.paymentSplitAdvance / 100.0),
      },
      {
        'term': 'Delivery',
        'percent': updatedQuotation.paymentSplitDelivery,
        'amount': updatedQuotation.grandTotal * (updatedQuotation.paymentSplitDelivery / 100.0),
      },
      {
        'term': 'Commissioning',
        'percent': updatedQuotation.paymentSplitCommissioning,
        'amount': updatedQuotation.grandTotal * (updatedQuotation.paymentSplitCommissioning / 100.0),
      },
    ];

    final halfGst = (updatedQuotation.gstAmount / 2.0);

    final data = {
      'id': updatedQuotation.id,
      'quotation_number': updatedQuotation.quoteRefNo,
      'customer_name': updatedQuotation.customerName,
      'customer_phone': updatedQuotation.customerMobile,
      'billing_address': updatedQuotation.customerAddress,
      'shipping_address': updatedQuotation.customerAddress,
      'line_items': lineItems,
      'subtotal': updatedQuotation.subtotal.toDouble(),
      'cgst_rate': updatedQuotation.gstPercent / 2.0,
      'sgst_rate': updatedQuotation.gstPercent / 2.0,
      'cgst_amount': halfGst,
      'sgst_amount': halfGst,
      'igst_amount': 0.0,
      'grand_total': updatedQuotation.netPayable.toDouble(),
      'terms_text': updatedQuotation.paymentTermsText,
      'pdf_url': publicPdfUrl,
      'status': updatedQuotation.status.toLowerCase(),
      'remarks': updatedQuotation.subjectLine,
      'product_specs': {
        'generator_quotation': updatedQuotation.toJson(),
        'generator_version': 'phase_2',
        'quote_type': updatedQuotation.quoteType.id,
        'model_name': updatedQuotation.model.modelName,
        'capacity_kw': updatedQuotation.model.displayCapacityKw,
      },
      'payment_terms': paymentTerms,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('quotations').upsert(data);
    } catch (e) {
      debugPrint('QuotationSupabaseRepository.saveQuotation error: $e');
      rethrow;
    }
  }

  Future<void> deleteQuotation(String id) async {
    if (kDisableUnsafeExistingWrites) {
      debugPrint('[CONTAINMENT GUARD] deleteQuotation: Writes to legacy "quotations" table are disabled.');
      return;
    }
    try {
      await _supabase.from('quotations').update({
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } catch (e) {
      debugPrint('QuotationSupabaseRepository.deleteQuotation error: $e');
      rethrow;
    }
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
      final gstAmount = (row['cgst_amount'] as num? ?? 0.0) + (row['sgst_amount'] as num? ?? 0.0);
      final createdAt = row['created_at'] != null ? DateTime.parse(row['created_at']) : DateTime.now();
      final updatedAt = row['updated_at'] != null ? DateTime.parse(row['updated_at']) : createdAt;
      final rawStatus = row['status'] as String?;
      final status = (rawStatus != null && rawStatus.trim().isNotEmpty)
          ? rawStatus.trim()
          : 'Draft';

      return GeneratorQuotation(
        id: id,
        quoteType: QuoteType.hpWithTank,
        status: status,
        customerName: cName,
        customerAddress: cAddr,
        customerMobile: cPhone,
        date: createdAt,
        quoteRefNo: qNum,
        salesRef: 'Insiya Sales',
        salesMobile: '+91 9292922992',
        model: const HeatPumpModel(
          id: 'IZ-4C',
          modelName: 'IZ-4C',
          displayCapacityKw: 4.0,
          ratedHeatingCapacity: '3.6kw',
          descriptionLine: 'Air Source Heat pump 3.6kw',
          makeModelLine: 'Make: IZYHEAT Heat Pump Model: IZ-4C 3.6kw',
          powerInputText: 'Power Input 0.86kw, output 3.6kw, 220V - 1Phase, 50Hz With Auto Defrost.',
        ),
        tankRate: subtotal.toInt(),
        tankSpec: const TankSpec(),
        extraPriceRows: const [],
        subtotal: subtotal.toInt(),
        gstAmount: gstAmount.toInt(),
        grandTotal: grandTotal.toInt(),
        termsAndConditions: const [
          'Proper 1 / 3 Phase power should be arranged where you install the heat pump.',
          'Electrical/civil/plumbing work materials – Customer Scope.',
          'Safe storage place need to be provided by you to keep our material & tools.',
        ],
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e) {
      debugPrint('_mapStandardRowToGeneratorQuotation error: $e');
      return null;
    }
  }
}
