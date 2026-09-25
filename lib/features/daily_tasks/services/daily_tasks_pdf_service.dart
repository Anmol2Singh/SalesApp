// lib/features/daily_tasks/services/daily_tasks_pdf_service.dart

import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext, Navigator, MaterialPageRoute;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../models/daily_task_model.dart';
import '../providers/daily_tasks_provider.dart';

class DailyTasksPdfService {
  static final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  static Future<void> generateAndPreviewPdf(
    BuildContext context, {
    required List<DailyTask> tasks,
    required DailyTaskFilter filter,
    String? currentUserName,
    String? targetPersonName,
    String? targetPersonRole,
  }) async {
    final pdfBytes = await generateTasksPdfBytes(
      tasks: tasks,
      filter: filter,
      currentUserName: currentUserName,
      targetPersonName: targetPersonName,
      targetPersonRole: targetPersonRole,
    );

    final fileName = 'Daily_Tasks_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

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

  static Future<Uint8List> generateTasksPdfBytes({
    required List<DailyTask> tasks,
    required DailyTaskFilter filter,
    String? currentUserName,
    String? targetPersonName,
    String? targetPersonRole,
  }) async {
    final pdf = pw.Document();

    final prefs = await SharedPreferences.getInstance();
    final companyName = prefs.getString('company_name') ?? 'INSIYA SOLAR INDUSTRY';
    final companyAddress = prefs.getString('company_address') ??
        'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra - 411014';
    final companyPhone = prefs.getString('company_phone') ?? '+91 9292922992';
    final companyEmail = prefs.getString('company_email') ?? 'insiyasolarindustry@gmail.com';
    final logoUrl = prefs.getString('company_logo_url');
    pw.ImageProvider? logoImage;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        logoImage = await networkImage(logoUrl);
      } catch (_) {}
    }

    final regularFont = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();

    final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);

    // Resolve specific target person if applicable
    String? resolvedTargetPerson = targetPersonName;
    String? resolvedTargetRole = targetPersonRole;

    if (resolvedTargetPerson == null || resolvedTargetPerson.isEmpty) {
      if (filter.selectedUserId != null && tasks.isNotEmpty) {
        final match = tasks.firstWhere(
          (t) => t.userId == filter.selectedUserId,
          orElse: () => tasks.first,
        );
        resolvedTargetPerson = match.userName;
        resolvedTargetRole = match.userRole;
      } else if (tasks.isNotEmpty && tasks.every((t) => t.userId == tasks.first.userId)) {
        resolvedTargetPerson = tasks.first.userName;
        resolvedTargetRole = tasks.first.userRole;
      }
    }

    // Build filter string
    String filterDescription = 'Date: ${filter.dateFilter.replaceAll('_', ' ').toUpperCase()}';
    if (filter.dateFilter == 'specific_day' && filter.specificDate != null) {
      filterDescription = 'Date: ${DateFormat('dd MMM yyyy').format(filter.specificDate!)}';
    } else if (filter.dateFilter == 'custom' && filter.customStartDate != null && filter.customEndDate != null) {
      filterDescription = 'Date: ${DateFormat('dd MMM yyyy').format(filter.customStartDate!)} - ${DateFormat('dd MMM yyyy').format(filter.customEndDate!)}';
    }
    if (filter.customerName != null && filter.customerName!.isNotEmpty) {
      filterDescription += ' | Customer: ${filter.customerName}';
    }
    if (resolvedTargetPerson != null && resolvedTargetPerson.isNotEmpty) {
      filterDescription += ' | Employee: $resolvedTargetPerson';
    }

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.indigo900, width: 2)),
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
                        companyName,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        companyAddress,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Phone: $companyPhone | Email: $companyEmail',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (logoImage != null) ...[
                      pw.Container(
                        height: 34,
                        width: 85,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(height: 4),
                    ],
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.indigo50,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.indigo200, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'REPORT GENERATED BY',
                            style: pw.TextStyle(
                              fontSize: 6.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.indigo800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            currentUserName?.isNotEmpty == true ? currentUserName! : 'Authorized Staff',
                            style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.indigo900,
                            ),
                          ),
                          pw.Text(
                            DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}${currentUserName != null ? " by $currentUserName" : ""}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (context) => [
          pw.SizedBox(height: 12),
          // Title banner
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.indigo50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.indigo200, width: 0.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DAILY TASKS COMPLETED REPORT',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      filterDescription,
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo900,
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Text(
                    '${tasks.length} Tasks',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // If a specific person report is being generated, show their name prominently above the table!
          if (resolvedTargetPerson != null && resolvedTargetPerson.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo900,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Text(
                        'TASKS COMPLETED BY: ',
                        style: pw.TextStyle(
                          color: PdfColors.indigo200,
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.Text(
                        resolvedTargetPerson,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (resolvedTargetRole != null && resolvedTargetRole.isNotEmpty)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        resolvedTargetRole.replaceAll('_', ' ').toUpperCase(),
                        style: pw.TextStyle(
                          color: PdfColors.indigo900,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 12),

          // Table
          if (tasks.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(24),
              alignment: pw.Alignment.center,
              child: pw.Text(
                'No daily tasks found for the selected criteria.',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              headerHeight: 24,
              cellHeight: 22,
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FixedColumnWidth(28), // S.No
                1: const pw.FixedColumnWidth(90), // Date & Time
                2: const pw.FixedColumnWidth(110), // Customer
                3: const pw.FixedColumnWidth(95), // User
                4: const pw.FlexColumnWidth(3), // Task Completed
                5: const pw.FixedColumnWidth(48), // Status
              },
              headers: [
                '#',
                'Date & Time',
                'Customer Name',
                'Logged By',
                'Task Completed',
                'Status',
              ],
              data: List.generate(tasks.length, (index) {
                final task = tasks[index];
                String statusText = 'Completed';
                if (task.isDeleted) {
                  statusText = 'Deleted';
                } else if (task.isEdited) {
                  statusText = 'Edited';
                }

                return [
                  (index + 1).toString(),
                  _dateFormat.format(task.completedAt),
                  task.customerName,
                  '${task.userName}\n(${task.userRole.replaceAll('_', ' ')})',
                  task.taskDescription,
                  statusText,
                ];
              }),
            ),
        ],
      ),
    );

    return pdf.save();
  }
}
