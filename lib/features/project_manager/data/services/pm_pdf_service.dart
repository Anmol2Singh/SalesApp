import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pm_project.dart';
import '../models/pm_purchase.dart';
import '../models/pm_ledger_entry.dart';

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
  }) async {
    final pdf = pw.Document();

    final headers = isPurchase
        ? ['Sr', 'Date', 'Type', 'Particulars', 'Ref/Inv', 'Bill Recd', 'Quotation', 'Paid', 'Balance']
        : ['Sr', 'Date', 'Type', 'Particulars', 'Ref/Inv', 'Bill Sub', 'Order Value', 'Payment Recd', 'Balance'];

    double runningBal = 0;
    final rows = entries.asMap().entries.map((entryMap) {
      final i = entryMap.key;
      final e = entryMap.value;
      final srNumber = (i + 1).toString();
      if (isPurchase) {
        runningBal += e.orderValue - e.paymentReceived;
        return [
          srNumber,
          _dateFormat.format(e.date),
          e.paymentType ?? '-',
          e.particulars ?? '-',
          e.invoiceNo ?? e.referenceNumber ?? '-',
          e.billReceived ? 'Yes' : 'No',
          _currencyFormat.format(e.orderValue),
          _currencyFormat.format(e.paymentReceived),
          _currencyFormat.format(runningBal),
        ];
      } else {
        runningBal += (e.orderValue + e.extraWorkValue) - e.paymentReceived;
        return [
          srNumber,
          _dateFormat.format(e.date),
          e.paymentType ?? '-',
          e.particulars ?? '-',
          e.invoiceNo ?? e.referenceNumber ?? '-',
          e.billSubmitted ? 'Yes' : 'No',
          _currencyFormat.format(e.orderValue + e.extraWorkValue),
          _currencyFormat.format(e.paymentReceived),
          _currencyFormat.format(runningBal),
        ];
      }
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
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
                    pw.Text(companyName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Financial Statement / Ledger', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Account: ${project.siteName}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: ${_dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('Closing Balance: Rs. ${_currencyFormat.format(project.balance)}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
