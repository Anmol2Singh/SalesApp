// lib/core/services/excel_service.dart

import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/pipeline.dart';
import '../models/customer.dart';
import '../models/amc_contract.dart';
import '../../features/crm/data/models/prospect_model.dart';
import '../../features/crm/data/models/lead_model.dart';
import '../../features/complaints/data/models/complaint_model.dart';
import '../../features/reports/models/activity_report_data.dart';
import '../models/inventory_item.dart';
import '../models/product.dart';
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
      'Salesperson (Created By)',
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
      'Company / Customer Name',
      'Contact Person',
      'Phone',
      'Email',
      'Address',
      'GST Number',
      'Created By (User)',
      'Assigned Salesperson',
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
        c.salesmanName ?? c.createdBy,
        c.assignedToName ?? '-',
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
      'Created By (User)',
      'Assigned To',
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
        p.createdByName ?? p.createdBy,
        p.assignedByName ?? p.assignedTo ?? '-',
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
      'Created By (User)',
      'Assigned To',
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
        l.createdByName ?? l.createdBy,
        l.assignedByName ?? l.assignedTo ?? '-',
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
      'Created By (User)',
      'Assigned To',
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
        l.createdByName ?? l.createdBy,
        l.assignedByName ?? l.assignedTo ?? '-',
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

  static Future<void> exportComplaints(BuildContext context, List<Complaint> complaints) async {
    final excel = Excel.createExcel();
    final sheet = excel['Complaints'];

    final headers = [
      'Ticket Number',
      'Title',
      'Customer Name',
      'Phone',
      'Address',
      'Product',
      'Priority',
      'Status',
      'Technician / Handled By',
      'Source / Logged By',
      'TAT Remaining',
      'Date Logged',
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

    for (int rowIdx = 0; rowIdx < complaints.length; rowIdx++) {
      final c = complaints[rowIdx];
      final row = rowIdx + 1;
      final data = [
        c.ticketNumber,
        c.title,
        c.customerName,
        c.customerPhone,
        c.customerAddress,
        c.productName ?? '-',
        c.priority,
        c.status.toUpperCase(),
        c.technicianName ?? 'Unassigned',
        c.source,
        c.tatRemaining,
        _dateFormat.format(c.createdAt),
      ];

      previewRows.add(data);

      for (int colIdx = 0; colIdx < data.length; colIdx++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: row));
        cell.value = TextCellValue(data[colIdx]);
      }
    }

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to generate Excel file');

    final fileName = 'Complaints_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (context.mounted) {
      ExportPreviewDialog.show(
        context,
        title: 'Export Preview — Complaints',
        fileName: fileName,
        headers: headers,
        rows: previewRows,
        fileBytes: fileBytes,
      );
    }
  }

  static Future<void> exportActivityReportExcel(
    BuildContext context, {
    required ActivityReportData data,
    required String userName,
    required String dateStr,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Activity Summary'];

    final headers = [
      'Activity Category',
      'Count',
      'Staff Member',
      'Period',
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

    final summaryRows = [
      ['Prospects Added', data.prospects.length.toString(), userName, dateStr],
      ['Leads Added', data.leads.length.toString(), userName, dateStr],
      ['Lead Communications Logged', data.communications.length.toString(), userName, dateStr],
      ['Deals Created', data.pipelines.length.toString(), userName, dateStr],
      ['Customers Added', data.customers.length.toString(), userName, dateStr],
      ['Complaints Handled', data.complaints.length.toString(), userName, dateStr],
      ['Deal Steps Completed', data.stepAuditLogs.length.toString(), userName, dateStr],
    ];

    for (int r = 0; r < summaryRows.length; r++) {
      for (int c = 0; c < summaryRows[r].length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        cell.value = TextCellValue(summaryRows[r][c]);
      }
    }

    // Prospects Sheet
    if (data.prospects.isNotEmpty) {
      final pSheet = excel['Prospects'];
      final pHeaders = ['Prospect Name', 'Phone', 'Company', 'Source', 'Converted', 'Created At'];
      for (int i = 0; i < pHeaders.length; i++) {
        final cell = pSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(pHeaders[i]);
        cell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
      }
      for (int r = 0; r < data.prospects.length; r++) {
        final pr = data.prospects[r];
        final rowData = [
          pr['name']?.toString() ?? '-',
          pr['phone']?.toString() ?? '-',
          pr['company']?.toString() ?? '-',
          pr['source']?.toString() ?? 'Manual',
          pr['converted_to_lead_id'] != null ? 'Yes' : 'No',
          pr['created_at'] != null ? _dateFormat.format(DateTime.tryParse(pr['created_at']) ?? DateTime.now()) : '-',
        ];
        for (int c = 0; c < rowData.length; c++) {
          pSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).value = TextCellValue(rowData[c]);
        }
      }
    }

    // Leads Sheet
    if (data.leads.isNotEmpty) {
      final lSheet = excel['Leads'];
      final lHeaders = ['Lead / Prospect', 'Product Name', 'Estimated Value', 'Status', 'Created At'];
      for (int i = 0; i < lHeaders.length; i++) {
        final cell = lSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(lHeaders[i]);
        cell.cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'), fontColorHex: ExcelColor.fromHexString('#FFFFFF'));
      }
      for (int r = 0; r < data.leads.length; r++) {
        final l = data.leads[r];
        final rowData = [
          l['prospect_name']?.toString() ?? '-',
          l['product_name']?.toString() ?? '-',
          '₹${l['estimated_value'] ?? 0}',
          l['status']?.toString() ?? 'New',
          l['created_at'] != null ? _dateFormat.format(DateTime.tryParse(l['created_at']) ?? DateTime.now()) : '-',
        ];
        for (int c = 0; c < rowData.length; c++) {
          lSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).value = TextCellValue(rowData[c]);
        }
      }
    }

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to generate Excel file');

    final fileName = 'Activity_Report_${userName.replaceAll(" ", "_")}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';

    if (context.mounted) {
      ExportPreviewDialog.show(
        context,
        title: 'Export Preview — Activity Report ($userName)',
        fileName: fileName,
        headers: headers,
        rows: summaryRows,
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

  static Future<void> exportInventoryItems(BuildContext context, List<InventoryItem> items) async {
    final excel = Excel.createExcel();
    final sheet = excel['Inventory_Items'];
    excel.setDefaultSheet('Inventory_Items');

    final headers = [
      '#',
      'Item Name',
      'HSN / SAC Code',
      'Unit (UOM)',
      'Default Price (₹)',
      'Warranty (Months)',
      'Created Date',
      'Item ID',
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

    for (int rowIdx = 0; rowIdx < items.length; rowIdx++) {
      final item = items[rowIdx];
      final row = rowIdx + 1;

      final data = [
        (rowIdx + 1).toString(),
        item.itemName,
        item.hsnSac != null && item.hsnSac!.isNotEmpty ? item.hsnSac! : '-',
        item.uom != null && item.uom!.isNotEmpty ? item.uom! : 'NOS',
        '₹${_currencyFormat.format(item.price)}',
        '${item.warrantyMonths}m',
        _dateFormat.format(item.createdAt.toLocal()),
        item.id,
      ];

      previewRows.add(data);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = IntCellValue(rowIdx + 1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(item.itemName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(item.hsnSac ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue(item.uom ?? 'NOS');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = DoubleCellValue(item.price);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = IntCellValue(item.warrantyMonths);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = TextCellValue(_dateFormat.format(item.createdAt.toLocal()));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = TextCellValue(item.id);

      if (row.isEven) {
        for (int c = 0; c < headers.length; c++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row)).cellStyle =
              CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'));
        }
      }
    }

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to generate Excel file');

    final fileName = 'Inventory_Items_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (context.mounted) {
      ExportPreviewDialog.show(
        context,
        title: 'Export Preview — Inventory Items (${items.length})',
        fileName: fileName,
        headers: headers,
        rows: previewRows,
        fileBytes: fileBytes,
      );
    }
  }

  static Future<void> exportProducts(BuildContext context, List<Product> products) async {
    final excel = Excel.createExcel();
    final sheet = excel['Products'];
    excel.setDefaultSheet('Products');

    final headers = [
      '#',
      'Product Name',
      'Category',
      'Capacities',
      'Status',
      'Created Date',
      'Product ID',
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

    for (int rowIdx = 0; rowIdx < products.length; rowIdx++) {
      final p = products[rowIdx];
      final row = rowIdx + 1;

      final data = [
        (rowIdx + 1).toString(),
        p.name,
        p.category ?? '-',
        p.baseSpecs.capacities.isNotEmpty ? p.baseSpecs.capacities.join(', ') : '-',
        p.isActive ? 'Active' : 'Inactive',
        _dateFormat.format(p.createdAt.toLocal()),
        p.id,
      ];

      previewRows.add(data);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = IntCellValue(rowIdx + 1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(p.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(p.category ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue(p.baseSpecs.capacities.join(', '));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue(p.isActive ? 'Active' : 'Inactive');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = TextCellValue(_dateFormat.format(p.createdAt.toLocal()));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = TextCellValue(p.id);

      if (row.isEven) {
        for (int c = 0; c < headers.length; c++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row)).cellStyle =
              CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F8FAFC'));
        }
      }
    }

    final fileBytes = excel.save();
    if (fileBytes == null) throw Exception('Failed to generate Excel file');

    final fileName = 'Product_Catalog_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

    if (context.mounted) {
      ExportPreviewDialog.show(
        context,
        title: 'Export Preview — Products (${products.length})',
        fileName: fileName,
        headers: headers,
        rows: previewRows,
        fileBytes: fileBytes,
      );
    }
  }
}
