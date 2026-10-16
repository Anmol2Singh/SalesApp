// lib/features/quotation_generator/services/boom_barrier_math.dart

import 'package:intl/intl.dart';
import '../models/boom_barrier_line_item.dart';

class BoomBarrierCalculationResult {
  final double subtotal;
  final double gstPercent;
  final double gstAmount;
  final double grandTotal;
  final String formattedSubtotal;
  final String formattedGst;
  final String formattedGrandTotal;
  final String amountInWords;

  const BoomBarrierCalculationResult({
    required this.subtotal,
    required this.gstPercent,
    required this.gstAmount,
    required this.grandTotal,
    required this.formattedSubtotal,
    required this.formattedGst,
    required this.formattedGrandTotal,
    required this.amountInWords,
  });
}

/// Commercial math and Indian numbering formatting for Boom Barrier quotations.
class BoomBarrierMath {
  static const double defaultGstPercent = 18.0;

  /// Calculates financial totals from a list of Boom Barrier line items.
  static BoomBarrierCalculationResult calculate({
    required List<BoomBarrierLineItem> items,
    double gstPercent = defaultGstPercent,
  }) {
    double sub = 0.0;
    for (final item in items) {
      if (item.hasMonetaryValue) {
        sub += item.price;
      }
    }

    final gst = (sub * (gstPercent / 100.0)).roundToDouble();
    final grand = sub + gst;

    return BoomBarrierCalculationResult(
      subtotal: sub,
      gstPercent: gstPercent,
      gstAmount: gst,
      grandTotal: grand,
      formattedSubtotal: formatRawOrIndian(sub),
      formattedGst: formatIndianCurrencyWithSymbol(gst),
      formattedGrandTotal: formatIndianCurrencyWithSymbol(grand),
      amountInWords: numberToIndianWords(grand),
    );
  }

  /// Formats a number with Indian currency grouping without symbol: 60,000 or 60000.
  static String formatIndianNumber(double amount, {bool decimal = false}) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '',
      decimalDigits: decimal ? 2 : 0,
    );
    return formatter.format(amount).trim();
  }

  /// Formats with standard Indian Rupee symbol: ₹ 70,800
  static String formatIndianCurrencyWithSymbol(double amount, {bool decimal = false}) {
    final numStr = formatIndianNumber(amount, decimal: decimal);
    return '₹ $numStr';
  }

  /// Raw integer format as displayed in template price rows (e.g. 45000, 60000).
  static String formatRawOrIndian(double amount) {
    if (amount % 1 == 0) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }

  /// Converts a numeric amount to Indian currency words.
  /// e.g. 70800 -> "Rupees Seventy Thousand Eight Hundred Only"
  static String numberToIndianWords(double amount) {
    final rounded = amount.round();
    if (rounded == 0) return 'Rupees Zero Only';

    final words = _convertNumberToWords(rounded);
    return 'Rupees $words Only';
  }

  static const List<String> _units = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen'
  ];

  static const List<String> _tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety'
  ];

  static String _convertNumberToWords(int n) {
    if (n < 0) return 'Minus ${_convertNumberToWords(-n)}';
    if (n == 0) return '';

    if (n < 20) {
      return _units[n];
    }

    if (n < 100) {
      final unit = n % 10;
      return '${_tens[n ~/ 10]}${unit > 0 ? " ${_units[unit]}" : ""}';
    }

    if (n < 1000) {
      final rem = n % 100;
      return '${_units[n ~/ 100]} Hundred${rem > 0 ? " ${_convertNumberToWords(rem)}" : ""}';
    }

    if (n < 100000) {
      final rem = n % 1000;
      return '${_convertNumberToWords(n ~/ 1000)} Thousand${rem > 0 ? " ${_convertNumberToWords(rem)}" : ""}';
    }

    if (n < 10000000) {
      final rem = n % 100000;
      return '${_convertNumberToWords(n ~/ 100000)} Lakh${rem > 0 ? " ${_convertNumberToWords(rem)}" : ""}';
    }

    final rem = n % 10000000;
    return '${_convertNumberToWords(n ~/ 10000000)} Crore${rem > 0 ? " ${_convertNumberToWords(rem)}" : ""}';
  }
}
