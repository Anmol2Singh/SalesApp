// lib/features/quotation_generator/models/qg_noc_builder_state.dart

/// NOC Wording Mode
enum NocWordingMode {
  /// Verbatim reproduction of reference template including original wording
  templateExact,

  /// Clean, modernized, numbered certification with enhanced wording (DEFAULT)
  enhanced;

  String get displayName => this == NocWordingMode.templateExact ? 'Template Exact' : 'Enhanced (Recommended)';
}

/// NOC Status
enum NocStatus {
  draft,
  issued,
  signed,
  archived;

  String get displayName {
    switch (this) {
      case NocStatus.draft:
        return 'Draft';
      case NocStatus.issued:
        return 'Issued';
      case NocStatus.signed:
        return 'Signed';
      case NocStatus.archived:
        return 'Archived';
    }
  }
}

/// Date Source for the NOC Date
enum NocDateSource {
  generationDate,
  installationCompletedDate,
  dealCompletedDate;

  String get displayName {
    switch (this) {
      case NocDateSource.generationDate:
        return 'Date of Generation (Today)';
      case NocDateSource.installationCompletedDate:
        return 'Installation Completion Date';
      case NocDateSource.dealCompletedDate:
        return 'Deal Completion Date';
    }
  }
}

/// Extracted Equipment Line for NOC System Details
class NocEquipmentLine {
  final String product;
  final String model;
  final int quantity;
  final String uom;
  final bool isAmbiguous;
  final String? ambiguityReason;

  const NocEquipmentLine({
    required this.product,
    required this.model,
    required this.quantity,
    this.uom = 'Nos',
    this.isAmbiguous = false,
    this.ambiguityReason,
  });

  NocEquipmentLine copyWith({
    String? product,
    String? model,
    int? quantity,
    String? uom,
    bool? isAmbiguous,
    String? ambiguityReason,
  }) {
    return NocEquipmentLine(
      product: product ?? this.product,
      model: model ?? this.model,
      quantity: quantity ?? this.quantity,
      uom: uom ?? this.uom,
      isAmbiguous: isAmbiguous ?? this.isAmbiguous,
      ambiguityReason: ambiguityReason ?? this.ambiguityReason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product': product,
      'model': model,
      'quantity': quantity,
      'uom': uom,
      'is_ambiguous': isAmbiguous,
      'ambiguity_reason': ambiguityReason,
    };
  }

  factory NocEquipmentLine.fromMap(Map<String, dynamic> map) {
    return NocEquipmentLine(
      product: map['product']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      uom: map['uom']?.toString() ?? 'Nos',
      isAmbiguous: map['is_ambiguous'] as bool? ?? false,
      ambiguityReason: map['ambiguity_reason']?.toString(),
    );
  }
}

/// Deal eligibility evaluation result
class NocEligibilityResult {
  final bool isEligible;
  final List<String> reasons;
  final Map<String, dynamic>? matchedInstallation;
  final bool canAdminOverride;

  const NocEligibilityResult({
    required this.isEligible,
    this.reasons = const [],
    this.matchedInstallation,
    this.canAdminOverride = false,
  });
}

/// Full NOC Payload represented in memory and stored in JSONB
class QgNocPayload {
  // Company block
  final String companyName;
  final String companyAddress;
  final String companyEmail;
  final String companyPhone;
  final String companyWebsite;
  final String? logoUrl;
  final String? stampImagePath;

  // Header & Subject
  final String salutation; // e.g. 'M/s'
  final String customerName; // e.g. 'TURQUOISE PUNE'
  final String recipient; // e.g. 'The Project Mannager.'
  final String address;
  final String productName; // e.g. 'Boom Barrier'
  final String subject;
  final DateTime date;
  final String? quotationNumber;
  final String? installationTicketNo;
  final DateTime? installationDate;

  // System Details
  final String equipmentLabel;
  final List<NocEquipmentLine> equipmentLines;
  final String workType;
  final String leakage; // 'Done' | 'Not Applicable'
  final String wiring; // 'Done' | 'Not Applicable'
  final String testing; // 'Done' | 'Not Applicable'
  final String remark;

  // Confirmations & Closing
  final List<String> confirmations;
  final String closingSentence;

  // Mode
  final NocWordingMode wordingMode;

  const QgNocPayload({
    required this.companyName,
    required this.companyAddress,
    required this.companyEmail,
    required this.companyPhone,
    required this.companyWebsite,
    this.logoUrl,
    this.stampImagePath,
    this.salutation = 'M/s',
    required this.customerName,
    this.recipient = 'The Project Mannager.',
    required this.address,
    required this.productName,
    required this.subject,
    required this.date,
    this.quotationNumber,
    this.installationTicketNo,
    this.installationDate,
    required this.equipmentLabel,
    required this.equipmentLines,
    required this.workType,
    this.leakage = 'Done',
    this.wiring = 'Done',
    this.testing = 'Done',
    required this.remark,
    required this.confirmations,
    required this.closingSentence,
    this.wordingMode = NocWordingMode.enhanced,
  });

  Map<String, dynamic> toMap() {
    return {
      'company_name': companyName,
      'company_address': companyAddress,
      'company_email': companyEmail,
      'company_phone': companyPhone,
      'company_website': companyWebsite,
      'logo_url': logoUrl,
      'stamp_image_path': stampImagePath,
      'salutation': salutation,
      'customer_name': customerName,
      'recipient': recipient,
      'address': address,
      'product_name': productName,
      'subject': subject,
      'date': date.toIso8601String(),
      'quotation_number': quotationNumber,
      'installation_ticket_no': installationTicketNo,
      'installation_date': installationDate?.toIso8601String(),
      'equipment_label': equipmentLabel,
      'equipment_lines': equipmentLines.map((e) => e.toMap()).toList(),
      'work_type': workType,
      'leakage': leakage,
      'wiring': wiring,
      'testing': testing,
      'remark': remark,
      'confirmations': confirmations,
      'closing_sentence': closingSentence,
      'wording_mode': wordingMode.name,
    };
  }

  factory QgNocPayload.fromMap(Map<String, dynamic> map) {
    List<NocEquipmentLine> lines = [];
    if (map['equipment_lines'] is List) {
      lines = (map['equipment_lines'] as List)
          .map((e) => NocEquipmentLine.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    List<String> confs = [];
    if (map['confirmations'] is List) {
      confs = (map['confirmations'] as List).map((e) => e.toString()).toList();
    }

    return QgNocPayload(
      companyName: map['company_name']?.toString() ?? '',
      companyAddress: map['company_address']?.toString() ?? '',
      companyEmail: map['company_email']?.toString() ?? '',
      companyPhone: map['company_phone']?.toString() ?? '',
      companyWebsite: map['company_website']?.toString() ?? '',
      logoUrl: map['logo_url']?.toString(),
      stampImagePath: map['stamp_image_path']?.toString(),
      salutation: map['salutation']?.toString() ?? 'M/s',
      customerName: map['customer_name']?.toString() ?? '',
      recipient: map['recipient']?.toString() ?? 'The Project Mannager.',
      address: map['address']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now() : DateTime.now(),
      quotationNumber: map['quotation_number']?.toString(),
      installationTicketNo: map['installation_ticket_no']?.toString(),
      installationDate: map['installation_date'] != null ? DateTime.tryParse(map['installation_date'].toString()) : null,
      equipmentLabel: map['equipment_label']?.toString() ?? '',
      equipmentLines: lines,
      workType: map['work_type']?.toString() ?? '',
      leakage: map['leakage']?.toString() ?? 'Done',
      wiring: map['wiring']?.toString() ?? 'Done',
      testing: map['testing']?.toString() ?? 'Done',
      remark: map['remark']?.toString() ?? '',
      confirmations: confs,
      closingSentence: map['closing_sentence']?.toString() ?? '',
      wordingMode: map['wording_mode'] == 'templateExact' ? NocWordingMode.templateExact : NocWordingMode.enhanced,
    );
  }
}
