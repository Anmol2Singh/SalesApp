// lib/features/quotation_generator/services/price_calculator.dart

import '../models/price_item.dart';
import '../models/price_row.dart';

class PriceCalculationResult {
  final int subtotal;
  final double gstPercent;
  final int gstAmount;
  final int grossTotal;
  final int buybackAmount;
  final int netPayable;
  final int grandTotal; // Equal to netPayable
  final List<PriceRow> adjustedRows;

  const PriceCalculationResult({
    required this.subtotal,
    required this.gstPercent,
    required this.gstAmount,
    required this.grossTotal,
    this.buybackAmount = 0,
    required this.netPayable,
    required this.grandTotal,
    this.adjustedRows = const [],
  });
}

class PriceCalculator {
  /// Legacy calculate method for backward compatibility
  static PriceCalculationResult calculate({
    required int tankRate,
    int tankQty = 1,
    PriceRowType hpAmountType = PriceRowType.included,
    int hpNumericPrice = 0,
    int hpQty = 1,
    required List<PriceItem> extraRows,
    double gstPercent = 18.0,
  }) {
    int sub = 0;

    // Heat pump amount
    if (hpAmountType == PriceRowType.amount) {
      sub += hpNumericPrice * hpQty;
    }

    // Storage tank amount (tankRate * tankQty)
    sub += tankRate * tankQty;

    // Extra rows amount
    for (final row in extraRows) {
      if (row.amountType == PriceRowType.amount) {
        sub += row.numericAmount;
      }
    }

    // GST rounded to nearest rupee
    final int gst = ((sub * gstPercent) / 100.0).round();
    final int total = sub + gst;

    return PriceCalculationResult(
      subtotal: sub,
      gstPercent: gstPercent,
      gstAmount: gst,
      grossTotal: total,
      buybackAmount: 0,
      netPayable: total,
      grandTotal: total,
    );
  }

  /// Phase 2 template-driven calculation from dynamic `PriceRow` list
  static PriceCalculationResult calculateFromRows({
    required List<PriceRow> rows,
    double gstPercent = 18.0,
    bool hasBuyback = false,
    int buybackRate = 0,
    int buybackQty = 0,
    String priceEntryMode = 'exclusive',
    int? targetTotal,
  }) {
    final int buyback = hasBuyback ? (buybackRate * buybackQty) : 0;

    if (priceEntryMode == 'inclusive' && targetTotal != null && targetTotal > 0) {
      // Inclusive Mode: Target total is fixed
      final int gross = targetTotal;
      final int sub = (gross / (1.0 + (gstPercent / 100.0))).round();
      final int gst = gross - sub; // Guarantee exact rupee sum
      final int net = gross - buyback;

      // Distribute back-calculated subtotal among priced rows
      final pricedIndices = <int>[];
      for (int i = 0; i < rows.length; i++) {
        if (rows[i].isPriced) pricedIndices.add(i);
      }

      final List<PriceRow> adjusted = List.from(rows);

      if (pricedIndices.isNotEmpty) {
        if (pricedIndices.length == 1) {
          final idx = pricedIndices.first;
          final r = rows[idx];
          final qty = r.qty > 0 ? r.qty : 1;
          adjusted[idx] = r.copyWith(
            rate: sub ~/ qty,
            amount: sub,
          );
        } else {
          int origSum = 0;
          for (final idx in pricedIndices) {
            origSum += rows[idx].computedAmount;
          }

          int allocated = 0;
          for (int j = 0; j < pricedIndices.length; j++) {
            final idx = pricedIndices[j];
            final r = rows[idx];
            final isLast = (j == pricedIndices.length - 1);
            final qty = r.qty > 0 ? r.qty : 1;

            if (isLast) {
              final remainder = sub - allocated;
              adjusted[idx] = r.copyWith(
                rate: remainder ~/ qty,
                amount: remainder,
              );
            } else {
              final double ratio = origSum > 0 ? (r.computedAmount / origSum) : (1.0 / pricedIndices.length);
              final rowSub = (sub * ratio).round();
              allocated += rowSub;
              adjusted[idx] = r.copyWith(
                rate: rowSub ~/ qty,
                amount: rowSub,
              );
            }
          }
        }
      }

      return PriceCalculationResult(
        subtotal: sub,
        gstPercent: gstPercent,
        gstAmount: gst,
        grossTotal: gross,
        buybackAmount: buyback,
        netPayable: net,
        grandTotal: net,
        adjustedRows: adjusted,
      );
    } else {
      // Exclusive Mode: Sum up all priced rows
      int sub = 0;
      for (final r in rows) {
        if (r.isPriced) {
          sub += r.computedAmount;
        }
      }

      final int gst = ((sub * gstPercent) / 100.0).round();
      final int gross = sub + gst;
      final int net = gross - buyback;

      return PriceCalculationResult(
        subtotal: sub,
        gstPercent: gstPercent,
        gstAmount: gst,
        grossTotal: gross,
        buybackAmount: buyback,
        netPayable: net,
        grandTotal: net,
        adjustedRows: rows,
      );
    }
  }

  /// Formats an integer amount into Indian number format e.g. 141600 -> "₹1,41,600"
  static String formatIndianCurrency(int amount, {bool includeSymbol = true}) {
    final prefix = includeSymbol ? '₹' : '';
    if (amount == 0) return '${prefix}0';
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final str = absAmount.toString();

    if (str.length <= 3) {
      return '$prefix${isNegative ? '-' : ''}$str';
    }

    final last3 = str.substring(str.length - 3);
    final rest = str.substring(0, str.length - 3);
    final buffer = StringBuffer();

    for (int i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(rest[i]);
    }
    buffer.write(',');
    buffer.write(last3);

    return '$prefix${isNegative ? '-' : ''}${buffer.toString()}';
  }

  /// Convert integer amount to Indian English words
  /// e.g. 141600 -> "Rupees One Lakh Forty One Thousand Six Hundred Only"
  static String numberToWords(int amount) {
    if (amount == 0) return 'Rupees Zero Only';
    if (amount < 0) return 'Minus ${numberToWords(amount.abs())}';

    final units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    final tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String twoDigits(int n) {
      if (n < 20) return units[n];
      final rem = n % 10;
      return tens[n ~/ 10] + (rem > 0 ? ' ${units[rem]}' : '');
    }

    String threeDigits(int n) {
      if (n == 0) return '';
      final h = n ~/ 100;
      final rem = n % 100;
      final prefix = h > 0 ? '${units[h]} Hundred' : '';
      if (rem == 0) return prefix;
      if (prefix.isEmpty) return twoDigits(rem);
      return '$prefix and ${twoDigits(rem)}';
    }

    int n = amount;
    final parts = <String>[];

    // Crores (>= 1,00,00,000)
    final crores = n ~/ 10000000;
    n %= 10000000;
    if (crores > 0) {
      parts.add('${twoDigits(crores)} Crore');
    }

    // Lakhs (>= 1,00,000)
    final lakhs = n ~/ 100000;
    n %= 100000;
    if (lakhs > 0) {
      parts.add('${twoDigits(lakhs)} Lakh');
    }

    // Thousands (>= 1,000)
    final thousands = n ~/ 1000;
    n %= 1000;
    if (thousands > 0) {
      parts.add('${twoDigits(thousands)} Thousand');
    }

    // Hundreds & units
    if (n > 0) {
      parts.add(threeDigits(n));
    }

    return 'Rupees ${parts.join(' ')} Only';
  }
}
