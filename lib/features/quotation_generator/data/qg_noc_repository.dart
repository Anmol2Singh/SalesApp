// lib/features/quotation_generator/data/qg_noc_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/qg_noc_builder_state.dart';
import '../models/qg_noc_document.dart';
import '../models/qg_noc_profile.dart';

class QgNocRepository {
  final SupabaseClient _supabase;

  QgNocRepository(this._supabase);

  // --------------------------------------------------------------------------
  // Profiles
  // --------------------------------------------------------------------------

  Future<List<QgNocProfile>> getProfiles() async {
    try {
      final res = await _supabase
          .from('qg_noc_profiles')
          .select()
          .order('product_name');

      return res.map((e) => QgNocProfile.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      debugPrint('QgNocRepository.getProfiles error: $e');
    }
    return [
      QgNocProfile.defaultProfile(),
    ];
  }

  Future<QgNocProfile> getProfileForProduct(String productName) async {
    try {
      final res = await _supabase
          .from('qg_noc_profiles')
          .select()
          .ilike('product_name', productName.trim())
          .maybeSingle();

      if (res != null) {
        return QgNocProfile.fromMap(Map<String, dynamic>.from(res));
      }

      // Check default profile
      final def = await _supabase
          .from('qg_noc_profiles')
          .select()
          .eq('product_name', 'Default')
          .maybeSingle();

      if (def != null) {
        return QgNocProfile.fromMap(Map<String, dynamic>.from(def));
      }
    } catch (e) {
      debugPrint('QgNocRepository.getProfileForProduct error: $e');
    }
    if (productName.toLowerCase().contains('heat pump')) {
      return QgNocProfile.defaultHeatPumpProfile();
    }
    if (productName.toLowerCase().contains('boom') || productName.toLowerCase().contains('barrier')) {
      return QgNocProfile.defaultBoomBarrierProfile();
    }
    return QgNocProfile.defaultProfile(productName: productName);
  }

  Future<void> updateProfileConfirmations(String profileId, List<String> confirmations) async {
    try {
      await _supabase
          .from('qg_noc_profiles')
          .update({'confirmation_lines': confirmations})
          .eq('id', profileId);
    } catch (e) {
      debugPrint('QgNocRepository.updateProfileConfirmations error: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // Documents
  // --------------------------------------------------------------------------

  Future<List<QgNocDocument>> getDocumentsForPipeline(String pipelineId) async {
    try {
      final res = await _supabase
          .from('qg_noc_documents')
          .select()
          .eq('pipeline_id', pipelineId)
          .order('version', ascending: false);

      return res.map((e) => QgNocDocument.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      debugPrint('QgNocRepository.getDocumentsForPipeline error: $e');
    }
    return [];
  }

  Future<QgNocDocument?> getCurrentDocument(String pipelineId) async {
    try {
      final res = await _supabase
          .from('qg_noc_documents')
          .select()
          .eq('pipeline_id', pipelineId)
          .eq('is_current', true)
          .maybeSingle();

      if (res != null) {
        return QgNocDocument.fromMap(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      debugPrint('QgNocRepository.getCurrentDocument error: $e');
    }
    return null;
  }

  // --------------------------------------------------------------------------
  // Finalize NOC via SECURITY DEFINER RPC
  // --------------------------------------------------------------------------

  Future<QgNocDocument> finalizeNoc({
    required String pipelineId,
    required Map<String, dynamic> payload,
    required String pdfPath,
    String? overrideReason,
  }) async {
    try {
      final res = await _supabase.rpc(
        'qg_finalize_noc',
        params: {
          'p_pipeline_id': pipelineId,
          'p_payload': payload,
          'p_pdf_path': pdfPath,
          'p_override_reason': overrideReason,
        },
      );

      if (res != null && res is Map) {
        return QgNocDocument.fromMap(Map<String, dynamic>.from(res));
      }
      throw Exception('Unexpected response from qg_finalize_noc: $res');
    } catch (e) {
      debugPrint('QgNocRepository.finalizeNoc error: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // PDF Storage Upload
  // --------------------------------------------------------------------------

  Future<String> uploadNocPdf({
    required String pipelineId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = 'noc/$pipelineId/$fileName';
    try {
      await _supabase.storage.from('quotation-generator').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );
      return path;
    } catch (e) {
      debugPrint('QgNocRepository.uploadNocPdf error: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // Deals Listing for NOC Hub (READ-ONLY)
  // --------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchDealsForNocHub() async {
    try {
      final res = await _supabase
          .from('sales_pipelines')
          .select('''
            id,
            status,
            current_step,
            created_at,
            customer_id,
            product_id,
            customers(id, name, company_name, phone, address),
            products(id, name, category),
            quotations(id, quotation_number, line_items, status)
          ''')
          .order('created_at', ascending: false);

      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('QgNocRepository.fetchDealsForNocHub error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchInstallationsForCustomer(String customerId) async {
    try {
      final res = await _supabase
          .from('installations')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('QgNocRepository.fetchInstallationsForCustomer error: $e');
    }
    return [];
  }

  // --------------------------------------------------------------------------
  // Static Convenience Methods
  // --------------------------------------------------------------------------

  static QgNocRepository get instance => QgNocRepository(Supabase.instance.client);

  static Future<List<QgNocProfile>> fetchProfiles() => instance.getProfiles();

  static Future<void> saveProfileConfirmations(String profileId, List<String> confirmations) =>
      instance.updateProfileConfirmations(profileId, confirmations);

  static Future<List<QgNocDocument>> listNocs({
    String? dealId,
    String? search,
    NocStatus? status,
  }) async {
    try {
      var query = Supabase.instance.client.from('qg_noc_documents').select();
      if (dealId != null && dealId.isNotEmpty) {
        query = query.eq('pipeline_id', dealId);
      }
      final res = await query.order('created_at', ascending: false);
      var list = res.map((e) => QgNocDocument.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      if (search != null && search.isNotEmpty) {
        final s = search.toLowerCase();
        list = list.where((d) =>
          d.nocNumber.toLowerCase().contains(s) ||
          d.customerName.toLowerCase().contains(s) ||
          d.productName.toLowerCase().contains(s)
        ).toList();
      }
      if (status != null) {
        list = list.where((d) => d.status == status).toList();
      }
      return list;
    } catch (e) {
      debugPrint('QgNocRepository.listNocs error: $e');
    }
    return [];
  }

  static Future<QgNocDocument?> fetchNocById(String id) async {
    try {
      final res = await Supabase.instance.client
          .from('qg_noc_documents')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (res != null) {
        return QgNocDocument.fromMap(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      debugPrint('QgNocRepository.fetchNocById error: $e');
    }
    return null;
  }

  static Future<QgNocDocument> saveDraft({
    String? dealId,
    String? quotationId,
    required String customerName,
    required String siteAddress,
    required String productName,
    required NocWordingMode wordingMode,
    required List<NocEquipmentLine> equipmentLines,
    required Map<String, dynamic> companySnapshot,
    List<String>? confirmations,
    String? closingSentence,
  }) async {
    final payload = {
      'status': 'draft',
      'customer_name': customerName,
      'site_address': siteAddress,
      'product_name': productName,
      'wording_mode': wordingMode == NocWordingMode.enhanced ? 'enhanced' : 'template_exact',
      'equipment_lines': equipmentLines.map((e) => e.toMap()).toList(),
      'company_snapshot': companySnapshot,
      if (confirmations != null && confirmations.isNotEmpty) 'confirmations': confirmations,
      if (closingSentence != null && closingSentence.isNotEmpty) 'closing_sentence': closingSentence,
    };

    final docMap = {
      'pipeline_id': dealId ?? '00000000-0000-0000-0000-000000000000',
      'quotation_id': quotationId,
      'noc_no': 'DRAFT-${DateTime.now().millisecondsSinceEpoch}',
      'version': 1,
      'is_current': true,
      'issued_on': DateTime.now().toIso8601String().split('T').first,
      'payload': payload,
    };

    final res = await Supabase.instance.client
        .from('qg_noc_documents')
        .insert(docMap)
        .select()
        .single();

    return QgNocDocument.fromMap(Map<String, dynamic>.from(res as Map));
  }

  static Future<Map<String, dynamic>> fetchCompanyDetailsFromTemplate(
    SupabaseClient supabase, {
    String? productId,
    String? productName,
  }) async {
    // 1. Check if product has assigned company in app_companies
    try {
      String? companyId;
      if (productId != null && productId.isNotEmpty) {
        final pRes = await supabase.from('products').select('company_id, base_specs').eq('id', productId).maybeSingle();
        if (pRes != null) {
          companyId = pRes['company_id'] as String? ?? (pRes['base_specs'] is Map ? (pRes['base_specs'] as Map)['company_id'] as String? : null);
        }
      }

      if (companyId == null && productName != null) {
        final pLower = productName.toLowerCase();
        if (pLower.contains('boom') || pLower.contains('barrier')) {
          companyId = 'insiya-trading';
        } else if (pLower.contains('heat') || pLower.contains('pump')) {
          companyId = 'insiya-solar';
        }
      }

      if (companyId != null && companyId.isNotEmpty) {
        final compRes = await supabase.from('app_companies').select().eq('id', companyId).maybeSingle();
        if (compRes != null) {
          return {
            'company_name': compRes['name'],
            'company_address': compRes['address'],
            'company_phone': compRes['phone'],
            'company_email': compRes['email'],
            'company_website': compRes['website'],
            'logo_url': compRes['logo_url'],
            'stamp_url': compRes['stamp_url'],
          };
        }
      } else {
        final defRes = await supabase.from('app_companies').select().eq('is_default', true).limit(1).maybeSingle();
        if (defRes != null) {
          return {
            'company_name': defRes['name'],
            'company_address': defRes['address'],
            'company_phone': defRes['phone'],
            'company_email': defRes['email'],
            'company_website': defRes['website'],
            'logo_url': defRes['logo_url'],
            'stamp_url': defRes['stamp_url'],
          };
        }
      }
    } catch (_) {}

    try {
      final tRes = await supabase
          .from('pdf_templates')
          .select('template_config')
          .eq('document_type', 'quotation')
          .maybeSingle();

      if (tRes != null && tRes['template_config'] is Map) {
        final cfg = Map<String, dynamic>.from(tRes['template_config'] as Map);
        if (cfg['company_name']?.toString().trim().isNotEmpty == true) {
          return cfg;
        }
      }
    } catch (_) {}

    try {
      final tRes = await supabase
          .from('pdf_templates')
          .select('template_config')
          .limit(1)
          .maybeSingle();

      if (tRes != null && tRes['template_config'] is Map) {
        final cfg = Map<String, dynamic>.from(tRes['template_config'] as Map);
        if (cfg['company_name']?.toString().trim().isNotEmpty == true) {
          return cfg;
        }
      }
    } catch (_) {}

    return {
      'company_name': 'INSIYA TRADING CORPORATION',
      'company_address': 'Plot No 23, Sector 19, Vashi, Navi Mumbai, Maharashtra - 400703',
      'company_email': 'insiyatrading@gmail.com',
      'company_phone': '+91 99999 99999',
      'company_website': 'www.insiyatrading.com',
    };
  }

  static Future<QgNocDocument> finalizeAndIssueNoc({
    String? dealId,
    String? quotationId,
    required String customerName,
    required String siteAddress,
    required String productName,
    required NocWordingMode wordingMode,
    required List<NocEquipmentLine> equipmentLines,
    required Uint8List pdfBytes,
    required Map<String, dynamic> companySnapshot,
    List<String>? confirmations,
    String? closingSentence,
    String? overrideReason,
  }) async {
    final client = Supabase.instance.client;
    final pipelineId = dealId ?? '00000000-0000-0000-0000-000000000000';

    final payload = {
      'status': 'issued',
      'customer_name': customerName,
      'site_address': siteAddress,
      'product_name': productName,
      'wording_mode': wordingMode == NocWordingMode.enhanced ? 'enhanced' : 'template_exact',
      'equipment_lines': equipmentLines.map((e) => e.toMap()).toList(),
      'company_snapshot': companySnapshot,
      if (confirmations != null && confirmations.isNotEmpty) 'confirmations': confirmations,
      if (closingSentence != null && closingSentence.isNotEmpty) 'closing_sentence': closingSentence,
    };

    // Generate virtual pdf reference (no file stored in Supabase storage as per requirement)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'noc_${pipelineId}_$timestamp.pdf';
    final pdfPath = 'virtual/noc/$fileName';

    // Check if an existing NOC already exists for this deal (strictly 1 per deal)
    if (pipelineId != '00000000-0000-0000-0000-000000000000') {
      try {
        final existingDocs = await client
            .from('qg_noc_documents')
            .select()
            .eq('pipeline_id', pipelineId)
            .order('version', ascending: false)
            .limit(1);

        if (existingDocs.isNotEmpty) {
          final existing = Map<String, dynamic>.from(existingDocs.first as Map);
          final updated = await client
              .from('qg_noc_documents')
              .update({
                'payload': payload,
                'pdf_path': pdfPath,
                'status': 'issued',
                'issued_on': DateTime.now().toIso8601String().split('T').first,
              })
              .eq('id', existing['id'])
              .select()
              .single();
          return QgNocDocument.fromMap(Map<String, dynamic>.from(updated));
        }
      } catch (e) {
        debugPrint('Warning: Check existing NOC error: $e');
      }
    }

    final effectiveOverrideReason = (overrideReason != null && overrideReason.trim().isNotEmpty)
        ? overrideReason.trim()
        : 'Completed deal installation & commissioning verified for $productName';

    // Call RPC to create new NOC
    final res = await client.rpc(
      'qg_finalize_noc',
      params: {
        'p_pipeline_id': pipelineId,
        'p_payload': payload,
        'p_pdf_path': pdfPath,
        'p_override_reason': effectiveOverrideReason,
      },
    );

    return QgNocDocument.fromMap(Map<String, dynamic>.from(res as Map));
  }

  /// Deletes an issued NOC from a deal so it can be re-generated if required.
  static Future<void> deleteNoc(String docId) async {
    final client = Supabase.instance.client;
    await client.from('qg_noc_documents').delete().eq('id', docId);
  }
}
