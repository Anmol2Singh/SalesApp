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
import '../models/price_item.dart';
import '../models/tank_line_item.dart';
import '../models/pool_heat_pump_model.dart';
import '../models/all_in_one_model.dart';
import 'price_calculator.dart';
import 'qg_payment_sentence_builder.dart';

class PdfQuotationBuilder {
  static Future<Uint8List> buildQuotationPdf(
    GeneratorQuotation quotation,
    GeneratorCompanySettings settings,
  ) async {
    final pdf = pw.Document();
    final config = QuoteTemplateConfig.forType(quotation.quoteType);
    final hasTank = quotation.hasTank;
    final dateStr = DateFormat('dd/MM/yyyy').format(quotation.date);

    final annexureResolver = DynamicAnnexureResolver(
      quoteType: quotation.quoteType,
      hasSpecs: config.hasTechnicalSpecs,
    );
    final annexureEntries = annexureResolver.resolveEntries();

    // Dynamic Page Numbering
    int nextFooterPage = 1;
    final offerLetterPage = nextFooterPage++; // 1
    final priceSchedulePage = nextFooterPage++; // 2
    final int? tankSpecPage = (quotation.quoteType == QuoteType.hpWithTank && hasTank) ? nextFooterPage++ : null; // 3 or null
    final termsPage = nextFooterPage++; // 4 if hasTank, else 3
    final acceptPage = nextFooterPage++; // 5 if hasTank, else 4
    final int? showcasePage = quotation.includeProductImagePage ? nextFooterPage++ : null; // 6 if hasTank, else 5

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
    final product38c = await _loadImageBytes('assets/images/product_iz_38c.png');

    // Product Images for the final page
    final List<Uint8List> productImages = [];
    if (quotation.includeProductImagePage) {
      if (quotation.productImagePaths.isNotEmpty) {
        for (final p in quotation.productImagePaths) {
          final b = await _loadImageBytes(p);
          if (b != null) productImages.add(b);
        }
      } else if (product38c != null && (quotation.model.modelName.contains('38') || quotation.quoteType == QuoteType.hpWithTank)) {
        productImages.add(product38c);
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

    pw.Widget buildHeader({bool showSubHeader = false}) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
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
            // Note: Quotation number and date appear exclusively at the bottom footer per requirement
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

      return pw.Column(
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 6),
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
          ),
          pw.SizedBox(height: 3),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  quotation.quoteRefNo.isNotEmpty ? quotation.quoteRefNo : '«Quotation_Number»',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
                ),
                pw.Text(
                  'DATE-  $dateStr',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final isConfirmed = quotation.status.toLowerCase() == 'confirmed';
    pw.Widget withWatermark(pw.Widget content) {
      if (isConfirmed) return content;
      return pw.Stack(
        children: [
          content,
          pw.Positioned.fill(
            child: pw.Center(
              child: pw.Transform.rotateBox(
                angle: -0.5,
                child: pw.Opacity(
                  opacity: 0.12,
                  child: pw.Text(
                    'DRAFT - NOT APPROVED',
                    style: pw.TextStyle(
                      fontSize: 44,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 1: COVER (FULL BLEED)
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          final custSalutation = quotation.salutation.isNotEmpty ? '${quotation.salutation} ' : '';
          return withWatermark(
            pw.Stack(
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
                        'Proposal',
                        style: pw.TextStyle(
                          color: darkGold,
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'TO,',
                        style: pw.TextStyle(
                          color: darkGold,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        '$custSalutation${quotation.customerName}',
                        style: pw.TextStyle(
                          color: darkGold,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Add-${quotation.customerAddress}',
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
            ),
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
          final custSalutation = quotation.salutation.isNotEmpty ? '${quotation.salutation.toUpperCase()} ' : '';
          final customerNameUpper = quotation.customerName.toUpperCase();

          return withWatermark(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                buildHeader(),
                pw.SizedBox(height: 6),

                // Centered QUOTATION Header at top in big font size
                pw.Center(
                  child: pw.Text(
                    'QUOTATION',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),

                // TO on left, Date & Ref block on right
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side: TO, Customer Name, Address
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('TO,', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            '$custSalutation$customerNameUpper',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'Add- ${quotation.customerAddress}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    // Right side: DATE, Quote Ref No, Sales/Ref, Mob. No
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'DATE-  $dateStr',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Text('Quote Ref No   : ', style: const pw.TextStyle(fontSize: 8.5)),
                              pw.Text(quotation.quoteRefNo, style: const pw.TextStyle(fontSize: 8.5)),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Text('Sales/Ref      : ', style: const pw.TextStyle(fontSize: 8.5)),
                              pw.Text(quotation.salesRef, style: const pw.TextStyle(fontSize: 8.5)),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.end,
                            children: [
                              pw.Text('Mob. No        : ', style: const pw.TextStyle(fontSize: 8.5)),
                              pw.Text(quotation.salesMobile, style: const pw.TextStyle(fontSize: 8.5)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 12),

                // Subject line
                pw.RichText(
                  text: pw.TextSpan(
                    text: 'Subject: ',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    children: [
                      pw.TextSpan(
                        text: quotation.subjectLine,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 10),

                // Salutation & Intro
                pw.Text('Dear Sir', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 5),
                pw.Text(
                  '    We thank you for the discussion regarding the supply of Energy Efficient "IZYHEAT" Heat Pump Water Heating Solutions for your Project. We would like to briefly present a summary of the technology that we propose as well as related cost benefits that you would derive from our solutions in response to detailed study Discussion; we are submitting our Quotation along with specifications suitable to your requirement.',
                  style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.35),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  '    Please find attached the brief presentation with summary of the technology that we propose as well as related cost benefits that you would derive from our solutions. Further we are pleased to attach herewith a quotation for your reference & speedy decision.',
                  style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.35),
                ),

                pw.SizedBox(height: 12),

                // COMPANY PROFILE
                pw.Text(
                  'COMPANY PROFILE:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  '    "${settings.companyName}", under the brand Name "${settings.brandName}" Heat Pump the manufacturers of Heat Pump System is a 15 year old company that has been a market leader and a pioneer in the Heat Pump water heater system industry. It is one of the leading brands of water heaters in India and stands for Quality, Reliability and Performance. It is in house product since 2008.',
                  style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.35),
                ),

                pw.SizedBox(height: 14),

                // Annexures list
                ...annexureEntries.map((e) {
                  String roman = e.romanNumeral;
                  if (!roman.contains('–') && !roman.contains('-')) {
                    roman = roman.replaceFirst('Annexure ', 'Annexure – ');
                  }
                  String desc;
                  if (e.romanNumeral == 'Annexure I' || e.romanNumeral.endsWith(' I')) {
                    desc = 'PRICE AND EXCLUSIONS ( OFFER 1 )';
                  } else if (e.title.contains('Technical') || e.title.contains('Specifications')) {
                    if (quotation.quoteType == QuoteType.hpWithTank) {
                      desc = hasTank
                          ? 'Technical Specifications. ( Heat Pump & Tank)'
                          : 'Technical Specifications (Heat Pump)';
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
                    padding: const pw.EdgeInsets.only(left: 16, bottom: 3),
                    child: pw.Text(
                      '$roman: $desc',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                  );
                }),

                pw.SizedBox(height: 14),

                // Signoff & Contact Details
                pw.Text(
                  settings.companyName,
                  style: pw.TextStyle(
                    color: navyColor,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Mob: ${settings.companyPhone} / ${settings.companyPhone2}',
                  style: const pw.TextStyle(fontSize: 8.5),
                ),
                pw.Row(
                  children: [
                    pw.Text('Web: ', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text(
                      settings.companyWebsite,
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        color: blueLink,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
                pw.Text('Email: ${settings.companyEmail}', style: const pw.TextStyle(fontSize: 8.5)),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Text('Follow us on:   ', style: const pw.TextStyle(fontSize: 8.5)),
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
            ),
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 3: ANNEXURE I (PRICE SCHEDULE) + ANNEXURE II (HP SPECS)
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 24, 36, 20),
        build: (context) {
          if (quotation.quoteType == QuoteType.hpWithTank || quotation.quoteType == QuoteType.hpOnly) {
            return withWatermark(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildHeader(showSubHeader: true),
                  pw.Text(
                    'Annexure – I: Price and exclusions Offer 1',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black, width: 0.6),
                    ),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    child: pw.Text('OFFER', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 4),

                  // 8-Column Price Schedule Table
                  _build8ColumnPriceSchedule(quotation),

                  pw.SizedBox(height: 8),

                  // Annexure II HP Technical Specifications immediately beneath
                  pw.Text(
                    'Annexure – II',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 1.5),
                  pw.Text(
                    'TECHNICAL SPECIFICATION FOR : ${settings.brandName}  HEAT PUMP –${quotation.model.modelName}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(28),
                      1: const pw.FixedColumnWidth(200),
                      2: const pw.FlexColumnWidth(),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8E8E8')),
                        children: [_th('SL'), _th('DESCRIPTION'), _th('SPECIFICATION')],
                      ),
                      ..._buildHpSpecRows(quotation),
                    ],
                  ),

                  pw.Spacer(),
                  buildFooter(priceSchedulePage),
                ],
              ),
            );
          } else {
            // Flexible layout for other types
            return withWatermark(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildHeader(showSubHeader: true),
                  pw.Text(
                    'Annexure – I: Price and exclusions Offer 1',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
                  ),
                  pw.SizedBox(height: 6),
                  _buildGenericPriceTable(quotation, config),
                  pw.Spacer(),
                  buildFooter(priceSchedulePage),
                ],
              ),
            );
          }
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PAGE 4: TANK TECHNICAL SPECIFICATIONS + BANNER (ONLY IF TANK ADDED)
    // ─────────────────────────────────────────────────────────────────────────
    if (quotation.quoteType == QuoteType.hpWithTank && hasTank) {
      pdf.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 24, 36, 20),
          build: (context) {
            return withWatermark(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildHeader(showSubHeader: true),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'TECHNICAL SPECIFICATION FOR : GI HOT WATER STORAGE TANK.',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
                  ),
                  pw.SizedBox(height: 6),

                  // Merged Tank Specification Table (10 rows, perfectly aligned UI)
                  _buildMergedTankSpecTable(quotation),

                  pw.SizedBox(height: 12),

                  // Insiya Banner
                  if (bannerImage != null)
                    pw.Center(
                      child: pw.Container(
                        height: 185,
                        width: double.infinity,
                        child: pw.Image(pw.MemoryImage(bannerImage), fit: pw.BoxFit.contain),
                      ),
                    ),

                  pw.Spacer(),
                  buildFooter(tankSpecPage!),
                ],
              ),
            );
          },
        ),
      );
    } else if (config.hasTechnicalSpecs && quotation.quoteType != QuoteType.hpWithTank && quotation.quoteType != QuoteType.hpOnly) {
      // Other types with technical specs (tankOnly, pool, allInOne)
      pdf.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 24, 36, 20),
          build: (context) {
            return withWatermark(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildHeader(showSubHeader: true),
                  if (config.specMode == SpecMode.tankOnly) ...[
                    _buildMergedTankSpecTable(quotation),
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

                  if (bannerImage != null) ...[
                    pw.SizedBox(height: 12),
                    pw.Center(
                      child: pw.Container(
                        height: 180,
                        width: double.infinity,
                        child: pw.Image(pw.MemoryImage(bannerImage), fit: pw.BoxFit.contain),
                      ),
                    ),
                  ],

                  pw.Spacer(),
                  buildFooter(priceSchedulePage + 1),
                ],
              ),
            );
          },
        ),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TERMS & CONDITIONS & WARRANTY PAGE
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 24, 36, 20),
        build: (context) {
          final termsTitle = (quotation.quoteType == QuoteType.partsOnly)
              ? 'ANNEXURE – II: COMMERCIAL TERMS AND CONDITIONS & WARRANTY.'
              : 'Annexure – III: Commercial terms and conditions & Warranty.';

          // Payment sentence with quirk 'satisfactoryinstallation and commissioning'
          final paymentSentence = QgPaymentSentenceBuilder.buildFromSplits(
            advance: quotation.paymentSplitAdvance,
            delivery: quotation.paymentSplitDelivery,
            commissioning: quotation.paymentSplitCommissioning,
            isAnnexureQuirk: true,
          );

          String warrantyText;
          if (quotation.quoteType == QuoteType.allInOneFloor || quotation.quoteType == QuoteType.allInOneWall) {
            warrantyText = '${quotation.warrantyHpYears} YEAR FOR HEAT PUMP AND 5 YEARS OF COMPRESSOR.';
          } else if (quotation.quoteType == QuoteType.partsOnly) {
            warrantyText = '1 YEAR FOR REPLACED PARTS.';
          } else if (quotation.quoteType == QuoteType.tankOnly) {
            warrantyText = '${quotation.warrantyTankYears} YEARS FOR TANK.';
          } else if (quotation.quoteType == QuoteType.hpOnly || quotation.quoteType == QuoteType.swimmingPool || !hasTank) {
            warrantyText = '${quotation.warrantyHpYears} YEAR FOR HEAT PUMP.';
          } else {
            warrantyText = '${quotation.warrantyHpYears} YEAR FOR HEAT PUMP, ${quotation.warrantyTankYears} YEARS FOR TANK .';
          }

          final termsList = quotation.termsAndConditions.isNotEmpty
              ? quotation.termsAndConditions
              : [
                  'Proper 1 / 3 Phase power should be arranged where you install the heat pump.',
                  'Electrical/civil/plumbing work materials – Customer Scope.',
                  'Safe storage place need to be provided by you to keep our material & tools.',
                  'All Interconnected pipe lines between system and Tank Your Scope but our team will do the installation. (If applicable): Included',
                ];

          return withWatermark(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                buildHeader(showSubHeader: true),
                pw.SizedBox(height: 6),
                pw.Text(
                  termsTitle,
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
                ),
                pw.SizedBox(height: 12),

                // Payment Terms
                pw.Text('Payment Terms :', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 6),
                  child: pw.Text(paymentSentence, style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.35)),
                ),

                pw.SizedBox(height: 12),

                // Warranty
                pw.Text('WARRANTY:- $warrantyText', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),

                pw.SizedBox(height: 12),

                // Other Terms & Conditions
                pw.Text('Other Terms & Conditions:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                ...termsList.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final text = entry.value;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3.5, left: 6),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('$idx.  ', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.25))),
                      ],
                    ),
                  );
                }),

                pw.SizedBox(height: 12),

                // Validity Of Offer
                pw.Text('Validity Of Offer :', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 6),
                  child: pw.Text(
                    'Prices quoted are firm and generally valid for ${quotation.validityDays} days from date of offer. After this prices are subject to your confirmation.',
                    style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.3),
                  ),
                ),

                pw.SizedBox(height: 12),

                // Bank Details
                pw.Text(
                  'OUR BANK ACCOUNT DETAILS:',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
                ),
                pw.SizedBox(height: 5),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 6),
                  child: pw.Table(
                    columnWidths: {
                      0: const pw.FixedColumnWidth(110),
                      1: const pw.FixedColumnWidth(16),
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
                ),

                pw.SizedBox(height: 12),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 6),
                  child: pw.Text(
                    'We hope you will find our quotation very competitive and favor us with your valued order at early date andindulge.',
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                ),

                pw.SizedBox(height: 12),
                pw.Text('Thanks & Regard', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('For', style: const pw.TextStyle(fontSize: 9)),
                pw.Text(settings.companyName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),

                if (stampImage != null)
                  pw.Container(
                    width: 65,
                    height: 65,
                    child: pw.Image(pw.MemoryImage(stampImage)),
                  ),

                pw.Spacer(),
                buildFooter(termsPage),
              ],
            ),
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // QUOTATION ACCEPTANCE LETTER
    // ─────────────────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 24, 36, 20),
        build: (context) {
          final totalFormatted = PriceCalculator.formatIndianCurrency(quotation.netPayable);

          // Payment sentence with standard space 'satisfactory installation and commissioning'
          final acceptancePaymentSentence = QgPaymentSentenceBuilder.buildFromSplits(
            advance: quotation.paymentSplitAdvance,
            delivery: quotation.paymentSplitDelivery,
            commissioning: quotation.paymentSplitCommissioning,
            isAnnexureQuirk: false,
          );

          return withWatermark(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                buildHeader(showSubHeader: false),
                pw.SizedBox(height: 16),
                pw.Center(
                  child: pw.Text(
                    'QUOTATION ACCEPTANCE LETTER',
                    style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  children: [
                    pw.Text('Customer Name: ', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(quotation.customerName,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  children: [
                    pw.Text('Customer Address: ', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(quotation.customerAddress,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 14),
                pw.Text('Subject: ${quotation.acceptanceSubjectLine}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text('Model No ${quotation.model.modelName}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 14),
                pw.Text('Dear Sir,', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 6),
                pw.Text(
                  'With reference to quotation number ${quotation.quoteRefNo} dated $dateStr, with Quotation Value $totalFormatted, I’m glad to inform you that your quote has been Approved for the corresponding project,',
                  style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.35),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'With Term conditions of Payment: $acceptancePaymentSentence',
                  style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.35),
                ),
                pw.SizedBox(height: 16),
                pw.Text('Looking forward to doing business with you.', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 28),
                pw.Text('Yours sincerely,', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 3),
                pw.Text(quotation.customerName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Mob. No:- ${quotation.customerMobile}', style: const pw.TextStyle(fontSize: 9)),

                pw.Spacer(),
                buildFooter(acceptPage),
              ],
            ),
          );
        },
      ),
    );

    // ─────────────────────────────────────────────────────────────────────────
    // PRODUCT IMAGE PAGE
    // ─────────────────────────────────────────────────────────────────────────
    if (quotation.includeProductImagePage) {
      pdf.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 24, 36, 20),
          build: (context) {
            final mainImg = productImages.isNotEmpty
                ? productImages.first
                : product38c;

            return withWatermark(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildHeader(showSubHeader: true),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Text(
                      'Product Image',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  if (mainImg != null)
                    pw.Center(
                      child: pw.Container(
                        height: 440,
                        width: double.infinity,
                        child: pw.Image(pw.MemoryImage(mainImg), fit: pw.BoxFit.contain),
                      ),
                    ),
                  pw.Spacer(),
                  buildFooter(showcasePage!),
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  // ─── 8-COLUMN PRICE SCHEDULE TABLE (hpWithTank / hpOnly) ──────────────────

  static pw.Widget _build8ColumnPriceSchedule(GeneratorQuotation q) {
    final hpKwInt = q.model.displayCapacityKw.toInt();
    final hpRatedPower = q.model.specs['Rated Input Power'] ?? '8.75kw';
    final hasTank = q.hasTank;
    final tankCap = q.tankCapacityLitres > 0 ? q.tankCapacityLitres : 3000;
    final tankQty = q.tankQty > 0 ? q.tankQty : 2;
    final innerMat = q.tankSpec.innerTankMaterial.isNotEmpty ? q.tankSpec.innerTankMaterial : 'GI';
    final pressStr = q.isTankPressurized ? 'Pressurized' : 'Non-Pressurized';

    // 1. Determine Heat Pump rate and amount (show actual rate!)
    int hpRate = 0;
    if (q.heatPumpNumericPrice > 0) {
      hpRate = q.heatPumpNumericPrice;
    } else {
      for (final r in q.priceRows) {
        final d = r.description.toLowerCase();
        if (d.contains('heat pump') || d.contains('air source') || d.contains('iz-')) {
          if (r.rate > 0) {
            hpRate = r.rate;
            break;
          }
        }
      }
    }
    if (hpRate == 0 && !hasTank) {
      hpRate = q.subtotal;
    }

    final hpQty = q.heatPumpQty > 0 ? q.heatPumpQty : 1;
    final hpAmount = hpRate * hpQty;

    String hpRateStr;
    String hpAmountStr;
    if (hpRate > 0) {
      hpRateStr = PriceCalculator.formatIndianCurrency(hpRate);
      hpAmountStr = PriceCalculator.formatIndianCurrency(hpAmount);
    } else if (hasTank && q.tankRate > 0) {
      hpRateStr = '-';
      hpAmountStr = 'Included';
    } else {
      hpRateStr = PriceCalculator.formatIndianCurrency(q.subtotal);
      hpAmountStr = PriceCalculator.formatIndianCurrency(q.subtotal);
    }

    int rowIdx = 1;
    final tableRows = <pw.TableRow>[];

    // Header Row
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8E8E8')),
        children: [
          _th('S.\nno.'),
          _th('DESCRIPTION'),
          _th('System\nLPH'),
          _th('HP KW'),
          _th('Qty'),
          _th('Rate/\nLiter'),
          _th('System Rate'),
          _th('AMOUNT'),
        ],
      ),
    );

    // Row 1: Heat Pump
    tableRows.add(
      pw.TableRow(
        children: [
          _tc((rowIdx++).toString().padLeft(2, '0'), center: true),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Air Source Heat pump ${hpKwInt}kw', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                pw.Text('Make: IZYHEAT Heat Pump Model: ${q.model.modelName} ${hpKwInt}kw', style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text('Power Input $hpRatedPower, output ${hpKwInt}kw, ${q.model.powerSupply}, 50Hz With Auto Defrost.', style: const pw.TextStyle(fontSize: 7.5)),
              ],
            ),
          ),
          _tc('', center: true),
          _tc(q.model.displayCapacityKw.toStringAsFixed(2), center: true),
          _tc('$hpQty', center: true),
          _tc('', center: true),
          _tc(hpRateStr, center: true),
          _tc(hpAmountStr, center: true),
        ],
      ),
    );

    // Row 2: Tank (ONLY IF TANK IS ADDED!)
    if (hasTank) {
      tableRows.add(
        pw.TableRow(
          children: [
            _tc((rowIdx++).toString().padLeft(2, '0'), center: true),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
              child: pw.Text(
                '$tankCap  LTR Capacity, $innerMat $pressStr Tank, 3mm Shell, and 3mm Dish, , Thickness,19mm IC CLAD insulation.',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            ),
            _tc('$tankCap', center: true),
            _tc('', center: true),
            _tc('$tankQty', center: true),
            _tc('', center: true),
            _tc(PriceCalculator.formatIndianCurrency(q.tankRate), center: true),
            _tc(PriceCalculator.formatIndianCurrency(q.tankRate * tankQty), center: true),
          ],
        ),
      );
    }

    // Supplementary Items: ONLY those that are actually added!
    pw.TableRow buildExtraRow(String sr, String desc, {String amtStr = ''}) {
      return pw.TableRow(
        children: [
          _tc(sr, center: true),
          _tc(desc),
          _tc('', center: true),
          _tc('', center: true),
          _tc('', center: true),
          _tc('', center: true),
          _tc(amtStr, center: true),
          _tc(amtStr, center: true),
        ],
      );
    }

    if (q.extraPriceRows.isNotEmpty) {
      for (final it in q.extraPriceRows) {
        String desc = it.description.trim();
        if (!desc.contains(' - ')) {
          final statusDesc = it.amountType == PriceRowType.included
              ? 'Included'
              : (it.amountType == PriceRowType.extra
                  ? 'Extra'
                  : (it.amountType == PriceRowType.customText
                      ? (it.customText.isNotEmpty ? it.customText : 'Extra')
                      : 'Extra'));
          desc = '$desc - $statusDesc';
        }
        final amt = (it.amountType == PriceRowType.extra || it.amountType == PriceRowType.amount) && it.numericAmount > 0
            ? PriceCalculator.formatIndianCurrency(it.numericAmount)
            : '';
        tableRows.add(buildExtraRow((rowIdx++).toString().padLeft(2, '0'), desc, amtStr: amt));
      }
    } else {
      // Check priceRows for supplementary items (skip HP and Tank)
      for (final r in q.priceRows) {
        final d = r.description.toLowerCase();
        if (d.contains('heat pump') || d.contains('air source') || d.contains('iz-')) continue;
        if (d.contains('tank') || d.contains('storage')) continue;
        if (r.description == '-' || r.description.trim().isEmpty) continue;

        String statusStr;
        if (r.status == PriceRowStatus.included) {
          statusStr = 'Included';
        } else if (r.status == PriceRowStatus.extra) {
          statusStr = 'Extra';
        } else if (r.status == PriceRowStatus.na) {
          statusStr = 'NA';
        } else {
          statusStr = r.amount > 0 ? PriceCalculator.formatIndianCurrency(r.amount) : 'Extra';
        }
        String desc = r.description.trim();
        if (!desc.contains(' - ')) {
          desc = '$desc - $statusStr';
        }
        final amt = (r.status == PriceRowStatus.extra || r.status == PriceRowStatus.priced) && r.amount > 0
            ? PriceCalculator.formatIndianCurrency(r.amount)
            : '';
        tableRows.add(buildExtraRow((rowIdx++).toString().padLeft(2, '0'), desc, amtStr: amt));
      }
    }

    return pw.Column(
      children: [
        pw.Table(
          border: const pw.TableBorder(
            left: pw.BorderSide(color: PdfColors.black, width: 0.6),
            right: pw.BorderSide(color: PdfColors.black, width: 0.6),
            top: pw.BorderSide(color: PdfColors.black, width: 0.6),
            bottom: pw.BorderSide(color: PdfColors.black, width: 0.6),
            horizontalInside: pw.BorderSide(color: PdfColors.black, width: 0.6),
            verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.6),
          ),
          columnWidths: {
            0: const pw.FixedColumnWidth(26),
            1: const pw.FixedColumnWidth(215),
            2: const pw.FixedColumnWidth(42),
            3: const pw.FixedColumnWidth(38),
            4: const pw.FixedColumnWidth(24),
            5: const pw.FixedColumnWidth(42),
            6: const pw.FixedColumnWidth(58),
            7: const pw.FixedColumnWidth(62),
          },
          children: tableRows,
        ),

        // Totals Block directly beneath
        pw.Table(
          border: const pw.TableBorder(
            left: pw.BorderSide(color: PdfColors.black, width: 0.6),
            right: pw.BorderSide(color: PdfColors.black, width: 0.6),
            bottom: pw.BorderSide(color: PdfColors.black, width: 0.6),
            horizontalInside: pw.BorderSide(color: PdfColors.black, width: 0.6),
            verticalInside: pw.BorderSide(color: PdfColors.black, width: 0.6),
          ),
          columnWidths: {
            0: const pw.FixedColumnWidth(445),
            1: const pw.FixedColumnWidth(62),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 8),
                  child: pw.Text('Sub Total', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                  child: pw.Text(PriceCalculator.formatIndianCurrency(q.subtotal), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 8),
                  child: pw.Text('GST 18%', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                  child: pw.Text(PriceCalculator.formatIndianCurrency(q.gstAmount), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 8),
                  child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
                  child: pw.Text(PriceCalculator.formatIndianCurrency(q.grandTotal), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ─── MERGED TANK SPECIFICATION TABLE (Page 4) ──────────────────────────────

  static pw.Widget _buildMergedTankSpecTable(GeneratorQuotation q) {
    final cap = q.tankCapacityLitres > 0 ? q.tankCapacityLitres : 3000;
    final pressStr = q.isTankPressurized ? 'Pressurized' : 'Non-Pressurized';
    final innerMat = q.tankSpec.innerTankMaterial.isNotEmpty ? q.tankSpec.innerTankMaterial : 'GI';
    final innerThick = q.tankSpec.innerTankThickness.isNotEmpty ? q.tankSpec.innerTankThickness : '3mm';

    final specRowsTop = [
      ['01', 'Capacity and Thickness', '$cap ltr, $innerThick Shell, $innerThick Dish.'],
      ['02', 'Operating pressure', q.isTankPressurized ? 'Up to 5 Bar' : 'Atmospheric'],
      ['03', 'Testing Pressure', q.isTankPressurized ? '7 bar pressure' : 'Atmospheric'],
      ['04', 'Hot Water Inlet/ outlet', '2 Inch,'],
      ['05', 'Heat Pump Circulation', '1 Inch,'],
      ['06', 'Outer Tank Insulation', '19mm IC CLAD insulation'],
    ];

    final specRowsBottom = [
      ['07', 'Temperature drop', '3º C / 8 hour'],
      ['08', 'Inner and outer Tank', innerMat],
      ['09', 'Tank direction', 'Horizontal / Vertical'],
      ['10', 'Other', 'Solar Provision Additional Heat Pump Provision'],
    ];

    const double col0Width = 32.0;
    const double col1Width = 110.0;
    const double col2Width = 368.0;
    const double col2LabelWidth = 145.0;
    const double col2ValueWidth = 223.0; // 368 - 145
    const double rowHeight = 20.0;
    const double section1Height = 6 * rowHeight; // 120.0

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.6),
      ),
      child: pw.Column(
        children: [
          // ─── Header Row ───
          pw.Container(
            height: 24,
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE8E8E8),
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.black, width: 0.6),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: col0Width,
                  alignment: pw.Alignment.center,
                  child: pw.Text('SL\nNO', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                ),
                pw.Container(width: 0.6, height: 24, color: PdfColors.black),
                pw.Container(
                  width: col1Width + 0.6 + col2LabelWidth,
                  alignment: pw.Alignment.center,
                  child: pw.Text('DESCRIPTION', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Container(width: 0.6, height: 24, color: PdfColors.black),
                pw.Container(
                  width: col2ValueWidth,
                  alignment: pw.Alignment.center,
                  child: pw.Text('SPECIFICATION', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          ),

          // ─── Section 1: Rows 01–06 (Merged Middle Cell) ───
          pw.Container(
            height: section1Height,
            child: pw.Row(
              children: [
                // Col 0: SL numbers 01 to 06
                pw.Container(
                  width: col0Width,
                  child: pw.Column(
                    children: specRowsTop.asMap().entries.map((e) {
                      final isLast = e.key == specRowsTop.length - 1;
                      return pw.Container(
                        height: rowHeight,
                        alignment: pw.Alignment.center,
                        decoration: isLast
                            ? null
                            : const pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.6)),
                              ),
                        child: pw.Text(e.value[0], style: const pw.TextStyle(fontSize: 7.5)),
                      );
                    }).toList(),
                  ),
                ),
                pw.Container(width: 0.6, height: section1Height, color: PdfColors.black),

                // Col 1: Merged Description Cell (Clean, centered, no horizontal lines)
                pw.Container(
                  width: col1Width,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  alignment: pw.Alignment.center,
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('$cap Ltr', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                      pw.SizedBox(height: 2),
                      pw.Text('HOT WATER', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text('STORRAGE $innerMat', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text(pressStr, style: const pw.TextStyle(fontSize: 7.5)),
                      pw.Text('TANK', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Container(width: 0.6, height: section1Height, color: PdfColors.black),

                // Col 2: Specifications (Label + Value) for rows 01 to 06
                pw.Container(
                  width: col2Width,
                  child: pw.Column(
                    children: specRowsTop.asMap().entries.map((e) {
                      final isLast = e.key == specRowsTop.length - 1;
                      return pw.Container(
                        height: rowHeight,
                        decoration: isLast
                            ? null
                            : const pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.6)),
                              ),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: col2LabelWidth,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                              alignment: pw.Alignment.centerLeft,
                              child: pw.Text(e.value[1], style: const pw.TextStyle(fontSize: 7.5)),
                            ),
                            pw.Container(width: 0.6, height: rowHeight, color: PdfColors.black),
                            pw.Container(
                              width: col2ValueWidth,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                              alignment: pw.Alignment.centerLeft,
                              child: pw.Text(e.value[2], style: const pw.TextStyle(fontSize: 7.5)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Divider between row 06 and row 07
          pw.Container(height: 0.6, color: PdfColors.black),

          // ─── Section 2: Rows 07–10 ───
          ...specRowsBottom.asMap().entries.map((e) {
            final isLast = e.key == specRowsBottom.length - 1;
            return pw.Container(
              height: rowHeight,
              decoration: isLast
                  ? null
                  : const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.6)),
                    ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: col0Width,
                    alignment: pw.Alignment.center,
                    child: pw.Text(e.value[0], style: const pw.TextStyle(fontSize: 7.5)),
                  ),
                  pw.Container(width: 0.6, height: rowHeight, color: PdfColors.black),
                  pw.Container(
                    width: col1Width + 0.6 + col2LabelWidth,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(e.value[1], style: const pw.TextStyle(fontSize: 7.5)),
                  ),
                  pw.Container(width: 0.6, height: rowHeight, color: PdfColors.black),
                  pw.Container(
                    width: col2ValueWidth,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(e.value[2], style: const pw.TextStyle(fontSize: 7.5)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── GENERIC PRICE TABLE (for non-hpWithTank quote types) ──────────────────

  static pw.Widget _buildGenericPriceTable(GeneratorQuotation quotation, QuoteTemplateConfig config) {
    final hasDiscountCol = config.priceColumnKeys.contains('discount');
    final rows = quotation.priceRows;

    return pw.Column(
      children: [
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
            _buildTotalRow(
              'TOTAL',
              PriceCalculator.formatIndianCurrency(quotation.grandTotal),
              isUnderlined: true,
            ),
          ],
        ),
      ],
    );
  }

  // ─── SPEC HELPERS ─────────────────────────────────────────────────────────

  static List<pw.TableRow> _buildHpSpecRows(GeneratorQuotation q) {
    final m = q.model;
    final tankCap = q.tankCapacityLitres > 0 ? '${q.tankCapacityLitres}' : '3000';
    final rowsData = [
      ['01', 'Size (W x D x H) mm', m.specs['Size (W x D x H)'] ?? '1410x748x1000'],
      ['02', 'Rated Heating Capacity', m.ratedHeatingCapacity],
      ['03', 'Power Supply', m.powerSupply],
      ['04', 'Rated Input Power', m.specs['Rated Input Power'] ?? '8.75kw'],
      ['05', 'Rated COP', m.specs['Rated COP'] ?? '4.34'],
      ['06', 'Rated Water Yield', m.specs['Rated Water Yield'] ?? '817 L/h'],
      ['07', 'Max Outlet Water Temperature', m.specs['Max Outlet Water Temperature'] ?? '60°C'],
      ['08', 'Water Flow Noise', m.specs['Water Flow Noise'] ?? '<=59dB(A)'],
      ['09', 'Condenser', m.specs['Condenser'] ?? '0'],
      ['10', 'Refrigerant', m.specs['Refrigerant'] ?? 'R134A/410A'],
      ['11', 'Operating ambient Temp', m.specs['Operating ambient Temp'] ?? '-15~43°C'],
      ['12', 'Capacity In litre', tankCap],
      ['13', 'Compressor', m.specs['Compressor'] ?? 'DOUBLE'],
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
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 3),
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
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 3.5),
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
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        ),
        pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              decoration: isUnderlined ? pw.TextDecoration.underline : pw.TextDecoration.none,
            ),
          ),
        ),
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
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
