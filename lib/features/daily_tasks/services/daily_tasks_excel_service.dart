// lib/features/daily_tasks/services/daily_tasks_excel_service.dart

import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/export_preview_dialog.dart';
import '../models/daily_task_model.dart';
import '../providers/daily_tasks_provider.dart';

class DailyTasksExcelService {
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  static Future<void> exportTasksExcel(
    BuildContext context, {
    required List<DailyTask> tasks,
    required DailyTaskFilter filter,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Daily Tasks'];

    final headers = [
      '#',
      'Completed Date & Time',
      'Customer Name',
      'Logged By User',
      'User Role',
      'Task Completed',
      'Status',
      'Edited Date',
      'Deleted Date',
      'Deleted By',
    ];

    // Format headers
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1E1B4B'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    final List<List<String>> previewRows = [];

    for (int rowIdx = 0; rowIdx < tasks.length; rowIdx++) {
      final t = tasks[rowIdx];
      final row = rowIdx + 1;

      String statusStr = 'Active';
      if (t.isDeleted) {
        statusStr = 'Deleted';
      } else if (t.isEdited) {
        statusStr = 'Edited';
      }

      final data = [
        (rowIdx + 1).toString(),
        _dateFormat.format(t.completedAt),
        t.customerName,
        t.userName,
        t.userRole.replaceAll('_', ' ').toUpperCase(),
        t.taskDescription,
        statusStr,
        t.editedAt != null ? _dateFormat.format(t.editedAt!) : '-',
        t.deletedAt != null ? _dateFormat.format(t.deletedAt!) : '-',
        t.deletedByName ?? '-',
      ];

      previewRows.add(data);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          IntCellValue(rowIdx + 1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue(_dateFormat.format(t.completedAt));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue(t.customerName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          TextCellValue(t.userName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          TextCellValue(t.userRole.replaceAll('_', ' ').toUpperCase());
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          TextCellValue(t.taskDescription);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value =
          TextCellValue(statusStr);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value =
          TextCellValue(t.editedAt != null ? _dateFormat.format(t.editedAt!) : '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value =
          TextCellValue(t.deletedAt != null ? _dateFormat.format(t.deletedAt!) : '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value =
          TextCellValue(t.deletedByName ?? '');

      if (row.isEven) {
        for (int c = 0; c < headers.length; c++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row)).cellStyle =
              CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'));
        }
      }
    }

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to generate Excel file');

    final fileName = 'Daily_Tasks_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (context.mounted) {
      ExportPreviewDialog.show(
        context,
        title: 'Export Preview — Daily Tasks (${tasks.length})',
        fileName: fileName,
        headers: headers,
        rows: previewRows,
        fileBytes: fileBytes,
      );
    }
  }
}
