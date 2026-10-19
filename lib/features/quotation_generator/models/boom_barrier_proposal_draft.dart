// lib/features/quotation_generator/models/boom_barrier_proposal_draft.dart

import 'boom_barrier_at_actual_line.dart';
import 'boom_barrier_line_item.dart';
import 'deal_quotation_item.dart';
import 'qg_product_profile.dart';
import '../services/boom_barrier_math.dart';
import '../services/qg_boom_barrier_item_parser.dart';
import '../../../core/utils/financial_year_helper.dart';

/// In-memory and persisted draft state for a Boom Barrier quotation proposal.
class BoomBarrierProposalDraft {
  final String quotationId;
  final String quotationNumber;
  final String status;
  final int revision;
  final DateTime quotationUpdatedAt;
  DateTime draftUpdatedAt;

  // Customer Details
  String customerName;
  String customerAddress;
  String customerPhone;
  String? customerGst;

  // Salesperson Details
  String salesmanName;
  String salesmanPhone;

  // Reference & Date
  String quoteDate; // dd/MM/yyyy
  String refNumber; // SD/SS/25-26/442
  String subjectText;
  String introLine;
  String optionTitle;

  // Table Line Items
  List<BoomBarrierLineItem> items;
  List<BoomBarrierAtActualLine> atActualCharges;

  // Financial Totals
  double subtotal;
  double gstPercent;
  double gstAmount;
  double grandTotal;

  // Technical Specs
  String primaryModelNo; // 'IZ-2001', 'IZ-2026', 'IZ-2004'
  List<Map<String, dynamic>> barrierSpecs;
  bool includeLprSpecs;
  List<Map<String, dynamic>> lprSpecs;

  // Notes, Terms & Acceptance
  List<String> notes;
  List<String> terms;
  String paymentSentence;
  String acceptanceP1;
  String acceptanceP2;
  String acceptanceClosing;

  // Bank Account
  String bankAccountName;
  String bankName;
  String bankAccountNumber;
  String bankBranch;
  String bankIfsc;

  // Branding / Image overrides
  String? logoPath;
  String? coverImagePath;
  String? stampPath;
  String? galleryIz2001Path;
  String? galleryIz2026Path;
  String? galleryIz2004Path;
  String? galleryNprsPath;

  BoomBarrierProposalDraft({
    required this.quotationId,
    required this.quotationNumber,
    required this.status,
    required this.revision,
    required this.quotationUpdatedAt,
    required this.draftUpdatedAt,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    this.customerGst,
    required this.salesmanName,
    required this.salesmanPhone,
    required this.quoteDate,
    required this.refNumber,
    required this.subjectText,
    required this.introLine,
    this.optionTitle = 'Option 1',
    required this.items,
    required this.atActualCharges,
    required this.subtotal,
    this.gstPercent = 18.0,
    required this.gstAmount,
    required this.grandTotal,
    required this.primaryModelNo,
    required this.barrierSpecs,
    this.includeLprSpecs = false,
    required this.lprSpecs,
    required this.notes,
    required this.terms,
    required this.paymentSentence,
    required this.acceptanceP1,
    this.acceptanceP2 = 'Looking forward to doing business with you.',
    this.acceptanceClosing = 'Yours sincerely,',
    required this.bankAccountName,
    required this.bankName,
    required this.bankAccountNumber,
    required this.bankBranch,
    required this.bankIfsc,
    this.logoPath,
    this.coverImagePath,
    this.stampPath,
    this.galleryIz2001Path,
    this.galleryIz2026Path,
    this.galleryIz2004Path,
    this.galleryNprsPath,
  });

  /// Returns standard default specifications for a given model.
  static List<Map<String, dynamic>> defaultSpecsForModel(String modelNo) {
    final upper = modelNo.toUpperCase().trim();
    final has2026 = upper.contains('2026');
    final has2004 = upper.contains('2004');
    final has2001 = upper.contains('2001');

    if (has2026 && has2001) {
      return [
        {'label': 'Model No', 'value': 'IZ-2001 & IZ-2026', 'visible': true},
        {'label': 'Power Supply', 'value': 'IZ-2001: 24V/10 AMP | IZ-2026: 24V DC / 220V AC', 'visible': true},
        {'label': 'Motor Power', 'value': 'IZ-2001: 90W | IZ-2026: 140W Brushless DC', 'visible': true},
        {'label': 'Boom Length', 'value': 'IZ-2001: 6M | IZ-2026: 4.5M - 6M', 'visible': true},
        {'label': 'Opening Time', 'value': 'IZ-2001: 3s - 6s | IZ-2026: 1.5s - 3s (Adjustable)', 'visible': true},
        {'label': 'RPM / Duty Cycle', 'value': 'IZ-2001: 1500 RPM | IZ-2026: 100% Continuous Duty', 'visible': true},
        {'label': 'Remote Distance', 'value': '30M (Transmitter)', 'visible': true},
        {'label': 'Working Temp', 'value': '-25°C to +70°C', 'visible': true},
        {'label': 'Housing Dimensions', 'value': 'IZ-2001: 100*34*26 cm | IZ-2026: 350*280*1020 mm', 'visible': true},
        {'label': 'Weight', 'value': 'IZ-2001: 35KG | IZ-2026: 45KG', 'visible': true},
        {'label': 'Protection Class', 'value': 'IP54 / IP55', 'visible': true},
      ];
    }
    if (has2026) {
      return [
        {'label': 'Power Supply', 'value': '24V DC / 220V AC', 'visible': true},
        {'label': 'Motor Power', 'value': '140W Brushless DC', 'visible': true},
        {'label': 'Boom Length', 'value': '4.5M - 6M', 'visible': true},
        {'label': 'Opening Time', 'value': '1.5s - 3s (Adjustable)', 'visible': true},
        {'label': 'Duty Cycle', 'value': '100% Continuous', 'visible': true},
        {'label': 'Remote Distance', 'value': '30M', 'visible': true},
        {'label': 'Working Temp', 'value': '-30°C to +70°C', 'visible': true},
        {'label': 'Housing Dia', 'value': '350*280*1020 mm', 'visible': true},
        {'label': 'Weight', 'value': '45KG', 'visible': true},
        {'label': 'Protection Class', 'value': 'IP54', 'visible': true},
      ];
    }
    if (has2004) {
      return [
        {'label': 'Power Supply', 'value': '220V AC ± 10%', 'visible': true},
        {'label': 'Motor Power', 'value': '120W AC', 'visible': true},
        {'label': 'Boom Length', 'value': '4M - 6M Telescopic', 'visible': true},
        {'label': 'Opening Time', 'value': '3s - 6s', 'visible': true},
        {'label': 'RPM', 'value': '1400 RPM', 'visible': true},
        {'label': 'Remote Distance', 'value': '30M', 'visible': true},
        {'label': 'Working Temp', 'value': '-25°C to +65°C', 'visible': true},
        {'label': 'Housing Dia', 'value': '340*280*1000 mm', 'visible': true},
        {'label': 'Weight', 'value': '40KG', 'visible': true},
        {'label': 'Protection Class', 'value': 'IP55', 'visible': true},
      ];
    }
    // Default IZ-2001 (High Speed)
    return [
      {'label': 'Power Supply', 'value': '24V/10 AMP', 'visible': true},
      {'label': 'Motor Power', 'value': '90W', 'visible': true},
      {'label': 'Boom Length', 'value': '6M', 'visible': true},
      {'label': 'RPM', 'value': '1500 RPM', 'visible': true},
      {'label': 'Remote Distance', 'value': '6M', 'visible': true},
      {'label': 'Transmitter', 'value': '30M', 'visible': true},
      {'label': 'Working Temp', 'value': '-25°C +60°C', 'visible': true},
      {'label': 'Housing Dia', 'value': '100*34*26', 'visible': true},
      {'label': 'Weight', 'value': '35KG', 'visible': true},
      {'label': 'Protection Class', 'value': 'IP55', 'visible': true},
    ];
  }

  /// Returns standard default specifications for Number Plate Recognition Camera (LPR/NPRS).
  static List<Map<String, dynamic>> defaultLprSpecs() {
    return [
      {'label': 'Size', 'value': '450*150*120 mm', 'visible': true},
      {'label': 'Operating temperature', 'value': '-20°C to +70°C', 'visible': true},
      {'label': 'Related humidity', 'value': '≤ 95% Non-condensing', 'visible': true},
      {'label': 'Normal work life', 'value': '> 50,000 Hours', 'visible': true},
      {'label': 'Power supply', 'value': 'DC 12V / PoE', 'visible': true},
      {'label': 'Operating system', 'value': 'Embedded Linux', 'visible': true},
      {'label': 'Power interface', 'value': 'RJ45 / Terminal Block', 'visible': true},
      {'label': 'Identification accuracy', 'value': '≥ 99.5% (Day & Night)', 'visible': true},
      {'label': 'Voice prompt', 'value': 'Integrated Audio Speaker', 'visible': true},
    ];
  }

  /// Factory constructing an initial draft from a CRM deal quotation and product profile.
  factory BoomBarrierProposalDraft.fromDealQuotation(
    DealQuotationItem deal, [
    QgProductProfile? profile,
  ]) {
    final prof = profile ?? QgProductProfile.defaultBoomBarrier();
    final parseResult = QgBoomBarrierItemParser.parse(deal);

    final mathResult = BoomBarrierMath.calculate(
      items: parseResult.lineItems,
      gstPercent: 18.0,
    );

    final defaultBarrierSpecs = defaultSpecsForModel(parseResult.detectedModelNo);
    final defaultLpr = defaultLprSpecs();

    final defaultNotes = [
      ': In 100 Meter Civil, Plumber, Earthling, Electrical work done by Clint side.',
      ': 1 Phase 230V AC, 5 Amp with proper earthing Power Supply at Entry Gate/Barrier',
      ': Cabling will be through 25mm 2 kg PVC conduit only.',
      ': Loop wire will be installed in 25mm 6 kg PVC conduit.',
      ': In case of open cabling it will be charged as per actual.',
      ': Any other work apart from the above will be charged extra.',
      ': Standard delivery & installation will depends up on site conditions.',
    ];

    final defaultTerms = [
      '1) Quotation Validity for 7 days only',
      '2) Delivery: within 7 Days',
      '3) Warranty: 2 years',
      '4) Payment: {payment_sentence}',
      '5) Installation Period: 1-2 Week or depends up on site conditions.',
      '6) 1 Year onsite service free for service call only.',
      '7) AMC charges 15% on total invoice value after 2 years.',
    ];

    final paymentSentence = deal.paymentTerms.isNotEmpty
        ? deal.paymentTerms.map((t) => '${t['percentage']}% ${t['term'] ?? t['condition']}').join(', ')
        : '80% Advance, 20% Against Delivery & Installation';

    final refNo = deal.quotationNumber.isNotEmpty ? deal.quotationNumber : 'SD/SS/25-26/442';

    final atActual = prof.defaultAtActualCharges.isNotEmpty
        ? prof.defaultAtActualCharges.map((e) => BoomBarrierAtActualLine.fromJson(e)).toList()
        : [
            const BoomBarrierAtActualLine(
              srNo: 1,
              description: 'Wiring charges CAT6 + 3 core Power cable',
              qty: '1 mtr',
              rate: '150.00',
              total: 'At Actual',
            ),
          ];

    return BoomBarrierProposalDraft(
      quotationId: deal.id,
      quotationNumber: deal.quotationNumber,
      status: deal.status,
      revision: deal.revision,
      quotationUpdatedAt: deal.updatedAt,
      draftUpdatedAt: DateTime.now(),
      customerName: deal.customerName,
      customerAddress: deal.customerAddress,
      customerPhone: deal.customerPhone,
      customerGst: deal.customerGst,
      salesmanName: deal.salesmanName.isNotEmpty ? deal.salesmanName : 'Sagar Farate (Rahul)',
      salesmanPhone: deal.salesmanPhone.isNotEmpty ? deal.salesmanPhone : '7588874019',
      quoteDate: deal.formattedDate,
      refNumber: refNo,
      subjectText: 'Quotation for Supply & Installation of Boom Barrier for Entry Gate Model No- ${parseResult.detectedModelNo}',
      introLine: 'With reference to your requirement of Barrier for Entry Gate, we are pleased to submit our best offer for the same.',
      optionTitle: 'Option 1',
      items: parseResult.lineItems,
      atActualCharges: atActual,
      subtotal: mathResult.subtotal,
      gstPercent: mathResult.gstPercent,
      gstAmount: mathResult.gstAmount,
      grandTotal: mathResult.grandTotal,
      primaryModelNo: parseResult.detectedModelNo,
      barrierSpecs: defaultBarrierSpecs,
      includeLprSpecs: parseResult.hasLpr,
      lprSpecs: defaultLpr,
      notes: prof.defaultNotes.isNotEmpty ? prof.defaultNotes : defaultNotes,
      terms: prof.defaultTerms.isNotEmpty ? prof.defaultTerms : defaultTerms,
      paymentSentence: paymentSentence,
      acceptanceP1: "With reference to quotation number $refNo dated ${deal.formattedDate}, with Quotation Value ₹ ${BoomBarrierMath.formatIndianNumber(mathResult.grandTotal)}, I'm glad to inform you that your quote has been Approved for the corresponding project, With Term conditions of Payment: $paymentSentence.",
      acceptanceP2: 'Looking forward to doing business with you.',
      acceptanceClosing: 'Yours sincerely,',
      bankAccountName: prof.bankAccountName,
      bankName: prof.bankName,
      bankAccountNumber: prof.bankAccountNo,
      bankBranch: prof.bankBranch,
      bankIfsc: prof.bankIfsc,
      logoPath: prof.logoPath,
      coverImagePath: prof.defaultCoverPath,
      stampPath: prof.stampPath,
      galleryIz2001Path: null,
      galleryIz2026Path: null,
      galleryIz2004Path: null,
      galleryNprsPath: null,
    );
  }

  /// Recalculates financial totals using current line items.
  void recalculateTotals() {
    final result = BoomBarrierMath.calculate(
      items: items,
      gstPercent: gstPercent,
    );
    subtotal = result.subtotal;
    gstAmount = result.gstAmount;
    grandTotal = result.grandTotal;
  }

  factory BoomBarrierProposalDraft.fromJson(Map<String, dynamic> json) {
    return BoomBarrierProposalDraft(
      quotationId: json['quotation_id'] as String? ?? '',
      quotationNumber: FinancialYearHelper.formatDocumentNumber(json['quotation_number'] as String? ?? ''),
      status: json['status'] as String? ?? 'confirmed',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      quotationUpdatedAt: DateTime.tryParse(json['quotation_updated_at']?.toString() ?? '') ?? DateTime.now(),
      draftUpdatedAt: DateTime.tryParse(json['draft_updated_at']?.toString() ?? '') ?? DateTime.now(),
      customerName: json['customer_name'] as String? ?? '',
      customerAddress: json['customer_address'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      customerGst: json['customer_gst'] as String?,
      salesmanName: json['salesman_name'] as String? ?? '',
      salesmanPhone: json['salesman_phone'] as String? ?? '',
      quoteDate: json['quote_date'] as String? ?? '',
      refNumber: FinancialYearHelper.formatDocumentNumber(json['ref_number'] as String? ?? ''),
      subjectText: json['subject_text'] as String? ?? '',
      introLine: json['intro_line'] as String? ?? '',
      optionTitle: json['option_title'] as String? ?? 'Option 1',
      items: ((json['items'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => BoomBarrierLineItem.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      atActualCharges: ((json['at_actual_charges'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => BoomBarrierAtActualLine.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      gstPercent: (json['gst_percent'] as num?)?.toDouble() ?? 18.0,
      gstAmount: (json['gst_amount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
      primaryModelNo: json['primary_model_no'] as String? ?? 'IZ-2001',
      barrierSpecs: ((json['barrier_specs'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
      includeLprSpecs: json['include_lpr_specs'] as bool? ?? false,
      lprSpecs: ((json['lpr_specs'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
      notes: (json['notes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      terms: (json['terms'] as List?)?.map((e) => e.toString()).toList() ?? [],
      paymentSentence: json['payment_sentence'] as String? ?? '',
      acceptanceP1: json['acceptance_p1'] as String? ?? '',
      acceptanceP2: json['acceptance_p2'] as String? ?? 'Looking forward to doing business with you.',
      acceptanceClosing: json['acceptance_closing'] as String? ?? 'Yours sincerely,',
      bankAccountName: json['bank_account_name'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      bankAccountNumber: json['bank_account_number'] as String? ?? '',
      bankBranch: json['bank_branch'] as String? ?? '',
      bankIfsc: json['bank_ifsc'] as String? ?? '',
      logoPath: json['logo_path'] as String?,
      coverImagePath: json['cover_image_path'] as String?,
      stampPath: json['stamp_path'] as String?,
      galleryIz2001Path: json['gallery_iz_2001_path'] as String?,
      galleryIz2026Path: json['gallery_iz_2026_path'] as String?,
      galleryIz2004Path: json['gallery_iz_2004_path'] as String?,
      galleryNprsPath: json['gallery_nprs_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quotation_id': quotationId,
      'quotation_number': quotationNumber,
      'status': status,
      'revision': revision,
      'quotation_updated_at': quotationUpdatedAt.toIso8601String(),
      'draft_updated_at': draftUpdatedAt.toIso8601String(),
      'customer_name': customerName,
      'customer_address': customerAddress,
      'customer_phone': customerPhone,
      if (customerGst != null) 'customer_gst': customerGst,
      'salesman_name': salesmanName,
      'salesman_phone': salesmanPhone,
      'quote_date': quoteDate,
      'ref_number': refNumber,
      'subject_text': subjectText,
      'intro_line': introLine,
      'option_title': optionTitle,
      'items': items.map((i) => i.toJson()).toList(),
      'at_actual_charges': atActualCharges.map((a) => a.toJson()).toList(),
      'subtotal': subtotal,
      'gst_percent': gstPercent,
      'gst_amount': gstAmount,
      'grand_total': grandTotal,
      'primary_model_no': primaryModelNo,
      'barrier_specs': barrierSpecs,
      'include_lpr_specs': includeLprSpecs,
      'lpr_specs': lprSpecs,
      'notes': notes,
      'terms': terms,
      'payment_sentence': paymentSentence,
      'acceptance_p1': acceptanceP1,
      'acceptance_p2': acceptanceP2,
      'acceptance_closing': acceptanceClosing,
      'bank_account_name': bankAccountName,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_branch': bankBranch,
      'bank_ifsc': bankIfsc,
      if (logoPath != null) 'logo_path': logoPath,
      if (coverImagePath != null) 'cover_image_path': coverImagePath,
      if (stampPath != null) 'stamp_path': stampPath,
      if (galleryIz2001Path != null) 'gallery_iz_2001_path': galleryIz2001Path,
      if (galleryIz2026Path != null) 'gallery_iz_2026_path': galleryIz2026Path,
      if (galleryIz2004Path != null) 'gallery_iz_2004_path': galleryIz2004Path,
      if (galleryNprsPath != null) 'gallery_nprs_path': galleryNprsPath,
    };
  }
}
