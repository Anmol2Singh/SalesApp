// lib/features/quotation_generator/services/qg_payment_sentence_builder.dart

/// Builds deterministic payment term sentences matching the reference template.
/// Supports both Annexure III (with the 'satisfactoryinstallation' quirk)
/// and the Quotation Acceptance Letter (with standard spacing 'satisfactory installation').
class QgPaymentSentenceBuilder {
  /// Builds the payment terms sentence.
  /// If [isAnnexureQuirk] is true, uses the template quirk 'satisfactoryinstallation'.
  static String buildSentence({
    required List<Map<String, dynamic>> paymentTerms,
    bool isAnnexureQuirk = false,
  }) {
    if (paymentTerms.isEmpty) {
      final term3 = isAnnexureQuirk
          ? 'satisfactoryinstallation and commissioning'
          : 'satisfactory installation and commissioning';
      return 'Advance will be 70% against PO, and 20% against delivery, the balance 10% against $term3.';
    }

    // Normalized stages: combine consecutive installation & commissioning if any
    final stages = <_PaymentStage>[];
    for (final pt in paymentTerms) {
      final term = pt['term']?.toString().trim() ?? '';
      final percent = (pt['percent'] as num?)?.toInt() ??
          (pt['percentage'] as num?)?.toInt() ??
          0;
      if (percent <= 0) continue;

      final phrase = _resolvePhrase(term, isAnnexureQuirk: isAnnexureQuirk);
      stages.add(_PaymentStage(percent: percent, phrase: phrase));
    }

    if (stages.isEmpty) {
      final term3 = isAnnexureQuirk
          ? 'satisfactoryinstallation and commissioning'
          : 'satisfactory installation and commissioning';
      return 'Advance will be 70% against PO, and 20% against delivery, the balance 10% against $term3.';
    }

    if (stages.length == 1) {
      return '${stages.first.percent}% Advance against ${stages.first.phrase}.';
    }

    final buffer = StringBuffer();
    // First stage
    buffer.write('Advance will be ${stages.first.percent}% against ${stages.first.phrase}');

    // Intermediate stages (from index 1 to length - 2)
    for (int i = 1; i < stages.length - 1; i++) {
      buffer.write(', and ${stages[i].percent}% against ${stages[i].phrase}');
    }

    // Last stage
    final last = stages.last;
    buffer.write(', the balance ${last.percent}% against ${last.phrase}.');

    return buffer.toString();
  }

  /// Helper when given integer splits (advance, delivery, commissioning).
  static String buildFromSplits({
    int advance = 70,
    int delivery = 20,
    int commissioning = 10,
    bool isAnnexureQuirk = false,
  }) {
    final termCommissioning = isAnnexureQuirk
        ? 'satisfactoryinstallation and commissioning'
        : 'satisfactory installation and commissioning';

    if (delivery == 0 && commissioning == 0) {
      return '$advance% Advance against PO.';
    }

    if (commissioning == 0) {
      return 'Advance will be $advance% against PO, the balance $delivery% against delivery.';
    }

    if (delivery == 0) {
      return 'Advance will be $advance% against PO, the balance $commissioning% against $termCommissioning.';
    }

    return 'Advance will be $advance% against PO, and $delivery% against delivery, the balance $commissioning% against $termCommissioning.';
  }

  static String _resolvePhrase(String rawTerm, {required bool isAnnexureQuirk}) {
    final lower = rawTerm.toLowerCase();
    final installPhrase = isAnnexureQuirk
        ? 'satisfactoryinstallation and commissioning'
        : 'satisfactory installation and commissioning';

    if (lower.contains('advance') || lower.contains('po') || lower.contains('order')) {
      return 'PO';
    } else if (lower.contains('delivery') || lower.contains('dispatch') || lower.contains('proforma')) {
      return 'delivery';
    } else if (lower.contains('completion')) {
      return 'completion';
    } else if (lower.contains('install') || lower.contains('commission')) {
      return installPhrase;
    }

    return lower;
  }
}

class _PaymentStage {
  final int percent;
  final String phrase;

  const _PaymentStage({required this.percent, required this.phrase});
}
