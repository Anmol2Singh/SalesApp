// lib/features/quotation_generator/services/qg_noc_eligibility_service.dart

import '../models/qg_noc_builder_state.dart';

class QgNocEligibilityService {
  /// Evaluates deal and installation data to determine NOC eligibility.
  /// Pure function for testability and UI guards.
  static NocEligibilityResult evaluateEligibility({
    required Map<String, dynamic> deal,
    required List<Map<String, dynamic>> installations,
    bool isAdmin = false,
  }) {
    final reasons = <String>[];

    // 1. Deal 100% completion check
    final dealStatus = deal['status']?.toString().toLowerCase() ?? '';
    final dealCurrentStep = deal['current_step']?.toString().toLowerCase() ?? '';
    final isDealCompleted = dealStatus == 'completed' || dealCurrentStep == 'completed';

    if (!isDealCompleted) {
      reasons.add('Deal is not 100% complete');
    }

    // 2. Installation resolution check
    final dealId = deal['id']?.toString() ?? '';
    final dealCustomerId = deal['customer_id']?.toString() ?? '';
    final dealCreatedAtStr = deal['created_at']?.toString();
    final dealCreatedAt = dealCreatedAtStr != null ? DateTime.tryParse(dealCreatedAtStr) : null;
    final dealProductName = (deal['products'] is Map ? deal['products']['name'] : deal['product_name'])?.toString().toLowerCase() ?? '';

    Map<String, dynamic>? matched;

    // Preferred: Explicit Deal ID match in notes
    for (final inst in installations) {
      final notes = inst['notes']?.toString() ?? '';
      if (notes.contains('Deal ID: $dealId')) {
        matched = inst;
        break;
      }
    }

    // Fallback: Same customer_id, product match, created on or after deal creation
    if (matched == null) {
      final sortedInst = List<Map<String, dynamic>>.from(installations);
      sortedInst.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate); // Newest first
      });

      for (final inst in sortedInst) {
        final instCustId = inst['customer_id']?.toString() ?? '';
        final instProdName = inst['product_name']?.toString().toLowerCase() ?? '';
        final instCreatedAtStr = inst['created_at']?.toString();
        final instCreatedAt = instCreatedAtStr != null ? DateTime.tryParse(instCreatedAtStr) : null;

        if (instCustId == dealCustomerId) {
          final isAfterDeal = dealCreatedAt == null || instCreatedAt == null || !instCreatedAt.isBefore(dealCreatedAt);
          final matchesProduct = dealProductName.isEmpty || instProdName.isEmpty || instProdName.contains(dealProductName) || dealProductName.contains(instProdName);

          if (isAfterDeal && matchesProduct) {
            matched = inst;
            break;
          }
        }
      }
    }

    // Status check on matched installation
    final instStatus = matched?['status']?.toString().toLowerCase() ?? '';
    final isInstCompleted = matched != null && (instStatus == 'resolved' || instStatus == 'closed');

    if (!isInstCompleted) {
      reasons.add('Installation not completed');
    }

    final isEligible = reasons.isEmpty;
    final canAdminOverride = isAdmin && !isInstCompleted && isDealCompleted;

    return NocEligibilityResult(
      isEligible: isEligible,
      reasons: reasons,
      matchedInstallation: matched,
      canAdminOverride: canAdminOverride,
    );
  }
}
