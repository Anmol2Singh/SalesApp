import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pm_project.dart';
import '../models/pm_purchase.dart';
import '../models/pm_ledger_entry.dart';
import '../models/pm_payment_term.dart';
import '../models/pm_expense.dart';
import '../models/pm_calling_record.dart';
import '../models/pm_checklist_item.dart';
import '../models/pm_work_remark.dart';

class PmPdfColumnDef {
  final String key;
  final String label;
  final String? purchaseLabel;
  final bool defaultEnabled;

  const PmPdfColumnDef({
    required this.key,
    required this.label,
    this.purchaseLabel,
    this.defaultEnabled = true,
  });
}

class PmPdfService {
  static final _currencyFormat = NumberFormat('#,##,##0', 'en_IN');
  static final _dateFormat = DateFormat('dd-MM-yyyy');

  static const String pdfColumnsPrefsKey = 'pm_pdf_export_columns';

  // Left column definitions matching UI screenshot
  static const List<PmPdfColumnDef> leftPdfColumns = [
    PmPdfColumnDef(key: 's_no', label: 'S No.'),
    PmPdfColumnDef(key: 'mobile', label: 'Mobile No.'),
    PmPdfColumnDef(key: 'type', label: 'Type'),
    PmPdfColumnDef(key: 'party_print', label: 'Party Print'),
    PmPdfColumnDef(key: 'city', label: 'City'),
    PmPdfColumnDef(key: 'extra_wrk', label: 'Extra Wrk'),
    PmPdfColumnDef(key: 'balance', label: 'Balance'),
  ];

  // Right column definitions matching UI screenshot
  static const List<PmPdfColumnDef> rightPdfColumns = [
    PmPdfColumnDef(key: 'customer_name', label: 'Customer Name', purchaseLabel: 'Vendor Name'),
    PmPdfColumnDef(key: 'id', label: 'ID'),
    PmPdfColumnDef(key: 'firm_name', label: 'Firm Name'),
    PmPdfColumnDef(key: 'sales_man', label: 'Sales Man'),
    PmPdfColumnDef(key: 'order_val', label: 'Order Val', purchaseLabel: 'Quotation'),
    PmPdfColumnDef(key: 'received', label: 'Received', purchaseLabel: 'Paid'),
    PmPdfColumnDef(key: 'reminder_date', label: 'Reminder Date', defaultEnabled: false),
  ];

  // All columns in logical export order
  static const List<PmPdfColumnDef> allPdfColumns = [
    PmPdfColumnDef(key: 's_no', label: 'S No.'),
    PmPdfColumnDef(key: 'id', label: 'ID'),
    PmPdfColumnDef(key: 'customer_name', label: 'Customer Name', purchaseLabel: 'Vendor Name'),
    PmPdfColumnDef(key: 'party_print', label: 'Party Print'),
    PmPdfColumnDef(key: 'type', label: 'Type'),
    PmPdfColumnDef(key: 'firm_name', label: 'Firm Name'),
    PmPdfColumnDef(key: 'mobile', label: 'Mobile No.'),
    PmPdfColumnDef(key: 'city', label: 'City'),
    PmPdfColumnDef(key: 'sales_man', label: 'Sales Man'),
    PmPdfColumnDef(key: 'order_val', label: 'Order Val', purchaseLabel: 'Quotation'),
    PmPdfColumnDef(key: 'extra_wrk', label: 'Extra Wrk'),
    PmPdfColumnDef(key: 'received', label: 'Received', purchaseLabel: 'Paid'),
    PmPdfColumnDef(key: 'balance', label: 'Balance'),
    PmPdfColumnDef(key: 'reminder_date', label: 'Reminder Date', defaultEnabled: false),
  ];

  static Future<Map<String, bool>> loadPdfExportColumns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(pdfColumnsPrefsKey);
      if (saved != null) {
        final map = <String, bool>{};
        for (final col in allPdfColumns) {
          map[col.key] = saved.contains(col.key);
        }
        return map;
      }
    } catch (_) {}
    final defaultMap = <String, bool>{};
    for (final col in allPdfColumns) {
      defaultMap[col.key] = col.defaultEnabled;
    }
    return defaultMap;
  }

  static Future<void> savePdfExportColumns(Map<String, bool> columns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final active = columns.entries.where((e) => e.value).map((e) => e.key).toList();
      await prefs.setStringList(pdfColumnsPrefsKey, active);
    } catch (_) {}
  }

  static String _getCellValue(dynamic rec, String key, int index, bool isPurchase, String companyName) {
    switch (key) {
      case 's_no':
        return (index + 1).toString();
      case 'id':
        return rec.idNo?.toString() ?? '-';
      case 'customer_name':
        return rec.siteName?.toString() ?? '-';
      case 'party_print':
        final pp = rec.partyPrintName?.toString().trim();
        return (pp != null && pp.isNotEmpty) ? pp : '-';
      case 'type':
        return rec.orderType?.toString() ?? '-';
      case 'firm_name':
        final fn = rec.firmName?.toString().trim();
        return (fn != null && fn.isNotEmpty) ? fn : companyName;
      case 'mobile':
        final mob = rec.mobileNumber?.toString().trim();
        return (mob != null && mob.isNotEmpty) ? mob : '-';
      case 'city':
        final addr = rec.address?.toString().trim();
        return (addr != null && addr.isNotEmpty) ? addr : '-';
      case 'sales_man':
        final sm = rec.salesMan?.toString().trim();
        return (sm != null && sm.isNotEmpty) ? sm : '-';
      case 'order_val':
        final val = isPurchase && rec is PmPurchase ? rec.quotationValue : (rec is PmProject ? rec.orderValue : 0.0);
        return _currencyFormat.format(val);
      case 'extra_wrk':
        if (isPurchase) return '-';
        final val = rec is PmProject ? rec.extraWorkValue : 0.0;
        return _currencyFormat.format(val);
      case 'received':
        final val = isPurchase && rec is PmPurchase ? rec.paymentPaid : (rec is PmProject ? rec.paymentReceived : 0.0);
        return _currencyFormat.format(val);
      case 'balance':
        return _currencyFormat.format(rec.balance ?? 0.0);
      case 'reminder_date':
        final dt = rec.reminderDate;
        return dt != null ? _dateFormat.format(dt) : '-';
      default:
        return '-';
    }
  }

  /// Generate Directory PDF for projects or vendors
  static Future<Uint8List> generateDirectoryPdf({
    required List<dynamic> records,
    required String companyName,
    required bool isPurchase,
    Map<String, bool>? visibleColumns,
  }) async {
    final pdf = pw.Document();

    final activeCols = visibleColumns ?? await loadPdfExportColumns();
    final enabledCols = allPdfColumns.where((c) => activeCols[c.key] ?? c.defaultEnabled).toList();
    final effectiveCols = enabledCols.isNotEmpty
        ? enabledCols
        : allPdfColumns.where((c) => ['id', 'customer_name', 'type', 'balance'].contains(c.key)).toList();

    final headers = effectiveCols.map((c) => (isPurchase && c.purchaseLabel != null) ? c.purchaseLabel! : c.label).toList();

    final dataRows = <List<String>>[];
    for (int i = 0; i < records.length; i++) {
      final rec = records[i];
      final row = <String>[];
      for (final col in effectiveCols) {
        row.add(_getCellValue(rec, col.key, i, isPurchase, companyName));
      }
      dataRows.add(row);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(companyName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text(isPurchase ? 'Vendor Directory' : 'Project Installation Directory',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text('Date: ${_dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: dataRows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Generate Project Financial Ledger PDF report
  static Future<Uint8List> generateProjectLedgerPdf({
    required dynamic project,
    required List<PmLedgerEntry> entries,
    required String companyName,
    required bool isPurchase,
    List<PmPaymentTerm> paymentTerms = const [],
    List<PmExpense> expenses = const [],
    List<PmCallingRecord> callingRecords = const [],
    List<PmChecklistItem> checklistItems = const [],
    List<PmWorkRemark> workRemarks = const [],
  }) async {
    final pdf = pw.Document();

    final orderVal = isPurchase
        ? (project is PmPurchase ? project.quotationValue : (project.orderValue as num?)?.toDouble() ?? 0.0)
        : (project is PmProject ? project.orderValue : (project.orderValue as num?)?.toDouble() ?? 0.0);
    final extraVal = isPurchase
        ? 0.0
        : (project is PmProject ? project.extraWorkValue : (project.extraWorkValue as num?)?.toDouble() ?? 0.0);
    final recVal = isPurchase
        ? (project is PmPurchase ? project.paymentPaid : (project.paymentReceived as num?)?.toDouble() ?? 0.0)
        : (project is PmProject ? project.paymentReceived : (project.paymentReceived as num?)?.toDouble() ?? 0.0);
    final balVal = isPurchase
        ? (project is PmPurchase ? project.balance : (orderVal - recVal))
        : (project is PmProject ? project.balance : ((orderVal + extraVal) - recVal));

    // Ledger Totals
    double totSalesM = 0;
    double totMOut = 0;
    double totOrderVal = 0;
    double totExtraWrk = 0;
    double totReceived = 0;

    for (final e in entries) {
      totSalesM += e.salesMValue;
      totMOut += e.mOutwardValue;
      totOrderVal += e.orderValue;
      totExtraWrk += e.extraWorkValue;
      totReceived += e.paymentReceived;
    }

    final tableHeaders = [
      'Sr',
      'Date',
      'Type',
      'Particulars',
      'Bill',
      'Ref No',
      'Inv No',
      'Sales M',
      'M Out',
      'Order Val',
      'Extra Wrk',
      isPurchase ? 'Paid' : 'Received',
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        header: (context) {
          if (context.pageNumber == 1) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      isPurchase ? '$companyName (Vendor-Purchase)' : companyName,
                      style: pw.TextStyle(
                        fontSize: 16.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.Text(
                      'PROJECT FINANCIAL LEDGER & STATEMENT',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3.5),
                pw.Container(height: 1.5, color: PdfColors.black),
                pw.SizedBox(height: 1),
                pw.Container(height: 0.5, color: PdfColors.grey600),
                pw.SizedBox(height: 2.5),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Generated Date: ${DateFormat('d/M/yyyy h:mm:ss a').format(DateTime.now()).toLowerCase()}',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                  ),
                ),
                pw.SizedBox(height: 5),
              ],
            );
          } else {
            final site = project.siteName ?? 'N/A';
            final mob = (project.mobileNumber != null && project.mobileNumber!.toString().trim().isNotEmpty)
                ? project.mobileNumber!.toString().trim()
                : 'No Mobile';
            final label = isPurchase ? 'Vendor' : 'Customer';
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${isPurchase ? "$companyName (Vendor-Purchase)" : companyName} - $label: $site ($mob)',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.Text(
                      'PROJECT FINANCIAL LEDGER',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2.5),
                pw.Container(height: 0.75, color: PdfColors.grey400),
                pw.SizedBox(height: 6),
              ],
            );
          }
        },
        footer: (context) {
          return pw.Column(
            children: [
              pw.SizedBox(height: 5),
              pw.Container(height: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    '${isPurchase ? "$companyName (Vendor-Purchase)" : companyName} - Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 100,
                        height: 0.75,
                        color: PdfColors.grey600,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Authorized Signatory',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
        build: (context) => [
          // 1. Details Box
          _buildProjectDetailsBox(project, companyName, isPurchase),
          pw.SizedBox(height: 8),

          // 2. Financial Summary Overview
          _buildFinancialSummaryOverview(
            isPurchase: isPurchase,
            orderVal: orderVal,
            extraVal: extraVal,
            recVal: recVal,
            balVal: balVal,
          ),
          pw.SizedBox(height: 10),

          // 3. Section 1: Financial Ledger Entries
          pw.Text(
            '1. FINANCIAL LEDGER ENTRIES',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 3.5),
          _buildLedgerEntriesTable(
            entries: entries,
            headers: tableHeaders,
            isPurchase: isPurchase,
            totSalesM: totSalesM,
            totMOut: totMOut,
            totOrderVal: totOrderVal,
            totExtraWrk: totExtraWrk,
            totReceived: totReceived,
          ),
          pw.SizedBox(height: 12),

          // 4. Section 2: Payment Terms Breakdown
          if (!isPurchase && paymentTerms.isNotEmpty) ...[
            _buildPaymentTermsSection(paymentTerms),
            pw.SizedBox(height: 12),
          ],

          // 5. Section 3: Project Expenses & Call Records
          _buildExpensesAndCallRecordsSection(expenses, callingRecords),
          pw.SizedBox(height: 12),

          // 6. Section 4: Checklist Scope Breakdown
          if (!isPurchase && checklistItems.isNotEmpty) ...[
            _buildChecklistSection(checklistItems, project.orderType?.toString() ?? ''),
            pw.SizedBox(height: 12),
          ],

          // 7. Section 5: Latest Work Remark
          if (!isPurchase)
            _buildWorkRemarksSection(workRemarks, project),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildProjectDetailsBox(dynamic project, String companyName, bool isPurchase) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: const PdfColor(0.97, 0.98, 0.99),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        border: pw.Border.all(color: const PdfColor(0.85, 0.88, 0.92), width: 0.6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left Column
          pw.Expanded(
            flex: 11,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: isPurchase ? 'Vendor Name: ' : 'Customer / Site: ',
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                      ),
                      pw.TextSpan(
                        text: '${project.siteName ?? "N/A"} (ID #${project.idNo ?? "-"})',
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: const PdfColor(0.06, 0.36, 0.9)),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 3),
                _buildDetailRow('Type', project.orderType?.toString() ?? (isPurchase ? 'Vendor Order' : 'N/A')),
                pw.SizedBox(height: 2),
                _buildDetailRow('Mobile No.', (project.mobileNumber != null && project.mobileNumber.toString().trim().isNotEmpty) ? project.mobileNumber.toString().trim() : 'N/A'),
                pw.SizedBox(height: 2),
                _buildDetailRow(isPurchase ? 'Vendor Address' : 'Site Address', (project.address != null && project.address.toString().trim().isNotEmpty) ? project.address.toString().trim() : 'N/A'),
              ],
            ),
          ),
          pw.SizedBox(width: 14),
          // Right Column
          pw.Expanded(
            flex: 9,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (!isPurchase) ...[
                  _buildDetailRow(
                    'HP Specs',
                    (project.hpType != null && project.hpType.toString().trim().isNotEmpty)
                        ? '${project.hpType} (${project.hpQty ?? 0} Qty)'
                        : 'N/A',
                  ),
                  pw.SizedBox(height: 2),
                  _buildDetailRow(
                    'Storage Tank',
                    (project.tankType != null && project.tankType.toString().trim().isNotEmpty)
                        ? '${project.tankType}${(project.tankQty != null && project.tankQty > 0) ? " (${project.tankQty} Qty)" : ""}'
                        : 'N/A',
                  ),
                  pw.SizedBox(height: 2),
                  _buildDetailRow(
                    'Sales Man',
                    (project.salesMan != null && project.salesMan.toString().trim().isNotEmpty)
                        ? project.salesMan.toString().trim()
                        : 'N/A',
                  ),
                ] else ...[
                  _buildDetailRow('Firm Name', (project.firmName != null && project.firmName.toString().trim().isNotEmpty) ? project.firmName.toString().trim() : 'N/A'),
                  pw.SizedBox(height: 2),
                  _buildDetailRow('Print Name', (project.partyPrintName != null && project.partyPrintName.toString().trim().isNotEmpty) ? project.partyPrintName.toString().trim() : 'N/A'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 70,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.black),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFinancialSummaryOverview({
    required bool isPurchase,
    required double orderVal,
    required double extraVal,
    required double recVal,
    required double balVal,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'FINANCIAL SUMMARY OVERVIEW',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 3.5),
        pw.Row(
          children: [
            _buildMetricCard(
              'Total Order Value',
              'Rs. ${_currencyFormat.format(orderVal)}',
              const PdfColor(0.06, 0.36, 0.9),
            ),
            pw.SizedBox(width: 6),
            _buildMetricCard(
              'Extra Work',
              'Rs. ${_currencyFormat.format(extraVal)}',
              const PdfColor(0.85, 0.5, 0.05),
            ),
            pw.SizedBox(width: 6),
            _buildMetricCard(
              'Payment Received',
              'Rs. ${_currencyFormat.format(recVal)}',
              const PdfColor(0.1, 0.6, 0.3),
            ),
            pw.SizedBox(width: 6),
            _buildMetricCard(
              'Outstanding Balance',
              'Rs. ${_currencyFormat.format(balVal)}',
              balVal > 0 ? const PdfColor(0.85, 0.15, 0.15) : const PdfColor(0.1, 0.6, 0.3),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildMetricCard(String label, String value, PdfColor valColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 7),
        decoration: pw.BoxDecoration(
          color: const PdfColor(0.98, 0.98, 0.99),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          border: pw.Border.all(color: const PdfColor(0.85, 0.88, 0.92), width: 0.6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
              maxLines: 1,
            ),
            pw.SizedBox(height: 2.5),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: valColor),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildLedgerEntriesTable({
    required List<PmLedgerEntry> entries,
    required List<String> headers,
    required bool isPurchase,
    required double totSalesM,
    required double totMOut,
    required double totOrderVal,
    required double totExtraWrk,
    required double totReceived,
  }) {
    if (entries.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Text(
          'No financial ledger entries recorded for this project.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(18),  // Sr
        1: pw.FixedColumnWidth(48),  // Date
        2: pw.FixedColumnWidth(36),  // Type
        3: pw.FlexColumnWidth(2.4),  // Particulars
        4: pw.FixedColumnWidth(24),  // Bill
        5: pw.FixedColumnWidth(34),  // Ref No
        6: pw.FixedColumnWidth(34),  // Inv No
        7: pw.FixedColumnWidth(40),  // Sales M
        8: pw.FixedColumnWidth(40),  // M Out
        9: pw.FixedColumnWidth(48),  // Order Val
        10: pw.FixedColumnWidth(44), // Extra Wrk
        11: pw.FixedColumnWidth(48), // Received / Paid
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor(0.12, 0.16, 0.22)),
          children: [
            _th('Sr', pw.Alignment.center),
            _th('Date', pw.Alignment.center),
            _th('Type', pw.Alignment.center),
            _th('Particulars', pw.Alignment.centerLeft),
            _th('Bill', pw.Alignment.center),
            _th('Ref No', pw.Alignment.center),
            _th('Inv No', pw.Alignment.center),
            _th('Sales M', pw.Alignment.centerRight),
            _th('M Out', pw.Alignment.centerRight),
            _th('Order Val', pw.Alignment.centerRight),
            _th('Extra Wrk', pw.Alignment.centerRight),
            _th(isPurchase ? 'Paid' : 'Received', pw.Alignment.centerRight),
          ],
        ),
        // Data Rows
        ...entries.asMap().entries.map((entryMap) {
          final i = entryMap.key;
          final e = entryMap.value;
          final isEven = i % 2 == 1;

          final billText = isPurchase
              ? (e.billReceived ? 'Yes' : 'No')
              : (e.billSubmitted ? 'Yes' : 'No');

          final refText = (e.referenceNumber != null && e.referenceNumber!.trim().isNotEmpty)
              ? e.referenceNumber!.trim()
              : '-';
          final invText = (e.invoiceNo != null && e.invoiceNo!.trim().isNotEmpty)
              ? e.invoiceNo!.trim()
              : '-';

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? const PdfColor(0.97, 0.98, 0.99) : PdfColors.white,
            ),
            children: [
              _tc((i + 1).toString(), pw.Alignment.center),
              _tc(_dateFormat.format(e.date), pw.Alignment.center),
              _tc(e.paymentType ?? '-', pw.Alignment.center),
              _tc(e.particulars ?? '-', pw.Alignment.centerLeft),
              _tc(billText, pw.Alignment.center),
              _tc(refText, pw.Alignment.center),
              _tc(invText, pw.Alignment.center),
              _tc(e.salesMValue > 0 ? _currencyFormat.format(e.salesMValue) : '-', pw.Alignment.centerRight),
              _tc(e.mOutwardValue > 0 ? _currencyFormat.format(e.mOutwardValue) : '-', pw.Alignment.centerRight),
              _tc(e.orderValue > 0 ? _currencyFormat.format(e.orderValue) : '-', pw.Alignment.centerRight),
              _tc(e.extraWorkValue > 0 ? _currencyFormat.format(e.extraWorkValue) : '-', pw.Alignment.centerRight),
              _tc(e.paymentReceived > 0 ? _currencyFormat.format(e.paymentReceived) : '-', pw.Alignment.centerRight),
            ],
          );
        }),
        // NET TOTALS Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor(0.93, 0.94, 0.96)),
          children: [
            _tc('', pw.Alignment.center),
            _tc('', pw.Alignment.center),
            _tc('', pw.Alignment.center),
            _tc('NET TOTALS', pw.Alignment.centerRight, isBold: true),
            _tc('', pw.Alignment.center),
            _tc('', pw.Alignment.center),
            _tc('', pw.Alignment.center),
            _tc(totSalesM > 0 ? 'Rs. ${_currencyFormat.format(totSalesM)}' : '-', pw.Alignment.centerRight, isBold: true),
            _tc(totMOut > 0 ? 'Rs. ${_currencyFormat.format(totMOut)}' : '-', pw.Alignment.centerRight, isBold: true),
            _tc('Rs. ${_currencyFormat.format(totOrderVal)}', pw.Alignment.centerRight, isBold: true),
            _tc('Rs. ${_currencyFormat.format(totExtraWrk)}', pw.Alignment.centerRight, isBold: true),
            _tc('Rs. ${_currencyFormat.format(totReceived)}', pw.Alignment.centerRight, isBold: true),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPaymentTermsSection(List<PmPaymentTerm> terms) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '2. PAYMENT TERMS BREAKDOWN',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
        ),
        pw.SizedBox(height: 3.5),
        if (terms.isEmpty)
          pw.Text(
            'No payment terms defined for this project.',
            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(24),
              1: pw.FlexColumnWidth(2.5),
              2: pw.FixedColumnWidth(48),
              3: pw.FixedColumnWidth(65),
              4: pw.FixedColumnWidth(65),
              5: pw.FixedColumnWidth(65),
              6: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor(0.2, 0.25, 0.3)),
                children: [
                  _th('Sr', pw.Alignment.center),
                  _th('Payment Term', pw.Alignment.centerLeft),
                  _th('Term %', pw.Alignment.center),
                  _th('Amount', pw.Alignment.centerRight),
                  _th('Received', pw.Alignment.centerRight),
                  _th('Pending', pw.Alignment.centerRight),
                  _th('Remark', pw.Alignment.centerLeft),
                ],
              ),
              ...terms.asMap().entries.map((e) {
                final i = e.key;
                final t = e.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i % 2 == 1 ? const PdfColor(0.97, 0.97, 0.98) : PdfColors.white,
                  ),
                  children: [
                    _tc((i + 1).toString(), pw.Alignment.center),
                    _tc(t.paymentTerm, pw.Alignment.centerLeft),
                    _tc('${t.termPercentage.toStringAsFixed(0)}%', pw.Alignment.center),
                    _tc('Rs. ${_currencyFormat.format(t.amount)}', pw.Alignment.centerRight),
                    _tc('Rs. ${_currencyFormat.format(t.receivedAmount)}', pw.Alignment.centerRight),
                    _tc('Rs. ${_currencyFormat.format(t.pendingAmount)}', pw.Alignment.centerRight),
                    _tc(t.remark ?? '-', pw.Alignment.centerLeft),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildExpensesAndCallRecordsSection(List<PmExpense> expenses, List<PmCallingRecord> callRecords) {
    final hasExpenses = expenses.isNotEmpty;
    final hasCalls = callRecords.isNotEmpty;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '3. PROJECT EXPENSES & CALL RECORDS',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
        ),
        pw.SizedBox(height: 3.5),
        if (!hasExpenses && !hasCalls)
          pw.Text(
            'No expenses or call records logged for this project.',
            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
          )
        else ...[
          if (hasExpenses) ...[
            pw.Text('Project Expenses:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
            pw.SizedBox(height: 2.5),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(24),
                1: pw.FixedColumnWidth(65),
                2: pw.FlexColumnWidth(2.5),
                3: pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor(0.2, 0.25, 0.3)),
                  children: [
                    _th('Sr', pw.Alignment.center),
                    _th('Date', pw.Alignment.center),
                    _th('Particular', pw.Alignment.centerLeft),
                    _th('Expense Amount', pw.Alignment.centerRight),
                  ],
                ),
                ...expenses.asMap().entries.map((e) {
                  final i = e.key;
                  final exp = e.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i % 2 == 1 ? const PdfColor(0.97, 0.97, 0.98) : PdfColors.white,
                    ),
                    children: [
                      _tc((i + 1).toString(), pw.Alignment.center),
                      _tc(_dateFormat.format(exp.date), pw.Alignment.center),
                      _tc(exp.particular ?? '-', pw.Alignment.centerLeft),
                      _tc('Rs. ${_currencyFormat.format(exp.expense)}', pw.Alignment.centerRight),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 6),
          ],
          if (hasCalls) ...[
            pw.Text('Call Records:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
            pw.SizedBox(height: 2.5),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(24),
                1: pw.FixedColumnWidth(65),
                2: pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor(0.2, 0.25, 0.3)),
                  children: [
                    _th('Sr', pw.Alignment.center),
                    _th('Date', pw.Alignment.center),
                    _th('Description', pw.Alignment.centerLeft),
                  ],
                ),
                ...callRecords.asMap().entries.map((e) {
                  final i = e.key;
                  final c = e.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i % 2 == 1 ? const PdfColor(0.97, 0.97, 0.98) : PdfColors.white,
                    ),
                    children: [
                      _tc((i + 1).toString(), pw.Alignment.center),
                      _tc(_dateFormat.format(c.date), pw.Alignment.center),
                      _tc(c.description ?? '-', pw.Alignment.centerLeft),
                    ],
                  );
                }),
              ],
            ),
          ],
        ],
      ],
    );
  }

  static pw.Widget _buildChecklistSection(List<PmChecklistItem> items, String orderType) {
    final customerItems = items.where((i) => i.customerScope).toList();
    final ourItems = items.where((i) => i.ourScope).toList();

    final typePrefix = orderType.trim().isNotEmpty ? '${orderType.toUpperCase()} ' : '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '4. ${typePrefix}CHECKLIST SCOPE BREAKDOWN',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
        ),
        pw.SizedBox(height: 3.5),

        // Customer Scope
        pw.Text('Customer Scope Items:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        pw.SizedBox(height: 2),
        if (customerItems.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 4, bottom: 5),
            child: pw.Text(
              'No items under customer scope.',
              style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
            ),
          )
        else ...[
          _buildChecklistTable(customerItems),
          pw.SizedBox(height: 5),
        ],

        // Our Scope
        pw.Text('Our Scope Items:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        pw.SizedBox(height: 2),
        if (ourItems.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 4, bottom: 5),
            child: pw.Text(
              'No items under our scope.',
              style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
            ),
          )
        else ...[
          _buildChecklistTable(ourItems),
          pw.SizedBox(height: 5),
        ],
      ],
    );
  }

  static pw.Widget _buildChecklistTable(List<PmChecklistItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(24),
        1: pw.FlexColumnWidth(2),
        2: pw.FixedColumnWidth(48),
        3: pw.FixedColumnWidth(58),
        4: pw.FixedColumnWidth(58),
        5: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor(0.2, 0.25, 0.3)),
          children: [
            _th('Sr', pw.Alignment.center),
            _th('Item Name', pw.Alignment.centerLeft),
            _th('Req Qty', pw.Alignment.center),
            _th('Dispatch Qty', pw.Alignment.center),
            _th('Installed Qty', pw.Alignment.center),
            _th('Remark', pw.Alignment.centerLeft),
          ],
        ),
        ...items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i % 2 == 1 ? const PdfColor(0.97, 0.97, 0.98) : PdfColors.white,
            ),
            children: [
              _tc((i + 1).toString(), pw.Alignment.center),
              _tc(item.itemName, pw.Alignment.centerLeft),
              _tc(item.reqQty.toStringAsFixed(item.reqQty.truncateToDouble() == item.reqQty ? 0 : 1), pw.Alignment.center),
              _tc(item.dispatchQty.toStringAsFixed(item.dispatchQty.truncateToDouble() == item.dispatchQty ? 0 : 1), pw.Alignment.center),
              _tc(item.installedQty.toStringAsFixed(item.installedQty.truncateToDouble() == item.installedQty ? 0 : 1), pw.Alignment.center),
              _tc(item.remark ?? '-', pw.Alignment.centerLeft),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildWorkRemarksSection(List<PmWorkRemark> remarks, dynamic project) {
    DateTime? latestDate;
    String? latestText;

    if (remarks.isNotEmpty) {
      final sorted = List<PmWorkRemark>.from(remarks)..sort((a, b) => b.date.compareTo(a.date));
      latestDate = sorted.first.date;
      latestText = sorted.first.remark;
    } else if (project.workRemark != null && project.workRemark.toString().trim().isNotEmpty) {
      latestDate = project.updatedAt ?? project.createdAt;
      latestText = project.workRemark.toString().trim();
    }

    final dateStr = latestDate != null ? _dateFormat.format(latestDate) : _dateFormat.format(DateTime.now());

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '5. LATEST WORK REMARK',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
        ),
        pw.SizedBox(height: 2.5),
        pw.Text(
          'Last Remark Date: $dateStr',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 2.5),
        if (latestText == null || latestText.isEmpty)
          pw.Text(
            'No work remarks recorded for this project.',
            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
          )
        else ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.97, 0.98, 0.99),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              border: pw.Border.all(color: const PdfColor(0.85, 0.88, 0.92), width: 0.6),
            ),
            child: pw.Text(
              latestText,
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
            ),
          ),
          if (remarks.length > 1) ...[
            pw.SizedBox(height: 3.5),
            pw.Text('Previous Remarks History:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            ...remarks.skip(1).map((r) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2, left: 4),
                  child: pw.Text(
                    '- ${_dateFormat.format(r.date)}: ${r.remark ?? ""}',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
                  ),
                )),
          ],
        ],
      ],
    );
  }

  static pw.Widget _th(String text, pw.Alignment alignment) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 3.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        textAlign: alignment == pw.Alignment.centerRight
            ? pw.TextAlign.right
            : (alignment == pw.Alignment.center ? pw.TextAlign.center : pw.TextAlign.left),
      ),
    );
  }

  static pw.Widget _tc(String text, pw.Alignment alignment, {bool isBold = false, PdfColor? color}) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 3.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
        textAlign: alignment == pw.Alignment.centerRight
            ? pw.TextAlign.right
            : (alignment == pw.Alignment.center ? pw.TextAlign.center : pw.TextAlign.left),
      ),
    );
  }
}
