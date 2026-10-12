import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';
import '../../providers/pm_company_provider.dart';
import '../../providers/pm_providers.dart';

class PmExcelImportModal extends ConsumerStatefulWidget {
  final bool isPurchase;

  const PmExcelImportModal({super.key, this.isPurchase = false});

  @override
  ConsumerState<PmExcelImportModal> createState() => _PmExcelImportModalState();
}

class _PmExcelImportModalState extends ConsumerState<PmExcelImportModal> {
  String? _selectedFileName;
  List<Map<String, dynamic>> _parsedRecords = [];
  bool _isLoading = false;

  void _downloadTemplate() {
    final excel = Excel.createExcel();
    final sheetName = widget.isPurchase ? 'Vendors_Template' : 'Customers_Template';
    final defaultSheet = excel.getDefaultSheet();
    final sheet = excel[sheetName];
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.delete(defaultSheet);
    }

    final headers = [
      'ID Number',
      'Site Name',
      'Mobile Number',
      'Address',
      'Sales Man Name',
      'Firm Name',
      'Party Print Name',
      'Item Group',
      'Order Value',
      'Item Name',
      'Item Qty',
      'Tank Type',
      'Tank Qty',
      'Remark',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#005CE6'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    // Add sample row
    final sample = [
      '1001',
      'GREEN TECH SOLAR',
      '9876543210',
      'Pune Maharashtra',
      'Sagar Farate',
      'Insiya Trading Corporation',
      'GREEN TECH CORP',
      'Solar Water Heater',
      '250000',
      'GI Pressurized Tank 500ltr',
      '2',
      'SOLAR WATER HEATER 700/38',
      '45',
      'Initial Site Installation',
    ];

    for (int c = 0; c < sample.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1)).value = TextCellValue(sample[c]);
    }

    final bytes = excel.save();
    if (bytes != null) {
      Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'Project_Manager_Import_Template.xlsx',
      );
    }
  }

  Future<void> _pickExcelFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      final path = files.first.path!;
      final bytes = File(path).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      final List<Map<String, dynamic>> records = [];
      for (final table in excel.tables.keys) {
        final rows = excel.tables[table]!.rows;
        if (rows.length <= 1) continue;

        for (int r = 1; r < rows.length; r++) {
          final row = rows[r];
          if (row.isEmpty) continue;

          String val(int idx) => idx < row.length && row[idx] != null ? row[idx]!.value.toString().trim() : '';

          final siteName = val(1);
          if (siteName.isEmpty) continue;

          records.add({
            'site_name': siteName,
            'mobile_number': val(2),
            'address': val(3),
            'salesman_name': val(4),
            'firm_name': val(5),
            'party_print_name': val(6),
            'order_type': val(7).isNotEmpty ? val(7) : (widget.isPurchase ? 'Vendor Supply' : 'Solar Water Heater'),
            'order_value': double.tryParse(val(8)) ?? 0.0,
            'hp_type': val(9),
            'hp_qty': int.tryParse(val(10)) ?? 0,
            'tank_type': val(11),
            'tank_qty': int.tryParse(val(12)) ?? 0,
            'work_remark': val(13),
          });
        }
        break; // Process primary sheet
      }

      setState(() {
        _selectedFileName = files.first.name;
        _parsedRecords = records;
      });
    }
  }

  Future<void> _importRecords() async {
    if (_parsedRecords.isEmpty) return;
    final activeCompany = ref.read(pmActiveCompanyProvider);
    setState(() => _isLoading = true);

    try {
      int importedCount = 0;
      for (final rec in _parsedRecords) {
        rec['company_id'] = activeCompany.id;
        if (widget.isPurchase) {
          rec['quotation_value'] = rec['order_value'];
          await ref.read(pmPurchasesRepositoryProvider).createPurchase(rec);
        } else {
          await ref.read(pmProjectsRepositoryProvider).createProject(rec);
        }
        importedCount++;
      }

      if (widget.isPurchase) {
        ref.invalidate(pmPurchasesListProvider);
      } else {
        ref.invalidate(pmProjectsListProvider);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported $importedCount records!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header matching Screenshot 3
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.fileSpreadsheet, size: 20, color: Color(0xFF005CE6)),
                      const SizedBox(width: 8),
                      Text(
                        widget.isPurchase ? 'Import Vendors from Excel' : 'Import Customers from Excel',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Upload an Excel (.xlsx or .csv) file or download a sample template to start.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // Need a sample file? card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Need a sample file?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Download pre-formatted Excel template', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                    InkWell(
                      onTap: _downloadTemplate,
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: const Color(0xFF005CE6)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.download, size: 13, color: Color(0xFF005CE6)),
                            SizedBox(width: 6),
                            Text('Download Template', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF005CE6))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Click to select Excel file dashed container (Screenshot 3)
              InkWell(
                onTap: _pickExcelFile,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF38BDF8),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.cloudUpload, size: 36, color: Color(0xFF0284C7)),
                        const SizedBox(height: 10),
                        Text(
                          _selectedFileName ?? 'Click to select Excel file (.xlsx, .csv)',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Required format pill box
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: const Text(
                            'Required format: Use the template to avoid errors.\nColumns: ID Number, Site Name, Mobile Number, Address, Sales Man Name, Firm Name, Party Print Name, Item Group, Order Value, Item Name, Item Qty, Tank Type, Tank Qty, Remark',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF15803D), height: 1.3),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

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
                      child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _parsedRecords.isNotEmpty && !_isLoading ? _importRecords : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                      decoration: BoxDecoration(
                        color: _parsedRecords.isNotEmpty ? const Color(0xFF005CE6) : const Color(0xFF93C5FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              'Import ${_parsedRecords.length} Customers',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
