// lib/core/services/pdf_service.dart
// Client-side PDF generation using the `pdf` package

import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/quotation.dart';
import '../models/boq.dart';
import '../models/factory_order.dart';
import '../models/purchase_order.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/sales_order.dart';
import '../models/amc_contract.dart';
import '../models/warranty_card.dart';
import '../models/service_visit.dart';
import '../../features/reports/models/activity_report_data.dart';
import 'package:flutter/material.dart' show BuildContext;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PdfService {
  static Future<Map<String, dynamic>> resolveTemplateConfig(Map<String, dynamic>? initialConfig) async {
    final Map<String, dynamic> resolved = {
      'company_name': 'INSIYA SOLAR INDUSTRY',
      'company_address': 'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra - 411014',
      'company_phone': '+91 9292922992',
      'company_email': 'insiyasolarindustry@gmail.com',
      'company_gst': '27CFTPS5292A1ZY',
      'footer_text': 'Thank you for your business.',
    };

    try {
      final res = await Supabase.instance.client
          .from('pdf_templates')
          .select('template_config')
          .limit(1)
          .maybeSingle();
      if (res != null && res['template_config'] is Map) {
        final dbCfg = Map<String, dynamic>.from(res['template_config'] as Map);
        dbCfg.forEach((key, value) {
          if (value != null && value.toString().trim().isNotEmpty) {
            resolved[key] = value;
          }
        });
      }
    } catch (_) {}

    if (initialConfig != null) {
      initialConfig.forEach((key, value) {
        if (value != null &&
            value.toString().trim().isNotEmpty &&
            value.toString() != 'IZYHEAT' &&
            value.toString() != 'IZYHEAT Office, India' &&
            value.toString() != 'info@izyheat.com') {
          resolved[key] = value;
        }
      });
    }

    return resolved;
  }

  static Future<pw.ImageProvider?> _fetchLogo(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      return await networkImage(url);
    } catch (_) {}
    return null;
  }

  static final _currencyFormat = NumberFormat('#,##,##0.00', 'en_IN');
  static const _rupee = 'Rs. ';

  static String _cleanText(String? text) {
    if (text == null) return '';
    return text.replaceAll('₹', 'Rs. ');
  }

  static Future<String> resolveCurrentUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final staffName = prefs.getString('staff_session_name') ??
          prefs.getString('technician_session_name');
      if (staffName != null && staffName.trim().isNotEmpty) {
        return staffName.trim();
      }

      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        final cached = prefs.getString('cached_profile_name_${currentUser.id}');
        if (cached != null && cached.trim().isNotEmpty) return cached.trim();

        final metaName = currentUser.userMetadata?['full_name'] as String? ??
            currentUser.userMetadata?['name'] as String?;
        if (metaName != null && metaName.trim().isNotEmpty) return metaName.trim();

        try {
          final res = await supabase
              .from('profiles')
              .select('full_name')
              .eq('id', currentUser.id)
              .maybeSingle();
          if (res != null &&
              res['full_name'] != null &&
              res['full_name'].toString().trim().isNotEmpty) {
            return res['full_name'].toString().trim();
          }
        } catch (_) {}

        if (currentUser.email != null && currentUser.email!.isNotEmpty) {
          return currentUser.email!.split('@').first;
        }
      }

      final custName = prefs.getString('customer_session_name');
      if (custName != null && custName.trim().isNotEmpty) return custName.trim();
    } catch (_) {}
    return 'Staff';
  }

  // ─── QUOTATION PDF ───────────────────────────────────────────────────────────

  static Future<Uint8List> generateQuotationPdf({
    required Quotation quotation,
    required Customer customer,
    required Product product,
    required Map<String, dynamic> templateConfig,
    String copyType = 'Original For Recipient',
    String docTitle = 'QUOTATION',
  }) async {
    final resolvedConfig = await resolveTemplateConfig(templateConfig);
    final logoUrl = resolvedConfig['logo_url'] as String?;
    final logoImage = await _fetchLogo(logoUrl);
    final generatedByName = await resolveCurrentUserName();

    final pdf = pw.Document();

    final companyName = resolvedConfig['company_name'] as String? ?? 'INSIYA SOLAR INDUSTRY';
    final companyAddress = resolvedConfig['company_address'] as String? ?? 'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra - 411014';
    final companyPhone = resolvedConfig['company_phone'] as String? ?? '+91 9292922992';
    final companyEmail = resolvedConfig['company_email'] as String? ?? 'insiyasolarindustry@gmail.com';
    final companyGst = resolvedConfig['company_gst'] as String? ?? '27CFTPS5292A1ZY';
    final companyStateCode = 27; // Maharashtra

    final bool isInterstate = quotation.stateCode != null && quotation.stateCode != companyStateCode;
    final bool isInvoice = docTitle.toUpperCase().contains('INVOICE');

    final pw.ThemeData theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _buildHeader(
          companyName: companyName,
          companyAddress: companyAddress,
          companyPhone: companyPhone,
          companyEmail: companyEmail,
          companyGst: companyGst,
          docTitle: docTitle,
          docNumber: isInvoice ? quotation.quotationNumber.replaceAll('QT', 'INV') : quotation.quotationNumber,
          docDate: quotation.orderDate ?? quotation.createdAt,
          status: quotation.status.displayName,
          logoImage: logoImage,
        ),
        footer: (context) => _buildFooter(
          resolvedConfig['footer_text'] as String? ?? 'Thank you for your business.',
          context.pageNumber,
          context.pagesCount,
          generatedBy: generatedByName,
        ),
        build: (context) {
          final totalQty = quotation.lineItems.fold<double>(0, (sum, item) => sum + item.qty);
          final totalAmount = quotation.lineItems.fold<double>(0, (sum, item) => sum + item.total);

          final taxRate = (quotation.cgstRate + quotation.sgstRate);
          final taxableValue = quotation.subtotal;
          
          final cgstAmt = isInterstate ? 0.0 : quotation.cgstAmount;
          final sgstAmt = isInterstate ? 0.0 : quotation.sgstAmount;
          final igstAmt = isInterstate ? quotation.igstAmount : 0.0;
          final totalTax = cgstAmt + sgstAmt + igstAmt;

          return [
            // Metadata Grid (2 columns)
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _metaItem(isInvoice ? 'Invoice No.' : 'Quotation No.', isInvoice ? quotation.quotationNumber.replaceAll('QT', 'INV') : quotation.quotationNumber),
                        _metaItem('Eway Bill No & Date', ''),
                        _metaItem('Bill Type', quotation.billType ?? 'Credit'),
                        _metaItem('Place of Supply', quotation.placeOfSupply ?? 'Maharashtra'),
                        _metaItem('Payment Term', 'Credit'),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _metaItem(isInvoice ? 'Invoice Date' : 'Quotation Date', quotation.orderDate != null ? DateFormat('dd/MM/yyyy').format(quotation.orderDate!) : DateFormat('dd/MM/yyyy').format(quotation.createdAt)),
                        _metaItem('Vehicle No', ''),
                        _metaItem('Distance', quotation.distance != null ? '${quotation.distance!.toStringAsFixed(0)} KM' : null),
                        _metaItem('GR/LR No.', quotation.grLrNo),
                        _metaItem('Destination', quotation.destination),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Billing & Shipping Address Section
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Customer Name & Billing Address', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E3A5F))),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Shipping Address', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E3A5F))),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(quotation.customerName ?? customer.companyName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text(quotation.billingAddress ?? customer.address ?? '', style: const pw.TextStyle(fontSize: 8)),
                          pw.SizedBox(height: 3),
                          pw.Text('Phone : ${quotation.customerPhone ?? customer.phone ?? "-"}', style: const pw.TextStyle(fontSize: 8)),
                          if (customer.gstNumber != null && customer.gstNumber!.isNotEmpty)
                            pw.Text('GSTIN : ${customer.gstNumber}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          if (quotation.partyContactPerson != null && quotation.partyContactPerson!.isNotEmpty)
                            pw.Text('Party Contact Person : ${quotation.partyContactPerson}', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(quotation.shippingName ?? customer.companyName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text(quotation.shippingAddress ?? customer.address ?? '', style: const pw.TextStyle(fontSize: 8)),
                          pw.SizedBox(height: 3),
                          pw.Text('State Code : ${quotation.stateCode ?? 27}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          if (quotation.salesman != null && quotation.salesman!.isNotEmpty)
                            pw.Text('Salesman : ${quotation.salesman}', style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Line Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(25), // S No
                1: const pw.FlexColumnWidth(3),   // Description
                2: const pw.FixedColumnWidth(55),  // HSN/SAC
                3: const pw.FixedColumnWidth(35),  // Qty
                4: const pw.FixedColumnWidth(40),  // GST %
                5: const pw.FixedColumnWidth(35),  // UOM
                6: const pw.FixedColumnWidth(55),  // Item Rate
                7: const pw.FixedColumnWidth(35),  // Disc %
                8: const pw.FixedColumnWidth(65),  // Amount
              },
              children: [
                // Header Row with dark blue background #1E3A5F and white text
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E3A5F)),
                  children: [
                    'S\nNo', 'Description', 'HSN / SAC', 'Qty', 'GST\n%', 'UOM', 'Item Rate', 'Disc %', 'Amount\n(INR)'
                  ].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: h == 'Description' ? pw.TextAlign.left : pw.TextAlign.center),
                  )).toList(),
                ),
                // Line Items Rows
                ...quotation.lineItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${idx + 1}', style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.center)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.description, style: const pw.TextStyle(fontSize: 7.5))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.hsnSac ?? '', style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.center)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.qty.toInt().toString(), style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.right)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${item.gstPercent.toStringAsFixed(0)}%', style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.right)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.uom, style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.center)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_currencyFormat.format(item.unitPrice), style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.right)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${item.discPercent.toStringAsFixed(2)}%', style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.right)),
                            pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_currencyFormat.format(item.total), style: const pw.TextStyle(fontSize: 7.5), textAlign: pw.TextAlign.right)),
                          ],
                        );
                      }),
                      // Totals Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Total', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(totalQty.toInt().toString(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_currencyFormat.format(totalAmount), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                        ],
                      ),
                    ],
                  ),
                  pw.Divider(color: PdfColors.black, height: 1, thickness: 0.8),

                  // Bottom Grid: Tax Summary vs Order Summary
                  pw.Table(
                    border: const pw.TableBorder(
                      verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    ),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        children: [
                          // Left Box: Tax summary table & amount in words
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                // Tax summary table
                                pw.Table(
                                  border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                                  children: [
                                    pw.TableRow(
                                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                                      children: [
                                        'Tax Rate', 'Taxable Value', 'CGST Amount', 'SGST Amount', 'IGST Amount', 'Total Tax'
                                      ].map((h) => pw.Padding(
                                        padding: const pw.EdgeInsets.all(3),
                                        child: pw.Text(h, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                                      )).toList(),
                                    ),
                                    pw.TableRow(
                                      children: [
                                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('TAX @ ${taxRate.toStringAsFixed(0)}%', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
                                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_currencyFormat.format(taxableValue), style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
                                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_currencyFormat.format(cgstAmt), style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
                                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_currencyFormat.format(sgstAmt), style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
                                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_currencyFormat.format(igstAmt), style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
                                        pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_currencyFormat.format(totalTax), style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
                                      ],
                                    ),
                                  ],
                                ),
                                pw.SizedBox(height: 8),
                                // Tax and Bill amount in words
                                pw.Text('Tax Amount : ${numberToIndianWords(totalTax)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                pw.Text('Bill Amount : ${numberToIndianWords(quotation.grandTotal)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 6),
                                pw.Text('Remark : ${quotation.remarks ?? "Being Quotation Generated"}', style: const pw.TextStyle(fontSize: 7.5)),
                              ],
                            ),
                          ),
                          // Right Box: Order Summary Box
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _totalSummaryRow('Sub Total', quotation.subtotal),
                                _totalSummaryRow('Taxable Amount', quotation.subtotal),
                                if (!isInterstate) ...[
                                  _totalSummaryRow('CGST', cgstAmt),
                                  _totalSummaryRow('SGST/UTGST', sgstAmt),
                                ] else ...[
                                  _totalSummaryRow('IGST', igstAmt),
                                ],
                                pw.Divider(color: PdfColors.black, thickness: 0.5),
                                _totalSummaryRow('Quotation Total', quotation.grandTotal, bold: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Divider(color: PdfColors.black, height: 1, thickness: 0.8),

                  // Declaration & terms and conditions
                  pw.Table(
                    border: const pw.TableBorder(
                      verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    ),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        children: [
                          // Declaration & Terms (Left)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Declaration:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                                pw.Text(
                                  'We declare that this invoice shows the actual price of the goods/services described and that all particulars are true and correct.',
                                  style: const pw.TextStyle(fontSize: 7),
                                ),
                                if (quotation.paymentTerms != null && quotation.paymentTerms!.isNotEmpty) ...[
                                  pw.SizedBox(height: 6),
                                  pw.Text('Payment Terms:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                                  pw.SizedBox(height: 3),
                                  pw.Table(
                                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                                    children: [
                                      pw.TableRow(
                                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                                        children: [
                                          pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Term / Stage', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold))),
                                          pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Percentage', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                                          pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('Amount (Rs.)', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                                        ],
                                      ),
                                      ...quotation.paymentTerms!.map((term) {
                                        final name = term['term']?.toString() ?? '';
                                        final pct = term['percent']?.toString() ?? '0';
                                        final amt = (term['amount'] as num?)?.toDouble() ?? 0.0;
                                        return pw.TableRow(
                                          children: [
                                            pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(name, style: const pw.TextStyle(fontSize: 6.5))),
                                            pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('$pct%', style: const pw.TextStyle(fontSize: 6.5), textAlign: pw.TextAlign.center)),
                                            pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(_currencyFormat.format(amt), style: const pw.TextStyle(fontSize: 6.5), textAlign: pw.TextAlign.right)),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                                if (quotation.termsText != null && quotation.termsText!.isNotEmpty) ...[
                                  pw.SizedBox(height: 6),
                                  pw.Text('Terms and Conditions:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                                  pw.Text(quotation.termsText!, style: const pw.TextStyle(fontSize: 7)),
                                ],
                              ],
                            ),
                          ),
                          // Signatures (Right)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Align(
                                  alignment: pw.Alignment.topRight,
                                  child: pw.Text('For ${companyName.toUpperCase()}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                ),
                                pw.SizedBox(height: 25),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Column(
                                      children: [
                                        pw.Container(width: 80, height: 0.5, color: PdfColors.black),
                                        pw.SizedBox(height: 2),
                                        pw.Text("Receiver's Signature", style: const pw.TextStyle(fontSize: 7.5)),
                                      ],
                                    ),
                                    pw.Column(
                                      children: [
                                        pw.Container(width: 80, height: 0.5, color: PdfColors.black),
                                        pw.SizedBox(height: 2),
                                        pw.Text('Authorised Signatory', style: const pw.TextStyle(fontSize: 7.5)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ];
              },
            ),
          );

          return pdf.save();
        }

  static pw.Widget _metaItem(String label, String? value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 100, child: pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
          pw.Text(' : ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(child: pw.Text(value ?? '', style: const pw.TextStyle(fontSize: 8))),
        ],
      ),
    );
  }

  static pw.Widget _totalSummaryRow(String label, double amount, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : null)),
          pw.Text('$_rupee${_currencyFormat.format(amount)}', style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : null)),
        ],
      ),
    );
  }

  // ─── BOQ PDF ─────────────────────────────────────────────────────────────────

  static Future<Uint8List> generateBoqPdf({
    required Boq boq,
    required Customer customer,
    required Product product,
    required Quotation quotation,
    required Map<String, dynamic> templateConfig,
    String scopeFilter = 'all', // 'all', 'company', 'customer'
  }) async {
    final resolvedConfig = await resolveTemplateConfig(templateConfig);
    final logoUrl = resolvedConfig['logo_url'] as String?;
    final logoImage = await _fetchLogo(logoUrl);
    final generatedByName = await resolveCurrentUserName();

    final pdf = pw.Document();

    String docTitle = 'BILL OF QUANTITIES';
    if (scopeFilter == 'company') {
      docTitle = 'BILL OF QUANTITIES (COMPANY SCOPE)';
    } else if (scopeFilter == 'customer') {
      docTitle = 'BILL OF QUANTITIES (CUSTOMER SCOPE)';
    }

    final companyItems = boq.items.where((i) => i.scope == 'company').toList();
    final customerItems = boq.items.where((i) => i.scope == 'customer').toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _buildHeader(
          companyName: resolvedConfig['company_name'] as String? ?? 'INSIYA SOLAR INDUSTRY',
          companyAddress: resolvedConfig['company_address'] as String? ?? '',
          companyPhone: resolvedConfig['company_phone'] as String? ?? '',
          companyEmail: resolvedConfig['company_email'] as String? ?? '',
          companyGst: resolvedConfig['company_gst'] as String? ?? '',
          docTitle: docTitle,
          docNumber: boq.boqNumber,
          docDate: boq.createdAt,
          status: boq.status.displayName,
          logoImage: logoImage,
        ),
        footer: (context) => _buildFooter(
          resolvedConfig['footer_text'] as String? ?? 'Thank you for your business.',
          context.pageNumber,
          context.pagesCount,
          generatedBy: generatedByName,
        ),
        build: (context) {
          final quotationItemNames = quotation.lineItems.map((li) => li.description).where((d) => d.isNotEmpty).join(', ');
          final displayProductName = quotationItemNames.isNotEmpty ? quotationItemNames : product.name;

          return [
            _buildBillTo(customer),
            pw.SizedBox(height: 10),
            // Product Title Banner
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF1E3A5F),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                'BOQ for product: ${_cleanText(displayProductName)}',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            // Reference to quotation
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                'Reference Quotation: ${quotation.quotationNumber}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.blue800),
              ),
            ),
            pw.SizedBox(height: 16),
            // BOQ items table (Filtered by scope)
            if (scopeFilter == 'all' || scopeFilter == 'company') ...[
              _buildSectionTitle('Company Scope'),
              pw.SizedBox(height: 8),
              _buildBoqItemsTable(companyItems),
              pw.SizedBox(height: 16),
            ],
            if (scopeFilter == 'all' || scopeFilter == 'customer') ...[
              _buildSectionTitle('Customer Scope'),
              pw.SizedBox(height: 8),
              _buildBoqItemsTable(customerItems),
              pw.SizedBox(height: 16),
            ],
            if (boq.remarks != null && boq.remarks!.trim().isNotEmpty) ...[
              _buildSectionTitle('Remarks / Notes'),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Text(
                  _cleanText(boq.remarks!),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ─── FACTORY ORDER PDF ───────────────────────────────────────────────────────

  static Future<Uint8List> generateFactoryOrderPdf({
    required FactoryOrder factoryOrder,
    required Customer customer,
    required Product product,
    required Map<String, dynamic> templateConfig,
  }) async {
    final resolvedConfig = await resolveTemplateConfig(templateConfig);
    final logoUrl = resolvedConfig['logo_url'] as String?;
    final logoImage = await _fetchLogo(logoUrl);
    final generatedByName = await resolveCurrentUserName();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(
              companyName:
                  resolvedConfig['company_name'] as String? ?? 'INSIYA SOLAR INDUSTRY',
              companyAddress:
                  resolvedConfig['company_address'] as String? ?? '',
              companyPhone: resolvedConfig['company_phone'] as String? ?? '',
              companyEmail: resolvedConfig['company_email'] as String? ?? '',
              companyGst: '',
              docTitle: 'FACTORY ORDER',
              docNumber: factoryOrder.orderNumber,
              docDate: factoryOrder.createdAt,
              status: factoryOrder.status.displayName,
          logoImage: logoImage,
            ),
            pw.SizedBox(height: 20),
            // Customer & product info
            pw.Row(
              children: [
                pw.Expanded(
                  child: _infoBlock('Customer', customer.companyName),
                ),
                pw.Expanded(
                  child: _infoBlock('Product', product.name),
                ),
              ],
            ),
            if (factoryOrder.expectedCompletionDate != null) ...[
              pw.SizedBox(height: 8),
              _infoBlock(
                'Expected Completion',
                DateFormat('dd MMM yyyy')
                    .format(factoryOrder.expectedCompletionDate!),
              ),
            ],
            if (factoryOrder.productionSpecs.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _buildSectionTitle('Production Specifications'),
              pw.SizedBox(height: 8),
              _buildExtraFieldsTable(factoryOrder.productionSpecs, product),
            ],
            if (factoryOrder.factoryNotes != null &&
                factoryOrder.factoryNotes!.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              _buildSectionTitle('Notes'),
              pw.SizedBox(height: 8),
              pw.Text(
                _cleanText(factoryOrder.factoryNotes),
                style: pw.TextStyle(fontSize: 10),
              ),
            ],
            if (factoryOrder.items.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              _buildSectionTitle('Items to Manufacture'),
              pw.SizedBox(height: 8),
              _buildFactoryItemsTable(factoryOrder.items),
            ],
            pw.Spacer(),
            _buildFooter(
              resolvedConfig['footer_text'] as String? ?? 'Thank you for your business.',
              1,
              1,
              generatedBy: generatedByName,
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // ─── PURCHASE ORDER PDF ──────────────────────────────────────────────────────

  static Future<Uint8List> generatePurchaseOrderPdf({
    required PurchaseOrder purchaseOrder,
    required Customer customer,
    required Product product,
    required Map<String, dynamic> templateConfig,
  }) async {
    final resolvedConfig = await resolveTemplateConfig(templateConfig);
    final logoUrl = resolvedConfig['logo_url'] as String?;
    final logoImage = await _fetchLogo(logoUrl);
    final generatedByName = await resolveCurrentUserName();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _buildHeader(
          companyName: resolvedConfig['company_name'] as String? ?? 'INSIYA SOLAR INDUSTRY',
          companyAddress: resolvedConfig['company_address'] as String? ?? '',
          companyPhone: resolvedConfig['company_phone'] as String? ?? '',
          companyEmail: resolvedConfig['company_email'] as String? ?? '',
          companyGst: resolvedConfig['company_gst'] as String? ?? '',
          docTitle: 'MATERIAL REQUISITION',
          docNumber: purchaseOrder.poNumber,
          docDate: purchaseOrder.createdAt,
          status: purchaseOrder.status.displayName,
          logoImage: logoImage,
        ),
        footer: (context) => _buildFooter(
          resolvedConfig['footer_text'] as String? ?? 'Thank you for your business.',
          context.pageNumber,
          context.pagesCount,
          generatedBy: generatedByName,
        ),
        build: (context) => [
          // Vendor details
          _buildSectionTitle('Vendor Details'),
          pw.SizedBox(height: 8),
          _buildVendorBlock(purchaseOrder.vendorDetails),
          pw.SizedBox(height: 16),
          // Items table
          _buildSectionTitle('Items'),
          pw.SizedBox(height: 8),
          _buildPoItemsTable(purchaseOrder.items),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  'Total Qty: ${purchaseOrder.items.fold<num>(0, (sum, it) => sum + it.qty).toInt()}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF1E3A5F),
                  ),
                ),
              ),
            ],
          ),
          if (purchaseOrder.purchaseNotes != null) ...[
            pw.SizedBox(height: 16),
            _buildSectionTitle('Notes'),
            pw.SizedBox(height: 8),
            pw.Text(
              _cleanText(purchaseOrder.purchaseNotes),
              style: pw.TextStyle(fontSize: 10),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  // ─── SHARED HELPERS ──────────────────────────────────────────────────────────

  static pw.Widget _buildHeader({
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    required String companyEmail,
    required String companyGst,
    required String docTitle,
    required String docNumber,
    required DateTime docDate,
    required String status,
    pw.ImageProvider? logoImage,
  }) {
    final cleanCompanyName = _cleanText(companyName);
    final cleanCompanyAddress = _cleanText(companyAddress);
    final cleanCompanyPhone = _cleanText(companyPhone);
    final cleanCompanyEmail = _cleanText(companyEmail);
    final cleanCompanyGst = _cleanText(companyGst);
    final cleanDocTitle = _cleanText(docTitle);
    final cleanDocNumber = _cleanText(docNumber);
    final cleanStatus = _cleanText(status);

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Company info
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null) ...[
                    pw.Image(logoImage, width: 60, height: 60, fit: pw.BoxFit.contain),
                    pw.SizedBox(width: 12),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          cleanCompanyName,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF1E3A5F),
                    ),
                  ),
                  if (cleanCompanyAddress.isNotEmpty)
                    pw.Text(cleanCompanyAddress,
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                  if (cleanCompanyPhone.isNotEmpty)
                    pw.Text(cleanCompanyPhone,
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                  if (cleanCompanyEmail.isNotEmpty)
                    pw.Text(cleanCompanyEmail,
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                  if (cleanCompanyGst.isNotEmpty)
                    pw.Text(cleanCompanyGst,
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Document info
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF1E3A5F),
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    cleanDocTitle,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(cleanDocNumber,
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  DateFormat('dd MMM yyyy').format(docDate),
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
                pw.Container(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color:
                        cleanStatus == 'Confirmed' || cleanStatus == 'Submitted'
                            ? PdfColors.green100
                            : PdfColors.orange100,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Text(
                    cleanStatus,
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: cleanStatus == 'Confirmed' ||
                              cleanStatus == 'Submitted'
                          ? PdfColors.green800
                          : PdfColors.orange800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 1.5, color: const PdfColor.fromInt(0xFF1E3A5F)),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _buildBillTo(Customer customer) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'BILL TO',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(_cleanText(customer.companyName),
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        if (customer.contactPerson != null)
          pw.Text(_cleanText(customer.contactPerson!),
              style: const pw.TextStyle(fontSize: 10)),
        if (customer.phone != null)
          pw.Text(_cleanText(customer.phone!),
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        if (customer.email != null)
          pw.Text(_cleanText(customer.email!),
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        if (customer.address != null)
          pw.Text(_cleanText(customer.address!),
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        if (customer.gstNumber != null)
          pw.Text('GSTIN: ${_cleanText(customer.gstNumber)}',
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      _cleanText(title),
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: const PdfColor.fromInt(0xFF1E3A5F),
      ),
    );
  }

  static pw.Widget _buildLineItemsTable(List<LineItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FixedColumnWidth(60),
        2: const pw.FixedColumnWidth(80),
        3: const pw.FixedColumnWidth(80),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF1E3A5F),
          ),
          children: ['Description', 'Qty', 'Unit Price', 'Total'].map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                _cleanText(h),
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        ),
        // Rows
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.grey50 : PdfColors.white,
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(_cleanText(item.description),
                    style: const pw.TextStyle(fontSize: 9)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(item.qty.toString(),
                    style: const pw.TextStyle(fontSize: 9)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  '$_rupee${_currencyFormat.format(item.unitPrice)}',
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  '$_rupee${_currencyFormat.format(item.total)}',
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTotalsBlock(Quotation q) {
    return pw.Container(
      width: 200,
      child: pw.Column(
        children: [
          _totalRow('Subtotal', q.subtotal),
          _totalRow('CGST (${q.cgstRate}%)', q.cgstAmount),
          _totalRow('SGST (${q.sgstRate}%)', q.sgstAmount),
          pw.Divider(thickness: 1),
          _totalRow('Grand Total', q.grandTotal, bold: true),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(String label, double amount, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(_cleanText(label),
            style: pw.TextStyle(
                fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : null)),
        pw.Text(
          '$_rupee${_currencyFormat.format(amount)}',
          style: pw.TextStyle(
              fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : null),
        ),
      ],
    );
  }

  static pw.Widget _buildBoqItemsTable(List<BoqItem> items) {
    if (items.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Text('No items in this scope.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 9, color: PdfColors.grey600)),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E3A5F)),
          children: ['Component', 'Qty', 'Unit']
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(_cleanText(h),
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold)),
                  ))
              .toList(),
        ),
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: i.isEven ? PdfColors.grey50 : PdfColors.white),
            children: [
              item.component,
              item.qty.toInt().toString(),
              item.unit,
            ]
                .map((v) => pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(_cleanText(v),
                          style: const pw.TextStyle(fontSize: 9)),
                    ))
                .toList(),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildFactoryItemsTable(List<FactoryOrderItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E3A5F)),
          children: ['Item Name', 'Qty']
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(_cleanText(h),
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold)),
                  ))
              .toList(),
        ),
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: i.isEven ? PdfColors.grey50 : PdfColors.white),
            children: [
              item.itemName,
              item.qty.toInt().toString(),
            ]
                .map((v) => pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(_cleanText(v),
                          style: const pw.TextStyle(fontSize: 9)),
                    ))
                .toList(),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildPoItemsTable(List<PoItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E3A5F)),
          children: ['Description', 'Qty', 'Unit']
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(_cleanText(h),
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold)),
                  ))
              .toList(),
        ),
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: i.isEven ? PdfColors.grey50 : PdfColors.white),
            children: [
              item.description,
              item.qty.toInt().toString(),
              item.unit,
            ]
                .map((v) => pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(_cleanText(v),
                          style: const pw.TextStyle(fontSize: 9)),
                    ))
                .toList(),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildSpecsTable(
      Map<String, dynamic> specs, Product product) {
    final rows = specs.entries.toList();
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
      children: rows.asMap().entries.map((entry) {
        final i = entry.key;
        final kv = entry.value;
        // Find display label from product field definitions
        final field = product.baseSpecs.quotationFields
            .where((f) => f.key == kv.key)
            .firstOrNull;
        final label = field?.label ?? kv.key;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.grey50 : PdfColors.white),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(_cleanText(label),
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(_cleanText(kv.value?.toString()),
                  style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        );
      }).toList(),
    );
  }

  static pw.Widget _buildExtraFieldsTable(
      Map<String, dynamic> fields, Product product) {
    final rows = fields.entries.toList();
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
      children: rows.asMap().entries.map((entry) {
        final i = entry.key;
        final kv = entry.value;
        final field = [
          ...product.baseSpecs.boqRequiredFields,
          ...product.baseSpecs.quotationFields,
        ].where((f) => f.key == kv.key).firstOrNull;
        final label = field?.label ?? kv.key;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.grey50 : PdfColors.white),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(_cleanText(label),
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(_cleanText(kv.value?.toString()),
                  style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        );
      }).toList(),
    );
  }

  static pw.Widget _buildVendorBlock(VendorDetails vendor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_cleanText(vendor.vendorName),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        if (vendor.contactPerson != null)
          pw.Text(_cleanText(vendor.contactPerson!),
              style: const pw.TextStyle(fontSize: 10)),
        if (vendor.phone != null)
          pw.Text(_cleanText(vendor.phone!),
              style: const pw.TextStyle(fontSize: 10)),
        if (vendor.email != null)
          pw.Text(_cleanText(vendor.email!),
              style: const pw.TextStyle(fontSize: 10)),
        if (vendor.address != null)
          pw.Text(_cleanText(vendor.address!),
              style: const pw.TextStyle(fontSize: 10)),
        if (vendor.gstNumber != null)
          pw.Text('GSTIN: ${_cleanText(vendor.gstNumber)}',
              style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildBankDetails(Map<String, dynamic> bank) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BANK DETAILS',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Bank: ${_cleanText(bank['bank_name']?.toString())}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
              'Account Name: ${_cleanText(bank['account_name']?.toString())}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
              'Account No.: ${_cleanText(bank['account_number']?.toString())}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text('IFSC: ${_cleanText(bank['ifsc']?.toString())}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Branch: ${_cleanText(bank['branch']?.toString())}',
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(
      String footerText, int pageNumber, int totalPages, {String? generatedBy}) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                _cleanText(footerText),
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ),
            if (generatedBy != null && generatedBy.trim().isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                child: pw.Text(
                  'Generated by: ${_cleanText(generatedBy)}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                ),
              ),
            pw.Text(
              'Page $pageNumber of $totalPages',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _infoBlock(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_cleanText(label),
            style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5)),
        pw.Text(_cleanText(value), style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  // ─── SALES ORDER PDF ─────────────────────────────────────────────────────────

  static Future<Uint8List> generateSalesOrderPdf({
    required SalesOrder salesOrder,
    required Customer customer,
    required Product product,
    required String variant,
    required Map<String, dynamic> templateConfig,
  }) async {
    final resolvedConfig = await resolveTemplateConfig(templateConfig);
    final logoUrl = resolvedConfig['logo_url'] as String?;
    final logoImage = await _fetchLogo(logoUrl);
    final generatedByName = await resolveCurrentUserName();

    final pdf = pw.Document();

    final companyName = resolvedConfig['company_name'] as String? ??
        'INSIYA SOLAR INDUSTRY';
    final companyAddress = resolvedConfig['company_address'] as String? ??
        'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra 411014';
    final companyPhone =
        resolvedConfig['company_phone'] as String? ?? '+91 92929 22992';
    final companyEmail = resolvedConfig['company_email'] as String? ??
        'insiyasolarindustry@gmail.com';
    final companyGst =
        resolvedConfig['company_gst'] as String? ?? '27CFTPS5292A1ZY';

    final cleanCompanyName = _cleanText(companyName);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => _buildHeader(
          companyName: companyName,
          companyAddress: companyAddress,
          companyPhone: companyPhone,
          companyEmail: companyEmail,
          companyGst: variant == 'production' ? '' : 'GSTIN : $companyGst',
          docTitle: 'SALES ORDER',
          docNumber: salesOrder.salesOrderNumber,
          docDate: salesOrder.orderDate,
          status: salesOrder.status.displayName,
          logoImage: logoImage,
        ),
        footer: (context) => _buildFooter(
          variant == 'production'
              ? ''
              : (resolvedConfig['footer_text'] as String? ?? 'Thank you for your business.'),
          context.pageNumber,
          context.pagesCount,
          generatedBy: generatedByName,
        ),
        build: (context) => [
          // Shipping metadata card
          if (variant != 'production') ...[
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    _metaCellRow(
                        'Sales Order No.', salesOrder.salesOrderNumber),
                    _metaCellRow('Order Date',
                        DateFormat('dd/MM/yyyy').format(salesOrder.orderDate)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _metaCellRow(
                        'Shipping Company', salesOrder.shippingCompany),
                    _metaCellRow('Vehicle No', salesOrder.vehicleNumber),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _metaCellRow('Eway Bill No & Date',
                        '${salesOrder.ewayBillNo ?? ''}${salesOrder.ewayBillDate != null && salesOrder.ewayBillDate!.isNotEmpty ? " | Dated ${salesOrder.ewayBillDate!}" : ""}'),
                    _metaCellRow('Distance', salesOrder.distance),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _metaCellRow('Bill Type', salesOrder.billType ?? 'Credit'),
                    _metaCellRow('GR/LR No.', salesOrder.grLrNo),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _metaCellRow('Place of Supply', salesOrder.placeOfSupply),
                    _metaCellRow('Destination', salesOrder.destination),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _metaCellRow('Payment Term', salesOrder.paymentTerms),
                    _metaCellRow('', ''), // empty spacer
                  ],
                ),
              ],
            ),
          ] else ...[
            // Production View metadata: only Destination
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    _metaCellRow('Destination', salesOrder.destination),
                  ],
                ),
              ],
            ),
          ],
          pw.SizedBox(height: 12),

          // Bill To and Shipped To Addresses
          if (variant != 'production') ...[
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Customer Name & Billing Address',
                          style: pw.TextStyle(
                              fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Shipping Address',
                          style: pw.TextStyle(
                              fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    // Billing Address Cell
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(_cleanText(customer.companyName),
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                              _cleanText(salesOrder.billingAddress ??
                                  customer.address),
                              style: const pw.TextStyle(fontSize: 8)),
                          if (customer.gstNumber != null &&
                              customer.gstNumber!.isNotEmpty)
                            pw.Text(
                                'GSTIN : ${_cleanText(customer.gstNumber)}  State Code : ${customer.gstNumber!.length >= 2 ? customer.gstNumber!.substring(0, 2) : "27"}',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                          if (customer.phone != null &&
                              customer.phone!.isNotEmpty)
                            pw.Text('Phone : ${_cleanText(customer.phone)}',
                                style: const pw.TextStyle(fontSize: 8)),
                          if (salesOrder.partyContactPerson != null &&
                              salesOrder.partyContactPerson!.isNotEmpty)
                            pw.Text(
                                'Party Contact Person : ${_cleanText(salesOrder.partyContactPerson)}',
                                style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                    // Shipping Address Cell
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(_cleanText(customer.companyName),
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                              _cleanText(salesOrder.shippingAddress ??
                                  customer.address),
                              style: const pw.TextStyle(fontSize: 8)),
                          if (customer.gstNumber != null &&
                              customer.gstNumber!.isNotEmpty)
                            pw.Text(
                                'State Code : ${customer.gstNumber!.length >= 2 ? customer.gstNumber!.substring(0, 2) : "27"}',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          if (salesOrder.salesman != null &&
                              salesOrder.salesman!.isNotEmpty)
                            pw.Text(
                                'Salesman : ${_cleanText(salesOrder.salesman)}',
                                style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
          ],

          // Line items table
          _buildSalesOrderItemsTable(salesOrder, variant),
          pw.SizedBox(height: 12),

          if (variant == 'commercial') ...[
            // Totals block & Taxes
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Tax Matrix table
                      _buildTaxMatrixTable(salesOrder),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'Tax Amount : ${numberToIndianWords(salesOrder.cgstAmount + salesOrder.sgstAmount + salesOrder.igstAmount)}',
                        style: pw.TextStyle(
                            fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Bill Amount : ${numberToIndianWords(salesOrder.grandTotal)}',
                        style: pw.TextStyle(
                            fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 10),
                      if (salesOrder.remarks != null &&
                          salesOrder.remarks!.isNotEmpty) ...[
                        pw.Text('Remark : ',
                            style: pw.TextStyle(
                                fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text(_cleanText(salesOrder.remarks),
                            style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(width: 15),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _soTotalRow('Sub Total', salesOrder.subtotal),
                      _soTotalRow('Taxable Amount', salesOrder.subtotal),
                      if (salesOrder.cgstAmount > 0) ...[
                        _soTotalRow('CGST @9.0%', salesOrder.cgstAmount),
                        _soTotalRow('SGST @9.0%', salesOrder.sgstAmount),
                      ] else ...[
                        _soTotalRow('IGST @18.0%', salesOrder.igstAmount),
                      ],
                      pw.Divider(thickness: 1),
                      _soTotalRow('Order Total', salesOrder.grandTotal,
                          bold: true),
                    ],
                  ),
                ),
              ],
            ),
          ],

          if (variant != 'production') ...[
            pw.SizedBox(height: 25),
            // Declaration
            pw.Text(
              'Declaration:\nWe declare that this invoice shows the actual price of the goods / services described and that all particulars are true and correct.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 30),
            // Sign-off
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                        width: 100, height: 1, color: PdfColors.grey500),
                    pw.SizedBox(height: 4),
                    pw.Text("Receiver's Signature",
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('For ${cleanCompanyName.toUpperCase()}',
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 25),
                    pw.Container(
                        width: 120, height: 1, color: PdfColors.grey500),
                    pw.SizedBox(height: 4),
                    pw.Text('Authorised Signatory',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _metaCellRow(String label, String? value) {
    if (label.isEmpty) return pw.Container();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(_cleanText(label),
                style: pw.TextStyle(
                    fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text(' : ',
              style:
                  pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(
            child: pw.Text(_cleanText(value ?? ''),
                style: const pw.TextStyle(fontSize: 8.5)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _soTotalRow(String label, double amount,
      {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(_cleanText(label),
            style: pw.TextStyle(
                fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : null)),
        pw.Text(
          '$_rupee${_currencyFormat.format(amount)}',
          style: pw.TextStyle(
              fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : null),
        ),
      ],
    );
  }

  static pw.Widget _buildSalesOrderItemsTable(
      SalesOrder salesOrder, String variant) {
    final items = salesOrder.lineItems;
    final headers = variant == 'commercial'
        ? [
            'S No',
            'Description',
            'HSN / SAC',
            'Qty',
            'GST %',
            'UOM',
            'Item Rate',
            'Disc %',
            'Amount (INR)'
          ]
        : variant == 'technical'
            ? ['S No', 'Description', 'HSN / SAC', 'Qty', 'UOM']
            : ['S No', 'Description', 'Qty', 'UOM'];

    final widths = variant == 'commercial'
        ? {
            0: const pw.FixedColumnWidth(25),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FixedColumnWidth(55),
            3: const pw.FixedColumnWidth(35),
            4: const pw.FixedColumnWidth(40),
            5: const pw.FixedColumnWidth(35),
            6: const pw.FixedColumnWidth(50),
            7: const pw.FixedColumnWidth(35),
            8: const pw.FixedColumnWidth(60),
          }
        : variant == 'technical'
            ? {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FixedColumnWidth(80),
                3: const pw.FixedColumnWidth(50),
                4: const pw.FixedColumnWidth(50),
              }
            : {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FixedColumnWidth(60),
              };

    final gstFraction = salesOrder.subtotal > 0
        ? (salesOrder.cgstAmount +
                salesOrder.sgstAmount +
                salesOrder.igstAmount) /
            salesOrder.subtotal
        : 0.18;

    double totalQty = 0;
    double totalAmount = 0;
    for (final item in items) {
      totalQty += item.qty;
      final lineTaxable = (item.qty * item.rate) * (1 - item.discPercent / 100);
      final lineAmountIncludingTax = lineTaxable * (1 + gstFraction);
      totalAmount += lineAmountIncludingTax;
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: widths,
      children: [
        // Header
        pw.TableRow(
          decoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E3A5F)),
          children: headers.map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                _cleanText(h),
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold),
              ),
            );
          }).toList(),
        ),
        // Rows
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;

          final lineTaxable =
              (item.qty * item.rate) * (1 - item.discPercent / 100);
          final lineAmountIncludingTax = lineTaxable * (1 + gstFraction);

          final cells = variant == 'commercial'
              ? [
                  (idx + 1).toString(),
                  item.description,
                  item.hsnSac ?? '',
                  item.qty.toStringAsFixed(2),
                  '${item.gstPercent.toStringAsFixed(0)}%',
                  item.uom,
                  _currencyFormat.format(item.rate),
                  '${item.discPercent.toStringAsFixed(2)}%',
                  _currencyFormat.format(lineAmountIncludingTax),
                ]
              : variant == 'technical'
                  ? [
                      (idx + 1).toString(),
                      item.description,
                      item.hsnSac ?? '',
                      item.qty.toStringAsFixed(2),
                      item.uom,
                    ]
                  : [
                      (idx + 1).toString(),
                      item.description,
                      item.qty.toStringAsFixed(2),
                      item.uom,
                    ];

          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: idx.isEven ? PdfColors.grey50 : PdfColors.white),
            children: cells.asMap().entries.map((cellEntry) {
              final colIdx = cellEntry.key;
              final val = cellEntry.value;

              final alignRight = variant == 'commercial' &&
                  (colIdx == 3 ||
                      colIdx == 4 ||
                      colIdx == 6 ||
                      colIdx == 7 ||
                      colIdx == 8);
              return pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  _cleanText(val),
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign:
                      alignRight ? pw.TextAlign.right : pw.TextAlign.left,
                ),
              );
            }).toList(),
          );
        }),
        // Total row at bottom
        if (variant == 'commercial')
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text('Total',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(_currencyFormat.format(totalQty),
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right),
              ),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(_currencyFormat.format(totalAmount),
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right),
              ),
            ],
          )
        else if (variant == 'technical')
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text('Total',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(_currencyFormat.format(totalQty),
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right),
              ),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
            ],
          )
        else
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text('Total',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(_currencyFormat.format(totalQty),
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right),
              ),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
            ],
          )
      ],
    );
  }

  static pw.Widget _buildTaxMatrixTable(SalesOrder so) {
    final taxRate = so.cgstRate + so.sgstRate;
    final taxableValue = so.subtotal;
    final cgst = so.cgstAmount;
    final sgst = so.sgstAmount;
    final igst = so.igstAmount;
    final totalTax = cgst + sgst + igst;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FixedColumnWidth(65),
        2: const pw.FixedColumnWidth(60),
        3: const pw.FixedColumnWidth(60),
        4: const pw.FixedColumnWidth(60),
        5: const pw.FixedColumnWidth(60),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            'Tax Rate',
            'Taxable Value',
            'CGST Amount',
            'SGST Amount',
            'IGST Amount',
            'Total Tax'
          ].map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(h,
                  style: pw.TextStyle(
                      fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
            );
          }).toList(),
        ),
        // Row
        pw.TableRow(
          children: [
            'TAX @ ${taxRate.toStringAsFixed(0)}%',
            _currencyFormat.format(taxableValue),
            _currencyFormat.format(cgst),
            _currencyFormat.format(sgst),
            _currencyFormat.format(igst),
            _currencyFormat.format(totalTax),
          ].map((v) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(v,
                  style: const pw.TextStyle(fontSize: 7.5),
                  textAlign: pw.TextAlign.right),
            );
          }).toList(),
        ),
      ],
    );
  }

  static String numberToIndianWords(double number) {
    if (number == 0) return 'INR Zero Only';
    if (number < 0) return 'Minus ${numberToIndianWords(-number)}';

    int whole = number.floor();
    int paise = ((number - whole) * 100).round();

    String result = _convertWholeNumber(whole);

    if (paise > 0) {
      result += ' and ${_convertWholeNumber(paise)} Paise';
    }

    return 'INR ${result.trim()} Only';
  }

  static String _convertWholeNumber(int number) {
    if (number == 0) return '';

    final units = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen'
    ];

    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety'
    ];

    if (number < 20) {
      return units[number];
    }

    if (number < 100) {
      return tens[number ~/ 10] +
          (number % 10 != 0 ? ' ${units[number % 10]}' : '');
    }

    if (number < 1000) {
      return '${units[number ~/ 100]} Hundred${number % 100 != 0 ? ' ${_convertWholeNumber(number % 100)}' : ''}';
    }

    if (number < 100000) {
      return '${_convertWholeNumber(number ~/ 1000)} Thousand${number % 1000 != 0 ? ' ${_convertWholeNumber(number % 1000)}' : ''}';
    }

    if (number < 10000000) {
      return '${_convertWholeNumber(number ~/ 100000)} Lac${number % 100000 != 0 ? ' ${_convertWholeNumber(number % 100000)}' : ''}';
    }

    return '${_convertWholeNumber(number ~/ 10000000)} Crore${number % 10000000 != 0 ? ' ${_convertWholeNumber(number % 10000000)}' : ''}';
  }

  static Future<Uint8List> generateAmcContractPdf({
    required AmcContract contract,
    required Map<String, dynamic> templateConfig,
  }) async {
    final resolvedConfig = await resolveTemplateConfig(templateConfig);
    final logoUrl = resolvedConfig['logo_url'] as String?;
    final logoImage = await _fetchLogo(logoUrl);
    final generatedByName = await resolveCurrentUserName();

    final pdf = pw.Document();

    final companyName = resolvedConfig['company_name'] as String? ?? 'INSIYA SOLAR INDUSTRY';
    final companyAddress = resolvedConfig['company_address'] as String? ?? '';
    final companyPhone = resolvedConfig['company_phone'] as String? ?? '';
    final companyEmail = resolvedConfig['company_email'] as String? ?? '';
    final companyGst = resolvedConfig['company_gst'] as String? ?? '';
    final footerText = resolvedConfig['footer_text'] as String? ?? 'Thank you for your business.';
    final termsDefault = resolvedConfig['terms_default'] as String? ?? '';

    final customer = contract.customer;
    final product = contract.product;
    if (customer == null) {
      throw Exception('Customer data is missing in contract');
    }
    if (product == null) {
      throw Exception('Product data is missing in contract');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => _buildHeader(
          companyName: companyName,
          companyAddress: companyAddress,
          companyPhone: companyPhone,
          companyEmail: companyEmail,
          companyGst: companyGst,
          docTitle: 'ANNUAL MAINTENANCE CONTRACT',
          docNumber: contract.amcNumber,
          docDate: contract.createdAt,
          status: contract.status.displayName,
          logoImage: logoImage,
        ),
        footer: (context) =>
            _buildFooter(footerText, context.pageNumber, context.pagesCount, generatedBy: generatedByName),
        build: (context) => [
          _buildBillTo(customer),
          pw.SizedBox(height: 20),
          _buildSectionTitle('Contract Specifications'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              _buildTableRow('Product Covered', product.name),
              _buildTableRow('Contract Number', contract.amcNumber),
              _buildTableRow(
                  'Start Date',
                  contract.startDate != null
                      ? DateFormat('dd MMM yyyy').format(contract.startDate!)
                      : '-'),
              _buildTableRow(
                  'End Date',
                  contract.endDate != null
                      ? DateFormat('dd MMM yyyy').format(contract.endDate!)
                      : '-'),
              _buildTableRow('No. of Visits Included',
                  '${contract.numberOfVisitsIncluded ?? 0} Visits'),
              _buildTableRow(
                  'Contract Value',
                  contract.contractAmount != null
                      ? 'Rs. ${_currencyFormat.format(contract.contractAmount)}'
                      : 'Rs. 0.00'),
            ],
          ),
          pw.SizedBox(height: 20),
          if (contract.serviceVisits != null &&
              contract.serviceVisits!.isNotEmpty) ...[
            _buildSectionTitle('Scheduled Maintenance Visits'),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(80),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(100),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Visit No.',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Scheduled Date',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Status',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                  ],
                ),
                ...contract.serviceVisits!.map((visit) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('#${visit.visitNumber}',
                              style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              DateFormat('dd MMM yyyy')
                                  .format(visit.scheduledDate),
                              style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(visit.status.displayName,
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  color: visit.status.name == 'completed'
                                      ? PdfColors.green800
                                      : PdfColors.grey800)),
                        ),
                      ],
                    )),
              ],
            ),
            pw.SizedBox(height: 20),
          ],
          _buildSectionTitle('Terms & Conditions'),
          pw.SizedBox(height: 8),
          pw.Text(
            _cleanText(contract.termsText ?? termsDefault),
            style: pw.TextStyle(
                fontSize: 9, color: PdfColors.grey700, lineSpacing: 4),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.TableRow _buildTableRow(String key, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(key,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  // ─── SINGLE-PAGE AMC VISIT RECEIPT PDF ──────────────────────────────────────

  static Future<Uint8List> generateAmcVisitPdf({
    required ServiceVisit visit,
    required Customer customer,
    required Map<String, dynamic> templateConfig,
  }) async {
    final resolvedConfig = await resolveTemplateConfig(templateConfig);
    final generatedByName = await resolveCurrentUserName();
    final pdf = pw.Document();
    final companyName = resolvedConfig['company_name'] as String? ?? 'INSIYA SOLAR INDUSTRY';
    final companyAddress = resolvedConfig['company_address'] as String? ?? 'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra - 411014';
    final companyPhone = resolvedConfig['company_phone'] as String? ?? '+91 9292922992';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
          ),
          padding: const pw.EdgeInsets.all(16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(companyName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Phone: $companyPhone', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
                    child: pw.Text('SERVICE VISIT RECEIPT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.black, height: 1),
              pw.SizedBox(height: 12),

              // Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer: ${customer.companyName}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      if (customer.contactPerson != null) pw.Text('Contact: ${customer.contactPerson}', style: const pw.TextStyle(fontSize: 8)),
                      if (customer.phone != null) pw.Text('Phone: ${customer.phone}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Visit Date: ${DateFormat('dd/MM/yyyy').format(visit.visitDate)}', style: const pw.TextStyle(fontSize: 9)),
                      if (visit.technicianName != null) pw.Text('Technician: ${visit.technicianName}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Spare Parts Table
              pw.Text('Spare Parts & Charges', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Part / Service Description', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Qty', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Unit Rate (INR)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Total (INR)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  ...visit.items.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.partName, style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.qty.toStringAsFixed(1), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_currencyFormat.format(item.unitPrice), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_currencyFormat.format(item.total), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                    ],
                  )),
                  if (visit.laborCharge > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Labor & Service Charges', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('1', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_currencyFormat.format(visit.laborCharge), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_currencyFormat.format(visit.laborCharge), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Grand Total: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rs. ${_currencyFormat.format(visit.totalCost)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                ],
              ),
              pw.SizedBox(height: 16),
              if (visit.serviceNotes != null && visit.serviceNotes!.isNotEmpty) ...[
                pw.Text('Service Visit Remarks:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(visit.serviceNotes!, style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 20),
              ],
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 100, height: 0.5, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text("Customer Signature", style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 100, height: 0.5, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text('Technician Signature', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Generated by: ${_cleanText(generatedByName)}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
              ),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  // ─── WARRANTY CARD PDF GENERATOR ───────────────────────────────────────────

  static Future<Uint8List> generateWarrantyCardPdf({
    required WarrantyCard card,
    required Map<String, dynamic> templateConfig,
  }) async {
    final resolvedConfig = await resolveTemplateConfig(templateConfig);
    final generatedByName = await resolveCurrentUserName();

    final pdf = pw.Document();
    final companyName = resolvedConfig['company_name'] as String? ?? 'INSIYA SOLAR INDUSTRY';
    final companyAddress = resolvedConfig['company_address'] as String? ?? 'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra - 411014';

    final wNum = card.warrantyNumber ?? card.invoiceNumber ?? '#WRN/26-27/0001';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blue900, width: 2),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(companyName.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.SizedBox(height: 4),
              pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: pw.BoxDecoration(color: PdfColors.amber100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                child: pw.Text('OFFICIAL WARRANTY CERTIFICATE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
              ),
              pw.SizedBox(height: 24),

              // Info Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                children: [
                  _buildTableRow('Warranty Number', wNum),
                  _buildTableRow('Customer Name', card.customerName ?? 'Valued Customer'),
                  _buildTableRow('Contact Number', card.customerPhone ?? 'N/A'),
                  _buildTableRow('Email Address', card.customerEmail ?? 'N/A'),
                  _buildTableRow('Warranty Period', '${card.warrantyYears} Year(s) Standard Warranty'),
                  _buildTableRow('Start Date', card.startDate != null ? DateFormat('dd MMM yyyy').format(card.startDate!) : 'N/A'),
                  _buildTableRow('Expiry / End Date', card.endDate != null ? DateFormat('dd MMM yyyy').format(card.endDate!) : 'N/A'),
                  _buildTableRow('Activation Status', card.isActivated ? 'ACTIVATED & VERIFIED' : 'PENDING ACTIVATION'),
                ],
              ),
              pw.SizedBox(height: 24),

              // QR Code and Terms
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: wNum,
                        width: 70,
                        height: 70,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Scan to Verify Warranty', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 20),
                      child: pw.Text(
                        'Terms: This warranty certificate guarantees product coverage according to standard terms. Please present this certificate with QR code for official service requests.',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        textAlign: pw.TextAlign.left,
                      ),
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Ref: $wNum', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('Generated by: ${_cleanText(generatedByName)}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 0.5, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateActivityReportPdf({
    required BuildContext context,
    required ActivityReportData data,
    required String userName,
    required String dateRangeType,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    final pdf = pw.Document();
    final generatedByName = await resolveCurrentUserName();

    final prefs = await SharedPreferences.getInstance();
    final companyName = prefs.getString('company_name') ?? 'Insiya Solar Industry';
    final companyAddress = prefs.getString('company_address') ?? 'Default Address';
    final companyPhone = prefs.getString('company_phone') ?? '+91 0000000000';
    final companyEmail = prefs.getString('company_email') ?? 'info@insiyasolar.com';
    final logoUrl = prefs.getString('company_logo_url');
    final logoImage = await _fetchLogo(logoUrl);

    String dateStr = dateRangeType.toUpperCase();
    if (dateRangeType == 'custom' && customStartDate != null && customEndDate != null) {
      dateStr = '${DateFormat('dd MMM yyyy').format(customStartDate)} to ${DateFormat('dd MMM yyyy').format(customEndDate)}';
    }

    final pdfTheme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.interRegular(),
      bold: await PdfGoogleFonts.interBold(),
    );

    pw.Widget buildHeader() {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(companyName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 4),
                pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Text('Phone: $companyPhone | Email: $companyEmail', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          ),
          if (logoImage != null)
            pw.Container(
              height: 50,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
        ],
      );
    }

    pw.Widget buildSectionHeader(String title, [PdfColor headerColor = PdfColors.blue900]) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue50,
          border: pw.Border(left: pw.BorderSide(color: headerColor, width: 4)),
        ),
        child: pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: headerColor)),
      );
    }

    pw.Widget buildStatBox(String label, String value, PdfColor color) {
      return pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        theme: pdfTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          children: [
            buildHeader(),
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('USER ACTIVITY REPORT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.black, letterSpacing: 1.5)),
                  pw.SizedBox(height: 4),
                  pw.Text('Generated for: $userName', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Period: $dateStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Generated by: ${_cleanText(generatedByName)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        build: (context) {
          return [
            // Activity Overview Summary Box
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  buildStatBox('Prospects', data.prospects.length.toString(), PdfColors.indigo800),
                  buildStatBox('Leads', data.leads.length.toString(), PdfColors.cyan900),
                  buildStatBox('Comms', data.communications.length.toString(), PdfColors.purple900),
                  buildStatBox('Deals', data.pipelines.length.toString(), PdfColors.teal900),
                  buildStatBox('Customers', data.customers.length.toString(), PdfColors.blue900),
                  buildStatBox('Complaints', data.complaints.length.toString(), PdfColors.orange900),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            if (data.customers.isNotEmpty) ...[
              buildSectionHeader('CUSTOMERS ADDED (${data.customers.length})', PdfColors.blue900),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headers: ['ID', 'Name', 'Phone', 'Created At'],
                data: data.customers.map((c) => [
                  (c['id']?.toString() ?? '').length > 8 ? (c['id']?.toString() ?? '').substring(0, 8) + '...' : (c['id']?.toString() ?? ''),
                  c['customer_name']?.toString() ?? '-',
                  c['phone']?.toString() ?? '-',
                  c['created_at'] != null ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.tryParse(c['created_at']) ?? DateTime.now()) : '-',
                ]).toList(),
              ),
            ],

            pw.SizedBox(height: 10),
            if (data.pipelines.isNotEmpty) ...[
              buildSectionHeader('DEALS CREATED (${data.pipelines.length})', PdfColors.teal900),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal900),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headers: ['Deal ID', 'Customer', 'Product', 'Status'],
                data: data.pipelines.map((p) => [
                  (p['id']?.toString() ?? '').length > 8 ? (p['id']?.toString() ?? '').substring(0, 8) + '...' : (p['id']?.toString() ?? ''),
                  p['customers'] != null ? p['customers']['customer_name'] : '-',
                  p['products'] != null ? p['products']['name'] : '-',
                  p['status']?.toString().toUpperCase() ?? '-',
                ]).toList(),
              ),
            ],

            pw.SizedBox(height: 10),
            if (data.stepAuditLogs.isNotEmpty) ...[
              buildSectionHeader('DEAL STEPS FINISHED (${data.stepAuditLogs.length})', PdfColors.indigo900),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headers: ['Deal / Customer', 'Step', 'Action', 'Time'],
                data: data.stepAuditLogs.map((s) {
                  final pipeline = s['sales_pipelines'] as Map<String, dynamic>?;
                  final cust = pipeline?['customers'] as Map<String, dynamic>?;
                  final prod = pipeline?['products'] as Map<String, dynamic>?;
                  final cName = cust?['customer_name'] ?? '';
                  final pName = prod?['name'] ?? '';
                  final dealStr = [cName, pName].where((e) => e.isNotEmpty).join(' - ');
                  return [
                    dealStr.isNotEmpty ? dealStr : (s['pipeline_id']?.toString().substring(0, 8) ?? '-'),
                    s['step_name']?.toString().toUpperCase() ?? '-',
                    s['action']?.toString() ?? '-',
                    s['performed_at'] != null ? DateFormat('dd MMM, HH:mm').format(DateTime.tryParse(s['performed_at']) ?? DateTime.now()) : '-',
                  ];
                }).toList(),
              ),
            ],

            pw.SizedBox(height: 10),
            if (data.communications.isNotEmpty) ...[
              buildSectionHeader('LEAD COMMUNICATIONS (${data.communications.length})', PdfColors.purple900),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.purple900),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headers: ['Lead / Prospect', 'Type', 'Summary', 'Time'],
                data: data.communications.map((comm) {
                  final lead = comm['crm_leads'] as Map<String, dynamic>?;
                  final leadName = lead?['prospect_name'] ?? '-';
                  return [
                    leadName,
                    comm['type']?.toString() ?? '-',
                    comm['summary']?.toString() ?? '-',
                    comm['created_at'] != null ? DateFormat('dd MMM, HH:mm').format(DateTime.tryParse(comm['created_at']) ?? DateTime.now()) : '-',
                  ];
                }).toList(),
              ),
            ],

            pw.SizedBox(height: 10),
            if (data.leads.isNotEmpty) ...[
              buildSectionHeader('LEADS ADDED (${data.leads.length})', PdfColors.cyan900),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan900),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headers: ['Prospect', 'Product', 'Est. Value', 'Status'],
                data: data.leads.map((l) => [
                  l['prospect_name']?.toString() ?? '-',
                  l['product_name']?.toString() ?? '-',
                  '₹${l['estimated_value'] ?? 0}',
                  l['status']?.toString() ?? 'New',
                ]).toList(),
              ),
            ],

            pw.SizedBox(height: 10),
            if (data.prospects.isNotEmpty) ...[
              buildSectionHeader('PROSPECTS ADDED (${data.prospects.length})', PdfColors.indigo800),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headers: ['Prospect Name', 'Phone', 'Company', 'Source', 'Converted', 'Date'],
                data: data.prospects.map((pr) => [
                  pr['name']?.toString() ?? '-',
                  pr['phone']?.toString() ?? '-',
                  pr['company']?.toString() ?? '-',
                  pr['source']?.toString() ?? 'Manual',
                  pr['converted_to_lead_id'] != null ? 'Yes (Lead)' : 'No',
                  pr['created_at'] != null ? DateFormat('dd MMM, HH:mm').format(DateTime.tryParse(pr['created_at']) ?? DateTime.now()) : '-',
                ]).toList(),
              ),
            ],

            pw.SizedBox(height: 10),
            if (data.conversions.isNotEmpty) ...[
              buildSectionHeader('CONVERSIONS (${data.conversions.length})', PdfColors.green900),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green900),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headers: ['Type', 'Name', 'Details', 'Time'],
                data: data.conversions.map((conv) => [
                  conv['type']?.toString() ?? '-',
                  conv['name']?.toString() ?? '-',
                  conv['details']?.toString() ?? '-',
                  conv['time'] != null ? DateFormat('dd MMM, HH:mm').format(DateTime.tryParse(conv['time']) ?? DateTime.now()) : '-',
                ]).toList(),
              ),
            ],

            pw.SizedBox(height: 10),
            if (data.complaints.isNotEmpty) ...[
              buildSectionHeader('COMPLAINTS LOGGED/HANDLED (${data.complaints.length})', PdfColors.orange900),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.orange900),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.all(6),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headers: ['Ticket ID', 'Title', 'Customer', 'Status'],
                data: data.complaints.map((c) => [
                  c['ticket_number'] ?? (c['id'] != null && c['id'].toString().length > 8 ? c['id'].toString().substring(0, 8) + '...' : '-'),
                  c['title']?.toString() ?? '-',
                  c['customer_name']?.toString() ?? '-',
                  c['status']?.toString().toUpperCase() ?? '-',
                ]).toList(),
              ),
            ],

            if (data.customers.isEmpty &&
                data.pipelines.isEmpty &&
                data.stepAuditLogs.isEmpty &&
                data.communications.isEmpty &&
                data.leads.isEmpty &&
                data.prospects.isEmpty &&
                data.conversions.isEmpty &&
                data.complaints.isEmpty)
              pw.Text('No activities recorded during this period.', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateAllUsersActivityReportPdf({
    required BuildContext context,
    required List<Map<String, dynamic>> userEntries,
    required String dateRangeType,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    final pdf = pw.Document();
    final generatedByName = await resolveCurrentUserName();

    final prefs = await SharedPreferences.getInstance();
    final companyName = prefs.getString('company_name') ?? 'Insiya Solar Industry';
    final companyAddress = prefs.getString('company_address') ?? 'Default Address';
    final companyPhone = prefs.getString('company_phone') ?? '+91 0000000000';
    final companyEmail = prefs.getString('company_email') ?? 'info@insiyasolar.com';
    final logoUrl = prefs.getString('company_logo_url');
    final logoImage = await _fetchLogo(logoUrl);

    String dateStr = dateRangeType.toUpperCase();
    if (dateRangeType == 'custom' && customStartDate != null && customEndDate != null) {
      dateStr = '${DateFormat('dd MMM yyyy').format(customStartDate)} to ${DateFormat('dd MMM yyyy').format(customEndDate)}';
    }

    final pdfTheme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.interRegular(),
      bold: await PdfGoogleFonts.interBold(),
    );

    pw.Widget buildHeader() {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(companyName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 3),
                pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.Text('Phone: $companyPhone | Email: $companyEmail', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ),
          if (logoImage != null)
            pw.Container(
              height: 45,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
        ],
      );
    }

    pw.Widget buildSectionHeader(String title, PdfColor headerColor) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border(left: pw.BorderSide(color: headerColor, width: 4)),
        ),
        child: pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: headerColor)),
      );
    }

    pw.Widget buildStatBox(String label, String value, PdfColor color) {
      return pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        ],
      );
    }

    for (final entry in userEntries) {
      final String uName = entry['userName'] as String;
      final String uRole = entry['userRole'] as String? ?? '';
      final ActivityReportData uData = entry['data'] as ActivityReportData;

      pdf.addPage(
        pw.MultiPage(
          theme: pdfTheme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pageCtx) => pw.Column(
            children: [
              buildHeader(),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('USER ACTIVITY REPORT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black, letterSpacing: 1.5)),
                    pw.SizedBox(height: 3),
                    pw.Text('Staff Member: $uName ${uRole.isNotEmpty ? "($uRole)" : ""}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('Period: $dateStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
            ],
          ),
          footer: (pageCtx) => pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text('Generated by: ${_cleanText(generatedByName)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.Text('Page ${pageCtx.pageNumber} of ${pageCtx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
          build: (pageCtx) {
            return [
              // Activity Overview Summary Box for this user
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    buildStatBox('Prospects', uData.prospects.length.toString(), PdfColors.indigo800),
                    buildStatBox('Leads', uData.leads.length.toString(), PdfColors.cyan900),
                    buildStatBox('Comms', uData.communications.length.toString(), PdfColors.purple900),
                    buildStatBox('Deals', uData.pipelines.length.toString(), PdfColors.teal900),
                    buildStatBox('Customers', uData.customers.length.toString(), PdfColors.blue900),
                    buildStatBox('Complaints', uData.complaints.length.toString(), PdfColors.orange900),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              if (uData.customers.isNotEmpty) ...[
                buildSectionHeader('CUSTOMERS ADDED (${uData.customers.length})', PdfColors.blue900),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(5),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headers: ['ID', 'Name', 'Phone', 'Created At'],
                  data: uData.customers.map((c) => [
                    (c['id']?.toString() ?? '').length > 8 ? (c['id']?.toString() ?? '').substring(0, 8) + '...' : (c['id']?.toString() ?? ''),
                    c['customer_name']?.toString() ?? '-',
                    c['phone']?.toString() ?? '-',
                    c['created_at'] != null ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.tryParse(c['created_at']) ?? DateTime.now()) : '-',
                  ]).toList(),
                ),
              ],
              
              pw.SizedBox(height: 10),
              if (uData.pipelines.isNotEmpty) ...[
                buildSectionHeader('DEALS CREATED (${uData.pipelines.length})', PdfColors.teal900),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal900),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(5),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headers: ['Deal ID', 'Customer', 'Product', 'Status'],
                  data: uData.pipelines.map((p) => [
                    (p['id']?.toString() ?? '').length > 8 ? (p['id']?.toString() ?? '').substring(0, 8) + '...' : (p['id']?.toString() ?? ''),
                    p['customers'] != null ? p['customers']['customer_name']?.toString() ?? '-' : '-',
                    p['products'] != null ? p['products']['name']?.toString() ?? '-' : '-',
                    p['status']?.toString().toUpperCase() ?? '-',
                  ]).toList(),
                ),
              ],

              pw.SizedBox(height: 10),
              if (uData.stepAuditLogs.isNotEmpty) ...[
                buildSectionHeader('DEAL STEPS FINISHED (${uData.stepAuditLogs.length})', PdfColors.indigo900),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(5),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headers: ['Deal / Customer', 'Step', 'Action', 'Time'],
                  data: uData.stepAuditLogs.map((s) {
                    final pipeline = s['sales_pipelines'] as Map<String, dynamic>?;
                    final cust = pipeline?['customers'] as Map<String, dynamic>?;
                    final prod = pipeline?['products'] as Map<String, dynamic>?;
                    final cName = cust?['customer_name'] ?? '';
                    final pName = prod?['name'] ?? '';
                    final dealStr = [cName, pName].where((e) => e.isNotEmpty).join(' - ');
                    return [
                      dealStr.isNotEmpty ? dealStr : (s['pipeline_id']?.toString().substring(0, 8) ?? '-'),
                      s['step_name']?.toString().toUpperCase() ?? '-',
                      s['action']?.toString() ?? '-',
                      s['performed_at'] != null ? DateFormat('dd MMM, HH:mm').format(DateTime.tryParse(s['performed_at']) ?? DateTime.now()) : '-',
                    ];
                  }).toList(),
                ),
              ],

              pw.SizedBox(height: 10),
              if (uData.communications.isNotEmpty) ...[
                buildSectionHeader('LEAD COMMUNICATIONS (${uData.communications.length})', PdfColors.purple900),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.purple900),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(5),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headers: ['Lead / Prospect', 'Type', 'Summary', 'Time'],
                  data: uData.communications.map((comm) {
                    final lead = comm['crm_leads'] as Map<String, dynamic>?;
                    final leadName = lead?['prospect_name'] ?? '-';
                    return [
                      leadName,
                      comm['type']?.toString() ?? '-',
                      comm['summary']?.toString() ?? '-',
                      comm['created_at'] != null ? DateFormat('dd MMM, HH:mm').format(DateTime.tryParse(comm['created_at']) ?? DateTime.now()) : '-',
                    ];
                  }).toList(),
                ),
              ],

              pw.SizedBox(height: 10),
              if (uData.leads.isNotEmpty) ...[
                buildSectionHeader('LEADS ADDED (${uData.leads.length})', PdfColors.cyan900),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan900),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(5),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headers: ['Prospect', 'Product', 'Est. Value', 'Status'],
                  data: uData.leads.map((l) => [
                    l['prospect_name']?.toString() ?? '-',
                    l['product_name']?.toString() ?? '-',
                    '₹${l['estimated_value'] ?? 0}',
                    l['status']?.toString() ?? 'New',
                  ]).toList(),
                ),
              ],

              pw.SizedBox(height: 10),
              if (uData.prospects.isNotEmpty) ...[
                buildSectionHeader('PROSPECTS ADDED (${uData.prospects.length})', PdfColors.indigo800),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(5),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headers: ['Prospect Name', 'Phone', 'Company', 'Source', 'Converted', 'Date'],
                  data: uData.prospects.map((pr) => [
                    pr['name']?.toString() ?? '-',
                    pr['phone']?.toString() ?? '-',
                    pr['company']?.toString() ?? '-',
                    pr['source']?.toString() ?? 'Manual',
                    pr['converted_to_lead_id'] != null ? 'Yes (Lead)' : 'No',
                    pr['created_at'] != null ? DateFormat('dd MMM, HH:mm').format(DateTime.tryParse(pr['created_at']) ?? DateTime.now()) : '-',
                  ]).toList(),
                ),
              ],

              pw.SizedBox(height: 10),
              if (uData.conversions.isNotEmpty) ...[
                buildSectionHeader('CONVERSIONS (${uData.conversions.length})', PdfColors.green900),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.green900),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(5),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headers: ['Type', 'Name', 'Details', 'Time'],
                  data: uData.conversions.map((conv) => [
                    conv['type']?.toString() ?? '-',
                    conv['name']?.toString() ?? '-',
                    conv['details']?.toString() ?? '-',
                    conv['time'] != null ? DateFormat('dd MMM, HH:mm').format(DateTime.tryParse(conv['time']) ?? DateTime.now()) : '-',
                  ]).toList(),
                ),
              ],

              pw.SizedBox(height: 10),
              if (uData.complaints.isNotEmpty) ...[
                buildSectionHeader('COMPLAINTS LOGGED / HANDLED (${uData.complaints.length})', PdfColors.orange900),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.orange900),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(5),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headers: ['Ticket ID', 'Title', 'Customer', 'Status'],
                  data: uData.complaints.map((c) => [
                    c['ticket_number']?.toString() ?? (c['id'] != null && c['id'].toString().length > 8 ? c['id'].toString().substring(0, 8) + '...' : '-'),
                    c['title']?.toString() ?? '-',
                    c['customer_name']?.toString() ?? '-',
                    c['status']?.toString().toUpperCase() ?? '-',
                  ]).toList(),
                ),
              ],

              if (uData.customers.isEmpty &&
                  uData.pipelines.isEmpty &&
                  uData.stepAuditLogs.isEmpty &&
                  uData.communications.isEmpty &&
                  uData.leads.isEmpty &&
                  uData.prospects.isEmpty &&
                  uData.conversions.isEmpty &&
                  uData.complaints.isEmpty)
                pw.Text('No activities recorded for this user during this period.', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
            ];
          },
        ),
      );
    }

    return pdf.save();
  }
}
