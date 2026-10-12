// lib/features/quotation_generator/data/deal_quotations_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deal_quotation_item.dart';

/// Repository for reading deal quotations created in sales_pipelines.
/// STRICTLY READ-ONLY against all core tables (quotations, sales_pipelines, customers, etc.).
class DealQuotationsRepository {
  final SupabaseClient _supabase;

  DealQuotationsRepository(this._supabase);

  static const List<String> defaultProductFilter = [];

  /// Fetches deal quotations for all deals, newest first.
  Future<List<DealQuotationItem>> getDealQuotations({
    List<String> productFilter = defaultProductFilter,
    String? searchQuery,
    String? statusFilter,
  }) async {
    try {
      // Read-only query with standard embeds
      final response = await _supabase
          .from('quotations')
          .select('''
            *,
            sales_pipelines (
              id,
              created_by,
              customers (*),
              products (id, name),
              profiles!sales_pipelines_created_by_fkey (full_name, phone)
            )
          ''')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      // Fetch finalized proposal summaries from qg_proposals
      Map<String, Map<String, dynamic>> currentProposalsByQuoteId = {};
      try {
        final proposalsRes = await _supabase
            .from('qg_proposals')
            .select('quotation_id, pdf_path, ref_no, finalized_at')
            .eq('is_current', true);
        for (final p in proposalsRes) {
          final qId = p['quotation_id'] as String?;
          if (qId != null) {
            currentProposalsByQuoteId[qId] = Map<String, dynamic>.from(p);
          }
        }
      } catch (e) {
        debugPrint('qg_proposals query failed (table may not be migrated yet): $e');
      }

      final List<DealQuotationItem> items = [];
      for (final raw in response) {
        try {
          final rowMap = Map<String, dynamic>.from(raw as Map);
          
          // Verify product filter (if provided)
          final rawPipeline = rowMap['sales_pipelines'];
          Map<String, dynamic>? pipeline;
          if (rawPipeline is Map) {
            pipeline = Map<String, dynamic>.from(rawPipeline);
          } else if (rawPipeline is List && rawPipeline.isNotEmpty && rawPipeline.first is Map) {
            pipeline = Map<String, dynamic>.from(rawPipeline.first as Map);
          }

          final rawProduct = pipeline != null ? pipeline['products'] : null;
          Map<String, dynamic>? product;
          if (rawProduct is Map) {
            product = Map<String, dynamic>.from(rawProduct);
          } else if (rawProduct is List && rawProduct.isNotEmpty && rawProduct.first is Map) {
            product = Map<String, dynamic>.from(rawProduct.first as Map);
          }
          final pName = product != null ? (product['name'] as String? ?? '') : '';

          final matchesProduct = productFilter.isEmpty ||
              productFilter.any((p) => pName.toLowerCase().contains(p.toLowerCase()));

          // If product filter specified and does not match, skip
          if (productFilter.isNotEmpty && !matchesProduct) {
            continue;
          }

          final qId = rowMap['id'] as String? ?? '';
          final proposalRecord = currentProposalsByQuoteId[qId];
          final item = DealQuotationItem.fromSupabase(rowMap, proposalRecord: proposalRecord);

          // Apply search filter if provided
          if (searchQuery != null && searchQuery.trim().isNotEmpty) {
            final query = searchQuery.trim().toLowerCase();
            final matchesSearch = item.customerName.toLowerCase().contains(query) ||
                item.quotationNumber.toLowerCase().contains(query) ||
                item.salesmanName.toLowerCase().contains(query);
            if (!matchesSearch) continue;
          }

          // Apply status filter if provided
          if (statusFilter != null && statusFilter != 'All' && statusFilter.isNotEmpty) {
            if (item.status.toLowerCase() != statusFilter.toLowerCase()) {
              continue;
            }
          }

          items.add(item);
        } catch (e) {
          debugPrint('Error parsing deal quotation item: $e');
        }
      }

      return items;
    } catch (e) {
      debugPrint('DealQuotationsRepository.getDealQuotations error: $e');
      return [];
    }
  }

  /// Fetches a single deal quotation by its quotation ID.
  Future<DealQuotationItem?> getDealQuotationById(String quotationId) async {
    try {
      final response = await _supabase
          .from('quotations')
          .select('''
            *,
            sales_pipelines (
              id,
              created_by,
              customers (*),
              products (id, name),
              profiles!sales_pipelines_created_by_fkey (full_name, phone)
            )
          ''')
          .eq('id', quotationId)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (response == null) return null;

      final rowMap = Map<String, dynamic>.from(response);

      Map<String, dynamic>? proposalRecord;
      try {
        final propRes = await _supabase
            .from('qg_proposals')
            .select('quotation_id, pdf_path, ref_no, finalized_at')
            .eq('quotation_id', quotationId)
            .eq('is_current', true)
            .maybeSingle();
        if (propRes != null) {
          proposalRecord = Map<String, dynamic>.from(propRes);
        }
      } catch (e) {
        debugPrint('qg_proposals maybeSingle query error: $e');
      }

      return DealQuotationItem.fromSupabase(rowMap, proposalRecord: proposalRecord);
    } catch (e) {
      debugPrint('DealQuotationsRepository.getDealQuotationById error: $e');
      return null;
    }
  }
}
