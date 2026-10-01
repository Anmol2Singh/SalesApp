import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../data/models/installation_model.dart';
import '../../../core/services/pdf_service.dart';

class InstallationPdfService {
  static Future<pw.MemoryImage?> _resolveImage(String? urlOrBase64) async {
    if (urlOrBase64 == null || urlOrBase64.trim().isEmpty) return null;
    try {
      Uint8List? bytes;
      if (urlOrBase64.startsWith('http://') || urlOrBase64.startsWith('https://')) {
        final response = await http
            .get(Uri.parse(urlOrBase64))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          bytes = response.bodyBytes;
        }
      } else if (urlOrBase64.contains('base64,')) {
        final base64Str = urlOrBase64.split('base64,').last;
        bytes = base64Decode(base64Str);
      } else {
        bytes = base64Decode(urlOrBase64);
      }

      if (bytes != null && bytes.length > 8) {
        final isPng = bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47;
        final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
        if (isPng || isJpeg) {
          return pw.MemoryImage(bytes);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<Uint8List> generateCompletionReportPdf(Installation installation) async {
    final pdf = pw.Document();
    final generatedByName = await PdfService.resolveCurrentUserName();

    final resolvedConfig = await PdfService.resolveTemplateConfig(null);
    final companyName = resolvedConfig['company_name'] as String? ?? 'INSIYA SOLAR INDUSTRY';
    final companyAddress = resolvedConfig['company_address'] as String? ?? 'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra - 411014';
    final companyPhone = resolvedConfig['company_phone'] as String? ?? '+91 9292922992';
    final companyEmail = resolvedConfig['company_email'] as String? ?? 'insiyasolarindustry@gmail.com';
    final logoUrl = resolvedConfig['logo_url'] as String?;
    final pw.MemoryImage? logoImage = await _resolveImage(logoUrl);

    final customerSignatureImage = await _resolveImage(installation.customerSignatureUrl);
    final techSignatureImage = await _resolveImage(installation.technicianSignatureUrl);

    // Photos
    pw.MemoryImage? beforeImage;
    if (installation.beforeImageUrl != null && installation.beforeImageUrl!.isNotEmpty) {
      final firstBefore = installation.beforeImageUrl!.split('|||').firstWhere((u) => u.trim().isNotEmpty, orElse: () => '');
      if (firstBefore.isNotEmpty) {
        beforeImage = await _resolveImage(firstBefore);
      }
    }

    pw.MemoryImage? afterImage;
    if (installation.afterImageUrl != null && installation.afterImageUrl!.isNotEmpty) {
      final firstAfter = installation.afterImageUrl!.split('|||').firstWhere((u) => u.trim().isNotEmpty, orElse: () => '');
      if (firstAfter.isNotEmpty) {
        afterImage = await _resolveImage(firstAfter);
      }
    }

    pw.ThemeData pdfTheme;
    try {
      pdfTheme = pw.ThemeData.withFont(
        base: await PdfGoogleFonts.interRegular(),
        bold: await PdfGoogleFonts.interBold(),
      );
    } catch (_) {
      pdfTheme = pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pdfTheme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        ),
        build: (context) {
          return [
            // Company Header
            pw.Row(
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
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      pw.Text('Phone: $companyPhone | Email: $companyEmail', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                if (logoImage != null)
                  pw.Container(
                    height: 45,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1.2, color: PdfColors.blue900),
            pw.SizedBox(height: 8),

            // Report Title Banner
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'INSTALLATION COMPLETION REPORT',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  pw.Text(
                    'Ticket: ${installation.ticketNumber}',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Details Section
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left Column: Customer & Site Info
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CUSTOMER & SITE DETAILS',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        _pdfRow('Customer Name:', installation.customerName),
                        _pdfRow('Phone:', installation.customerPhone.isNotEmpty ? installation.customerPhone : 'N/A'),
                        _pdfRow('Address:', installation.customerAddress.isNotEmpty ? installation.customerAddress : 'N/A'),
                        if (installation.hasActiveAmc)
                          _pdfRow('AMC Status:', 'Active (Expires: ${installation.amcExpiry})'),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                // Right Column: Installation Summary
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'INSTALLATION DETAILS',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        _pdfRow('Created Date:', DateFormat('dd MMM yyyy, hh:mm a').format(installation.createdAt)),
                        _pdfRow('Product:', installation.productName ?? 'Solar Installation System'),
                        _pdfRow('Priority:', installation.priority),
                        _pdfRow('Status:', installation.status.toUpperCase()),
                        if (installation.technicianName != null)
                          _pdfRow('Technician:', installation.technicianName!),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Installation Description & Notes Card
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SCOPE OF WORK & DESCRIPTION',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    installation.title,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    installation.description.isNotEmpty ? installation.description : 'Standard system installation completed as per technical specifications.',
                    style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800),
                  ),
                  if (installation.notes != null && installation.notes!.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text('Notes / Observations: ${installation.notes!}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                  if (installation.sealNumberBefore != null || installation.sealNumberAfter != null) ...[
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        if (installation.sealNumberBefore != null)
                          pw.Expanded(child: _pdfRow('Seal # Before:', installation.sealNumberBefore!)),
                        if (installation.sealNumberAfter != null)
                          pw.Expanded(child: _pdfRow('Seal # After:', installation.sealNumberAfter!)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Site Photos Section (if available)
            if (beforeImage != null || afterImage != null) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SITE VERIFICATION PHOTOS',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                      children: [
                        if (beforeImage != null)
                          pw.Column(
                            children: [
                              pw.Container(
                                width: 200,
                                height: 110,
                                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                                child: pw.Image(beforeImage, fit: pw.BoxFit.contain),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text('Before Installation', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                            ],
                          ),
                        if (afterImage != null)
                          pw.Column(
                            children: [
                              pw.Container(
                                width: 200,
                                height: 110,
                                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                                child: pw.Image(afterImage, fit: pw.BoxFit.contain),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text('After Installation (Commissioned)', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
            ],

            // Signatures Section
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SIGN-OFF & DIGITAL CONFIRMATION',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // Technician Signature
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'Technician: ${installation.technicianName ?? "Field Engineer"}',
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 4),
                          if (techSignatureImage != null)
                            pw.Container(
                              width: 140,
                              height: 45,
                              child: pw.Image(techSignatureImage, fit: pw.BoxFit.contain),
                            )
                          else
                            pw.Container(
                              width: 140,
                              height: 45,
                              alignment: pw.Alignment.center,
                              child: pw.Text('Digitally Certified', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
                            ),
                          pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                          pw.SizedBox(height: 2),
                          pw.Text('Technician Signature', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                        ],
                      ),
                      // Customer Signature
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'Customer: ${installation.customerName}',
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 4),
                          if (customerSignatureImage != null)
                            pw.Container(
                              width: 140,
                              height: 45,
                              child: pw.Image(customerSignatureImage, fit: pw.BoxFit.contain),
                            )
                          else
                            pw.Container(
                              width: 140,
                              height: 45,
                              alignment: pw.Alignment.center,
                              child: pw.Text('Digitally Certified', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
                            ),
                          pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                          pw.SizedBox(height: 2),
                          pw.Text('Customer Signature', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Footer note
            pw.Divider(thickness: 0.8),
            pw.Text(
              'This is a system generated installation completion certificate verified via digital customer acceptance.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(companyName, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                pw.Text('Generated by: $generatedByName', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text('Page 1 of 1', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 95,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> shareCompletionReport(Installation installation) async {
    final pdfBytes = await generateCompletionReportPdf(installation);
    final safeTicket = installation.ticketNumber.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '_');
    final filename = 'InstallationReport_$safeTicket.pdf';
    try {
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (_) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Installation Report for ${installation.ticketNumber}',
      );
    }
  }
}
