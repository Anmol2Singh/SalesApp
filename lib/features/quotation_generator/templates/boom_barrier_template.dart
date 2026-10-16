// lib/features/quotation_generator/templates/boom_barrier_template.dart

import 'dart:typed_data';
import 'package:flutter/widgets.dart';

import '../models/boom_barrier_proposal_draft.dart';
import '../models/deal_quotation_item.dart';
import '../models/qg_product_profile.dart';
import '../services/pdf_boom_barrier_builder.dart';
import '../ui/screens/boom_barrier_proposal_builder_screen.dart';
import 'qg_product_template.dart';

/// Boom Barrier template implementation.
class BoomBarrierTemplate implements QgProductTemplate {
  const BoomBarrierTemplate();

  @override
  String get key => 'boom_barrier_quotation';

  @override
  String get label => 'Boom Barrier';

  @override
  bool matchesProduct(String productName) {
    final lower = productName.toLowerCase();
    return lower.contains('boom barrier') ||
        lower.contains('boombarrier') ||
        lower.contains('barrier');
  }

  @override
  Widget buildBuilderBody(
    BuildContext context, {
    required String quotationId,
    required DealQuotationItem dealOption,
    required QgProductProfile profile,
  }) {
    return BoomBarrierProposalBuilderScreen(
      quotationId: quotationId,
      initialDealQuotation: dealOption,
      initialProfile: profile,
    );
  }

  @override
  Future<Uint8List> buildPdf({
    required dynamic draft,
    required QgProductProfile profile,
    Map<String, dynamic>? assets,
  }) async {
    final BoomBarrierProposalDraft bbDraft;
    if (draft is BoomBarrierProposalDraft) {
      bbDraft = draft;
    } else if (draft is Map) {
      bbDraft = BoomBarrierProposalDraft.fromJson(Map<String, dynamic>.from(draft));
    } else {
      throw ArgumentError(
        'Draft must be of type BoomBarrierProposalDraft or Map for BoomBarrierTemplate',
      );
    }

    final overrides = assets?.map((k, v) => MapEntry(k, v as Uint8List));
    return PdfBoomBarrierBuilder.buildQuotationPdf(
      bbDraft,
      profile,
      assetOverrides: overrides,
    );
  }
}
