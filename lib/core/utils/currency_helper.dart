// lib/core/utils/currency_helper.dart

/// Formats numbers using the Indian numbering system with comma separators (e.g., ₹ 60,18,000.00).
String formatIndianCurrency(num amount, {String symbol = '₹', bool includeDecimals = false}) {
  final isNegative = amount < 0;
  final absAmount = amount.abs();
  final wholePart = absAmount.truncate();
  final decimalPart = absAmount - wholePart;

  String s = wholePart.toString();
  if (s.length > 3) {
    String lastThree = s.substring(s.length - 3);
    String remaining = s.substring(0, s.length - 3);
    String formattedRemaining = '';
    while (remaining.length > 2) {
      formattedRemaining = ',${remaining.substring(remaining.length - 2)}$formattedRemaining';
      remaining = remaining.substring(0, remaining.length - 2);
    }
    s = '$remaining$formattedRemaining,$lastThree';
  }

  String prefix = symbol.isNotEmpty ? '$symbol ' : '';
  if (isNegative) prefix = '-$prefix';

  if (includeDecimals || decimalPart > 0.001) {
    final cents = (decimalPart * 100).round().toString().padLeft(2, '0');
    return '$prefix$s.$cents';
  }
  return '$prefix$s';
}

