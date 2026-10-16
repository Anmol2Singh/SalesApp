// lib/core/utils/financial_year_helper.dart

/// Helper utility for Indian Academic / Financial Year formatting.
/// Financial Year runs from April 1 to March 31.
/// E.g.:
/// - April 2026 to March 2027 => '26-27'
/// - April 2027 to March 2028 => '27-28'
/// On April 1, it automatically rolls over.
class FinancialYearHelper {
  /// Returns the current or date-specific 2-digit academic year string, e.g. '26-27'.
  static String getFinancialYearCode([DateTime? date]) {
    final d = date ?? DateTime.now();
    final startYear = d.month >= 4 ? d.year : d.year - 1;
    final startShort = (startYear % 100).toString().padLeft(2, '0');
    final endShort = ((startYear + 1) % 100).toString().padLeft(2, '0');
    return '$startShort-$endShort';
  }

  /// Formats document numbers (Quotation, Sales Order, BOQ, FO, PO, AMC, NOC)
  /// so that 4-digit years like '2026' or '2027' are converted to academic year format '26-27'.
  /// Also ensures proper structure: e.g. 'IZY/QT/26-27/0069'.
  static String formatDocumentNumber(String docNumber, [DateTime? date]) {
    final clean = docNumber.trim();
    if (clean.isEmpty) return clean;

    final fy = getFinancialYearCode(date);

    // Replace 4-digit year segments like /2026/ or /2025/ with the academic year code
    return clean.replaceAllMapped(
      RegExp(r'/20\d{2}/'),
      (match) => '/$fy/',
    );
  }
}
