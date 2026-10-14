import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/pm_project.dart';
import '../models/pm_purchase.dart';
import '../models/pm_ledger_entry.dart';

class PmPdfService {
  static final _currencyFormat = NumberFormat('#,##,##0', 'en_IN');
  static final _dateFormat = DateFormat('dd-MM-yyyy');

  /// Generate Directory PDF for projects or vendors
  static Future<Uint8List> generateDirectoryPdf({
    required List<dynamic> records,
    required String companyName,
    required bool isPurchase,
    Map<String, bool>? visibleColumns,
  }) async {
    final pdf = pw.Document();

    final headers = isPurchase
        ? ['ID', 'Type', 'Vendor Name', 'Party Print Name', 'Mobile', 'Address', 'Quotation', 'Paid', 'Balance']
        : ['ID', 'Type', 'Site Name', 'Party Print Name', 'Mobile', 'Address', 'Order Value', 'Extra Work', 'Recd', 'Balance'];

    final dataRows = records.map((rec) {
      if (isPurchase && rec is PmPurchase) {
        return [
          rec.idNo.toString(),
          rec.orderType,
          rec.siteName,
          rec.partyPrintName ?? '-',
          rec.mobileNumber ?? '-',
          rec.address ?? '-',
          _currencyFormat.format(rec.quotationValue),
          _currencyFormat.format(rec.paymentPaid),
          _currencyFormat.format(rec.balance),
        ];
      } else if (rec is PmProject) {
        return [
          rec.idNo.toString(),
          rec.orderType,
          rec.siteName,
          rec.partyPrintName ?? '-',
          rec.mobileNumber ?? '-',
          rec.address ?? '-',
          _currencyFormat.format(rec.orderValue),
          _currencyFormat.format(rec.extraWorkValue),
          _currencyFormat.format(rec.paymentReceived),
          _currencyFormat.format(rec.balance),
        ];
      }
      return <String>[];
    }).where((r) => r.isNotEmpty).toList();

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
