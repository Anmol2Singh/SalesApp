// lib/features/quotation_generator/services/quote_number_service.dart

class QuoteNumberService {
  /// Computes the Financial Year (FY) string (e.g. "26-27") based on Indian fiscal year (1 April – 31 March)
  static String computeFinancialYear(DateTime date) {
    final year = date.year;
    final month = date.month;

    int startYear;
    int endYear;

    if (month >= 4) {
      startYear = year;
      endYear = year + 1;
    } else {
      startYear = year - 1;
      endYear = year;
    }

    final startSuffix = (startYear % 100).toString().padLeft(2, '0');
    final endSuffix = (endYear % 100).toString().padLeft(2, '0');

    return '$startSuffix-$endSuffix';
  }

  /// Formats the reference number, e.g. "IN/HP/SS/26-27/1406"
  static String formatQuoteRef({
    String prefix = 'IN/HP/SS',
    required DateTime date,
    required int runningNumber,
  }) {
    final fy = computeFinancialYear(date);
    return '$prefix/$fy/$runningNumber';
  }
}
