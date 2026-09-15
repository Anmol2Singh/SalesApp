import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/complaint_model.dart';

class ComplaintPdfService {
  static Future<pw.MemoryImage?> _resolveSignatureImage(String? urlOrBase64) async {
    if (urlOrBase64 == null || urlOrBase64.trim().isEmpty) return null;
    try {
      Uint8List? bytes;
      if (urlOrBase64.startsWith('http://') || urlOrBase64.startsWith('https://')) {
        final response = await http.get(Uri.parse(urlOrBase64)).timeout(const Duration(seconds: 5));
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
        final isPng = bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
        final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
        if (isPng || isJpeg) {
          return pw.MemoryImage(bytes);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<Uint8List> generateCompletionReportPdf(Complaint complaint) async {
    final pdf = pw.Document();

    final customerSignatureImage = await _resolveSignatureImage(complaint.customerSignatureUrl);
    final techSignatureImage = await _resolveSignatureImage(complaint.technicianSignatureUrl);

    final List<Map<String, dynamic>> allReplacedItems = [];
    double totalPaidAmount = 0.0;
    bool hasSuccessfulPayment = false;
    bool isCoveredUnderWarranty = complaint.hasActiveAmc;
    String? paymentRef;
    DateTime? paymentDate;

    try {
      final partOrdersRes = await Supabase.instance.client
          .from('complaint_part_orders')
          .select()
          .eq('complaint_id', complaint.id);

      for (final po in (partOrdersRes as List? ?? [])) {
        final rawItems = po['items'] as List?;
        if (rawItems != null) {
          for (final itm in rawItems) {
            if (itm is Map) {
              allReplacedItems.add(Map<String, dynamic>.from(itm));
            }
          }
        }
        if (po['is_warranty'] == true) {
          isCoveredUnderWarranty = true;
        }
        final pStatus = po['payment_status']?.toString().toLowerCase();
        if (pStatus == 'paid') {
          hasSuccessfulPayment = true;
          totalPaidAmount += (po['total_amount'] as num?)?.toDouble() ?? 0.0;
          if (po['payment_reference'] != null) {
            paymentRef = po['payment_reference'].toString();
          }
          if (po['paid_at'] != null) {
            paymentDate = DateTime.tryParse(po['paid_at'].toString());
          }
        }
      }
    } catch (_) {}

    String companyName = 'INSIYA SOLAR INDUSTRY';
    String companyAddress = 'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, MH - 411014';
    String companyPhone = '+91 9292922992';
    String companyEmail = 'insiyasolarindustry@gmail.com';
    String companyGst = '27CFTPS5292A1ZY';
    pw.ImageProvider? logoImage;

    try {
      final tRes = await Supabase.instance.client
          .from('pdf_templates')
          .select('template_config')
          .limit(1)
          .maybeSingle();
      if (tRes != null && tRes['template_config'] is Map) {
        final cfg = Map<String, dynamic>.from(tRes['template_config'] as Map);
        if (cfg['company_name'] != null && cfg['company_name'].toString().trim().isNotEmpty) {
          companyName = cfg['company_name'].toString().trim();
        }
        if (cfg['company_address'] != null && cfg['company_address'].toString().trim().isNotEmpty) {
          companyAddress = cfg['company_address'].toString().trim();
        }
        if (cfg['company_phone'] != null && cfg['company_phone'].toString().trim().isNotEmpty) {
          companyPhone = cfg['company_phone'].toString().trim();
        }
        if (cfg['company_email'] != null && cfg['company_email'].toString().trim().isNotEmpty) {
          companyEmail = cfg['company_email'].toString().trim();
        }
        if (cfg['company_gst'] != null && cfg['company_gst'].toString().trim().isNotEmpty) {
          companyGst = cfg['company_gst'].toString().trim();
        }
        if (cfg['logo_url'] != null && cfg['logo_url'].toString().trim().isNotEmpty) {
          try {
            logoImage = await networkImage(cfg['logo_url'].toString().trim());
          } catch (_) {}
        }
      }
    } catch (_) {}

    String formattedProductName = complaint.productName ?? 'Solar Equipment';
    if (formattedProductName.length > 25 && RegExp(r'^[0-9a-fA-F\-]+$').hasMatch(formattedProductName.trim())) {
      formattedProductName = 'Solar Equipment';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF1E1B4B),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        if (logoImage != null) ...[
                          pw.Container(
                            width: 44,
                            height: 44,
                            margin: const pw.EdgeInsets.only(right: 10),
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          ),
                        ],
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              companyName.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 15,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.Text(
                              companyAddress,
                              style: const pw.TextStyle(
                                fontSize: 7.5,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.Text(
                              'Ph: $companyPhone | Email: $companyEmail | GST: $companyGst',
                              style: const pw.TextStyle(
                                fontSize: 7,
                                color: PdfColors.white,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'SERVICE COMPLETION REPORT',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.amber300,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          complaint.ticketNumber,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          'Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Customer & Product Info Grid
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CUSTOMER & SERVICE DETAILS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Divider(),
                    pw.SizedBox(height: 6),
                    _pdfRow('Customer Name:', complaint.customerName),
                    _pdfRow('Mobile Number:', complaint.customerPhone),
                    _pdfRow('Address:', complaint.customerAddress),
                    _pdfRow('Product Name:', formattedProductName),
                    _pdfRow('Priority Level:', complaint.priority),
                    _pdfRow('Service Status:', 'CLOSED / COMPLETED'),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Issue Description
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('REPORTED ISSUE & RESOLUTION DETAILS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Divider(),
                    pw.SizedBox(height: 6),
                    pw.Text('Category / Fault: ${complaint.title}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.SizedBox(height: 4),
                    pw.Text('Description: ${complaint.description.isNotEmpty ? complaint.description : "Service and repair completed."}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Replaced Parts & Order Items
              if (allReplacedItems.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('REPLACED SPARE PARTS & ORDER ITEMS', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E1B4B))),
                      pw.Divider(),
                      pw.SizedBox(height: 4),
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Item Description', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Unit Price', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                            ],
                          ),
                          ...allReplacedItems.map((item) {
                            final name = item['name']?.toString() ?? 'Part';
                            final qty = item['quantity']?.toString() ?? '1';
                            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                            final total = (item['total'] as num?)?.toDouble() ?? (price * (int.tryParse(qty) ?? 1));
                            return pw.TableRow(
                              children: [
                                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(name, style: const pw.TextStyle(fontSize: 8))),
                                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(qty, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
                                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rs. ${price.toStringAsFixed(0)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rs. ${total.toStringAsFixed(0)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
              ],

              // Payment & Transaction Receipt
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PAYMENT & TRANSACTION STATUS: ${hasSuccessfulPayment ? "PAYMENT SUCCESSFUL" : (isCoveredUnderWarranty ? "COVERED UNDER WARRANTY / AMC (FREE)" : "NO CHARGES")}',
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                        if (paymentRef != null && paymentRef.isNotEmpty)
                          pw.Text('Txn Ref: $paymentRef', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        if (paymentDate != null)
                          pw.Text('Paid Date: ${DateFormat('dd/MM/yyyy HH:mm').format(paymentDate)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Text('Total Paid: Rs. ${totalPaidAmount.toStringAsFixed(0)}',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Technician & Customer Confirmation Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Technician: ${complaint.technicianName ?? "Field Staff"}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      if (techSignatureImage != null)
                        pw.Container(
                          width: 130,
                          height: 50,
                          child: pw.Image(techSignatureImage, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.Container(
                          width: 130,
                          height: 50,
                          alignment: pw.Alignment.center,
                          child: pw.Text('Signed Digitally',
                              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ),
                      pw.Container(
                        width: 130,
                        height: 1,
                        color: PdfColors.grey600,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Technician Signature',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Customer: ${complaint.customerName}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      if (customerSignatureImage != null)
                        pw.Container(
                          width: 130,
                          height: 50,
                          child: pw.Image(customerSignatureImage, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.Container(
                          width: 130,
                          height: 50,
                          alignment: pw.Alignment.center,
                          child: pw.Text('Signed Digitally',
                              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ),
                      pw.Container(
                        width: 130,
                        height: 1,
                        color: PdfColors.grey600,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Customer Signature',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.Text(
                'Thank you for choosing Insiya Solar Industry! For any further assistance, please contact customer care.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 120, child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  static Future<void> shareCompletionReport(Complaint complaint) async {
    final pdfBytes = await generateCompletionReportPdf(complaint);
    final safeTicket = complaint.ticketNumber.replaceAll(RegExp(r'[/\\?%*:|"<>]'), '_');
    final filename = 'CompletionReport_$safeTicket.pdf';
    try {
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (_) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Service Completion Report for ${complaint.ticketNumber}',
      );
    }
  }
}
