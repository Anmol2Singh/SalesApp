// lib/features/quotation_generator/data/deal_quotations_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deal_quotation_item.dart';
import '../templates/qg_template_registry.dart';

/// Repository for reading deal quotations created in sales_pipelines.
/// STRICTLY READ-ONLY against all core tables (quotations, sales_pipelines, customers, etc.).
class DealQuotationsRepository {
  final SupabaseClient _supabase;

  DealQuotationsRepository(this._supabase);

  static const List<String> defaultProductFilter = QgTemplateRegistry.defaultProductFilter;

  /// Fetches deal quotations for all deals, newest first.
  /// If [canViewAll] is false, restricts results to quotations created by, assigned to,
  /// or under the name of the salesperson.
  Future<List<DealQuotationItem>> getDealQuotations({
    List<String> productFilter = defaultProductFilter,
    String? searchQuery,
    String? statusFilter,
    String? currentUserId,
    String? currentUserName,
    bool canViewAll = true,
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

          // If not elevated (standard salesperson), restrict to quotations under their name
          // or for customers present for / assigned to them.
          if (!canViewAll) {
            final qCreatedBy = rowMap['created_by'] as String?;
            final pCreatedBy = pipeline != null ? pipeline['created_by'] as String? : null;

            final rawCust = pipeline != null ? pipeline['customers'] : null;
            Map<String, dynamic>? custMap;
            if (rawCust is Map) {
              custMap = Map<String, dynamic>.from(rawCust);
            } else if (rawCust is List && rawCust.isNotEmpty && rawCust.first is Map) {
              custMap = Map<String, dynamic>.from(rawCust.first as Map);
            }
            final custCreatedBy = custMap != null ? custMap['created_by'] as String? : null;
            final custAssignedTo = custMap != null ? custMap['assigned_to'] as String? : null;

            final rawProf = pipeline != null ? pipeline['profiles'] : null;
            Map<String, dynamic>? profMap;
            if (rawProf is Map) {
              profMap = Map<String, dynamic>.from(rawProf);
            } else if (rawProf is List && rawProf.isNotEmpty && rawProf.first is Map) {
              profMap = Map<String, dynamic>.from(rawProf.first as Map);
            }
            final profName = profMap != null ? (profMap['full_name'] as String?)?.trim() : null;
            final qSalesman = (rowMap['salesman'] as String?)?.trim();

            final uId = currentUserId?.trim();
            final uName = currentUserName?.trim().toLowerCase();

            bool matches = false;

            if (uId != null && uId.isNotEmpty) {
              if (qCreatedBy == uId ||
                  pCreatedBy == uId ||
                  custCreatedBy == uId ||
                  custAssignedTo == uId) {
                matches = true;
              }
            }

            if (!matches && uName != null && uName.isNotEmpty) {
              if (qSalesman != null && qSalesman.toLowerCase() == uName) {
                matches = true;
              } else if (profName != null && profName.toLowerCase() == uName) {
                matches = true;
              } else if (item.salesmanName.trim().toLowerCase() == uName) {
                matches = true;
              }
            }

            if (!matches) {
              continue;
            }
          }

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
