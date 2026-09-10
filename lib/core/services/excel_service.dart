// lib/core/services/excel_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/pipeline.dart';
import '../models/customer.dart';
import '../models/amc_contract.dart';
import '../../features/crm/data/models/prospect_model.dart';
import '../../features/crm/data/models/lead_model.dart';
import '../widgets/export_preview_dialog.dart';

class ExcelService {
  static final _currencyFormat = NumberFormat('#,##,##0.00', 'en_IN');
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  static Future<void> exportPipelines(BuildContext context, List<SalesPipeline> pipelines) async {
    final excel = Excel.createExcel();
    final sheet = excel['Deals'];

    final headers = [
      'Deal ID',
      'Customer',
      'Contact Person',
      'Phone',
      'Email',
      'Product',
      'Current Step',
      'Status',
      'Salesperson',
      'Created Date',
      'Last Updated',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    final List<List<String>> previewRows = [];

    for (int rowIdx = 0; rowIdx < pipelines.length; rowIdx++) {
      final p = pipelines[rowIdx];
      final row = rowIdx + 1;

      final data = [
        p.id,
        p.customer?.companyName ?? '',
        p.customer?.contactPerson ?? '',
        p.customer?.phone ?? '',
        p.customer?.email ?? '',
        p.product?.name ?? '',
        p.currentStep.displayName,
        p.status.displayName,
        p.createdByProfile?.fullName ?? '',
        _dateFormat.format(p.createdAt),
        _dateFormat.format(p.updatedAt),
      ];

      previewRows.add(data);

      for (int colIdx = 0; colIdx < data.length; colIdx++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row),
        );
        cell.value = TextCellValue(data[colIdx]);
        if (row.isEven) {
          cell.cellStyle =
              CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'));
        }
      }
    }

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to generate Excel file');

    final fileName = 'IZYHEAT_Deals_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (context.mounted) {
      ExportPreviewDialog.show(
        context,
        title: 'Export Preview — Deals',
        fileName: fileName,
        headers: headers,
        rows: previewRows,
        fileBytes: fileBytes,
      );
    }
  }

  static Future<void> exportCustomers(BuildContext context, List<Customer> customers) async {
    final excel = Excel.createExcel();
    final sheet = excel['Customers'];

    final headers = [
      'Company Name',
      'Contact Person',
      'Phone',
      'Email',
      'Address',
      'GST Number',
      'Created Date',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    final List<List<String>> previewRows = [];

    for (int rowIdx = 0; rowIdx < customers.length; rowIdx++) {
      final c = customers[rowIdx];
      final row = rowIdx + 1;

      final data = [
        c.companyName,
        c.contactPerson ?? '',
        c.phone ?? '',
        c.email ?? '',
        c.address ?? '',
        c.gstNumber ?? '',
        _dateFormat.format(c.createdAt),
      ];

      previewRows.add(data);

      for (int colIdx = 0; colIdx < data.length; colIdx++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row),
        );
        cell.value = TextCellValue(data[colIdx]);
      }
    }

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to generate Excel file');

    final fileName = 'IZYHEAT_Customers_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (context.mounted) {
      ExportPreviewDialog.show(
        context,
        title: 'Export Preview — Customers',
        fileName: fileName,
        headers: headers,
        rows: previewRows,
        fileBytes: fileBytes,
      );
    }
  }

  static Future<void> exportProspects(BuildContext context, List<Prospect> prospects) async {
    final excel = Excel.createExcel();
    final sheet = excel['Prospects'];

    final headers = [
      'Prospect Name',
      'Phone',
      'Email',
      'Company / Business',
      'Address',
      'GST Number',
      'Lead Source',
      'Created Date',
      'Converted to Lead',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    final List<List<String>> previewRows = [];

    for (int rowIdx = 0; rowIdx < prospects.length; rowIdx++) {
      final p = prospects[rowIdx];
      final row = rowIdx + 1;
      final data = [
        p.name,
        p.phone,
        p.email ?? '',
        p.company ?? '',
        p.address ?? '',
        p.gst ?? '',
        p.source,
        _dateFormat.format(p.createdAt),
        p.convertedToLeadId != null ? 'Yes' : 'No',
      ];

      previewRows.add(data);

      for (int colIdx = 0; colIdx < data.length; colIdx++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
        cell.value = TextCellValue(data[colIdx]);
      }
    }

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to generate Excel file');

    final fileName = 'Prospects_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (context.mounted) {
      ExportPreviewDialog.show(
        context,
        title: 'Export Preview — Prospects',
        fileName: fileName,
        headers: headers,
        rows: previewRows,
        fileBytes: fileBytes,
      );
    }
  }

  static Future<void> exportLeads(BuildContext context, List<Lead> leads, List<Prospect> prospects) async {
    final excel = Excel.createExcel();
    final sheet = excel['Leads'];

    final headers = [
      'Prospect / Contact',
      'Phone',
      'Product Name',
      'Status',
      'Estimated Value',
      'Expected Date',
      'Created Date',
      'Notes',
      'Converted to Customer',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    final List<List<String>> previewRows = [];

    for (int rowIdx = 0; rowIdx < leads.length; rowIdx++) {
      final l = leads[rowIdx];
      final p = prospects.where((p) => p.id == l.prospectId).firstOrNull;
      final displayName = (l.prospectName != null && l.prospectName!.isNotEmpty)
          ? l.prospectName!
          : (p?.name ?? 'Lead');
      final displayPhone = (l.contactPhone != null && l.contactPhone!.isNotEmpty)
          ? l.contactPhone!
          : (p?.phone ?? '');

      final row = rowIdx + 1;
      final data = [
        displayName,
        displayPhone,
        l.productName,
        l.status,
        _currencyFormat.format(l.estimatedValue),
        l.expectedDate != null ? _dateFormat.format(l.expectedDate!) : '',
        _dateFormat.format(l.createdAt),
        l.notes ?? '',
        (l.convertedToCustomerId != null || l.status == 'Won') ? 'Yes' : 'No',
      ];

      previewRows.add(data);

      for (int colIdx = 0; colIdx < data.length; colIdx++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
        cell.value = TextCellValue(data[colIdx]);
      }
    }

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to generate Excel file');

    final fileName = 'Leads_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (context.mounted) {
      ExportPreviewDialog.show(
        context,
        title: 'Export Preview — Leads',
        fileName: fileName,
        headers: headers,
        rows: previewRows,
        fileBytes: fileBytes,
      );
    }
  }

  static Future<void> exportCrmCustomers(BuildContext context, List<Lead> leads, List<Prospect> prospects) async {
    final excel = Excel.createExcel();
    final sheet = excel['CRM Customers'];

    final headers = [
      'Customer Name',
      'Product',
      'Phone',
      'Email',
      'Address',
      'GST',
      'Deal Value',
      'Won Date',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    final List<List<String>> previewRows = [];

    for (int rowIdx = 0; rowIdx < leads.length; rowIdx++) {
      final l = leads[rowIdx];
      final p = prospects.where((p) => p.id == l.prospectId).firstOrNull;
      final displayName = (l.prospectName != null && l.prospectName!.isNotEmpty)
          ? l.prospectName!
          : (p?.name ?? 'Customer');
      final displayPhone = (l.contactPhone != null && l.contactPhone!.isNotEmpty)
          ? l.contactPhone!
          : (p?.phone ?? '');

      final row = rowIdx + 1;
      final data = [
        displayName,
        l.productName,
        displayPhone,
        p?.email ?? '',
        p?.address ?? '',
        p?.gst ?? '',
        _currencyFormat.format(l.estimatedValue),
        _dateFormat.format(l.updatedAt),
      ];

      previewRows.add(data);

      for (int colIdx = 0; colIdx < data.length; colIdx++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
        cell.value = TextCellValue(data[colIdx]);
      }
    }

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to generate Excel file');

    final fileName = 'CRMCustomers_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (context.mounted) {
      ExportPreviewDialog.show(
        context,
        title: 'Export Preview — CRM Customers',
        fileName: fileName,
        headers: headers,
        rows: previewRows,
        fileBytes: fileBytes,
      );
    }
  }

  static Future<void> exportAmcContracts(BuildContext context, List<AmcContract> contracts) async {
    final excel = Excel.createExcel();
    final sheet = excel['AMC Contracts'];

    final headers = [
      'AMC Number',
      'Customer',
      'Product',
      'Status',
      'Start Date',
      'End Date',
      'Contract Amount',
      'Visits Completed',
      'Total Visits',
      'Created By',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    final dateFormat = DateFormat('dd/MM/yyyy');
    final List<List<String>> previewRows = [];

    for (int rowIdx = 0; rowIdx < contracts.length; rowIdx++) {
      final c = contracts[rowIdx];
      final row = rowIdx + 1;

      final completedVisits = (c.serviceVisits ?? []).where((v) => v.status.name == 'completed').length;

      final data = [
        c.amcNumber,
        c.customer?.companyName ?? '',
        c.product?.name ?? '',
        c.status.displayName,
        c.startDate != null ? dateFormat.format(c.startDate!) : '',
        c.endDate != null ? dateFormat.format(c.endDate!) : '',
        c.contractAmount != null ? _currencyFormat.format(c.contractAmount) : '0.00',
        completedVisits.toString(),
        (c.numberOfVisitsIncluded ?? 0).toString(),
        c.createdByProfile?.fullName ?? '',
      ];

      previewRows.add(data);

      for (int colIdx = 0; colIdx < data.length; colIdx++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row),
        );
        cell.value = TextCellValue(data[colIdx]);
        if (row.isEven) {
          cell.cellStyle =
              CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'));
        }
      }
    }

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to generate Excel file');

    final fileName = 'IZYHEAT_AMC_Contracts_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (context.mounted) {
      ExportPreviewDialog.show(
        context,
        title: 'Export Preview — AMC Contracts',
        fileName: fileName,
        headers: headers,
        rows: previewRows,
        fileBytes: fileBytes,
      );
    }
  }
}
