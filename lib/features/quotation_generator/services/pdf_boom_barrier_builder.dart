// lib/features/quotation_generator/services/pdf_boom_barrier_builder.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/boom_barrier_proposal_draft.dart';
import '../models/qg_product_profile.dart';
import 'boom_barrier_math.dart';
import '../../../core/services/pdf_service.dart';

/// 5-Page PDF Builder for Boom Barrier quotations adhering strictly to
/// the reference template (/reference/Boom_Barrier_Quotation_Template.pdf):
/// - Page 1: Cover Page (Full artwork + To: recipient)
/// - Page 2: Quotation & Option 1 Price Table + At-Actual + Notes + Sales rep
/// - Page 3: Terms & Conditions + Tech Specs (Barrier & LPR) + Bank Details
/// - Page 4: Visual Product Showcase / Gallery (4 models: IZ-2001, IZ-2026, IZ-2004, NPRS)
/// - Page 5: Quotation Acceptance Letter
class PdfBoomBarrierBuilder {
  static const PdfColor _navy = PdfColor.fromInt(0xFF1E3A5F);
  static const PdfColor _darkText = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _mutedText = PdfColor.fromInt(0xFF475569);
  static const PdfColor _borderColor = PdfColor.fromInt(0xFF334155);
  static const PdfColor _headerBg = PdfColor.fromInt(0xFFF1F5F9);

  static Future<Uint8List> buildQuotationPdf(
    BoomBarrierProposalDraft draft,
    QgProductProfile profile, {
    Map<String, Uint8List>? assetOverrides,
  }) async {
    final pdf = pw.Document();

    // 1. Resolve Fonts
    pw.Font fontRegular;
    pw.Font fontBold;
    pw.Font fontItalic;
    try {
      final regData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      fontRegular = pw.Font.ttf(regData);
      fontBold = pw.Font.ttf(boldData);
      fontItalic = pw.Font.helveticaOblique();
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
      fontItalic = pw.Font.helveticaOblique();
    }

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      italic: fontItalic,
    );

    // 2. Load Assets
    final coverBytes = assetOverrides?['cover'] ??
        await _loadImageBytes(draft.coverImagePath ?? profile.defaultCoverPath);
    final resolvedLogoPath = (draft.logoPath != null && !draft.logoPath!.endsWith('logo.png'))
        ? draft.logoPath!
        : (profile.logoPath.isNotEmpty && !profile.logoPath.endsWith('logo.png')
            ? profile.logoPath
            : 'assets/images/boom_barrier/sefdor_logo.png');
    final logoBytes = assetOverrides?['logo'] ??
        await _loadImageBytes(resolvedLogoPath);
    final stampBytes = assetOverrides?['stamp'] ??
        await _loadImageBytes(draft.stampPath ?? profile.stampPath ?? 'assets/images/company_stamp.png');

    final imgIz2001 = assetOverrides?['iz_2001'] ??
        await _loadImageBytes(draft.galleryIz2001Path ?? 'assets/images/boom_barrier/product_iz_2001.png');
    final imgIz2026 = assetOverrides?['iz_2026'] ??
        await _loadImageBytes(draft.galleryIz2026Path ?? 'assets/images/boom_barrier/product_iz_2026.png');
    final imgIz2004 = assetOverrides?['iz_2004'] ??
        await _loadImageBytes(draft.galleryIz2004Path ?? 'assets/images/boom_barrier/product_iz_2004.png');
    final imgNprs = assetOverrides?['nprs'] ??
        await _loadImageBytes(draft.galleryNprsPath ?? 'assets/images/boom_barrier/product_nprs.png');

    final statusLower = draft.status.trim().toLowerCase();
    final isConfirmed = statusLower == 'confirmed' || statusLower == 'approved';
    final generatedByName = await PdfService.resolveCurrentUserName();

    // ─── PAGE 1: COVER PAGE ──────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Stack(
            fit: pw.StackFit.expand,
            children: [
              if (coverBytes != null)
                pw.Image(
                  pw.MemoryImage(coverBytes),
                  fit: pw.BoxFit.cover,
                ),
              // Gradient / dark overlay for recipient box readability if needed
              pw.Positioned(
                left: 45,
                bottom: 240,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'To',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      draft.customerName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Add:- ${draft.customerAddress}',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isConfirmed) _buildWatermark(),
            ],
          );
        },
      ),
    );

    // ─── PAGE 2: QUOTATION, COMMERCIAL OFFER & SUPPLEMENTARY ITEMS ────────
    pdf.addPage(
      pw.MultiPage(
        header: (context) => _buildHeader(profile, logoBytes),
        footer: (context) => _buildSalesRepFooter(draft, generatedByName),
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
          buildBackground: (context) => !isConfirmed ? _buildWatermark() : pw.SizedBox.shrink(),
        ),
        build: (context) {
          return [
            pw.SizedBox(height: 10),
            _buildRefDateBar(draft.refNumber, draft.quoteDate),
            pw.SizedBox(height: 8),
            _buildQuotationMeta(draft),
            pw.SizedBox(height: 8),
            _buildSubjectAndIntro(draft),
            pw.SizedBox(height: 8),
            _buildOption1Table(draft),
            pw.SizedBox(height: 8),
            _buildAtActualSection(draft),
            pw.SizedBox(height: 6),
            _buildNotesSection(draft),
            pw.SizedBox(height: 14),
          ];
        },
      ),
    );

    // ─── PAGE 3: TERMS & CONDITIONS + SPECIFICATIONS + BANK DETAILS ───────
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        build: (context) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(profile, logoBytes),
                  pw.SizedBox(height: 10),
                  _buildRefDateBar(draft.refNumber, draft.quoteDate),
                  pw.SizedBox(height: 10),
                  _buildTermsAndConditions(draft),
                  pw.SizedBox(height: 12),
                  _buildSpecsSection(draft),
                  pw.SizedBox(height: 12),
                  _buildBankDetails(draft),
                ],
              ),
              if (!isConfirmed) _buildWatermark(),
            ],
          );
        },
      ),
    );

    // ─── PAGE 4: VISUAL PRODUCT SHOWCASE / GALLERY ────────────────────────
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        build: (context) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(profile, logoBytes),
                  pw.SizedBox(height: 10),
                  _buildRefDateBar(draft.refNumber, draft.quoteDate),
                  pw.SizedBox(height: 20),
                  _buildProductGalleryGrid(
                    imgIz2001: imgIz2001,
                    imgIz2026: imgIz2026,
                    imgIz2004: imgIz2004,
                    imgNprs: imgNprs,
                  ),
                ],
              ),
              if (!isConfirmed) _buildWatermark(),
            ],
          );
        },
      ),
    );

    // ─── PAGE 5: QUOTATION ACCEPTANCE LETTER ──────────────────────────────
    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        build: (context) {
          return pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildHeader(profile, logoBytes),
                  pw.SizedBox(height: 10),
                  _buildRefDateBar(draft.refNumber, draft.quoteDate),
                  pw.SizedBox(height: 16),
                  _buildAcceptanceLetterBody(draft, stampBytes),
                ],
              ),
              if (!isConfirmed) _buildWatermark(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ─── COMMON COMPONENT BUILDERS ──────────────────────────────────────────

  static pw.Widget _buildHeader(QgProductProfile profile, Uint8List? logoBytes) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                profile.companyName,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
              pw.SizedBox(height: 2),
              for (final line in profile.companyAddressLines)
                pw.Text(
                  line,
                  style: const pw.TextStyle(fontSize: 8.5, color: _darkText),
                ),
              pw.Text(
                'Email: ${profile.companyEmail}',
                style: const pw.TextStyle(fontSize: 8.5, color: _darkText),
              ),
              pw.Text(
                'Mob. ${profile.companyMobile}',
                style: const pw.TextStyle(fontSize: 8.5, color: _darkText),
              ),
              pw.Text(
                profile.companyWebsite,
                style: const pw.TextStyle(fontSize: 8.5, color: _darkText),
              ),
            ],
          ),
        ),
        if (logoBytes != null)
          pw.Container(
            width: 130,
            height: 55,
            alignment: pw.Alignment.topRight,
            child: pw.Image(
              pw.MemoryImage(logoBytes),
              fit: pw.BoxFit.contain,
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildRefDateBar(String refNo, String dateStr) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _borderColor, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            refNo,
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _navy),
          ),
          pw.Text(
            'Date:- : $dateStr',
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _navy),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildQuotationMeta(BoomBarrierProposalDraft draft) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Quotation',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _navy),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Quote No.: ${draft.refNumber}',
          style: const pw.TextStyle(fontSize: 9, color: _darkText),
        ),
        pw.Text(
          'Date          : ${draft.quoteDate}',
          style: const pw.TextStyle(fontSize: 9, color: _darkText),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'To,',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _darkText),
        ),
        pw.Text(
          draft.customerName,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _darkText),
        ),
        pw.Text(
          draft.customerAddress,
          style: const pw.TextStyle(fontSize: 8.5, color: _darkText),
        ),
      ],
    );
  }

  static pw.Widget _buildSubjectAndIntro(BoomBarrierProposalDraft draft) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Sub: ${draft.subjectText}',
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _navy),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          draft.introLine,
          style: const pw.TextStyle(fontSize: 8.5, color: _darkText),
        ),
      ],
    );
  }

  static pw.Widget _buildOption1Table(BoomBarrierProposalDraft draft) {
    const double colSr = 30;
    const double colQty = 35;
    const double colRate = 55;
    const double colDisc = 50;
    const double colPrice = 60;

    final totalTaxable = draft.subtotal + draft.supplementarySubtotal;

    final tableRows = <pw.TableRow>[
      // Header Row
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _headerBg),
        children: [
          _th('Sr.No', align: pw.TextAlign.center),
          _th('Item Description', align: pw.TextAlign.left),
          _th('Qty.', align: pw.TextAlign.center),
          _th('Rate', align: pw.TextAlign.right),
          _th('Discount', align: pw.TextAlign.center),
          _th('Price', align: pw.TextAlign.right),
        ],
      ),
      // Item Rows
      for (final item in draft.items)
        pw.TableRow(
          children: [
            _td('${item.srNo}', align: pw.TextAlign.center),
            pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item.description,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: item.inclusions.isNotEmpty ? pw.FontWeight.bold : pw.FontWeight.normal,
                    ),
                  ),
                  if (item.inclusions.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    for (final inc in item.inclusions)
                      pw.Text(
                        inc,
                        style: const pw.TextStyle(fontSize: 7.5, color: _mutedText),
                      ),
                  ],
                ],
              ),
            ),
            _td('${item.qty}', align: pw.TextAlign.center),
            _td(item.formattedRateText, align: pw.TextAlign.right),
            _td('', align: pw.TextAlign.center),
            _td(
              item.formattedPriceText,
              align: pw.TextAlign.right,
              bold: item.hasMonetaryValue,
            ),
          ],
        ),
    ];

    // Supplementary items continuing the Sr. No!
    int srNo = draft.items.length;
    for (final item in draft.supplementaryItems) {
      srNo++;
      final rawDesc = (item['name'] ?? item['term'] ?? item['item_name'] ?? item['description'] ?? item['title'] ?? '')
          .toString()
          .trim();
      final desc = rawDesc.isNotEmpty ? rawDesc : 'Supplementary Item';
      final qty = (item['qty'] ?? item['quantity'] as num?)?.toInt() ?? 1;
      final rate = (item['rate'] ?? item['unit_price'] as num?)?.toDouble() ?? 0.0;
      final total = (item['amount'] ?? item['total'] as num?)?.toDouble() ?? (qty * rate);
      final type = item['type']?.toString().toLowerCase();
      final isIncluded = type == 'included' || (total <= 0 && rate <= 0);

      tableRows.add(
        pw.TableRow(
          children: [
            _td('$srNo', align: pw.TextAlign.center),
            pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                desc,
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            _td('$qty', align: pw.TextAlign.center),
            _td(isIncluded ? 'Included' : BoomBarrierMath.formatRawOrIndian(rate), align: pw.TextAlign.right),
            _td('', align: pw.TextAlign.center),
            _td(
              isIncluded ? 'Included' : BoomBarrierMath.formatRawOrIndian(total),
              align: pw.TextAlign.right,
              bold: !isIncluded,
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          draft.optionTitle,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _navy,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Table(
          border: const pw.TableBorder(
            left: pw.BorderSide(color: _borderColor, width: 1.0),
            right: pw.BorderSide(color: _borderColor, width: 1.0),
            top: pw.BorderSide(color: _borderColor, width: 1.0),
            bottom: pw.BorderSide(color: _borderColor, width: 1.0),
            horizontalInside: pw.BorderSide(color: _borderColor, width: 1.0),
            verticalInside: pw.BorderSide(color: _borderColor, width: 1.0),
          ),
          columnWidths: const {
            0: pw.FixedColumnWidth(colSr),
            1: pw.FlexColumnWidth(),
            2: pw.FixedColumnWidth(colQty),
            3: pw.FixedColumnWidth(colRate),
            4: pw.FixedColumnWidth(colDisc),
            5: pw.FixedColumnWidth(colPrice),
          },
          children: tableRows,
        ),
        // Unified Totals Block directly attached beneath the table
        pw.Table(
          border: const pw.TableBorder(
            left: pw.BorderSide(color: _borderColor, width: 1.0),
            right: pw.BorderSide(color: _borderColor, width: 1.0),
            bottom: pw.BorderSide(color: _borderColor, width: 1.0),
            horizontalInside: pw.BorderSide(color: _borderColor, width: 1.0),
            verticalInside: pw.BorderSide(color: _borderColor, width: 1.0),
          ),
          columnWidths: const {
            0: pw.FlexColumnWidth(),
            1: pw.FixedColumnWidth(colPrice),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 8),
                  child: pw.Text(
                    'Total Taxable Value:',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _navy),
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
                  child: pw.Text(
                    BoomBarrierMath.formatRawOrIndian(totalTaxable),
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 8),
                  child: pw.Text(
                    'GST ${draft.gstPercent.toInt()}%:',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
                  child: pw.Text(
                    BoomBarrierMath.formatIndianCurrencyWithSymbol(draft.gstAmount),
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _headerBg),
              children: [
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: pw.Text(
                    'Grand Total:',
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _navy),
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: pw.Text(
                    BoomBarrierMath.formatIndianCurrencyWithSymbol(draft.grandTotal),
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _navy),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildAtActualSection(BoomBarrierProposalDraft draft) {
    if (draft.atActualCharges.isEmpty) return pw.SizedBox.shrink();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final item in draft.atActualCharges)
          pw.Text(
            '${item.srNo}) ${item.description} ${item.qty} ${item.rate} ${item.total}',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _darkText),
          ),
      ],
    );
  }

  static pw.Widget _buildNotesSection(BoomBarrierProposalDraft draft) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Note :',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _navy),
        ),
        for (final note in draft.notes)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 16, top: 1.5),
            child: pw.Text(
              note.startsWith(':') ? note : ': $note',
              style: const pw.TextStyle(fontSize: 7.5, color: _mutedText),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildSalesRepFooter(BoomBarrierProposalDraft draft, [String? generatedByName]) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Sales/Ref  :-${draft.salesmanName}',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _navy),
            ),
            pw.Text(
              'Mob. No   : ${draft.salesmanPhone}',
              style: const pw.TextStyle(fontSize: 8.5, color: _darkText),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (generatedByName != null && generatedByName.isNotEmpty)
              pw.Text(
                'Generated by: $generatedByName',
                style: const pw.TextStyle(fontSize: 7.5, color: _mutedText),
              ),
            pw.Text(
              'Page 2 of 5',
              style: const pw.TextStyle(fontSize: 8, color: _mutedText),
            ),
          ],
        ),
      ],
    );
  }

  // ─── PAGE 3 SPECIFICATIONS & TERMS ──────────────────────────────────────

  static pw.Widget _buildTermsAndConditions(BoomBarrierProposalDraft draft) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TERMS & CONDITIONS',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navy),
        ),
        pw.SizedBox(height: 4),
        for (final t in draft.terms)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            child: pw.Text(
              t.replaceAll('{payment_sentence}', draft.paymentSentence),
              style: const pw.TextStyle(fontSize: 8, color: _darkText),
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildSpecsSection(BoomBarrierProposalDraft draft) {
    if (!draft.includeLprSpecs) {
      // Only Primary Barrier Specs are rendered cleanly across the page
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PRODUCT SPECIFICATIONS- MODEL NO- ${draft.primaryModelNo}',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _navy),
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: _borderColor, width: 1.0),
            columnWidths: const {
              0: pw.FixedColumnWidth(180),
              1: pw.FlexColumnWidth(),
            },
            children: [
              for (final row in draft.barrierSpecs)
                if (row['visible'] != false)
                  pw.TableRow(
                    children: [
                      _td(row['label']?.toString() ?? '', bold: true),
                      _td(row['value']?.toString() ?? ''),
                    ],
                  ),
            ],
          ),
        ],
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Barrier Specs Table
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PRODUCT SPECIFICATIONS- MODEL NO- ${draft.primaryModelNo}',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _navy),
              ),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: _borderColor, width: 1.0),
                children: [
                  for (final row in draft.barrierSpecs)
                    if (row['visible'] != false)
                      pw.TableRow(
                        children: [
                          _td(row['label']?.toString() ?? '', bold: true),
                          _td(row['value']?.toString() ?? ''),
                        ],
                      ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        // LPR Specs Table
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PRODUCT SPECIFICATIONS- MODEL NO- LPR',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _navy),
              ),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: _borderColor, width: 1.0),
                children: [
                  for (final row in draft.lprSpecs)
                    if (row['visible'] != false)
                      pw.TableRow(
                        children: [
                          _td(row['label']?.toString() ?? '', bold: true),
                          _td(row['value']?.toString() ?? ''),
                        ],
                      ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildBankDetails(BoomBarrierProposalDraft draft) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'BANK ACCOUNT DETAILS:',
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _navy),
        ),
        pw.SizedBox(height: 3),
        pw.Text('Account Name   :- ${draft.bankAccountName}', style: const pw.TextStyle(fontSize: 8, color: _darkText)),
        pw.Text('Bank Name      :- ${draft.bankName}', style: const pw.TextStyle(fontSize: 8, color: _darkText)),
        pw.Text('Account Number :- ${draft.bankAccountNumber}', style: const pw.TextStyle(fontSize: 8, color: _darkText)),
        pw.Text('Branch         :- ${draft.bankBranch}', style: const pw.TextStyle(fontSize: 8, color: _darkText)),
        pw.Text('IFSC Code      :- ${draft.bankIfsc}', style: const pw.TextStyle(fontSize: 8, color: _darkText)),
      ],
    );
  }

  // ─── PAGE 4 GALLERY GRID ───────────────────────────────────────────────

  static pw.Widget _buildProductGalleryGrid({
    Uint8List? imgIz2001,
    Uint8List? imgIz2026,
    Uint8List? imgIz2004,
    Uint8List? imgNprs,
  }) {
    return pw.Column(
      children: [
        // Row 1: IZ-2001 & IZ-2026
        pw.Row(
          children: [
            pw.Expanded(child: _buildGalleryCard('IZ-2001', imgIz2001)),
            pw.SizedBox(width: 20),
            pw.Expanded(child: _buildGalleryCard('IZ-2026', imgIz2026)),
          ],
        ),
        pw.SizedBox(height: 20),
        // Row 2: IZ-2004 & NPRS
        pw.Row(
          children: [
            pw.Expanded(child: _buildGalleryCard('IZ-2004', imgIz2004)),
            pw.SizedBox(width: 20),
            pw.Expanded(child: _buildGalleryCard('Number Plate Recognition System (NPRS)', imgNprs)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildGalleryCard(String label, Uint8List? imgBytes) {
    return pw.Container(
      height: 280,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Expanded(
            child: imgBytes != null
                ? pw.Image(pw.MemoryImage(imgBytes), fit: pw.BoxFit.contain)
                : pw.Center(
                    child: pw.Text(
                      label,
                      style: const pw.TextStyle(fontSize: 10, color: _mutedText),
                    ),
                  ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            label,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy),
          ),
        ],
      ),
    );
  }

  // ─── PAGE 5 ACCEPTANCE LETTER ──────────────────────────────────────────

  static pw.Widget _buildAcceptanceLetterBody(
    BoomBarrierProposalDraft draft,
    Uint8List? stampBytes,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            'QUOTATION ACCEPTANCE LETTER',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Text(
          'Customer Name : ${draft.customerName}',
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Customer Address : ${draft.customerAddress}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Date: ${draft.quoteDate}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Subject: Quotation for Supply & Installation of Boom Barrier for Entry Gate Model No ${draft.primaryModelNo}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navy),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Dear Sir,',
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          draft.acceptanceP1,
          style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          draft.acceptanceP2,
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 40),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  draft.acceptanceClosing,
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  draft.customerName,
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Mob. No:- ${draft.customerPhone}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
            if (stampBytes != null)
              pw.Container(
                width: 90,
                height: 90,
                child: pw.Image(pw.MemoryImage(stampBytes), fit: pw.BoxFit.contain),
              ),
          ],
        ),
      ],
    );
  }

  // ─── TABLE HELPERS ──────────────────────────────────────────────────────

  static pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _navy),
      ),
    );
  }

  static pw.Widget _td(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
    PdfColor color = _darkText,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _buildWatermark() {
    return pw.Positioned.fill(
      child: pw.Center(
        child: pw.Transform.rotate(
          angle: -0.5,
          child: pw.Text(
            'DRAFT - NOT APPROVED',
            style: pw.TextStyle(
              fontSize: 42,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red.shade(0.2),
            ),
          ),
        ),
      ),
    );
  }

  static Future<Uint8List?> _loadImageBytes(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    final trimmed = path.trim();
    try {
      // 1. Base64 data URI
      if (trimmed.startsWith('data:image')) {
        final commaIdx = trimmed.indexOf(',');
        if (commaIdx != -1) {
          return base64Decode(trimmed.substring(commaIdx + 1));
        }
      }

      // 2. Pure Base64
      if (trimmed.length > 100 &&
          !trimmed.contains('/') &&
          !trimmed.contains('\\') &&
          !trimmed.contains(':')) {
        try {
          return base64Decode(trimmed);
        } catch (_) {}
      }

      // 3. Asset path (handles Flutter Web and Native)
      if (trimmed.startsWith('assets/')) {
        final data = await rootBundle.load(trimmed);
        return data.buffer.asUint8List();
      }

      // 4. Supabase Storage URL - bypasses browser CORS via Supabase client SDK
      if (trimmed.contains('/storage/v1/object/')) {
        try {
          final uri = Uri.parse(trimmed);
          final pathSegments = uri.pathSegments;
          final objIdx = pathSegments.indexOf('object');
          if (objIdx != -1) {
            int bucketIdx = objIdx + 1;
            if (bucketIdx < pathSegments.length &&
                (pathSegments[bucketIdx] == 'public' ||
                 pathSegments[bucketIdx] == 'authenticated' ||
                 pathSegments[bucketIdx] == 'sign')) {
              bucketIdx++;
            }
            if (bucketIdx < pathSegments.length) {
              final bucket = pathSegments[bucketIdx];
              final rawPath = pathSegments.sublist(bucketIdx + 1).join('/');
              final filePath = Uri.decodeComponent(rawPath);
              if (bucket.isNotEmpty && filePath.isNotEmpty) {
                final downloaded = await Supabase.instance.client.storage
                    .from(bucket)
                    .download(filePath);
                return downloaded;
              }
            }
          }
        } catch (_) {}
      }

      // 5. Remote HTTP/HTTPS URL
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final res = await http.get(Uri.parse(trimmed));
        if (res.statusCode == 200) return res.bodyBytes;
      }

      // 6. Local File (only on non-web platforms where dart:io File exists)
      if (!kIsWeb) {
        final file = File(trimmed);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      }

      // 7. Fallback asset check
      try {
        final data = await rootBundle.load('assets/$trimmed');
        return data.buffer.asUint8List();
      } catch (_) {}

      return null;
    } catch (_) {
      return null;
    }
  }
}
