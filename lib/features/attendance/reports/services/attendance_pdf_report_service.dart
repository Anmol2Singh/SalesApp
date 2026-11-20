// lib/features/attendance/reports/services/attendance_pdf_report_service.dart

import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext, Navigator, MaterialPageRoute;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/services/pdf_service.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../models/attendance_record_model.dart';
import '../../models/employee_profile_model.dart';

class AttendancePdfReportService {
  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _timeFormat = DateFormat('hh:mm a');

  static Future<void> generateAndPreviewPdf(
    BuildContext context, {
    required AttendanceEmployeeProfile employee,
    required List<AttendanceRecord> records,
    required DateTime periodStart,
    required DateTime periodEnd,
    String? organizationTitle,
  }) async {
    final pdfBytes = await generateAttendancePdfBytes(
      employee: employee,
      records: records,
      periodStart: periodStart,
      periodEnd: periodEnd,
      organizationTitle: organizationTitle,
    );

    final fileName = 'Attendance_Report_${employee.employeeCode}_${DateFormat('yyyyMM').format(periodStart)}.pdf';

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            fileName: fileName,
          ),
        ),
      );
    }
  }

  static Future<Uint8List> generateAttendancePdfBytes({
    required AttendanceEmployeeProfile employee,
    required List<AttendanceRecord> records,
    required DateTime periodStart,
    required DateTime periodEnd,
    String? organizationTitle,
  }) async {
    final pdf = pw.Document();

    final resolvedConfig = await PdfService.resolveTemplateConfig(null);
    final companyName = organizationTitle ??
        (resolvedConfig['company_name'] as String? ?? 'INSIYA SOLAR INDUSTRY');
    final companyAddress = resolvedConfig['company_address'] as String? ??
        'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra - 411014';
    final companyPhone = resolvedConfig['company_phone'] as String? ?? '+91 91122 00055';
    final companyEmail = resolvedConfig['company_email'] as String? ?? 'info@insiyasolar.com';

    // Summary calculations
    int presentCount = 0;
    int lateCount = 0;
    int absentCount = 0;
    int halfDayCount = 0;
    double totalWorkedHours = 0;
    double totalOvertimeHours = 0;

    for (final r in records) {
      if (r.status == AttendanceRecordStatus.present) {
        presentCount++;
      } else if (r.status == AttendanceRecordStatus.late || r.isLate) {
        lateCount++;
        presentCount++;
      } else if (r.status == AttendanceRecordStatus.absent) {
        absentCount++;
      } else if (r.status == AttendanceRecordStatus.halfDay) {
        halfDayCount++;
      }
      totalWorkedHours += (r.totalWorkingMinutes / 60.0);
      totalOvertimeHours += (r.overtimeMinutes / 60.0);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(
          companyName: companyName,
          companyAddress: companyAddress,
          companyPhone: companyPhone,
          companyEmail: companyEmail,
        ),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildReportTitle(periodStart, periodEnd),
          pw.SizedBox(height: 16),
          _buildEmployeeInfoCard(employee),
          pw.SizedBox(height: 16),
          _buildSummaryStats(
            totalRecords: records.length,
            presentCount: presentCount,
            lateCount: lateCount,
            absentCount: absentCount,
            halfDayCount: halfDayCount,
            totalWorkedHours: totalWorkedHours,
            totalOvertimeHours: totalOvertimeHours,
          ),
          pw.SizedBox(height: 20),
          _buildRecordsTable(records),
          pw.SizedBox(height: 30),
          _buildSignatures(),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader({
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    required String companyEmail,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blue900, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  companyName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  companyAddress,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Phone: $companyPhone | Email: $companyEmail',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber800,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'IZYHEAT HR & OPS',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReportTitle(DateTime start, DateTime end) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'EMPLOYEE ATTENDANCE STATEMENT',
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
        pw.Text(
          'Period: ${_dateFormat.format(start)} - ${_dateFormat.format(end)}',
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildEmployeeInfoCard(AttendanceEmployeeProfile employee) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Employee Name: ${employee.fullName}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Employee Code: ${employee.employeeCode}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
              pw.SizedBox(height: 4),
              pw.Text('Designation: ${employee.designation}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Attendance Role: ${employee.attendanceRole.name.toUpperCase()}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
              pw.SizedBox(height: 4),
              pw.Text('Department: ${employee.departmentName ?? "Operations"}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
              pw.SizedBox(height: 4),
              pw.Text('Joined: ${_dateFormat.format(employee.joiningDate)}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryStats({
    required int totalRecords,
    required int presentCount,
    required int lateCount,
    required int absentCount,
    required int halfDayCount,
    required double totalWorkedHours,
    required double totalOvertimeHours,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('Present Days', '$presentCount', PdfColors.green800),
          _buildStatBox('Late Days', '$lateCount', PdfColors.orange800),
          _buildStatBox('Absent Days', '$absentCount', PdfColors.red800),
          _buildStatBox('Half Days', '$halfDayCount', PdfColors.purple800),
          _buildStatBox('Total Hours', '${totalWorkedHours.toStringAsFixed(1)}h', PdfColors.blue900),
          _buildStatBox('Overtime', '${totalOvertimeHours.toStringAsFixed(1)}h', PdfColors.indigo800),
        ],
      ),
    );
  }

  static pw.Widget _buildStatBox(String title, String val, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          val,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _buildRecordsTable(List<AttendanceRecord> records) {
    if (records.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        alignment: pw.Alignment.center,
        child: pw.Text('No attendance records logged for this period.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
      );
    }

    return pw.TableHelper.fromTextArray(
      headers: ['Date', 'Check In', 'Check Out', 'Hours', 'OT', 'Status', 'Location / Geofence'],
      data: records.map((r) {
        final inTimeStr = r.checkInTime != null ? _timeFormat.format(r.checkInTime!) : '--';
        final outTimeStr = r.checkOutTime != null ? _timeFormat.format(r.checkOutTime!) : '--';
        final isInside = (r.checkInDistanceMeters ?? 999) <= 250;
        final geofenceStr = isInside ? 'Verified Office' : 'Outside Geofence';
        final hoursStr = (r.totalWorkingMinutes / 60.0).toStringAsFixed(1);
        final otStr = (r.overtimeMinutes / 60.0).toStringAsFixed(1);
        final dateStr = DateFormat('yyyy-MM-dd').format(r.attendanceDate);

        return [
          dateStr,
          inTimeStr,
          outTimeStr,
          '${hoursStr}h',
          '${otStr}h',
          r.status.name.toUpperCase(),
          geofenceStr,
        ];
      }).toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
    );
  }

  static pw.Widget _buildSignatures() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 140,
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey600, width: 1)),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Employee Signature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              width: 140,
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey600, width: 1)),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Manager / HR Authorization', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())} via IZYHEAT Attendance System',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }
}
