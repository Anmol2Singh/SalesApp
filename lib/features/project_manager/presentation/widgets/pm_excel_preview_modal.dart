import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';
import '../../data/services/pm_excel_service.dart';

class PmExcelPreviewModal extends StatelessWidget {
  final List<dynamic> records;
  final bool isPurchase;
  final String companyName;

  const PmExcelPreviewModal({
    super.key,
    required this.records,
    required this.isPurchase,
    required this.companyName,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##,##0', 'en_IN');
    final fileName = '${companyName.replaceAll(' ', '_')}_Directory.xlsx';

    void handleExport({required bool share}) {
      final bytes = PmExcelService.exportDirectoryToExcel(
        records: records,
        isPurchase: isPurchase,
      );
      if (bytes != null) {
        Printing.sharePdf(bytes: bytes, filename: fileName);
      }
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 1000,
        height: 750,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.fileSpreadsheet, size: 20, color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Text(
                      'Excel Export Preview - ${isPurchase ? "Vendors" : "Customers"} (${records.length} Records)',
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Review the formatted spreadsheet rows below before saving or sharing.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            // Preview Table Container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                        headingRowHeight: 40,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 44,
                        columns: [
                          const DataColumn(label: Text('ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                          const DataColumn(label: Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                          DataColumn(label: Text(isPurchase ? 'VENDOR NAME' : 'SITE NAME', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                          const DataColumn(label: Text('PARTY PRINT NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                          const DataColumn(label: Text('MOBILE NO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                          const DataColumn(label: Text('ADDRESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                          DataColumn(numeric: true, label: Text(isPurchase ? 'QUOTATION' : 'ORDER VAL', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                          if (!isPurchase)
                            const DataColumn(numeric: true, label: Text('EXTRA WORK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                          DataColumn(numeric: true, label: Text(isPurchase ? 'PAID' : 'RECEIVED', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                          const DataColumn(numeric: true, label: Text('BALANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                        ],
                        rows: records.map((r) {
                          return DataRow(
                            cells: [
                              DataCell(Text('${r.idNo}', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(r.orderType.toString(), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(r.siteName.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                              DataCell(Text(r.partyPrintName ?? '-', style: const TextStyle(fontSize: 11.5))),
                              DataCell(Text(r.mobileNumber ?? '-', style: const TextStyle(fontSize: 11.5))),
                              DataCell(Text(r.address ?? '-', style: const TextStyle(fontSize: 11))),
                              DataCell(Text('₹${currency.format(r.orderValue)}', style: const TextStyle(fontSize: 12))),
                              if (!isPurchase)
                                DataCell(Text('₹${currency.format(r.extraWorkValue)}', style: const TextStyle(fontSize: 12))),
                              DataCell(Text('₹${currency.format(r.paymentReceived)}', style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold))),
                              DataCell(Text('₹${currency.format(r.balance)}', style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Bottom Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => handleExport(share: true),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.fileSpreadsheet, size: 15, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Download / Save Excel (.xlsx)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
