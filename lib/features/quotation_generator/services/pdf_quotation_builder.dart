// lib/features/quotation_generator/services/pdf_quotation_builder.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/dynamic_annexure_resolver.dart';
import '../config/quote_template_config.dart';
import '../config/quote_type.dart';
import '../models/generator_quotation.dart';
import '../models/generator_company_settings.dart';
import '../models/price_row.dart';
import '../models/tank_line_item.dart';
import '../models/pool_heat_pump_model.dart';
import '../models/all_in_one_model.dart';
import 'price_calculator.dart';

class PdfQuotationBuilder {
  static Future<Uint8List> buildQuotationPdf(
    GeneratorQuotation quotation,
    GeneratorCompanySettings settings,
  ) async {
    final pdf = pw.Document();
    final config = QuoteTemplateConfig.forType(quotation.quoteType);
    final annexureResolver = DynamicAnnexureResolver(
      quoteType: quotation.quoteType,
      hasSpecs: config.hasTechnicalSpecs,
    );
    final annexureEntries = annexureResolver.resolveEntries();

    // 1. Load Fonts
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      final regData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      fontRegular = pw.Font.ttf(regData);
      fontBold = pw.Font.ttf(boldData);
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    // 2. Load Core Images
    final izyheatLogo = await _loadImageBytes('assets/images/izyheat_logo.png');
    final coverImage = await _loadImageBytes(quotation.coverImagePath ?? settings.defaultCoverImagePath ?? 'assets/images/cover_proposal.png');
    final bannerImage = quotation.includeBanner
        ? await _loadImageBytes(quotation.bannerImagePath ?? settings.defaultBannerImagePath ?? 'assets/images/insiya_banner.png')
        : null;
    final stampImage = await _loadImageBytes(settings.stampImagePath ?? 'assets/images/company_stamp.png');
    final fbIcon = await _loadImageBytes('assets/images/facebook_icon.png');
    final igIcon = await _loadImageBytes('assets/images/instagram_icon.png');

    // Product Images for the final page
    final List<Uint8List> productImages = [];
    if (quotation.includeProductImagePage) {
      if (quotation.productImagePaths.isNotEmpty) {
        for (final p in quotation.productImagePaths) {
          final b = await _loadImageBytes(p);
          if (b != null) productImages.add(b);
        }
      } else {
        final b = await _loadImageBytes(quotation.model.defaultImagePath);
        if (b != null) productImages.add(b);
      }
    }

    // Colors
    final navyColor = PdfColor.fromHex('#1E3A5F');
    final blueLink = PdfColor.fromHex('#1E88E5');
    final paleGreen = PdfColor.fromHex('#9CCC65');
    final darkGold = PdfColor.fromHex('#F4B400');
    final greyText = PdfColor.fromHex('#555555');

    // ─── REUSABLE HEADER / FOOTER BUILDERS ─────────────────────────────────

    pw.Widget buildHeader() {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 14,
                  height: 48,
                  color: paleGreen,
                  margin: const pw.EdgeInsets.only(right: 8),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      settings.companyName,
                      style: pw.TextStyle(
                        color: navyColor,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'ADDRESS: - ${settings.shortAddress}',
                      style: pw.TextStyle(fontSize: 7.5, color: greyText, fontStyle: pw.FontStyle.italic),
                    ),
                    pw.Text(
                      'EMAIL ID: - ${settings.companyEmail}',
                      style: pw.TextStyle(fontSize: 7.5, color: greyText, fontStyle: pw.FontStyle.italic),
                    ),
                    pw.Text(
                      'CONTACT: ${settings.companyPhone}',
                      style: pw.TextStyle(fontSize: 7.5, color: greyText, fontStyle: pw.FontStyle.italic),
                    ),
                    pw.Row(
                      children: [
                        pw.Text(
                          'WEBSITE: - ',
                          style: pw.TextStyle(fontSize: 7.5, color: greyText, fontStyle: pw.FontStyle.italic),
                        ),
                        pw.Text(
                          settings.companyWebsite,
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            color: blueLink,
                            fontStyle: pw.FontStyle.italic,
                            decoration: pw.TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (izyheatLogo != null)
              pw.Container(
                width: 115,
                height: 42,
                child: pw.Image(pw.MemoryImage(izyheatLogo), fit: pw.BoxFit.contain),
              ),
          ],
        ),
      );
    }

    pw.Widget buildFooter(int pageNumber) {
      final double totalWidth = PdfPageFormat.a4.width - 36 - 36;
      const double barHeight = 11.0;
      const double slantWidth = 7.0;
      const double gap = 6.0;
      final blueColor = PdfColor.fromHex('#1C5D97');
      final goldColor = PdfColor.fromHex('#D1AA4B');

      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 8),
        width: totalWidth,
        height: barHeight,
        child: pw.Stack(
          children: [
            pw.CustomPaint(
              size: PdfPoint(totalWidth, barHeight),
              painter: (canvas, size) {
                final w = size.x;
                final h = size.y;
                final blueWidth = w * 0.44;

                // Deep Blue polygon on left
                canvas.setFillColor(blueColor);
                canvas.moveTo(0, 0);
                canvas.lineTo(0, h);
                canvas.lineTo(blueWidth + slantWidth, h);
                canvas.lineTo(blueWidth, 0);
                canvas.closePath();
                canvas.fillPath();

                // Gold polygon on right
                canvas.setFillColor(goldColor);
                canvas.moveTo(blueWidth + gap, 0);
                canvas.lineTo(blueWidth + slantWidth + gap, h);
                canvas.lineTo(w, h);
                canvas.lineTo(w, 0);
                canvas.closePath();
                canvas.fillPath();
              },
            ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(right: 28),
                child: pw.Text(
                  '$pageNumber',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    int nextFooterPage = 1;
    final offerLetterPage = nextFooterPage++; // 1
    final priceSchedulePage = nextFooterPage++; // 2
    final int? specPage = config.hasTechnicalSpecs ? nextFooterPage++ : null; // 3 or null
    final termsPage = nextFooterPage++; // 4 or 3
    final acceptPage = nextFooterPage++; // 5 or 4
    final int? showcasePage = (bannerImage != null || productImages.isNotEmpty) ? nextFooterPage++ : null; // 6 or 5 or null

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 1: COVER
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          final custSalutation = quotation.salutation.isNotEmpty ? '${quotation.salutation} ' : '';
          return pw.Stack(
            children: [
              if (coverImage != null)
                pw.Positioned.fill(
                  child: pw.Image(pw.MemoryImage(coverImage), fit: pw.BoxFit.cover),
                )
              else
                pw.Positioned.fill(
                  child: pw.Container(color: navyColor),
                ),
              // Customer Name & Address overlay
              pw.Positioned(
                bottom: 155,
                left: 36,
                right: 36,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'TO,',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      '$custSalutation${quotation.customerName.toUpperCase()}',
                      style: pw.TextStyle(
                        color: darkGold,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Add - ${quotation.customerAddress}',
                      style: pw.TextStyle(
                        color: darkGold,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 2: OFFER LETTER (EXACT REFERENCE DESIGN)
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 24, 36, 20),
        build: (context) {
          final dateStr = DateFormat('dd/MM/yyyy').format(quotation.date);
          final custSalutation = quotation.salutation.isNotEmpty ? '${quotation.salutation.toUpperCase()} ' : '';
          final customerNameUpper = quotation.customerName.toUpperCase();

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildHeader(),
              pw.SizedBox(height: 6),

              // Metadata block matching Reference Image 3
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Left side: To, Customer Name, Address
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('To,', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text(
                          '$custSalutation$customerNameUpper',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Add- ${quotation.customerAddress}',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                      ],
                    ),
                  ),

                  // Middle: QUOTATION
                  pw.Expanded(
                    flex: 3,
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 10),
                      child: pw.Center(
                        child: pw.Text(
                          'QUOTATION',
                          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ),
                  ),

                  // Right side: DATE, Quote Ref No, Sales/Ref, Mob. No
                  pw.Expanded(
                    flex: 4,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            'DATE- $dateStr',
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Row(
                          children: [
                            pw.SizedBox(
                              width: 65,
                              child: pw.Text('Quote Ref No', style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Text(': ${quotation.quoteRefNo}', style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                        pw.Row(
                          children: [
                            pw.SizedBox(
                              width: 65,
                              child: pw.Text('Sales/Ref', style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Text(': ${quotation.salesRef}', style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                        pw.Row(
                          children: [
                            pw.SizedBox(
                              width: 65,
                              child: pw.Text('Mob. No', style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Text(': ${quotation.salesMobile}', style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // Subject: matching Reference Image 3
              pw.RichText(
                text: pw.TextSpan(
                  text: 'Subject: ',
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  children: [
                    pw.TextSpan(
                      text: quotation.subjectLine,
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // Salutation & Intro
              pw.Text('Dear Sir', style: const pw.TextStyle(fontSize: 8.5)),
              pw.SizedBox(height: 6),
              pw.Text(
                '    We thank you for the discussion regarding the supply of Energy Efficient "IZYHEAT" Heat Pump Water Heating Solutions for your Project. We would like to briefly present a summary of the technology that we propose as well as related cost benefits that you would derive from our solutions in response to detailed study Discussion; we are submitting our Quotation along with specifications suitable to your requirement.',
                style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.3),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                '    Please find attached the brief presentation with summary of the technology that we propose as well as related cost benefits that you would derive from our solutions. Further we are pleased to attach herewith a quotation for your reference & speedy decision.',
                style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.3),
                textAlign: pw.TextAlign.justify,
              ),

              pw.SizedBox(height: 10),

              // COMPANY PROFILE
              pw.Text(
                'COMPANY PROFILE:',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '    "${settings.companyName}", under the brand Name "${settings.brandName}" Heat Pump the manufacturers of Heat Pump System is a 15 year old company that has been a market leader and a pioneer in the Heat Pump water heater system industry. It is one of the leading brands of water heaters in India and stands for Quality, Reliability and Performance. It is in house product since 2008.',
                style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.3),
                textAlign: pw.TextAlign.justify,
              ),

              pw.SizedBox(height: 12),

              // Annexures list matching Reference Image 3
              ...annexureEntries.map((e) {
                String roman = e.romanNumeral;
                if (!roman.contains('–') && !roman.contains('-')) {
                  roman = roman.replaceFirst('Annexure ', 'Annexure – ');
                }
                String desc;
                if (e.romanNumeral == 'Annexure I' || e.romanNumeral.endsWith(' I')) {
                  desc = 'PRICE AND EXCLUSIONS ( Offer 1 )';
                } else if (e.title.contains('Technical') || e.title.contains('Specifications')) {
                  if (quotation.quoteType == QuoteType.hpWithTank) {
                    desc = 'Technical Specifications. ( Heat Pump & Tank)';
                  } else if (quotation.quoteType == QuoteType.hpOnly) {
                    desc = 'Technical Specifications (Heat Pump)';
                  } else if (quotation.quoteType == QuoteType.tankOnly) {
                    desc = 'Technical Specifications (Storage Tank)';
                  } else if (quotation.quoteType == QuoteType.swimmingPool) {
                    desc = 'Technical Specifications (Swimming Pool Heat Pump)';
                  } else {
                    desc = 'Technical Specifications. (${quotation.model.modelName})';
                  }
                } else {
                  desc = 'Commercial terms and conditions & Warranty.';
                }
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 16, bottom: 2.5),
                  child: pw.Text(
                    '$roman: $desc',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                );
              }),

              pw.SizedBox(height: 12),

              // Signoff & Contact Details matching Reference Image 3
              pw.Text(
                settings.companyName,
                style: pw.TextStyle(
                  color: navyColor,
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Mob: ${settings.companyPhone} / ${settings.companyPhone2}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Row(
                children: [
                  pw.Text('Web: ', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    settings.companyWebsite,
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: blueLink,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ],
              ),
              pw.Text('Email: ${settings.companyEmail}', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 6),
              pw.Row(
                children: [
                  pw.Text('Follow us on:   ', style: const pw.TextStyle(fontSize: 8)),
                  if (fbIcon != null)
                    pw.Container(
                      width: 14,
                      height: 14,
                      margin: const pw.EdgeInsets.only(right: 6),
                      child: pw.Image(pw.MemoryImage(fbIcon)),
                    ),
                  if (igIcon != null)
                    pw.Container(
                      width: 14,
                      height: 14,
                      child: pw.Image(pw.MemoryImage(igIcon)),
                    ),
                ],
              ),

              pw.Spacer(),
              buildFooter(offerLetterPage),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 3: ANNEXURE I (PRICE SCHEDULE)
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 24),
        build: (context) {
          final annexureTitle = annexureEntries.isNotEmpty
              ? '${annexureEntries[0].romanNumeral.toUpperCase()} : PRICE SCHEDULE'
              : 'ANNEXURE I : PRICE SCHEDULE';

          final hasDiscountCol = config.priceColumnKeys.contains('discount');
          final rows = quotation.priceRows;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildHeader(),
              pw.Text(
                annexureTitle,
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
              ),
              pw.SizedBox(height: 8),
              // Price Schedule Table
              pw.Table(
                border: const pw.TableBorder(
                  left: pw.BorderSide(color: PdfColors.black, width: 0.6),
                  right: pw.BorderSide(color: PdfColors.black, width: 0.6),
                  top: pw.BorderSide(color: PdfColors.black, width: 0.6),
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.6),
                  horizontalInside: pw.BorderSide(color: PdfColors.black, width: 0.6),
                  verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.6),
                ),
                columnWidths: hasDiscountCol
                    ? {
                        0: const pw.FixedColumnWidth(26),
                        1: const pw.FlexColumnWidth(3.0),
                        2: const pw.FixedColumnWidth(32),
                        3: const pw.FixedColumnWidth(55),
                        4: const pw.FixedColumnWidth(65),
                        5: const pw.FixedColumnWidth(70),
                      }
                    : {
                        0: const pw.FixedColumnWidth(26),
                        1: const pw.FlexColumnWidth(3.1),
                        2: const pw.FixedColumnWidth(35),
                        3: const pw.FixedColumnWidth(28),
                        4: const pw.FixedColumnWidth(65),
                        5: const pw.FixedColumnWidth(70),
                      },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8E8E8')),
                    children: hasDiscountCol
                        ? [
                            _th('SR\nNO'),
                            _th('DESCRIPTION'),
                            _th('QTY'),
                            _th('RATE'),
                            _th('DISCOUNT'),
                            _th('TOTAL'),
                          ]
                        : [
                            _th('SR\nNO'),
                            _th('DESCRIPTION'),
                            _th('UNIT'),
                            _th('QTY'),
                            _th('RATE'),
                            _th('TOTAL'),
                          ],
                  ),
                  ...rows.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final r = entry.value;
                    final srText = r.serialNo.isNotEmpty ? r.serialNo : ((idx + 1) < 10 ? '0${idx + 1}' : '${idx + 1}');

                    String rateStr;
                    String totalStr;

                    if (r.status == PriceRowStatus.included) {
                      rateStr = 'Included';
                      totalStr = 'Included';
                    } else if (r.status == PriceRowStatus.extra) {
                      rateStr = 'Extra';
                      totalStr = 'Extra';
                    } else if (r.status == PriceRowStatus.na) {
                      rateStr = 'NA';
                      totalStr = 'NA';
                    } else if (r.status == PriceRowStatus.customText) {
                      rateStr = r.customStatusText ?? 'Custom';
                      totalStr = r.customStatusText ?? 'Custom';
                    } else {
                      rateStr = PriceCalculator.formatIndianCurrency(r.rate, includeSymbol: false);
                      totalStr = PriceCalculator.formatIndianCurrency(r.amount, includeSymbol: false);
                    }

                    if (hasDiscountCol) {
                      final discStr = r.discountAmount != null && r.discountAmount! > 0
                          ? PriceCalculator.formatIndianCurrency(r.discountAmount!, includeSymbol: false)
                          : '-';
                      return pw.TableRow(
                        children: [
                          _tc(srText, center: true),
                          _tc(r.description),
                          _tc('${r.qty}', center: true),
                          _tc(rateStr, center: true),
                          _tc(discStr, center: true),
                          _tc(totalStr, center: true),
                        ],
                      );
                    } else {
                      return pw.TableRow(
                        children: [
                          _tc(srText, center: true),
                          _tc(r.description),
                          _tc(r.unitLabel ?? 'NOS', center: true),
                          _tc('${r.qty}', center: true),
                          _tc(rateStr, center: true),
                          _tc(totalStr, center: true),
                        ],
                      );
                    }
                  }),
                ],
              ),
              // Totals Table directly beneath (matching Reference Image 2: merged initial columns, right-aligned labels)
              pw.Table(
                border: const pw.TableBorder(
                  left: pw.BorderSide(color: PdfColors.black, width: 0.6),
                  right: pw.BorderSide(color: PdfColors.black, width: 0.6),
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.6),
                  horizontalInside: pw.BorderSide(color: PdfColors.black, width: 0.6),
                  verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.6),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.0),
                  1: const pw.FixedColumnWidth(65),
                  2: const pw.FixedColumnWidth(70),
                },
                children: [
                  _buildTotalRow(
                    'Sub Total',
                    PriceCalculator.formatIndianCurrency(quotation.subtotal),
                  ),
                  _buildTotalRow(
                    'GST %',
                    PriceCalculator.formatIndianCurrency(quotation.gstAmount),
                  ),
                  if (quotation.hasBuyback) ...[
                    _buildTotalRow(
                      'Gross Total',
                      PriceCalculator.formatIndianCurrency(quotation.grossTotal),
                    ),
                    _buildTotalRow(
                      'Less: Buyback (${quotation.buybackDescription?.isNotEmpty == true ? quotation.buybackDescription : "Old System"})',
                      '-${PriceCalculator.formatIndianCurrency(quotation.buybackTotal)}',
                    ),
                    _buildTotalRow(
                      'TOTAL',
                      PriceCalculator.formatIndianCurrency(quotation.netPayable),
                      isUnderlined: true,
                    ),
                  ] else ...[
                    _buildTotalRow(
                      'TOTAL',
                      PriceCalculator.formatIndianCurrency(quotation.grandTotal),
                      isUnderlined: true,
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Rupees in Words: ${PriceCalculator.numberToWords(quotation.netPayable)}',
                style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
              ),
              pw.SizedBox(height: 12),
              // Commercial terms preview
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
                ),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('COMMERCIAL TERMS & CONDITIONS:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                    pw.SizedBox(height: 4),
                    pw.Text('1. Payment Terms: ${quotation.paymentTermsText}', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text('2. Validity: Quotation valid for ${quotation.validityDays} days.', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text('3. Delivery: As mutually agreed upon receipt of clear Purchase Order & advance.', style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
              ),
              pw.Spacer(),
              buildFooter(priceSchedulePage),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 4: ANNEXURE II (TECHNICAL SPECIFICATIONS) - ONLY IF PRESENT
    // ─────────────────────────────────────────────────────────────────────────
    if (config.hasTechnicalSpecs) {
      pdf.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 24),
          build: (context) {
            final specEntry = annexureEntries.firstWhere(
              (e) => e.romanNumeral == 'Annexure II',
              orElse: () => const AnnexureEntry(romanNumeral: 'Annexure II', title: 'Technical Specifications', pageLabel: 'Page 4', section: DocSection.specHeatPump),
            );

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                buildHeader(),
                pw.Text(
                  '${specEntry.romanNumeral.toUpperCase()} : ${specEntry.title.toUpperCase()}',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
                ),
                pw.SizedBox(height: 8),

                // Render specs based on config.specMode
                if (config.specMode == SpecMode.heatPumpAndTank) ...[
                  // Heat Pump Spec
                  pw.Text(
                    'TECHNICAL SPECIFICATION FOR : ${settings.brandName} HEAT PUMP – ${quotation.model.modelName}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(28),
                      1: const pw.FlexColumnWidth(2.5),
                      2: const pw.FlexColumnWidth(2.5),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8E8E8')),
                        children: [_th('SL'), _th('DESCRIPTION'), _th('SPECIFICATION')],
                      ),
                      ..._buildHpSpecRows(quotation),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  // Tank Spec
                  ..._buildTankSpecTables(quotation),
                ] else if (config.specMode == SpecMode.heatPumpOnly) ...[
                  pw.Text(
                    'TECHNICAL SPECIFICATION FOR : ${settings.brandName} HEAT PUMP – ${quotation.model.modelName}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(28),
                      1: const pw.FlexColumnWidth(2.5),
                      2: const pw.FlexColumnWidth(2.5),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8E8E8')),
                        children: [_th('SL'), _th('DESCRIPTION'), _th('SPECIFICATION')],
                      ),
                      ..._buildHpSpecRows(quotation),
                    ],
                  ),
                ] else if (config.specMode == SpecMode.tankOnly) ...[
                  ..._buildTankSpecTables(quotation),
                ] else if (config.specMode == SpecMode.swimmingPool) ...[
                  pw.Text(
                    'TECHNICAL SPECIFICATION FOR : SWIMMING POOL HEAT PUMP – ${quotation.poolModel?.modelName ?? "IZ-35SP"}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  _buildPoolSpecTable(quotation.poolModel ?? PoolHeatPumpModel.defaultModel()),
                ] else if (config.specMode == SpecMode.allInOne) ...[
                  pw.Text(
                    'TECHNICAL SPECIFICATION FOR : ALL IN ONE HEAT PUMP – ${quotation.allInOneModel?.modelName ?? "IZ-200A"}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  _buildAllInOneSpecTable(quotation.allInOneModel ?? AllInOneModel.defaultFloorModel()),
                ],

                pw.Spacer(),
                buildFooter(specPage!),
              ],
            );
          },
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TERMS & CONDITIONS PAGE
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 24),
        build: (context) {
          final termsEntry = annexureEntries.firstWhere(
            (e) => e.section == DocSection.termsAndConditions,
            orElse: () => const AnnexureEntry(romanNumeral: 'Annexure III', title: 'Terms & Conditions', pageLabel: 'Page 5', section: DocSection.termsAndConditions),
          );

          String warrantyText;
          if (quotation.quoteType == QuoteType.allInOneFloor || quotation.quoteType == QuoteType.allInOneWall) {
            warrantyText = '${quotation.warrantyHpYears} YEAR FOR HEAT PUMP AND 5 YEARS OF COMPRESSOR.';
          } else if (quotation.quoteType == QuoteType.partsOnly) {
            warrantyText = '1 YEAR FOR REPLACED PARTS.';
          } else if (quotation.quoteType == QuoteType.tankOnly) {
            warrantyText = '${quotation.warrantyTankYears} YEARS FOR TANK.';
          } else if (quotation.quoteType == QuoteType.hpOnly || quotation.quoteType == QuoteType.swimmingPool) {
            warrantyText = '${quotation.warrantyHpYears} YEAR FOR HEAT PUMP.';
          } else {
            warrantyText = '${quotation.warrantyHpYears} YEAR FOR HEAT PUMP, ${quotation.warrantyTankYears} YEARS FOR TANK.';
          }

          // Build dynamic terms list
          final dynamicTerms = <String>[];
          // Check power phase term for HP types
          if (config.catalogSource == CatalogSource.heatPump || config.catalogSource == CatalogSource.allInOne || config.catalogSource == CatalogSource.pool) {
            final supplyStr = quotation.model.powerSupply.toLowerCase();
            final is3Phase = supplyStr.contains('3phase') || supplyStr.contains('415v') || supplyStr.contains('380v');
            final phaseLine = is3Phase
                ? 'Proper 3 Phase 415V power should be arranged where you install the heat pump.'
                : 'Proper 1 Phase 220V power should be arranged where you install the heat pump.';

            // Check if user already provided terms
            if (quotation.termsAndConditions.isEmpty) {
              dynamicTerms.add(phaseLine);
              dynamicTerms.addAll(config.defaultTerms);
            } else {
              // Ensure phase line reflects the model if default placeholder exists
              for (final t in quotation.termsAndConditions) {
                if (t.toLowerCase().contains('proper 1 / 3 phase') || t.toLowerCase().contains('proper 1/3 phase')) {
                  dynamicTerms.add(phaseLine);
                } else {
                  dynamicTerms.add(t);
                }
              }
            }
          } else {
            dynamicTerms.addAll(quotation.termsAndConditions.isNotEmpty ? quotation.termsAndConditions : config.defaultTerms);
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildHeader(),
              pw.Text(
                '${termsEntry.romanNumeral.toUpperCase()} : COMMERCIAL TERMS AND CONDITIONS & WARRANTY.',
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
              ),
              pw.SizedBox(height: 10),
              // Payment terms
              pw.Text('Payment Terms :', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text(quotation.paymentTermsText, style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 10),
              // Warranty
              pw.Text('WARRANTY: - $warrantyText', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              // Other terms & conditions
              pw.Text('Other Terms & Conditions:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              ...dynamicTerms.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final text = entry.value;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3, left: 8),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('$idx. ', style: const pw.TextStyle(fontSize: 8)),
                      pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 8))),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 8),
              // Validity
              pw.Text('Validity Of Offer :', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(
                'Prices quoted are firm and generally valid for ${quotation.validityDays} days from date of offer. After this prices are subject to your confirmation.',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 10),
              // Bank Details
              pw.Text('OUR BANK ACCOUNT DETAILS:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
              pw.SizedBox(height: 3),
              pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(95),
                  1: const pw.FixedColumnWidth(14),
                  2: const pw.FlexColumnWidth(),
                },
                children: [
                  _bankRow('Account Name', settings.bankAccountName),
                  _bankRow('Bank Name', '${settings.bankName},'),
                  _bankRow('Account Number', settings.bankAccountNumber),
                  _bankRow('Branch', '${settings.bankBranch},'),
                  _bankRow('IFSC Code', settings.bankIfsc),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'We hope you will find our quotation very competitive and favor us with your valued order at early date and indulge.',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Thanks & Regards', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Text('For ${settings.companyName}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              if (stampImage != null)
                pw.Container(
                  width: 60,
                  height: 60,
                  child: pw.Image(pw.MemoryImage(stampImage)),
                ),
              pw.Spacer(),
              buildFooter(termsPage),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE: ACCEPTANCE LETTER
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 24),
        build: (context) {
          final dateStr = DateFormat('dd/MM/yyyy').format(quotation.date);
          final totalFormatted = PriceCalculator.formatIndianCurrency(quotation.netPayable);
          final custSalutation = quotation.salutation.isNotEmpty ? '${quotation.salutation} ' : '';

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              buildHeader(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'QUOTATION ACCEPTANCE LETTER',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text('Customer Name: $custSalutation${quotation.customerName}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text('Customer Address: ${quotation.customerAddress}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 10),
              pw.Text('Subject: ${quotation.acceptanceSubjectLine}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Quotation Ref: ${quotation.quoteRefNo}',
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              if (quotation.quoteType != QuoteType.partsOnly && quotation.quoteType != QuoteType.tankOnly) ...[
                pw.Text('Make: ${settings.brandName}', style: const pw.TextStyle(fontSize: 8.5)),
                if (quotation.quoteType == QuoteType.swimmingPool)
                  pw.Text('Model: ${quotation.poolModel?.modelName ?? "IZ-35SP"}', style: const pw.TextStyle(fontSize: 8.5))
                else if (quotation.quoteType == QuoteType.allInOneFloor || quotation.quoteType == QuoteType.allInOneWall)
                  pw.Text('Model: ${quotation.allInOneModel?.modelName ?? "IZ-200A"}', style: const pw.TextStyle(fontSize: 8.5))
                else
                  pw.Text('Model: ${quotation.model.modelName}', style: const pw.TextStyle(fontSize: 8.5)),
                pw.SizedBox(height: 8),
              ],
              pw.Text(
                'We hereby confirm and accept the quotation and specifications as outlined above for the net payable value of $totalFormatted (inclusive of GST).',
                style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.4),
              ),
              pw.SizedBox(height: 24),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Authorized Customer Signatory:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 40),
                      pw.Container(width: 140, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('Name & Stamp', style: const pw.TextStyle(fontSize: 7.5)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('For ${settings.companyName}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      if (stampImage != null)
                        pw.Container(width: 55, height: 55, child: pw.Image(pw.MemoryImage(stampImage)))
                      else
                        pw.SizedBox(height: 40),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 7.5)),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              buildFooter(acceptPage),
            ],
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE: BANNER & SHOWCASE
    // ─────────────────────────────────────────────────────────────────────────
    if (bannerImage != null || productImages.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 24),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                buildHeader(),
                pw.SizedBox(height: 10),
                if (bannerImage != null)
                  pw.Container(
                    height: 180,
                    width: double.infinity,
                    child: pw.Image(pw.MemoryImage(bannerImage), fit: pw.BoxFit.contain),
                  ),
                pw.SizedBox(height: 14),
                if (productImages.isNotEmpty) ...[
                  pw.Text('PRODUCT SHOWCASE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: productImages.take(2).map((imgBytes) {
                      return pw.Container(
                        width: 190,
                        height: 190,
                        margin: const pw.EdgeInsets.symmetric(horizontal: 8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Image(pw.MemoryImage(imgBytes), fit: pw.BoxFit.contain),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                pw.Spacer(),
                buildFooter(showcasePage!),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  // ─── SPEC HELPERS ─────────────────────────────────────────────────────────

  static List<pw.TableRow> _buildHpSpecRows(GeneratorQuotation q) {
    final m = q.model;
    final rowsData = [
      ['01', 'Heat Pump Model', m.modelName],
      ['02', 'Size (W x D x H) mm', m.specs['Size (W x D x H)'] ?? '936x385x550mm'],
      ['03', 'Rated Heating Capacity', m.ratedHeatingCapacity],
      ['04', 'Power Supply', m.powerSupply],
      ['05', 'Rated Input Power', m.specs['Rated Input Power'] ?? '0.86kw'],
      ['06', 'Rated COP', m.specs['Rated COP'] ?? '4.18'],
      ['07', 'Rated Water Yield', m.specs['Rated Water Yield'] ?? '78 L/h'],
      ['08', 'Max Outlet Water Temperature', m.specs['Max Outlet Water Temperature'] ?? '60°C'],
      ['09', 'Water Flow Noise', m.specs['Water Flow Noise'] ?? '<=47dB(A)'],
      ['10', 'Condenser', m.specs['Condenser'] ?? 'Shell and tube heat exchanger'],
      ['11', 'Refrigerant', m.specs['Refrigerant'] ?? 'R134A/410A'],
      ['12', 'Operating ambient Temp', m.specs['Operating ambient Temp'] ?? '-15~43°C'],
      ['13', 'Compressor', m.specs['Compressor'] ?? 'SINGLE'],
    ];

    return rowsData.map((r) {
      return pw.TableRow(
        children: [
          _tc(r[0], center: true),
          _tc(r[1]),
          _tc(r[2]),
        ],
      );
    }).toList();
  }

  static List<pw.Widget> _buildTankSpecTables(GeneratorQuotation q) {
    final widgets = <pw.Widget>[];
    final items = q.tankLines.isNotEmpty
        ? q.tankLines
        : [
            TankLineItem(
              id: 'tank_1',
              capacityLitres: q.tankCapacityLitres,
              qty: q.tankQty,
              isPressurized: q.isTankPressurized,
              rate: q.tankRate,
              innerTankMaterial: q.tankSpec.innerTankMaterial,
              innerTankThickness: q.tankSpec.innerTankThickness,
              outerCladdingMaterial: q.tankSpec.outerCladdingMaterial,
              insulationMaterial: q.tankSpec.insulationMaterial,
            )
          ];

    for (final item in items) {
      final press = item.isPressurized ? 'PRESSURIZED' : 'NON-PRESSURIZED';
      final moc = item.innerTankMaterial.toUpperCase();
      final title = '${item.capacityLitres} Ltr / HOT WATER STORAGE / $moc / $press TANK.';

      widgets.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'TECHNICAL SPECIFICATION FOR : $title',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
            ),
            pw.SizedBox(height: 3),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
              columnWidths: {
                0: const pw.FixedColumnWidth(26),
                1: const pw.FlexColumnWidth(2.2),
                2: const pw.FlexColumnWidth(2.8),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8E8E8')),
                  children: [_th('SL'), _th('DESCRIPTION'), _th('SPECIFICATION')],
                ),
                pw.TableRow(children: [_tc('01', center: true), _tc('Capacity and Thickness'), _tc('${item.capacityLitres} Litre & ${item.innerTankThickness} Inner & ${item.outerCladdingThickness} Outer')]),
                pw.TableRow(children: [_tc('02', center: true), _tc('Operating pressure'), _tc(item.isPressurized ? '0.3 to 0.4 Mpa (4 to 5 kg/cm²)' : 'Atmospheric')]),
                pw.TableRow(children: [_tc('03', center: true), _tc('Testing Pressure'), _tc(item.isPressurized ? '0.7 to 0.8 Mpa (7 to 8 kg/cm²)' : 'Atmospheric')]),
                pw.TableRow(children: [_tc('04', center: true), _tc('Hot Water Inlet/ outlet'), _tc('As per Site Requirement')]),
                pw.TableRow(children: [_tc('05', center: true), _tc('Heat Pump Circulation'), _tc('As per Site Requirement')]),
                pw.TableRow(children: [_tc('06', center: true), _tc('Outer Tank Insulation'), _tc('${item.insulationThickness} ${item.insulationMaterial}')]),
                pw.TableRow(children: [_tc('07', center: true), _tc('Temperature drop'), _tc('Within 3°C to 4°C in 24 Hours')]),
                pw.TableRow(children: [_tc('08', center: true), _tc('Inner and outer Tank'), _tc('Inner ${item.innerTankMaterial} and outer ${item.outerCladdingMaterial}')]),
                pw.TableRow(children: [_tc('09', center: true), _tc('Tank direction'), _tc('Vertical/Horizontal')]),
                pw.TableRow(children: [_tc('10', center: true), _tc('Other'), _tc('Drain, Air Vent, Temp Sensor Pocket, Electric Heater Flange')]),
              ],
            ),
            pw.SizedBox(height: 8),
          ],
        ),
      );
    }

    return widgets;
  }

  static pw.Widget _buildPoolSpecTable(PoolHeatPumpModel m) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8E8E8')),
          children: [_th('SL'), _th('DESCRIPTION'), _th('SPECIFICATION')],
        ),
        pw.TableRow(children: [_tc('01', center: true), _tc('Model'), _tc(m.modelName)]),
        pw.TableRow(children: [_tc('02', center: true), _tc('Heating Capacity'), _tc(m.heatingCapacity)]),
        pw.TableRow(children: [_tc('03', center: true), _tc('Power Input'), _tc(m.powerInput)]),
        pw.TableRow(children: [_tc('04', center: true), _tc('Power Supply'), _tc(m.powerSupply)]),
        pw.TableRow(children: [_tc('05', center: true), _tc('Max Power Input / Current'), _tc('${m.maxPowerInput} / ${m.maxCurrent}')]),
        pw.TableRow(children: [_tc('06', center: true), _tc('Water Flow Rate'), _tc(m.waterFlowRate)]),
        pw.TableRow(children: [_tc('07', center: true), _tc('Noise'), _tc(m.noise)]),
        pw.TableRow(children: [_tc('08', center: true), _tc('Heat Exchanger'), _tc(m.heatExchanger)]),
        pw.TableRow(children: [_tc('09', center: true), _tc('Refrigerant'), _tc(m.refrigerant)]),
        pw.TableRow(children: [_tc('10', center: true), _tc('Ambient Working Temp'), _tc(m.workingTempRange)]),
      ],
    );
  }

  static pw.Widget _buildAllInOneSpecTable(AllInOneModel m) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8E8E8')),
          children: [_th('SL'), _th('DESCRIPTION'), _th('SPECIFICATION')],
        ),
        pw.TableRow(children: [_tc('01', center: true), _tc('Product Dimension'), _tc(m.productDimension)]),
        pw.TableRow(children: [_tc('02', center: true), _tc('Tank Volume'), _tc('${m.tankVolumeLtr} Ltr')]),
        pw.TableRow(children: [_tc('03', center: true), _tc('Power Supply'), _tc(m.powerSupply)]),
        pw.TableRow(children: [_tc('04', center: true), _tc('Heating Rate / Water Yield'), _tc(m.waterYield)]),
        pw.TableRow(children: [_tc('05', center: true), _tc('COP'), _tc(m.cop.toString())]),
        pw.TableRow(children: [_tc('06', center: true), _tc('Compressor'), _tc(m.compressor)]),
        pw.TableRow(children: [_tc('07', center: true), _tc('Refrigerant'), _tc(m.refrigerant)]),
        pw.TableRow(children: [_tc('08', center: true), _tc('Max Outlet Water Temp'), _tc(m.maxOutletWaterTemp)]),
        pw.TableRow(children: [_tc('09', center: true), _tc('Ambient Temperature'), _tc(m.ambientTemperature)]),
        pw.TableRow(children: [_tc('10', center: true), _tc('Water Tank Material'), _tc(m.waterTankMaterial)]),
        pw.TableRow(children: [_tc('11', center: true), _tc('Net Weight'), _tc(m.netWeight)]),
      ],
    );
  }

  // ─── HELPER TABLE ROW BUILDERS ─────────────────────────────────────────────

  static pw.Widget _th(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  static pw.Widget _tc(String text, {bool center = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static pw.TableRow _buildTotalRow(
    String label,
    String amount, {
    bool isUnderlined = false,
  }) {
    return pw.TableRow(
      children: [
        // Spanned empty area covering initial columns with NO internal dividing lines
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
        ),
        // Column 1: Label ("Sub Total", "GST %", "TOTAL") aligned to right matching column 4
        pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              decoration: isUnderlined ? pw.TextDecoration.underline : pw.TextDecoration.none,
            ),
          ),
        ),
        // Column 2: Amount centered matching column 5
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
          child: pw.Text(
            amount,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  static pw.TableRow _bankRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(':-', style: const pw.TextStyle(fontSize: 8)),
        pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      ],
    );
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
