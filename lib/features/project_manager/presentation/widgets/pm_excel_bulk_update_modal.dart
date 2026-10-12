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

class PmExcelBulkUpdateModal extends ConsumerStatefulWidget {
  final bool isPurchase;

  const PmExcelBulkUpdateModal({super.key, this.isPurchase = false});

  @override
  ConsumerState<PmExcelBulkUpdateModal> createState() => _PmExcelBulkUpdateModalState();
}

class _PmExcelBulkUpdateModalState extends ConsumerState<PmExcelBulkUpdateModal> {
  String? _selectedFileName;
  List<Map<String, dynamic>> _parsedRecords = [];
  bool _isLoading = false;

  void _downloadTemplate() {
    final excel = Excel.createExcel();
    final sheetName = widget.isPurchase ? 'Vendor_Update_Template' : 'Customer_Update_Template';
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
      'Order Value',
      'Extra Work Value',
      'Party Print Name',
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

    final sample = [
      '1001',
      'GREEN TECH SOLAR',
      '9876543210',
      'Pune Maharashtra',
      '260000',
      '15000',
      'GREEN TECH CORP',
    ];

    for (int c = 0; c < sample.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1)).value = TextCellValue(sample[c]);
    }

    final bytes = excel.save();
    if (bytes != null) {
      Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'Project_Manager_Update_Template.xlsx',
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

          final idNoStr = val(0);
          final siteName = val(1);
          if (idNoStr.isEmpty && siteName.isEmpty) continue;

          records.add({
            'id_no': int.tryParse(idNoStr),
            'site_name': siteName,
            'mobile_number': val(2),
            'address': val(3),
            'order_value': double.tryParse(val(4)),
            'extra_work_value': double.tryParse(val(5)),
            'party_print_name': val(6),
          });
        }
        break;
      }

      setState(() {
        _selectedFileName = files.first.name;
        _parsedRecords = records;
      });
    }
  }

  Future<void> _updateRecords() async {
    if (_parsedRecords.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      int updatedCount = 0;
      final activeCompany = ref.read(pmActiveCompanyProvider);
      final List<dynamic> existing = widget.isPurchase
          ? await ref.read(pmPurchasesRepositoryProvider).getPurchases(companyId: activeCompany.id)
          : await ref.read(pmProjectsRepositoryProvider).getProjects(companyId: activeCompany.id);

      for (final rec in _parsedRecords) {
        final idNo = rec['id_no'] as int?;
        final siteName = rec['site_name'] as String?;

        dynamic match;
        if (idNo != null) {
          for (final e in existing) {
            if (e.idNo == idNo) {
              match = e;
              break;
            }
          }
        }
        if (match == null && siteName != null && siteName.isNotEmpty) {
          for (final e in existing) {
            if (e.siteName.toString().toLowerCase() == siteName.toLowerCase()) {
              match = e;
              break;
            }
          }
        }

        if (match != null) {
          final updateData = <String, dynamic>{};
          if (rec['mobile_number'] != null && (rec['mobile_number'] as String).isNotEmpty) {
            updateData['mobile_number'] = rec['mobile_number'];
          }
          if (rec['address'] != null && (rec['address'] as String).isNotEmpty) {
            updateData['address'] = rec['address'];
          }
          if (rec['order_value'] != null) {
            if (widget.isPurchase) {
              updateData['quotation_value'] = rec['order_value'];
            } else {
              updateData['order_value'] = rec['order_value'];
            }
          }
          if (rec['extra_work_value'] != null && !widget.isPurchase) {
            updateData['extra_work_value'] = rec['extra_work_value'];
          }
          if (rec['party_print_name'] != null && (rec['party_print_name'] as String).isNotEmpty) {
            updateData['party_print_name'] = rec['party_print_name'];
          }

          if (updateData.isNotEmpty) {
            if (widget.isPurchase) {
              await ref.read(pmPurchasesRepositoryProvider).updatePurchase(match.id, updateData);
            } else {
              await ref.read(pmProjectsRepositoryProvider).updateProject(match.id, updateData);
            }
            updatedCount++;
          }
        }
      }

      if (widget.isPurchase) {
        ref.invalidate(pmPurchasesListProvider);
      } else {
        ref.invalidate(pmProjectsListProvider);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully updated $updatedCount records via Excel!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk update failed: $e')),
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
              // Header matching Screenshot 4
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.fileUp, size: 20, color: Color(0xFF005CE6)),
                      SizedBox(width: 8),
                      Text(
                        'Bulk Update via Excel',
                        style: TextStyle(
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
                'Update existing customer records by uploading an Excel file. New records will not be created.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // How it works card (Screenshot 4)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCCFBF1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('How it works:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Download the template or use your exported Excel file.\n2. Ensure the match key (ID or Customer Name) is present and correct.\n3. Upload the file, then select which columns you want to overwrite.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _downloadTemplate,
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.download, size: 13, color: Color(0xFF005CE6)),
                            SizedBox(width: 6),
                            Text('Download Template', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Upload Excel/CSV File label & dashed box (Screenshot 4)
              const Text('Upload Excel/CSV File', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickExcelFile,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 150,
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
                          _selectedFileName ?? 'Click to select file',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '.xlsx, .xls, or .csv',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        if (_parsedRecords.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_parsedRecords.length} records ready to update',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                          ),
                        ],
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
                    onTap: _parsedRecords.isNotEmpty && !_isLoading ? _updateRecords : null,
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
                              'Update ${_parsedRecords.length} Customers',
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
