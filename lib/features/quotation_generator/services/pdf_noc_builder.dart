// lib/features/quotation_generator/services/pdf_noc_builder.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/qg_noc_builder_state.dart';

class PdfNocBuilder {
  static const PdfColor _navyColor = PdfColor.fromInt(0xFF203764);
  static const PdfColor _blueTitleColor = PdfColor.fromInt(0xFF0070C0);
  static const PdfColor _greenBarColor = PdfColor.fromInt(0xFFB8D786);
  static const PdfColor _linkBlue = PdfColor.fromInt(0xFF0070C0);

  /// Builds the complete NOC PDF certificate matching reference template.
  static Future<Uint8List> buildNocPdf(
    QgNocPayload payload, {
    Uint8List? logoBytes,
    Uint8List? stampBytes,
  }) async {
    final pdf = pw.Document();

    // 1. Resolve Logo Bytes
    Uint8List? finalLogo = logoBytes;
    if (finalLogo == null && payload.logoUrl != null && payload.logoUrl!.isNotEmpty) {
      finalLogo = await _loadImageBytes(payload.logoUrl!);
    }
    finalLogo ??= await _loadImageBytes('assets/images/izyheat_logo.png');

    // 2. Resolve Stamp Bytes
    Uint8List? finalStamp = stampBytes;
    if (finalStamp == null && payload.stampImagePath != null && payload.stampImagePath!.isNotEmpty) {
      finalStamp = await _loadImageBytes(payload.stampImagePath!);
    }
    finalStamp ??= await _loadImageBytes('assets/images/company_stamp.png');

    // 3. Load Fonts if available, otherwise default Helvetica
    pw.Font? regularFont;
    pw.Font? boldFont;
    try {
      final regData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      regularFont = pw.Font.ttf(regData);
      boldFont = pw.Font.ttf(boldData);
    } catch (_) {}

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );

    final isExact = payload.wordingMode == NocWordingMode.templateExact;
    final dateStr = DateFormat('dd/MM/yyyy').format(payload.date);

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 26, 36, 22),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ─── HEADER ────────────────────────────────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Green Bar + Company Details Block
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Green vertical accent bar
                      pw.Container(
                        width: 14,
                        height: 58,
                        decoration: const pw.BoxDecoration(color: _greenBarColor),
                      ),
                      pw.SizedBox(width: 10),
                      // Company text lines
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            payload.companyName,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: _navyColor,
                            ),
                          ),
                          pw.SizedBox(height: 1.5),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'ADDRESS:- ',
                                style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic),
                              ),
                              pw.Container(
                                width: 310,
                                child: pw.Text(
                                  payload.companyAddress,
                                  style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 1),
                          pw.Row(
                            children: [
                              pw.Text(
                                'EMAIL   :- ',
                                style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic),
                              ),
                              pw.Text(
                                payload.companyEmail,
                                style: pw.TextStyle(
                                  fontSize: 7.5,
                                  fontStyle: pw.FontStyle.italic,
                                  color: _linkBlue,
                                  decoration: pw.TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 1),
                          pw.Row(
                            children: [
                              pw.Text(
                                'MOBILE : - ',
                                style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic),
                              ),
                              pw.Text(
                                payload.companyPhone,
                                style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 1),
                          pw.Row(
                            children: [
                              pw.Text(
                                'WEB      :- ',
                                style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic),
                              ),
                              pw.Text(
                                payload.companyWebsite,
                                style: pw.TextStyle(
                                  fontSize: 7.5,
                                  fontStyle: pw.FontStyle.italic,
                                  color: _linkBlue,
                                  decoration: pw.TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Company Logo (Top-Right)
                  if (finalLogo != null)
                    pw.Container(
                      width: 120,
                      height: 52,
                      alignment: pw.Alignment.topRight,
                      child: pw.Image(pw.MemoryImage(finalLogo), fit: pw.BoxFit.contain),
                    ),
                ],
              ),

              pw.SizedBox(height: 14),

              // ─── CENTRED BLUE TITLE ───────────────────────────────────────────
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'NO OBJECTION CERTIFICATE (NOC) FOR ${payload.productName.toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: _blueTitleColor,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 1.5),
                    pw.Text(
                      isExact
                          ? 'SATISFACTORY INSTALLATION & COMMISSION'
                          : 'SATISFACTORY INSTALLATION & COMMISSIONING',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: _blueTitleColor,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // ─── RECIPIENT & DATE ──────────────────────────────────────────────
              if (isExact)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('To,', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('    The Chairman / Secretary / Sir / Madam', style: const pw.TextStyle(fontSize: 9)),
                  ],
                )
              else
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('To,', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text('  The Chairman / Secretary / Sir / Madam', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text('Date: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Text(dateStr, style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                        if (payload.quotationNumber != null) ...[
                          pw.SizedBox(height: 1.5),
                          pw.Text(
                            'Ref. Quotation: ${payload.quotationNumber}',
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                          ),
                        ],
                        if (payload.installationTicketNo != null) ...[
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'Installation Ref.: ${payload.installationTicketNo}',
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

              pw.SizedBox(height: 9),

              // ─── SITE / CONSUMER NAME, ADDRESS, SUBJECT ──────────────────────
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Site / Consumer Name:- ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: '${payload.salutation} ${payload.customerName}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Address: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: payload.address, style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Subject: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: payload.subject, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // ─── SYSTEM DETAILS ───────────────────────────────────────────────
              pw.Text('System Details:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),

              if (!isExact && payload.installationDate != null) ...[
                pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(text: 'Date of Installation & Commissioning: ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.TextSpan(text: DateFormat('dd/MM/yyyy').format(payload.installationDate!), style: const pw.TextStyle(fontSize: 8.5)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 3),
              ],

              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Equipment: ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: payload.equipmentLabel, style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ),
              pw.SizedBox(height: 3.5),

              // Model No & Quantity lines
              ...payload.equipmentLines.map((line) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: '${line.product} Model No:  ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                        pw.TextSpan(text: '${line.model}  & Quantity:  ', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.TextSpan(text: '${line.quantity}  ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                        pw.TextSpan(text: line.uom, style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ),
                );
              }),

              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Work type : ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: payload.workType, style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ),
              pw.SizedBox(height: 3),

              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Wiring: ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: payload.wiring, style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ),
              pw.SizedBox(height: 3),

              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Testing : ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: payload.testing, style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ),
              pw.SizedBox(height: 3),

              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Remark: ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.TextSpan(text: payload.remark, style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // ─── WE CONFIRM THAT ─────────────────────────────────────────────
              pw.Text('We confirm that:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),

              if (isExact) ...[
                pw.Text('1. The installation of the ${payload.productName} is permitted at the above location.', style: const pw.TextStyle(fontSize: 8.5)),
                pw.SizedBox(height: 2),
                pw.Text('3. Necessary precautions has been.', style: const pw.TextStyle(fontSize: 8.5)),
              ] else ...[
                ...payload.confirmations.asMap().entries.map((e) {
                  final idx = e.key + 1;
                  var txt = e.value.trim();
                  // Strip existing leading number if present
                  if (RegExp(r'^\d+\.?\s*').hasMatch(txt)) {
                    txt = txt.replaceFirst(RegExp(r'^\d+\.?\s*'), '');
                  }
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Text('$idx. $txt', style: const pw.TextStyle(fontSize: 8.5)),
                  );
                }),
              ],

              pw.SizedBox(height: 8),

              // ─── CLOSING PARAGRAPH ───────────────────────────────────────────
              pw.Text(
                payload.closingSentence,
                style: const pw.TextStyle(fontSize: 8.5),
              ),
              if (!isExact) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'This certificate is issued in good faith for record purposes and may be produced wherever required.',
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
              ],

              pw.Spacer(),

              // ─── SIGNATURE BLOCK ─────────────────────────────────────────────
              if (isExact) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Customer', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text(payload.companyName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Authorised Signatory', style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 3),
                        pw.Text('Name: ', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.SizedBox(height: 3),
                        pw.Text('Designation: ', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.SizedBox(height: 3),
                        pw.Text('Signature: ', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.SizedBox(height: 3),
                        pw.Text('Seal: ', style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (finalStamp != null)
                          pw.Container(
                            width: 80,
                            height: 72,
                            alignment: pw.Alignment.center,
                            child: pw.Image(pw.MemoryImage(finalStamp), fit: pw.BoxFit.contain),
                          )
                        else
                          pw.SizedBox(height: 60),
                        pw.SizedBox(height: 3),
                        pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Customer / Authorized Signatory
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Customer / Authorized Signatory', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text('Place: ____________', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text('Date:  ____________', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.SizedBox(height: 3),
                        pw.Text('Name: ', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.SizedBox(height: 3),
                        pw.Text('Designation: ', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.SizedBox(height: 3),
                        pw.Text('Signature: ', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.SizedBox(height: 3),
                        pw.Text('Seal: ', style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),

                    // Right: Company Signatory + Stamp
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          payload.companyName,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Authorised Signatory',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                        pw.SizedBox(height: 4),

                        // Stamp Image
                        if (finalStamp != null)
                          pw.Container(
                            width: 80,
                            height: 72,
                            alignment: pw.Alignment.center,
                            child: pw.Image(pw.MemoryImage(finalStamp), fit: pw.BoxFit.contain),
                          )
                        else
                          pw.Container(
                            width: 80,
                            height: 60,
                          ),
                      ],
                    ),
                  ],
                ),
              ],

              pw.SizedBox(height: 6),

              // ─── FOOTER (ENHANCED MODE) ──────────────────────────────────────
              if (!isExact) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.only(top: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${payload.companyName} | Ph: ${payload.companyPhone} | Web: ${payload.companyWebsite}',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Page 1 of 1',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List?> _loadImageBytes(String pathOrUrl) async {
    try {
      if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
        final res = await http.get(Uri.parse(pathOrUrl));
        if (res.statusCode == 200) return res.bodyBytes;
      } else if (pathOrUrl.startsWith('assets/')) {
        final data = await rootBundle.load(pathOrUrl);
        return data.buffer.asUint8List();
      } else {
        final file = File(pathOrUrl);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }
    } catch (_) {}
    return null;
  }
}
