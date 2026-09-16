// lib/features/crm/services/crm_pdf_service.dart

import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/models/lead_model.dart';
import '../data/models/prospect_model.dart';
import '../data/models/communication_model.dart';
import '../../../core/services/pdf_service.dart';

class CrmPdfService {
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');
  static final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

  static Future<Uint8List> generateLeadReportPdf({
    required Lead lead,
    Prospect? prospect,
    required List<Communication> communications,
  }) async {
    final pdf = pw.Document();
    final generatedByName = await PdfService.resolveCurrentUserName();

    final displayName = (lead.prospectName != null && lead.prospectName!.isNotEmpty)
        ? lead.prospectName!
        : (prospect?.name ?? 'Lead #${lead.id.substring(0, 6)}');
    final displayPhone = (lead.contactPhone != null && lead.contactPhone!.isNotEmpty)
        ? lead.contactPhone!
        : (prospect?.phone ?? 'N/A');
    final displayEmail = prospect?.email ?? 'N/A';
    final displayAddress = prospect?.address ?? 'N/A';
    final displayGst = prospect?.gst ?? 'N/A';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF1E3A5F), width: 1.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'INSIYA SOLAR INDUSTRY',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF1E3A5F),
                    ),
                  ),
                  pw.Text(
                    'IZYHEAT CRM • Lead & Interaction Record',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Generated on: ${_dateFormat.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Status: ${lead.status.toUpperCase()}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: lead.status == 'Won'
                          ? PdfColors.green800
                          : (lead.status == 'Lost' ? PdfColors.red800 : const PdfColor.fromInt(0xFF1E3A5F)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 16),

            // 1. Prospect & Deal Summary Grid
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF8FAFC),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'OPPORTUNITY & CONTACT DETAILS',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF1E3A5F),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Prospect Name:', displayName),
                            _buildInfoRow('Phone Number:', displayPhone),
                            _buildInfoRow('Email Address:', displayEmail),
                            _buildInfoRow('GST Number:', displayGst),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Product Name:', lead.productName),
                            _buildInfoRow('Estimated Value:', _currencyFormat.format(lead.estimatedValue)),
                            _buildInfoRow(
                              'Expected Date:',
                              lead.expectedDate != null ? _dateFormat.format(lead.expectedDate!) : 'Not Specified',
                            ),
                            _buildInfoRow('Lead Created:', _dateFormat.format(lead.createdAt)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (displayAddress != 'N/A') ...[
                    pw.SizedBox(height: 4),
                    _buildInfoRow('Address:', displayAddress),
                  ],
                  if (lead.notes != null && lead.notes!.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    _buildInfoRow('Requirements:', lead.notes!),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // 2. Communication History Section
            pw.Text(
              'COMMUNICATION & INTERACTION TIMELINE (${communications.length} Logs)',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF1E3A5F),
              ),
            ),
            pw.SizedBox(height: 8),

            if (communications.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text('No communications logged for this lead.', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF1E3A5F),
                ),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                headers: ['#', 'Date & Time', 'Type', 'Interaction Summary / Outcome'],
                columnWidths: {
                  0: const pw.FixedColumnWidth(25),
                  1: const pw.FixedColumnWidth(110),
                  2: const pw.FixedColumnWidth(70),
                  3: const pw.FlexColumnWidth(3),
                },
                data: List.generate(communications.length, (index) {
                  final c = communications[index];
                  return [
                    '${index + 1}',
                    _dateTimeFormat.format(c.createdAt),
                    c.type,
                    c.summary,
                  ];
                }),
              ),

            pw.SizedBox(height: 24),
            pw.Divider(color: const PdfColor.fromInt(0xFFE2E8F0)),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Insiya Solar Industry - Confidential Document', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Generated by: $generatedByName', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text('Page 1 of 1', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 85,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }
}
