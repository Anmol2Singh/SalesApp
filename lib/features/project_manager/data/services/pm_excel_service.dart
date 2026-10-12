import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/pm_project.dart';
import '../models/pm_purchase.dart';
import '../models/pm_ledger_entry.dart';

class PmExcelService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Export Directory to Excel
  static Uint8List? exportDirectoryToExcel({
    required List<dynamic> records,
    required bool isPurchase,
  }) {
    final excel = Excel.createExcel();
    final sheetName = isPurchase ? 'Vendors' : 'Customers';
    final sheet = excel[sheetName];

    final headers = isPurchase
        ? ['ID', 'Order Type', 'Vendor Name', 'Party Print Name', 'Mobile Number', 'Address', 'Quotation Value', 'Payment Paid', 'Balance']
        : ['ID', 'Order Type', 'Site Name', 'Party Print Name', 'Mobile Number', 'Address', 'Order Value', 'Extra Work Value', 'Payment Received', 'Balance'];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    for (int rowIdx = 0; rowIdx < records.length; rowIdx++) {
      final rec = records[rowIdx];
      final r = rowIdx + 1;
      List<String> values = [];

      if (isPurchase && rec is PmPurchase) {
        values = [
          rec.idNo.toString(),
          rec.orderType,
          rec.siteName,
          rec.partyPrintName ?? '',
          rec.mobileNumber ?? '',
          rec.address ?? '',
          rec.quotationValue.toStringAsFixed(2),
          rec.paymentPaid.toStringAsFixed(2),
          rec.balance.toStringAsFixed(2),
        ];
      } else if (rec is PmProject) {
        values = [
          rec.idNo.toString(),
          rec.orderType,
          rec.siteName,
          rec.partyPrintName ?? '',
          rec.mobileNumber ?? '',
          rec.address ?? '',
          rec.orderValue.toStringAsFixed(2),
          rec.extraWorkValue.toStringAsFixed(2),
          rec.paymentReceived.toStringAsFixed(2),
          rec.balance.toStringAsFixed(2),
        ];
      }

      for (int c = 0; c < values.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).value =
            TextCellValue(values[c]);
      }
    }

    return Uint8List.fromList(excel.save() ?? []);
  }

  /// Export Customer Ledger to Excel
  static Uint8List? exportLedgerToExcel({
    required List<PmLedgerEntry> entries,
    required bool isPurchase,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel['Ledger'];

    final headers = isPurchase
        ? ['Sr No', 'Date', 'Type', 'Reference', 'Invoice', 'Particulars', 'Bill Received', 'Payment Bill', 'Quotation Value', 'Payment Paid']
        : ['Sr No', 'Date', 'Type', 'Reference', 'Invoice', 'Particulars', 'Bill Submitted', 'Payment Receipt', 'Order Value', 'Extra Work Value', 'Payment Received'];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    for (int rowIdx = 0; rowIdx < entries.length; rowIdx++) {
      final e = entries[rowIdx];
      final r = rowIdx + 1;
      List<String> values = isPurchase
          ? [
              e.srNo.toString(),
              _dateFormat.format(e.date),
              e.paymentType ?? '',
              e.referenceNumber ?? '',
              e.invoiceNo ?? '',
              e.particulars ?? '',
              e.billReceived ? 'Yes' : 'No',
              e.paymentBill ? 'Yes' : 'No',
              e.orderValue.toStringAsFixed(2),
              e.paymentReceived.toStringAsFixed(2),
            ]
          : [
              e.srNo.toString(),
              _dateFormat.format(e.date),
              e.paymentType ?? '',
              e.referenceNumber ?? '',
              e.invoiceNo ?? '',
              e.particulars ?? '',
              e.billSubmitted ? 'Yes' : 'No',
              e.paymentReceipt ? 'Yes' : 'No',
              e.orderValue.toStringAsFixed(2),
              e.extraWorkValue.toStringAsFixed(2),
              e.paymentReceived.toStringAsFixed(2),
            ];

      for (int c = 0; c < values.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).value =
            TextCellValue(values[c]);
      }
    }

    return Uint8List.fromList(excel.save() ?? []);
  }
}
