// lib/features/quotation_generator/services/pdf_boom_barrier_builder.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/boom_barrier_proposal_draft.dart';
import '../models/qg_product_profile.dart';
import 'boom_barrier_math.dart';

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
  static const PdfColor _accentTeal = PdfColor.fromInt(0xFF0D9488);

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
    final logoBytes = assetOverrides?['logo'] ??
        await _loadImageBytes(draft.logoPath ?? profile.logoPath);
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

    final isConfirmed = draft.status.trim().toLowerCase() == 'confirmed';

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

    // ─── PAGE 2: QUOTATION & OPTION 1 PRICE TABLE ─────────────────────────
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
                  pw.Spacer(),
                  _buildSalesRepFooter(draft),
                ],
              ),
              if (!isConfirmed) _buildWatermark(),
            ],
          );
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
                  pw.Spacer(),
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
          border: pw.TableBorder.all(color: _borderColor, width: 1.0),
          columnWidths: {
            0: const pw.FixedColumnWidth(colSr),
            1: const pw.FlexColumnWidth(),
            2: const pw.FixedColumnWidth(colQty),
            3: const pw.FixedColumnWidth(colRate),
            4: const pw.FixedColumnWidth(colDisc),
            5: const pw.FixedColumnWidth(colPrice),
          },
          children: [
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

            // Sub Total Row
            pw.TableRow(
              children: [
                _td(''),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                  child: pw.Text(
                    'Sub Total',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                _td(''),
                _td(''),
                _td(''),
                _td(
                  BoomBarrierMath.formatRawOrIndian(draft.subtotal),
                  align: pw.TextAlign.right,
                  bold: true,
                ),
              ],
            ),
            // GST Row
            pw.TableRow(
              children: [
                _td(''),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                  child: pw.Text(
                    'GST ${draft.gstPercent.toInt()}%',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                _td(''),
                _td(''),
                _td(''),
                _td(
                  BoomBarrierMath.formatIndianCurrencyWithSymbol(draft.gstAmount),
                  align: pw.TextAlign.right,
                  bold: true,
                ),
              ],
            ),
            // Total Row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _headerBg),
              children: [
                _td(''),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                  child: pw.Text(
                    'Total',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _navy),
                  ),
                ),
                _td(''),
                _td(''),
                _td(''),
                _td(
                  BoomBarrierMath.formatIndianCurrencyWithSymbol(draft.grandTotal),
                  align: pw.TextAlign.right,
                  bold: true,
                  color: _navy,
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

  static pw.Widget _buildSalesRepFooter(BoomBarrierProposalDraft draft) {
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
        pw.Text(
          'Page 2 of 5',
          style: const pw.TextStyle(fontSize: 8, color: _mutedText),
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
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _headerBg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _borderColor, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BANK ACCOUNT DETAILS:',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _navy),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Account Name   :- ${draft.bankAccountName}', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Bank Name      :- ${draft.bankName}', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Account Number :- ${draft.bankAccountNumber}', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Branch         :- ${draft.bankBranch}', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('IFSC Code      :- ${draft.bankIfsc}', style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
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

  static Future<Uint8List?> _loadImageBytes(String path) async {
    try {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        final res = await http.get(Uri.parse(path));
        if (res.statusCode == 200) return res.bodyBytes;
      }
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
