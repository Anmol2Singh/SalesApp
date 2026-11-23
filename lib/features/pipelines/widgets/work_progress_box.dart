// lib/features/pipelines/widgets/work_progress_box.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/user_role.dart';
import '../../../core/models/pipeline.dart';
import '../../../core/auth/role_access.dart';
import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sales_order.dart';
import '../../../core/models/factory_order.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/utils/financial_year_helper.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../providers/pipelines_provider.dart';
import '../../sales_order/widgets/delivery_challan_modal.dart';
import '../../quotation_generator/data/qg_noc_repository.dart';
import '../../quotation_generator/models/qg_noc_document.dart';
import '../../quotation_generator/models/qg_noc_builder_state.dart';
import '../../quotation_generator/services/pdf_noc_builder.dart';
import '../../quotation_generator/services/qg_noc_extractor.dart';
import '../../quotation_generator/ui/widgets/noc_signatures_dialog.dart';
import '../../quotation/services/quotation_pdf_launcher.dart';

/// Helper service for Work Progress metadata persistence & live evaluations.
class WorkProgressService {
  static const String _wpTagPrefix = '[WORK_PROGRESS:';
  static const String _wpTagSuffix = ':WORK_PROGRESS]';

  static Map<String, dynamic> _extractMetaFromNotes(String? notes) {
    if (notes == null || !notes.contains(_wpTagPrefix)) return {};
    final start = notes.indexOf(_wpTagPrefix) + _wpTagPrefix.length;
    int end = notes.indexOf(_wpTagSuffix, start);
    if (end == -1) {
      end = notes.lastIndexOf(']');
    }
    if (end != -1 && end > start) {
      try {
        final jsonStr = notes.substring(start, end);
        final parsed = jsonDecode(jsonStr);
        if (parsed is Map) {
          return Map<String, dynamic>.from(parsed);
        }
      } catch (_) {}
    }
    return {};
  }

  static String _replaceWorkProgressTag(String text, String newTag) {
    if (!text.contains(_wpTagPrefix)) {
      return text.trim().isEmpty ? newTag : '${text.trim()} $newTag';
    }
    final start = text.indexOf(_wpTagPrefix);
    int end = text.indexOf(_wpTagSuffix, start);
    if (end != -1) {
      end += _wpTagSuffix.length;
    } else {
      end = text.lastIndexOf(']');
      if (end != -1) end += 1;
    }
    if (end == -1 || end <= start) {
      return '$text $newTag';
    }
    return '${text.substring(0, start)}$newTag${text.substring(end)}'.trim();
  }

  /// Extracts work progress metadata from pipeline notes or steps_config.
  static Map<String, dynamic> parseProgressMeta(SalesPipeline pipeline) {
    final fromNotes = _extractMetaFromNotes(pipeline.notes);
    if (fromNotes.isNotEmpty) return fromNotes;

    if (pipeline.stepsConfig != null) {
      for (final s in pipeline.stepsConfig!) {
        if (s['id'] == '_work_progress' || s['work_progress'] != null) {
          final raw = s['work_progress'] ?? s;
          if (raw is Map) return Map<String, dynamic>.from(raw);
        }
      }
    }
    return {};
  }

  /// Returns the list of recorded delivery challans for this pipeline.
  static List<Map<String, dynamic>> getDeliveryChallans(SalesPipeline pipeline) {
    final meta = parseProgressMeta(pipeline);
    if (meta['delivery_challans'] is List) {
      return List<Map<String, dynamic>>.from(
        (meta['delivery_challans'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
    return [];
  }

  /// Extracts all dispatched items across all delivery challans for this pipeline.
  /// If multiple challans exist, items with the same name are combined and their dispatched quantities summed.
  static List<Map<String, dynamic>> getChallanItems(SalesPipeline pipeline) {
    final challans = getDeliveryChallans(pipeline);
    if (challans.isEmpty) return [];

    final Map<String, Map<String, dynamic>> combined = {};

    for (final ch in challans) {
      final rawItems = ch['items'];
      if (rawItems is List) {
        for (final raw in rawItems) {
          if (raw is Map) {
            final item = Map<String, dynamic>.from(raw);
            final name = (item['name'] ?? item['description'] ?? '').toString().trim();
            if (name.isEmpty) continue;

            final double qty = (item['qty'] is num)
                ? (item['qty'] as num).toDouble()
                : (double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0);
            final uom = (item['uom'] ?? 'NOS').toString().trim();
            final remark = item['remark']?.toString().trim();

            if (combined.containsKey(name)) {
              final existing = combined[name]!;
              final double prevQty = (existing['qty'] is num) ? (existing['qty'] as num).toDouble() : 0.0;
              existing['qty'] = prevQty + qty;
              if (remark != null && remark.isNotEmpty) {
                final existingRem = existing['remark']?.toString() ?? '';
                if (existingRem.isNotEmpty && !existingRem.contains(remark)) {
                  existing['remark'] = '$existingRem; $remark';
                } else if (existingRem.isEmpty) {
                  existing['remark'] = remark;
                }
              }
            } else {
              combined[name] = {
                'name': name,
                'description': name,
                'qty': qty,
                'uom': uom.isNotEmpty ? uom : 'NOS',
                if (remark != null && remark.isNotEmpty) 'remark': remark,
                if (item['required_qty'] != null) 'required_qty': item['required_qty'],
              };
            }
          }
        }
      }
    }

    return combined.values.toList();
  }

  /// Records a newly generated delivery challan for this pipeline.
  static Future<void> recordDeliveryChallan(
    SupabaseClient supabase,
    String pipelineId,
    Map<String, dynamic> challanData,
  ) async {
    final res = await supabase
        .from('sales_pipelines')
        .select('notes')
        .eq('id', pipelineId)
        .maybeSingle();

    final currentNotes = res?['notes']?.toString() ?? '';
    final Map<String, dynamic> currentMeta = _extractMetaFromNotes(currentNotes);

    final List<dynamic> challans = (currentMeta['delivery_challans'] is List)
        ? List<dynamic>.from(currentMeta['delivery_challans'] as List)
        : [];
    challans.add(challanData);
    currentMeta['delivery_challans'] = challans;
    currentMeta['challan_generated'] = true;
    currentMeta['site_dispatched'] = true;
    currentMeta['dispatch_ready'] = true;

    // Check if factory is also dispatched, or default to overall dispatched
    final bool fDisp = currentMeta['factory_dispatched'] == true;
    if (fDisp || challans.isNotEmpty) {
      currentMeta['dispatched'] = true;
    }

    final newTag = '$_wpTagPrefix${jsonEncode(currentMeta)}$_wpTagSuffix';
    final newNotes = _replaceWorkProgressTag(currentNotes, newTag);

    await supabase.from('sales_pipelines').update({
      'notes': newNotes,
    }).eq('id', pipelineId);
  }

  /// Updates specific sub-track statuses (Factory / Site)
  static Future<void> updateTrackStatus(
    SupabaseClient supabase,
    String pipelineId, {
    bool? factoryReady,
    bool? factoryDispatched,
    bool? siteReady,
    bool? siteDispatched,
  }) async {
    final res = await supabase
        .from('sales_pipelines')
        .select('notes')
        .eq('id', pipelineId)
        .maybeSingle();

    final currentNotes = res?['notes']?.toString() ?? '';
    final Map<String, dynamic> currentMeta = _extractMetaFromNotes(currentNotes);

    if (factoryReady != null) {
      currentMeta['factory_ready'] = factoryReady;
      if (!factoryReady) currentMeta['factory_dispatched'] = false;
    }
    if (factoryDispatched != null) currentMeta['factory_dispatched'] = factoryDispatched;
    if (siteReady != null) {
      currentMeta['site_ready'] = siteReady;
      if (!siteReady) currentMeta['site_dispatched'] = false;
    }
    if (siteDispatched != null) currentMeta['site_dispatched'] = siteDispatched;

    // If both tracks are dispatched, mark overall dispatched
    final bool fDisp = currentMeta['factory_dispatched'] == true;
    final bool sDisp = currentMeta['site_dispatched'] == true;
    if (fDisp && sDisp) {
      currentMeta['dispatched'] = true;
    } else {
      currentMeta['dispatched'] = false;
    }

    final newTag = '$_wpTagPrefix${jsonEncode(currentMeta)}$_wpTagSuffix';
    final newNotes = _replaceWorkProgressTag(currentNotes, newTag);

    await supabase.from('sales_pipelines').update({
      'notes': newNotes,
    }).eq('id', pipelineId);
  }

  /// Updates work progress metadata in sales_pipelines notes.
  static Future<void> updateProgressMeta(
    SupabaseClient supabase,
    String pipelineId, {
    bool? dispatchReady,
    bool? challanGenerated,
    bool? dispatched,
  }) async {
    final res = await supabase
        .from('sales_pipelines')
        .select('notes')
        .eq('id', pipelineId)
        .maybeSingle();

    final currentNotes = res?['notes']?.toString() ?? '';
    final Map<String, dynamic> currentMeta = _extractMetaFromNotes(currentNotes);

    if (dispatchReady != null) currentMeta['dispatch_ready'] = dispatchReady;
    if (challanGenerated != null) currentMeta['challan_generated'] = challanGenerated;
    if (dispatched != null) currentMeta['dispatched'] = dispatched;

    final newTag = '$_wpTagPrefix${jsonEncode(currentMeta)}$_wpTagSuffix';
    final newNotes = _replaceWorkProgressTag(currentNotes, newTag);

    await supabase.from('sales_pipelines').update({
      'notes': newNotes,
    }).eq('id', pipelineId);
  }

  /// Resolves the installation ticket corresponding strictly to a specific pipeline/deal.
  /// Prevents cross-contamination when a customer has multiple deals with different tickets.
  static Map<String, dynamic>? resolveInstallationForPipeline({
    required List<dynamic> installations,
    required String pipelineId,
    String? dealNumber,
    String? productName,
    DateTime? dealCreatedAt,
    bool customerHasMultipleDeals = false,
  }) {
    if (installations.isEmpty) return null;

    final cleanPipeId = pipelineId.trim().toLowerCase();
    final cleanDealNum = dealNumber?.trim().toLowerCase();
    final cleanProdName = productName?.trim().toLowerCase();

    // 1. Strict match: Check if notes explicitly tags this deal (by UUID, dealNumber, or "Deal ID: ...")
    for (final item in installations) {
      final m = Map<String, dynamic>.from(item as Map);
      final notes = (m['notes'] ?? '').toString();
      final notesLower = notes.toLowerCase();

      // Check if DB columns match directly (if present)
      final colPipeId = m['pipeline_id']?.toString().toLowerCase();
      final colDealId = m['deal_id']?.toString().toLowerCase();
      if ((colPipeId != null && colPipeId == cleanPipeId) ||
          (cleanDealNum != null && cleanDealNum.isNotEmpty && colDealId != null && colDealId == cleanDealNum)) {
        return m;
      }

      // Check explicit "Deal ID: <tag>" pattern in notes
      final dealMatch = RegExp(r'Deal ID:\s*([^\s\(\)\n]+)').firstMatch(notes);
      if (dealMatch != null) {
        final matchedTag = dealMatch.group(1)?.trim().toLowerCase();
        if (matchedTag == cleanPipeId ||
            (cleanDealNum != null && cleanDealNum.isNotEmpty && matchedTag == cleanDealNum)) {
          return m;
        }
      }

      // Check if notes contains the pipeline UUID or formatted deal number
      if (cleanPipeId.isNotEmpty && notesLower.contains(cleanPipeId)) {
        return m;
      }
      if (cleanDealNum != null && cleanDealNum.isNotEmpty && notesLower.contains(cleanDealNum)) {
        return m;
      }
    }

    // Helper: Determine if an installation belongs to a DIFFERENT deal
    bool belongsToDifferentDeal(Map<String, dynamic> m) {
      final notes = (m['notes'] ?? '').toString();
      final dealMatch = RegExp(r'Deal ID:\s*([^\s\(\)\n]+)').firstMatch(notes);
      if (dealMatch != null) {
        final otherTag = dealMatch.group(1)?.trim().toLowerCase();
        if (otherTag != null && otherTag.isNotEmpty) {
          if (otherTag == cleanPipeId || (cleanDealNum != null && otherTag == cleanDealNum)) {
            return false;
          }
          return true;
        }
      }
      return false;
    }

    // 2. Product name match among unassigned installations (or installations not belonging to another deal)
    if (cleanProdName != null && cleanProdName.isNotEmpty) {
      for (final item in installations) {
        final m = Map<String, dynamic>.from(item as Map);
        if (belongsToDifferentDeal(m)) continue;

        final instProd = (m['product_name'] ?? '').toString().toLowerCase();
        final instTitle = (m['title'] ?? '').toString().toLowerCase();
        if ((instProd.isNotEmpty && (instProd.contains(cleanProdName) || cleanProdName.contains(instProd))) ||
            (instTitle.isNotEmpty && (instTitle.contains(cleanProdName) || cleanProdName.contains(instTitle)))) {
          return m;
        }
      }
    }

    // 3. Fallback: If customer has strictly 1 deal OR only 1 installation exists
    final unassigned = installations
        .map((it) => Map<String, dynamic>.from(it as Map))
        .where((m) => !belongsToDifferentDeal(m))
        .toList();

    if (unassigned.isNotEmpty) {
      // If customer has 1 deal, or if there's only 1 unassigned installation for this customer
      if (!customerHasMultipleDeals || unassigned.length == 1) {
        return unassigned.first;
      }

      // If multiple unassigned exist, pick the newest created on or after deal creation
      if (dealCreatedAt != null) {
        for (final m in unassigned) {
          final cAtStr = m['created_at']?.toString();
          if (cAtStr != null) {
            final cAt = DateTime.tryParse(cAtStr);
            if (cAt != null && !cAt.isBefore(dealCreatedAt)) {
              return m;
            }
          }
        }
      }

      return unassigned.first;
    }

    return null;
  }

  /// Resolves ALL installation tickets corresponding to a specific pipeline/deal.
  static List<Map<String, dynamic>> resolveAllInstallationsForPipeline({
    required List<dynamic> installations,
    required String pipelineId,
    String? dealNumber,
    String? productName,
    DateTime? dealCreatedAt,
    bool customerHasMultipleDeals = false,
  }) {
    if (installations.isEmpty) return [];

    final cleanPipeId = pipelineId.trim().toLowerCase();
    final cleanDealNum = dealNumber?.trim().toLowerCase();
    final List<Map<String, dynamic>> matched = [];

    // 1. Strict match
    for (final item in installations) {
      final m = Map<String, dynamic>.from(item as Map);
      final notes = (m['notes'] ?? '').toString();
      final notesLower = notes.toLowerCase();

      final colPipeId = m['pipeline_id']?.toString().toLowerCase();
      final colDealId = m['deal_id']?.toString().toLowerCase();
      if ((colPipeId != null && colPipeId == cleanPipeId) ||
          (cleanDealNum != null && cleanDealNum.isNotEmpty && colDealId != null && colDealId == cleanDealNum)) {
        matched.add(m);
        continue;
      }

      final dealMatch = RegExp(r'Deal ID:\s*([^\s\(\)\n]+)').firstMatch(notes);
      if (dealMatch != null) {
        final matchedTag = dealMatch.group(1)?.trim().toLowerCase();
        if (matchedTag == cleanPipeId ||
            (cleanDealNum != null && cleanDealNum.isNotEmpty && matchedTag == cleanDealNum)) {
          matched.add(m);
          continue;
        }
      }

      if (cleanPipeId.isNotEmpty && notesLower.contains(cleanPipeId)) {
        matched.add(m);
        continue;
      }
      if (cleanDealNum != null && cleanDealNum.isNotEmpty && notesLower.contains(cleanDealNum)) {
        matched.add(m);
        continue;
      }
    }

    if (matched.isNotEmpty) return matched;

    // 2. Fallback to single resolver if no explicit tags found
    final single = resolveInstallationForPipeline(
      installations: installations,
      pipelineId: pipelineId,
      dealNumber: dealNumber,
      productName: productName,
      dealCreatedAt: dealCreatedAt,
      customerHasMultipleDeals: customerHasMultipleDeals,
    );
    if (single != null) return [single];
    return [];
  }

  static List<String> getSkippedSteps(SalesPipeline pipeline) {
    return pipeline.skippedSteps;
  }

  static bool isStepSkipped(SalesPipeline pipeline, String stepKey) {
    return pipeline.isStepSkipped(stepKey);
  }

  static Future<void> setStepSkipped(
    SupabaseClient supabase,
    String pipelineId,
    String stepKey,
    bool skipped,
  ) async {
    final res = await supabase
        .from('sales_pipelines')
        .select('notes')
        .eq('id', pipelineId)
        .maybeSingle();

    final currentNotes = res?['notes']?.toString() ?? '';
    final Map<String, dynamic> currentMeta = _extractMetaFromNotes(currentNotes);
    final List<String> list = (currentMeta['skipped_steps'] is List)
        ? List<String>.from((currentMeta['skipped_steps'] as List).map((e) => e.toString()))
        : [];

    if (skipped) {
      if (!list.contains(stepKey)) list.add(stepKey);
    } else {
      list.remove(stepKey);
    }
    currentMeta['skipped_steps'] = list;

    final newTag = '$_wpTagPrefix${jsonEncode(currentMeta)}$_wpTagSuffix';
    final newNotes = _replaceWorkProgressTag(currentNotes, newTag);

    await supabase.from('sales_pipelines').update({
      'notes': newNotes,
    }).eq('id', pipelineId);
  }

  /// Checks whether an installation ticket for this customer & pipeline is completed (resolved, closed, or completed).
  static Future<bool> isInstallationComplete(
    SupabaseClient supabase,
    String customerId,
    String pipelineId, {
    String? dealNumber,
    String? productName,
    DateTime? dealCreatedAt,
  }) async {
    try {
      final instList = await supabase
          .from('installations')
          .select('id, status, notes, customer_id, product_name, title, created_at')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      String? effectiveDealNumber = dealNumber;
      String? effectiveProductName = productName;
      DateTime? effectiveCreatedAt = dealCreatedAt;

      if (effectiveDealNumber == null || effectiveProductName == null) {
        try {
          final pipeRow = await supabase
              .from('sales_pipelines')
              .select('id, deal_id, created_at, products(name)')
              .eq('id', pipelineId)
              .maybeSingle();
          if (pipeRow != null) {
            effectiveDealNumber ??= pipeRow['deal_id']?.toString();
            if (pipeRow['created_at'] != null) {
              effectiveCreatedAt ??= DateTime.tryParse(pipeRow['created_at'].toString());
            }
            if (pipeRow['products'] is Map) {
              effectiveProductName ??= pipeRow['products']['name']?.toString();
            }
          }
        } catch (_) {}
      }

      bool hasMultipleDeals = false;
      try {
        final dealsRes = await supabase
            .from('sales_pipelines')
            .select('id')
            .eq('customer_id', customerId)
            .isFilter('deleted_at', null);
        if ((dealsRes as List).length > 1) {
          hasMultipleDeals = true;
        }
      } catch (_) {}

      final ticket = resolveInstallationForPipeline(
        installations: (instList as List? ?? []),
        pipelineId: pipelineId,
        dealNumber: effectiveDealNumber,
        productName: effectiveProductName,
        dealCreatedAt: effectiveCreatedAt,
        customerHasMultipleDeals: hasMultipleDeals,
      );

      if (ticket != null) {
        final s = (ticket['status']?.toString() ?? '').toLowerCase().trim();
        return s == 'resolved' || s == 'closed' || s == 'completed';
      }
    } catch (_) {}
    return false;
  }

  /// Checks whether all 5 operational phases of Work Progress are 100% completed:
  /// 1. Quotation done
  /// 2. Sales Order done
  /// 3. Material & Dispatch done (factory or site dispatched, or challans recorded)
  /// 4. Installation completed (ticket resolved or closed)
  /// 5. NOC certificate document generated
  static Future<bool> isWorkProgressComplete({
    required SupabaseClient supabase,
    required SalesPipeline pipeline,
  }) async {
    // 1. Quotation
    if (pipeline.quotation == null) return false;

    // 2. Sales Order
    if (pipeline.salesOrder == null) return false;

    // 3. Material & Dispatch
    final meta = parseProgressMeta(pipeline);
    final bool factoryDispatched = meta['factory_dispatched'] == true;
    final deliveryChallans = getDeliveryChallans(pipeline);
    final bool siteDispatched = meta['site_dispatched'] == true || deliveryChallans.isNotEmpty;
    if (!factoryDispatched && !siteDispatched) return false;

    // 4. Installation
    final isInstallDone = await isInstallationComplete(
      supabase,
      pipeline.customerId,
      pipeline.id,
      dealNumber: pipeline.dealId,
      productName: pipeline.product?.name,
      dealCreatedAt: pipeline.createdAt,
    );
    if (!isInstallDone) return false;

    // 5. NOC
    try {
      final nocList = await QgNocRepository.instance.getDocumentsForPipeline(pipeline.id);
      if (nocList.isEmpty) return false;
    } catch (_) {
      return false;
    }

    return true;
  }

  /// Evaluates which operational phase in Work Progress is currently active/pending.
  /// E.g. 'Dispatch', 'Installation', 'NOC', or 'Completed'.
  static Future<String> getWorkProgressStage({
    required SupabaseClient supabase,
    required SalesPipeline pipeline,
  }) async {
    // 1. Quotation
    if (pipeline.quotation == null) return 'Quotation';

    // 2. Sales Order
    if (pipeline.salesOrder == null) return 'Sales Order';

    // 3. Material & Dispatch
    final meta = parseProgressMeta(pipeline);
    final bool factoryDispatched = meta['factory_dispatched'] == true;
    final deliveryChallans = getDeliveryChallans(pipeline);
    final bool siteDispatched = meta['site_dispatched'] == true || deliveryChallans.isNotEmpty;
    if (!factoryDispatched || !siteDispatched) {
      if (!factoryDispatched && !siteDispatched) return 'Dispatch';
      if (!factoryDispatched) return 'Factory Dispatch';
      return 'Site Dispatch';
    }

    // 4. Installation
    final isInstallDone = await isInstallationComplete(
      supabase,
      pipeline.customerId,
      pipeline.id,
      dealNumber: pipeline.dealId,
      productName: pipeline.product?.name,
      dealCreatedAt: pipeline.createdAt,
    );
    if (!isInstallDone) {
      return 'Installation';
    }

    // 5. NOC
    try {
      final nocList = await QgNocRepository.instance.getDocumentsForPipeline(pipeline.id);
      if (nocList.isEmpty) return 'NOC';
    } catch (_) {
      return 'NOC';
    }

    return 'Completed';
  }
}

final pipelineWorkStageProvider = FutureProvider.family<String, SalesPipeline>((ref, pipeline) async {
  final supabase = ref.watch(supabaseClientProvider);
  return WorkProgressService.getWorkProgressStage(
    supabase: supabase,
    pipeline: pipeline,
  );
});

/// Dynamic Work Progress Tracker displaying the 5 core operational phases:
/// Quote -> Sales Order -> Material & Dispatch -> Install -> NOC
/// with Factory & Site sub-tracks and a dedicated Delivery Challan generator slot.
class WorkProgressBox extends ConsumerStatefulWidget {
  final SalesPipeline pipeline;
  final ValueChanged<bool>? onProgressEvaluated;

  const WorkProgressBox({super.key, required this.pipeline, this.onProgressEvaluated});

  @override
  ConsumerState<WorkProgressBox> createState() => _WorkProgressBoxState();
}

class _WorkProgressBoxState extends ConsumerState<WorkProgressBox> {
  bool _loadingAux = true;
  bool _isInstallationCreated = false;
  bool _isInstallationCompleted = false;
  String? _installationTicketNumber;
  String? _installationId;
  String _installationStatus = 'none';
  List<Map<String, dynamic>> _dealInstallations = [];

  QgNocDocument? _nocDoc;
  bool _isNocCompleted = false;

  @override
  void initState() {
    super.initState();
    _fetchAuxData();
  }

  @override
  void didUpdateWidget(covariant WorkProgressBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pipeline.id != widget.pipeline.id ||
        oldWidget.pipeline.notes != widget.pipeline.notes ||
        oldWidget.pipeline.currentStep != widget.pipeline.currentStep) {
      _fetchAuxData();
    }
  }

  Future<void> _fetchAuxData() async {
    final supabase = ref.read(supabaseClientProvider);
    final custId = widget.pipeline.customerId;
    final pId = widget.pipeline.id;

    try {
      // 1. Check installations strictly for this deal / pipeline
      final instList = await supabase
          .from('installations')
          .select('id, ticket_number, status, notes, customer_id, product_name, title, created_at')
          .eq('customer_id', custId)
          .order('created_at', ascending: false);

      bool hasMultipleDeals = false;
      try {
        final dealsRes = await supabase
            .from('sales_pipelines')
            .select('id')
            .eq('customer_id', custId)
            .isFilter('deleted_at', null);
        if ((dealsRes as List).length > 1) {
          hasMultipleDeals = true;
        }
      } catch (_) {}

      final allTickets = WorkProgressService.resolveAllInstallationsForPipeline(
        installations: (instList as List? ?? []),
        pipelineId: pId,
        dealNumber: widget.pipeline.dealId,
        productName: widget.pipeline.product?.name,
        dealCreatedAt: widget.pipeline.createdAt,
        customerHasMultipleDeals: hasMultipleDeals,
      );

      _dealInstallations = allTickets;

      bool isCreated = false;
      bool isDone = false;
      String? tNum;
      String? tId;
      String sStatus = 'none';

      if (allTickets.isNotEmpty) {
        isCreated = true;
        final primaryTicket = allTickets.first;
        tId = primaryTicket['id']?.toString();
        tNum = primaryTicket['ticket_number']?.toString();
        final s = (primaryTicket['status']?.toString() ?? '').toLowerCase().trim();
        sStatus = s;

        // Marked completed if any ticket is completed or all completed
        if (allTickets.any((t) {
          final st = (t['status']?.toString() ?? '').toLowerCase().trim();
          return st == 'resolved' || st == 'closed' || st == 'completed';
        })) {
          isDone = true;
        }
      }

      // 2. Check NOC
      final nocList = await QgNocRepository.instance.getDocumentsForPipeline(pId);
      final noc = nocList.isNotEmpty ? nocList.first : null;

      if (mounted) {
        final meta = WorkProgressService.parseProgressMeta(widget.pipeline);
        final deliveryChallans = WorkProgressService.getDeliveryChallans(widget.pipeline);
        final bool factoryDispatched = meta['factory_dispatched'] == true;
        final bool siteDispatched = meta['site_dispatched'] == true || deliveryChallans.isNotEmpty;
        final bool step1QuotationDone = widget.pipeline.quotation != null;
        final bool step2SalesOrderDone = widget.pipeline.salesOrder != null;
        final bool step3DispatchDone = factoryDispatched || siteDispatched;
        final bool isAllDone = step1QuotationDone &&
            step2SalesOrderDone &&
            step3DispatchDone &&
            isDone &&
            (noc != null);

        setState(() {
          _isInstallationCreated = isCreated;
          _isInstallationCompleted = isDone;
          _installationTicketNumber = tNum;
          _installationId = tId;
          _installationStatus = sStatus;
          _nocDoc = noc;
          _isNocCompleted = noc != null;
          _loadingAux = false;
        });

        widget.onProgressEvaluated?.call(isAllDone);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingAux = false);
        widget.onProgressEvaluated?.call(false);
      }
    }
  }

  Future<void> _viewExistingChallan(Map<String, dynamic> challan) async {
    final pipeline = widget.pipeline;
    final cust = pipeline.customer;
    if (cust == null) return;

    final itemsList = (challan['items'] is List) ? (challan['items'] as List) : [];
    final List<SalesOrderLineItem> customLineItems = itemsList.map((it) {
      final m = Map<String, dynamic>.from(it as Map);
      return SalesOrderLineItem(
        description: m['name']?.toString() ?? '',
        qty: (m['qty'] as num?)?.toDouble() ?? 1.0,
        uom: m['uom']?.toString() ?? 'NOS',
        remark: m['remark']?.toString(),
        rate: 0.0,
        discPercent: 0.0,
        amount: 0.0,
      );
    }).toList();

    final so = pipeline.salesOrder;
    final effectiveSalesOrder = so != null
        ? so.copyWith(
            vehicleNumber: challan['vehicle_number']?.toString(),
            shippingCompany: challan['shipping_company']?.toString(),
            lineItems: customLineItems,
          )
        : SalesOrder(
            id: 'so_temp',
            pipelineId: pipeline.id,
            salesOrderNumber: pipeline.baseQuotationNumber,
            orderDate: DateTime.tryParse(challan['date']?.toString() ?? '') ?? DateTime.now(),
            vehicleNumber: challan['vehicle_number']?.toString(),
            shippingCompany: challan['shipping_company']?.toString(),
            billingAddress: cust.address,
            shippingAddress: cust.address,
            lineItems: customLineItems,
            subtotal: 0,
            cgstRate: 0,
            sgstRate: 0,
            cgstAmount: 0,
            sgstAmount: 0,
            igstAmount: 0,
            grandTotal: 0,
            status: SalesOrderStatus.confirmed,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

    final supabase = ref.read(supabaseClientProvider);
    Map<String, dynamic> templateConfig = {};
    try {
      final res = await supabase
          .from('pdf_templates')
          .select()
          .eq('document_type', 'sales_order')
          .maybeSingle();
      if (res != null && res['template_config'] != null) {
        templateConfig = res['template_config'] as Map<String, dynamic>;
      }
    } catch (_) {}

    final product = pipeline.product ??
        Product(
          id: pipeline.productId,
          name: 'Product',
          category: 'Solar',
          baseSpecs: const ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    final challanDate = DateTime.tryParse(challan['date']?.toString() ?? '') ?? DateTime.now();
    final challanNo = challan['challan_number']?.toString() ?? 'IZY/DC/0001';

    final pdfBytes = await PdfService.generateDeliveryChallanPdf(
      salesOrder: effectiveSalesOrder,
      customer: cust,
      product: product,
      templateConfig: templateConfig,
      quotationNumber: pipeline.baseQuotationNumber,
      challanDate: challanDate,
      customLineItems: customLineItems,
      customChallanNumber: challanNo,
      deliveryTakenBy: challan['delivery_taken_by']?.toString(),
    );

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          pdfBytes: pdfBytes,
          fileName: '${challanNo.replaceAll('/', '_')}.pdf',
        ),
      ),
    );
  }

  void _openDeliveryChallanModal() {
    final cust = widget.pipeline.customer;
    if (cust == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer information missing on deal.'), backgroundColor: AppColors.error),
      );
      return;
    }
    DeliveryChallanModal.show(
      context,
      pipelineId: widget.pipeline.id,
      customer: cust,
    );
  }

  Future<void> _viewQuotationPdf() async {
    final quot = widget.pipeline.quotation;
    if (quot == null) return;
    await QuotationPdfLauncher.showFormatSelectionAndLaunch(
      context: context,
      ref: ref,
      quotation: quot,
      customer: widget.pipeline.customer,
      product: widget.pipeline.product,
      leadOrDealTitle: widget.pipeline.product?.name ?? widget.pipeline.customer?.companyName,
      salesmanName: widget.pipeline.createdByProfile?.fullName ?? quot.salesman,
    );
  }

  Future<void> _viewSalesOrderPdf() async {
    final so = widget.pipeline.salesOrder;
    if (so == null) return;
    final cust = widget.pipeline.customer;
    if (cust == null) return;
    final supabase = ref.read(supabaseClientProvider);

    final currentRoles = ref.read(currentProfileProvider)?.roles ?? [UserRole.customer];
    final hasCommercial = currentRoles.contains(UserRole.admin) || currentRoles.contains(UserRole.manager) || currentRoles.contains(UserRole.sales) || currentRoles.contains(UserRole.salesHead);
    final hasTechnical = currentRoles.contains(UserRole.admin) || currentRoles.contains(UserRole.manager) || currentRoles.contains(UserRole.boq) || currentRoles.contains(UserRole.serviceHead);
    final hasProduction = currentRoles.contains(UserRole.admin) || currentRoles.contains(UserRole.manager) || currentRoles.contains(UserRole.factory);

    String? variant;
    final availableCount = (hasCommercial ? 1 : 0) + (hasTechnical ? 1 : 0) + (hasProduction ? 1 : 0);
    if (availableCount > 1) {
      variant = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select PDF Variant'),
          content: const Text(
            'Choose the variant of Sales Order you want to view:',
            style: TextStyle(fontFamily: 'Inter'),
          ),
          actions: [
            if (hasCommercial)
              TextButton(onPressed: () => Navigator.pop(ctx, 'commercial'), child: const Text('Commercial (Main)')),
            if (hasTechnical)
              TextButton(onPressed: () => Navigator.pop(ctx, 'technical'), child: const Text('Technical (BOQ)')),
            if (hasProduction)
              TextButton(onPressed: () => Navigator.pop(ctx, 'production'), child: const Text('Production (Factory)')),
          ],
        ),
      );
      if (variant == null) return;
    } else if (hasTechnical) {
      variant = 'technical';
    } else if (hasProduction) {
      variant = 'production';
    } else {
      variant = 'commercial';
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final product = widget.pipeline.product ??
          Product(
            id: 'prod',
            name: 'Product',
            category: 'Solar',
            baseSpecs: const ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      Map<String, dynamic> templateConfig = {};
      try {
        final res = await supabase.from('pdf_templates').select().eq('document_type', 'sales_order').single();
        templateConfig = res['template_config'] as Map<String, dynamic>;
      } catch (_) {}

      final bytes = await PdfService.generateSalesOrderPdf(
        salesOrder: so,
        customer: cust,
        product: product,
        templateConfig: templateConfig,
        variant: variant,
      );

      if (mounted) Navigator.pop(context);
      if (mounted) {
        final formattedSo = PdfService.formatSalesOrderNumber(so.salesOrderNumber, so.orderDate);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: bytes,
              fileName: '${formattedSo.replaceAll('/', '_')}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showInstallationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (_isInstallationCompleted ? AppColors.success : const Color(0xFFD97706)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isInstallationCompleted ? Icons.task_alt : Icons.build_outlined,
                color: _isInstallationCompleted ? AppColors.success : const Color(0xFFD97706),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Installation Progress',
                style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_dealInstallations.isNotEmpty) ...[
              Text(
                'Installation Tickets (${_dealInstallations.length}):',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _dealInstallations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (c, idx) {
                    final t = _dealInstallations[idx];
                    final tNum = t['ticket_number']?.toString() ?? 'Ticket #${idx + 1}';
                    final st = (t['status']?.toString() ?? 'assigned').toLowerCase();
                    final isRes = st == 'resolved' || st == 'closed' || st == 'completed';
                    final tId = t['id']?.toString() ?? '';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tNum, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text(
                                  st.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isRes ? AppColors.success : const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              if (tId.isNotEmpty) {
                                context.push('/installations/details/$tId');
                              }
                            },
                            child: const Text('Open ➔', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_isInstallationCompleted) ...[
              const Text(
                'Installation verified and marked resolved! The NOC certificate can now be issued.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.success),
              ),
            ] else if (_dealInstallations.isNotEmpty) ...[
              const Text(
                'Complete all installations and resolve ticket to unlock the NOC certificate.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
              ),
            ] else ...[
              const Text(
                'No installation ticket created yet for this deal. You can book one or more installation tickets below.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textPrimary, height: 1.4),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (_dealInstallations.isNotEmpty)
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Book Another Ticket'),
              onPressed: () async {
                Navigator.pop(ctx);
                await context.push('${AppRoutes.bookInstallation}?customerId=${widget.pipeline.customerId}&dealId=${widget.pipeline.id}');
                _fetchAuxData();
              },
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (_dealInstallations.isNotEmpty) {
                if (_installationId != null && _installationId!.isNotEmpty) {
                  await context.push('/installations/details/$_installationId');
                } else {
                  await context.push(AppRoutes.installationsList);
                }
              } else {
                await context.push('${AppRoutes.bookInstallation}?customerId=${widget.pipeline.customerId}&dealId=${widget.pipeline.id}');
              }
              _fetchAuxData();
            },
            child: Text(_dealInstallations.isNotEmpty ? 'View Latest Ticket' : 'Book Installation Ticket'),
          ),
        ],
      ),
    );
  }

  Future<void> _viewNocPdf(QgNocDocument doc) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final payload = doc.toPayload();
      final pdfBytes = await PdfNocBuilder.buildNocPdf(payload);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: '${doc.nocNumber.replaceAll('/', '_')}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating NOC PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _generateNoc() async {
    final pipeline = widget.pipeline;
    final supabase = ref.read(supabaseClientProvider);

    try {
      final custRes = await supabase.from('customers').select().eq('id', pipeline.customerId).maybeSingle();
      final cRes = custRes != null ? Map<String, dynamic>.from(custRes) : null;

      final customerName = cRes?['company_name']?.toString() ??
          cRes?['customer_name']?.toString() ??
          pipeline.customer?.companyName ??
          'Valued Customer';
      final siteAddress = cRes?['address']?.toString() ?? pipeline.customer?.address ?? '';

      // Check for existing installation to pre-populate signatures & technician name
      Map<String, dynamic>? ticket;
      try {
        final instList = await supabase
            .from('installations')
            .select('id, customer_signature_url, technician_signature_url, technician_name, notes, product_name, title, created_at')
            .eq('customer_id', pipeline.customerId)
            .order('created_at', ascending: false);
        ticket = WorkProgressService.resolveInstallationForPipeline(
          installations: (instList as List? ?? []),
          pipelineId: pipeline.id,
          dealNumber: pipeline.dealId,
          productName: pipeline.product?.name,
          dealCreatedAt: pipeline.createdAt,
        );
      } catch (_) {}

      final prefillTechName = ticket?['technician_name']?.toString() ?? ref.read(currentProfileProvider)?.fullName;

      // Prompt for Customer & Technician Signatures (fresh new signatures taken for NOC)
      if (!mounted) return;
      final sigResult = await NocSignaturesDialog.show(
        context: context,
        customerName: customerName,
        initialTechnicianName: prefillTechName,
      );

      if (sigResult == null) return; // User cancelled

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final qRes = await supabase.from('quotations').select().eq('pipeline_id', pipeline.id).maybeSingle();
      final qData = qRes != null ? Map<String, dynamic>.from(qRes) : null;

      final rawLines = (qData?['line_items'] is List)
          ? List<Map<String, dynamic>>.from(qData!['line_items'] as List)
          : (pipeline.quotation != null
              ? pipeline.quotation!.lineItems.map((l) => l.toJson()).toList()
              : <Map<String, dynamic>>[]);

      final itemsTreatedAsProducts = await QgNocExtractor.fetchItemsTreatedAsProducts(supabase);

      String productName = '';
      if (rawLines.isNotEmpty) {
        final firstDesc = (rawLines.first['description'] ?? rawLines.first['item_name'])?.toString().trim() ?? '';
        if (firstDesc.isNotEmpty) productName = firstDesc;
      }
      if (productName.isEmpty && pipeline.quotation != null && pipeline.quotation!.lineItems.isNotEmpty) {
        productName = pipeline.quotation!.lineItems.first.description.trim();
      }
      if (productName.isEmpty) productName = pipeline.product?.name ?? 'Standard System';

      final equipmentLines = QgNocExtractor.extractEquipmentLines(
        lineItems: rawLines,
        defaultProductName: productName,
        itemsTreatedAsProducts: itemsTreatedAsProducts,
      );

      final compConfig = await QgNocRepository.fetchCompanyDetailsFromTemplate(
        supabase,
        productId: pipeline.productId,
        productName: productName,
      );
      final companyName = compConfig['company_name']?.toString() ?? 'INSIYA TRADING CORPORATION';
      final companyAddress = compConfig['company_address']?.toString() ?? compConfig['address']?.toString() ?? '';
      final companyPhone = compConfig['company_phone']?.toString() ?? compConfig['phone']?.toString() ?? '';
      final companyEmail = compConfig['company_email']?.toString() ?? compConfig['email']?.toString() ?? '';
      final companyWebsite = compConfig['company_website']?.toString() ?? compConfig['website']?.toString() ?? 'www.izyheat.com';
      final logoUrl = compConfig['logo_url']?.toString();

      final subject = 'No Objection Certificate for Installation & Commissioning of $productName.';
      final rawQuote = qData?['quotation_number']?.toString() ?? pipeline.baseQuotationNumber;
      final quoteNumber = rawQuote.isNotEmpty ? FinancialYearHelper.extractBaseNumber(rawQuote) : null;

      final nocProfile = await QgNocRepository.instance.getProfileForProduct(productName);
      final profileConfirmations = nocProfile.confirmationLines.isNotEmpty
          ? nocProfile.confirmationLines.map((l) => l.replaceAll('{Product}', productName)).toList()
          : [
              '1. The installation of the $productName system is permitted at the above location.',
              '2. The system installed as per standard safety norms and guidelines.',
              '3. Necessary precautions has been taken to avoid noise, vibration, or water leakage issues.',
            ];
      final profileClosing = (nocProfile.closingSentence ?? 'This NOC is issued upon request for installation and operation of the {Product} System.')
          .replaceAll('{Product}', productName);

      final payload = QgNocPayload(
        companyName: companyName,
        companyAddress: companyAddress,
        companyEmail: companyEmail,
        companyPhone: companyPhone,
        companyWebsite: companyWebsite,
        logoUrl: logoUrl,
        salutation: 'M/s',
        customerName: customerName,
        address: siteAddress,
        productName: productName,
        subject: subject,
        date: DateTime.now(),
        equipmentLabel: productName,
        equipmentLines: equipmentLines,
        workType: '$productName Installation work',
        wiring: 'Done',
        testing: 'Done',
        remark: 'All Installation & Commissioning work Completed as per work order',
        confirmations: profileConfirmations,
        closingSentence: profileClosing,
        customerSignatureUrl: sigResult.customerSignature,
        customerSignatoryName: sigResult.customerSignatoryName,
        technicianSignatureUrl: sigResult.technicianSignature,
        technicianName: sigResult.technicianName,
        wordingMode: NocWordingMode.templateExact,
        quotationNumber: quoteNumber,
      );

      final pdfBytes = await PdfNocBuilder.buildNocPdf(payload);

      final issuedDoc = await QgNocRepository.finalizeAndIssueNoc(
        dealId: pipeline.id,
        quotationId: qData?['id']?.toString() ?? pipeline.quotation?.id,
        customerName: customerName,
        siteAddress: siteAddress,
        productName: productName,
        wordingMode: NocWordingMode.templateExact,
        equipmentLines: equipmentLines,
        pdfBytes: pdfBytes,
        companySnapshot: compConfig,
        confirmations: profileConfirmations,
        closingSentence: profileClosing,
        customerSignatureUrl: sigResult.customerSignature,
        customerSignatoryName: sigResult.customerSignatoryName,
        technicianSignatureUrl: sigResult.technicianSignature,
        technicianName: sigResult.technicianName,
        overrideReason: 'Completed deal installation & commissioning verified for $productName',
      );

      // Back-propagate signatures to installation ticket if missing
      if (ticket != null && ticket['id'] != null) {
        try {
          final updates = <String, dynamic>{};
          if ((ticket['customer_signature_url'] == null || ticket['customer_signature_url'].toString().isEmpty) && sigResult.customerSignature.isNotEmpty) {
            updates['customer_signature_url'] = sigResult.customerSignature;
          }
          if ((ticket['technician_signature_url'] == null || ticket['technician_signature_url'].toString().isEmpty) && sigResult.technicianSignature.isNotEmpty) {
            updates['technician_signature_url'] = sigResult.technicianSignature;
          }
          if (updates.isNotEmpty) {
            await supabase.from('installations').update(updates).eq('id', ticket['id']);
          }
        } catch (_) {}
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _nocDoc = issuedDoc;
          _isNocCompleted = true;
        });

        ref.invalidate(pipelineDetailProvider(widget.pipeline.id));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ NOC ${issuedDoc.nocNumber} issued successfully!'),
            backgroundColor: const Color(0xFF286B37),
          ),
        );

        _viewNocPdf(issuedDoc);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating NOC: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<bool> _showConfirmRevertDialog({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: AppColors.warning, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textPrimary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final pipeline = widget.pipeline;
    final meta = WorkProgressService.parseProgressMeta(pipeline);
    final deliveryChallans = WorkProgressService.getDeliveryChallans(pipeline);
    final profile = ref.watch(currentProfileProvider);

    final bool canViewQuoteAndSo = RoleAccess.canViewQuotationAndSalesOrder(profile);
    final bool canManageFactoryTrack = RoleAccess.canManageFactoryTrack(profile);
    final bool canManageSiteTrack = RoleAccess.canManageSiteTrack(profile);
    final bool canGenerateDeliveryChallan = RoleAccess.canGenerateDeliveryChallan(profile);
    final bool hasDeliveryChallan = deliveryChallans.isNotEmpty;

    // Live Step 1: Quotation
    final bool step1QuotationDone = pipeline.quotation != null;

    // Live Step 2: Sales Order
    final bool step2SalesOrderDone = pipeline.salesOrder != null;

    // Live Sub-Track A: Factory Track
    // BOQ -> Ready -> Dispatched
    final bool factoryBoqDone = pipeline.boq != null &&
        (pipeline.boq!.items.any((i) => i.scope == 'company') || pipeline.boq!.isSubmitted || pipeline.boq!.items.isNotEmpty);
    final bool factoryOrderReady = meta['factory_ready'] == true ||
        (pipeline.factoryOrder != null &&
            (pipeline.factoryOrder!.status == FactoryOrderStatus.completed ||
                pipeline.factoryOrder!.status == FactoryOrderStatus.inProduction));
    final bool factoryDispatched = meta['factory_dispatched'] == true;

    int factoryProgressCount = 0;
    if (factoryBoqDone) factoryProgressCount++;
    if (factoryOrderReady) factoryProgressCount++;
    if (factoryDispatched) factoryProgressCount++;

    // Live Sub-Track B: Site Track
    // BOQ -> Ready -> Dispatched
    final bool siteBoqDone = pipeline.boq != null &&
        (pipeline.boq!.items.any((i) => i.scope == 'customer') || pipeline.boq!.extraFields.isNotEmpty || pipeline.boq!.isSubmitted);
    final bool siteReady = meta['site_ready'] == true ||
        (pipeline.purchaseOrder != null && pipeline.purchaseOrder!.items.isNotEmpty);
    final bool siteDispatched = meta['site_dispatched'] == true || deliveryChallans.isNotEmpty;

    int siteProgressCount = 0;
    if (siteBoqDone) siteProgressCount++;
    if (siteReady) siteProgressCount++;
    if (siteDispatched) siteProgressCount++;

    // Live Step 3: Material & Dispatch overall
    final bool step3DispatchDone = factoryDispatched && siteDispatched;
    final bool step3DispatchActive = step2SalesOrderDone && !step3DispatchDone;

    // Live Step 4: Installation
    final bool step4InstallDone = _isInstallationCompleted;
    final bool hasAnyChallanOrDispatch = deliveryChallans.isNotEmpty || siteDispatched || step3DispatchDone;
    final bool isInstallUnlocked = hasAnyChallanOrDispatch || _isInstallationCreated;
    final bool step4InstallActive = (isInstallUnlocked) && !step4InstallDone;

    // Live Step 5: NOC
    final bool step5NocDone = _isNocCompleted;
    final bool step5NocActive = step4InstallDone && !step5NocDone;

    // Count overall completed phases (out of 5)
    int completedPhases = 0;
    if (step1QuotationDone) completedPhases++;
    if (step2SalesOrderDone) completedPhases++;
    if (step3DispatchDone || (factoryDispatched || siteDispatched)) completedPhases++;
    if (step4InstallDone) completedPhases++;
    if (step5NocDone) completedPhases++;

    final double overallFraction = (completedPhases / 5.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_tree_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Work Progress',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (_loadingAux) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Live order fulfillment & commissioning pipeline',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: AppColors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: overallFraction == 1.0
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: overallFraction == 1.0
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : const Color(0xFF2563EB).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '$completedPhases / 5 (${(overallFraction * 100).toInt()}%)',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: overallFraction == 1.0 ? const Color(0xFF059669) : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Sleek progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: overallFraction,
                backgroundColor: AppColors.border.withValues(alpha: 0.6),
                valueColor: AlwaysStoppedAnimation<Color>(
                  overallFraction == 1.0 ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 2. Top Horizontal Compact Stepper (Matching Reference Image)
          _buildTopHorizontalStepper(
            step1Done: step1QuotationDone,
            step2Done: step2SalesOrderDone,
            step3Done: step3DispatchDone,
            step3Active: step3DispatchActive,
            step4Done: step4InstallDone,
            step4Active: step4InstallActive,
            step5Done: step5NocDone,
            step5Active: step5NocActive,
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          // 3. Vertical Timeline Pipeline Nodes
          // Node 1: Quotation
          _buildVerticalNode(
            isFirst: true,
            isCompleted: step1QuotationDone,
            isActive: !step1QuotationDone,
            title: 'Quotation',
            statusText: step1QuotationDone ? 'Done' : 'Pending',
            statusColor: step1QuotationDone ? AppColors.success : AppColors.textDisabled,
            onTap: (step1QuotationDone && canViewQuoteAndSo) ? _viewQuotationPdf : null,
            child: (step1QuotationDone && canViewQuoteAndSo)
                ? Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: InkWell(
                      onTap: _viewQuotationPdf,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'View Quote PDF (${pipeline.baseQuotationNumber})',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          ),

          // Node 2: Sales Order
          _buildVerticalNode(
            isCompleted: step2SalesOrderDone,
            isActive: step1QuotationDone && !step2SalesOrderDone,
            title: 'Sales Order',
            statusText: step2SalesOrderDone ? 'Done' : (step1QuotationDone ? 'In Work' : 'Locked'),
            statusColor: step2SalesOrderDone ? AppColors.success : (step1QuotationDone ? const Color(0xFF2563EB) : AppColors.textDisabled),
            onTap: (step2SalesOrderDone && canViewQuoteAndSo) ? _viewSalesOrderPdf : null,
            child: (step2SalesOrderDone && canViewQuoteAndSo)
                ? Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: InkWell(
                      onTap: _viewSalesOrderPdf,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'View SO PDF (${pipeline.salesOrder != null ? PdfService.formatSalesOrderNumber(pipeline.salesOrder!.salesOrderNumber, pipeline.salesOrder!.orderDate) : ""})',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          ),

          // Node 3: Material & Dispatch (Dual Tracks + Delivery Challan Slot)
          _buildVerticalNode(
            isCompleted: step3DispatchDone,
            isActive: step3DispatchActive,
            isLocked: !step2SalesOrderDone,
            title: 'Material & Dispatch',
            statusText: step3DispatchDone ? 'Done' : (step3DispatchActive ? 'In Work' : 'Locked'),
            statusColor: step3DispatchDone ? AppColors.success : (step3DispatchActive ? const Color(0xFF2563EB) : AppColors.textDisabled),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Sub-Card A: Factory Track
                _buildSubTrackCard(
                  icon: Icons.factory_outlined,
                  trackTitle: 'Factory Track',
                  progressFractionText: '$factoryProgressCount/3',
                  step1Title: 'BOQ',
                  step1Done: factoryBoqDone,
                  step2Title: 'Ready',
                  step2Done: factoryOrderReady,
                  step2Active: factoryBoqDone && !factoryOrderReady,
                  onTapStep2: (factoryOrderReady && !factoryDispatched && canManageFactoryTrack)
                      ? () async {
                          final confirm = await _showConfirmRevertDialog(
                            title: 'Unmark Factory Ready?',
                            message: 'Are you sure you want to revert factory status back to unready?',
                            confirmText: 'Unmark Ready',
                          );
                          if (confirm) {
                            final supabase = ref.read(supabaseClientProvider);
                            await WorkProgressService.updateTrackStatus(supabase, pipeline.id, factoryReady: false);
                            ref.invalidate(pipelineDetailProvider(pipeline.id));
                          }
                        }
                      : null,
                  step3Title: 'Dispatched',
                  step3Done: factoryDispatched,
                  step3Active: factoryOrderReady && !factoryDispatched,
                  onTapStep3: (factoryDispatched && canManageFactoryTrack)
                      ? () async {
                          final confirm = await _showConfirmRevertDialog(
                            title: 'Unmark Factory Dispatched?',
                            message: 'Are you sure you want to revert factory dispatch status back to ready?',
                            confirmText: 'Unmark Dispatched',
                          );
                          if (confirm) {
                            final supabase = ref.read(supabaseClientProvider);
                            await WorkProgressService.updateTrackStatus(supabase, pipeline.id, factoryDispatched: false);
                            ref.invalidate(pipelineDetailProvider(pipeline.id));
                          }
                        }
                      : null,
                  showAction: factoryBoqDone,
                  actionButtonText: factoryDispatched
                      ? 'Factory Dispatched ✓ (Tap to Unmark)'
                      : (factoryOrderReady
                          ? (hasDeliveryChallan ? 'Mark Factory Dispatched' : 'Mark Factory Dispatched (Challan Req.)')
                          : 'Mark Factory Ready'),
                  isActionDone: factoryDispatched,
                  onAction: !canManageFactoryTrack
                      ? null
                      : (factoryDispatched
                          ? () async {
                              final confirm = await _showConfirmRevertDialog(
                                title: 'Unmark Factory Dispatched?',
                                message: 'Are you sure you want to revert factory dispatch status back to ready?',
                                confirmText: 'Unmark Dispatched',
                              );
                              if (confirm) {
                                final supabase = ref.read(supabaseClientProvider);
                                await WorkProgressService.updateTrackStatus(supabase, pipeline.id, factoryDispatched: false);
                                ref.invalidate(pipelineDetailProvider(pipeline.id));
                              }
                            }
                          : (!factoryOrderReady
                              ? () async {
                                  final supabase = ref.read(supabaseClientProvider);
                                  await WorkProgressService.updateTrackStatus(supabase, pipeline.id, factoryReady: true);
                                  ref.invalidate(pipelineDetailProvider(pipeline.id));
                                }
                              : (hasDeliveryChallan
                                  ? () async {
                                      final supabase = ref.read(supabaseClientProvider);
                                      await WorkProgressService.updateTrackStatus(supabase, pipeline.id, factoryDispatched: true);
                                      ref.invalidate(pipelineDetailProvider(pipeline.id));
                                    }
                                  : null))),
                  onRevertReady: (factoryOrderReady && !factoryDispatched && canManageFactoryTrack)
                      ? () async {
                          final confirm = await _showConfirmRevertDialog(
                            title: 'Unmark Factory Ready?',
                            message: 'Are you sure you want to revert factory status back to unready?',
                            confirmText: 'Unmark Ready',
                          );
                          if (confirm) {
                            final supabase = ref.read(supabaseClientProvider);
                            await WorkProgressService.updateTrackStatus(supabase, pipeline.id, factoryReady: false);
                            ref.invalidate(pipelineDetailProvider(pipeline.id));
                          }
                        }
                      : null,
                ),

                const SizedBox(height: 12),

                // Sub-Card B: Site Track
                _buildSubTrackCard(
                  icon: Icons.location_on_outlined,
                  trackTitle: 'Site Track',
                  progressFractionText: '$siteProgressCount/3',
                  step1Title: 'BOQ',
                  step1Done: siteBoqDone,
                  step2Title: 'Ready',
                  step2Done: siteReady,
                  step2Active: siteBoqDone && !siteReady,
                  onTapStep2: (siteReady && !siteDispatched && canManageSiteTrack)
                      ? () async {
                          final confirm = await _showConfirmRevertDialog(
                            title: 'Unmark Material Ready?',
                            message: 'Are you sure you want to revert site material status back to unready?',
                            confirmText: 'Unmark Ready',
                          );
                          if (confirm) {
                            final supabase = ref.read(supabaseClientProvider);
                            await WorkProgressService.updateTrackStatus(supabase, pipeline.id, siteReady: false);
                            ref.invalidate(pipelineDetailProvider(pipeline.id));
                          }
                        }
                      : null,
                  step3Title: 'Dispatched',
                  step3Done: siteDispatched,
                  step3Active: siteReady && !siteDispatched,
                  onTapStep3: (siteDispatched && canManageSiteTrack)
                      ? () async {
                          final confirm = await _showConfirmRevertDialog(
                            title: 'Unmark Material Dispatched?',
                            message: 'Are you sure you want to revert site dispatch status back to ready?',
                            confirmText: 'Unmark Dispatched',
                          );
                          if (confirm) {
                            final supabase = ref.read(supabaseClientProvider);
                            await WorkProgressService.updateTrackStatus(supabase, pipeline.id, siteDispatched: false);
                            ref.invalidate(pipelineDetailProvider(pipeline.id));
                          }
                        }
                      : null,
                  showAction: siteBoqDone,
                  actionButtonText: siteDispatched
                      ? 'Material Dispatched ✓ (Tap to Unmark)'
                      : (siteReady
                          ? (hasDeliveryChallan ? 'Mark Material Dispatched' : 'Mark Material Dispatched (Challan Req.)')
                          : 'Mark Material Ready'),
                  isActionDone: siteDispatched,
                  onAction: !canManageSiteTrack
                      ? null
                      : (siteDispatched
                          ? () async {
                              final confirm = await _showConfirmRevertDialog(
                                title: 'Unmark Material Dispatched?',
                                message: 'Are you sure you want to revert site dispatch status back to ready?',
                                confirmText: 'Unmark Dispatched',
                              );
                              if (confirm) {
                                final supabase = ref.read(supabaseClientProvider);
                                await WorkProgressService.updateTrackStatus(supabase, pipeline.id, siteDispatched: false);
                                ref.invalidate(pipelineDetailProvider(pipeline.id));
                              }
                            }
                          : (!siteReady
                              ? () async {
                                  final supabase = ref.read(supabaseClientProvider);
                                  await WorkProgressService.updateTrackStatus(supabase, pipeline.id, siteReady: true);
                                  ref.invalidate(pipelineDetailProvider(pipeline.id));
                                }
                              : (hasDeliveryChallan
                                  ? () async {
                                      final supabase = ref.read(supabaseClientProvider);
                                      await WorkProgressService.updateTrackStatus(supabase, pipeline.id, siteDispatched: true);
                                      ref.invalidate(pipelineDetailProvider(pipeline.id));
                                    }
                                  : null))),
                  onRevertReady: (siteReady && !siteDispatched && canManageSiteTrack)
                      ? () async {
                          final confirm = await _showConfirmRevertDialog(
                            title: 'Unmark Material Ready?',
                            message: 'Are you sure you want to revert site material status back to unready?',
                            confirmText: 'Unmark Ready',
                          );
                          if (confirm) {
                            final supabase = ref.read(supabaseClientProvider);
                            await WorkProgressService.updateTrackStatus(supabase, pipeline.id, siteReady: false);
                            ref.invalidate(pipelineDetailProvider(pipeline.id));
                          }
                        }
                      : null,
                ),

                const SizedBox(height: 12),

                // Dedicated Slot: Delivery Challans
                _buildDeliveryChallansSlot(
                  deliveryChallans,
                  canGenerate: canGenerateDeliveryChallan,
                  isDispatchStepReached: step2SalesOrderDone,
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),

          // Node 4: Installation
          _buildVerticalNode(
            isCompleted: step4InstallDone,
            isActive: step4InstallActive,
            isLocked: !isInstallUnlocked,
            title: 'Installation',
            statusText: step4InstallDone
                ? 'Done'
                : (_isInstallationCreated
                    ? (_installationStatus == 'in_progress'
                        ? 'In Progress'
                        : (_installationStatus == 'assigned' ? 'Assigned' : 'Created'))
                    : (isInstallUnlocked ? 'Ready' : 'Locked')),
            statusColor: step4InstallDone
                ? AppColors.success
                : (_isInstallationCreated
                    ? const Color(0xFFD97706)
                    : (isInstallUnlocked ? const Color(0xFF2563EB) : AppColors.textDisabled)),
            onTap: isInstallUnlocked ? _showInstallationDialog : null,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: isInstallUnlocked
                  ? Row(
                      children: [
                        if (_isInstallationCreated && _installationTicketNumber != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: step4InstallDone ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _dealInstallations.length > 1
                                  ? '${_dealInstallations.length} Tickets'
                                  : _installationTicketNumber!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: step4InstallDone ? const Color(0xFF065F46) : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        InkWell(
                          onTap: _showInstallationDialog,
                          child: Text(
                            _isInstallationCreated ? 'View Tickets & Status ➔' : 'Assign / Check Installation ➔',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Unlocks automatically once Material & Dispatch step is started.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textDisabled),
                    ),
            ),
          ),

          // Node 5: NOC
          _buildVerticalNode(
            isLast: true,
            isCompleted: step5NocDone,
            isActive: step5NocActive,
            isLocked: !step4InstallDone,
            title: 'NOC (No Objection Certificate)',
            statusText: step5NocDone
                ? 'Issued ✓'
                : (step4InstallDone ? 'Ready' : 'Locked'),
            statusColor: step5NocDone
                ? AppColors.success
                : (step4InstallDone ? const Color(0xFF2563EB) : AppColors.textDisabled),
            onTap: step5NocDone
                ? () => _viewNocPdf(_nocDoc!)
                : (step4InstallDone ? _generateNoc : null),
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: step5NocDone
                  ? OutlinedButton.icon(
                      onPressed: () => _viewNocPdf(_nocDoc!),
                      icon: const Icon(Icons.verified, size: 14, color: Color(0xFF059669)),
                      label: Text(
                        'View NOC PDF (${_nocDoc!.nocNumber})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  : Text(
                      step4InstallDone
                          ? 'Ready to be generated.'
                          : 'Unlocks automatically once customer installation is resolved/closed.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: step4InstallDone ? const Color(0xFF059669) : AppColors.textSecondary,
                        fontWeight: step4InstallDone ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Top Horizontal Compact Stepper
  Widget _buildTopHorizontalStepper({
    required bool step1Done,
    required bool step2Done,
    required bool step3Done,
    required bool step3Active,
    required bool step4Done,
    required bool step4Active,
    required bool step5Done,
    required bool step5Active,
  }) {
    return Row(
      children: [
        _buildTopStepperItem('Quote', step1Done, !step1Done),
        _buildTopStepperLine(step1Done),
        _buildTopStepperItem('Sales Order', step2Done, step1Done && !step2Done),
        _buildTopStepperLine(step2Done),
        _buildTopStepperItem('Dispatch', step3Done, step3Active),
        _buildTopStepperLine(step3Done),
        _buildTopStepperItem('Install', step4Done, step4Active),
        _buildTopStepperLine(step4Done),
        _buildTopStepperItem('NOC', step5Done, step5Active),
      ],
    );
  }

  Widget _buildTopStepperItem(String title, bool isDone, bool isActive) {
    Color iconBg;
    Widget iconChild;

    if (isDone) {
      iconBg = const Color(0xFF10B981);
      iconChild = const Icon(Icons.check, size: 12, color: Colors.white);
    } else if (isActive) {
      iconBg = const Color(0xFF2563EB);
      iconChild = Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
    } else {
      iconBg = const Color(0xFFE2E8F0);
      iconChild = const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: iconChild,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
            color: isDone
                ? const Color(0xFF059669)
                : (isActive ? const Color(0xFF1E3A8A) : const Color(0xFF94A3B8)),
          ),
        ),
      ],
    );
  }

  Widget _buildTopStepperLine(bool isDone) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 2,
        color: isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
      ),
    );
  }

  // Vertical Timeline Node with connector
  Widget _buildVerticalNode({
    bool isFirst = false,
    bool isLast = false,
    required bool isCompleted,
    required bool isActive,
    bool isLocked = false,
    required String title,
    required String statusText,
    required Color statusColor,
    VoidCallback? onTap,
    Widget? child,
  }) {
    Widget indicator;
    if (isCompleted) {
      indicator = Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFF10B981),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    } else if (isActive) {
      indicator = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2563EB), width: 2),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else {
      indicator = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator & vertical line
          Column(
            children: [
              indicator,
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: isLocked ? const Color(0xFF94A3B8) : AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (child != null) child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sub-Track Card (Factory / Site Track)
  Widget _buildSubTrackCard({
    required IconData icon,
    required String trackTitle,
    required String progressFractionText,
    required String step1Title,
    required bool step1Done,
    required String step2Title,
    required bool step2Done,
    required bool step2Active,
    VoidCallback? onTapStep2,
    required String step3Title,
    required bool step3Done,
    required bool step3Active,
    VoidCallback? onTapStep3,
    required bool showAction,
    required String actionButtonText,
    required bool isActionDone,
    VoidCallback? onAction,
    VoidCallback? onRevertReady,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Track Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF334155)),
                  const SizedBox(width: 8),
                  Text(
                    trackTitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  progressFractionText,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Mini horizontal stepper
          Row(
            children: [
              _buildMiniStep(step1Title, step1Done, false),
              _buildMiniLine(step1Done),
              _buildMiniStep(step2Title, step2Done, step2Active, onTap: onTapStep2),
              _buildMiniLine(step2Done),
              _buildMiniStep(step3Title, step3Done, step3Active, onTap: onTapStep3),
            ],
          ),

          const SizedBox(height: 12),

          // Action Button Area
          if (!showAction)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: const [
                  Icon(Icons.lock_outline, size: 13, color: Color(0xFF94A3B8)),
                  SizedBox(width: 6),
                  Text(
                    'Step locked until BOQ is completed.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActionDone ? const Color(0xFFECFDF5) : const Color(0xFF2563EB),
                  foregroundColor: isActionDone ? const Color(0xFF059669) : Colors.white,
                  disabledBackgroundColor: const Color(0xFFF1F5F9),
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  elevation: (isActionDone || onAction == null) ? 0 : 1,
                  side: isActionDone
                      ? const BorderSide(color: Color(0xFF10B981))
                      : (onAction == null ? BorderSide(color: Colors.grey.shade300) : BorderSide.none),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onAction,
                child: Text(
                  actionButtonText,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (onRevertReady != null) ...[
              const SizedBox(height: 4),
              Center(
                child: InkWell(
                  onTap: onRevertReady,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.undo, size: 12, color: Color(0xFF64748B)),
                        SizedBox(width: 4),
                        Text(
                          'Unmark Ready?',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B), decoration: TextDecoration.underline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStep(String label, bool isDone, bool isActive, {VoidCallback? onTap}) {
    Widget icon;
    if (isDone) {
      icon = Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 11, color: Colors.white),
      );
    } else if (isActive) {
      icon = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2563EB), width: 2),
        ),
        child: Center(
          child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle)),
        ),
      );
    } else {
      icon = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        ),
      );
    }

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: isDone || isActive ? FontWeight.bold : FontWeight.normal,
            color: isDone ? const Color(0xFF059669) : (isActive ? const Color(0xFF1E3A8A) : const Color(0xFF64748B)),
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: column,
        ),
      );
    }
    return column;
  }

  Widget _buildMiniLine(bool isDone) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 2,
        color: isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
      ),
    );
  }

  // Dedicated Slot: Delivery Challans
  Widget _buildDeliveryChallansSlot(
    List<Map<String, dynamic>> challans, {
    bool canGenerate = false,
    bool isDispatchStepReached = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 18, color: Color(0xFF166534)),
                  const SizedBox(width: 8),
                  const Text(
                    'Delivery Challans',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF14532D),
                    ),
                  ),
                  if (challans.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${challans.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          if (challans.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...challans.map((dc) {
              final dcNum = dc['challan_number']?.toString() ?? 'Challan';
              final dStr = dc['date'] != null
                  ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(dc['date'].toString()) ?? DateTime.now())
                  : '';
              final itemCount = dc['item_count'] ?? (dc['items'] as List?)?.length ?? 0;
              final receiver = dc['delivery_taken_by']?.toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 16, color: Color(0xFF166534)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dcNum,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '$dStr • $itemCount items${(receiver != null && receiver.isNotEmpty) ? " • Recv: $receiver" : ""}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF166534),
                        side: const BorderSide(color: Color(0xFF22C55E)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(50, 28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _viewExistingChallan(dc),
                      icon: const Icon(Icons.picture_as_pdf, size: 13),
                      label: const Text('View PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }),
          ] else if (!canGenerate) ...[
            const SizedBox(height: 8),
            const Text(
              'No delivery challans generated yet. (Admins only)',
              style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textDisabled, fontStyle: FontStyle.italic),
            ),
          ],

          if (canGenerate) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDispatchStepReached ? const Color(0xFF16A34A) : Colors.grey.shade300,
                  foregroundColor: isDispatchStepReached ? Colors.white : Colors.grey.shade600,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                  elevation: isDispatchStepReached ? 1 : 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: isDispatchStepReached ? _openDeliveryChallanModal : null,
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  !isDispatchStepReached
                      ? 'Challan Locked (Sales Order Required)'
                      : (challans.isEmpty ? 'Generate Delivery Challan' : 'Add Another Delivery Challan'),
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
