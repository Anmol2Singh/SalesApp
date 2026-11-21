import 'qg_noc_builder_state.dart';

class QgNocDocument {
  final String id;
  final String pipelineId;
  final String? quotationId;
  final String? customerId;
  final String? installationId;
  final String nocNo;
  final int version;
  final bool isCurrent;
  final DateTime issuedOn;
  final Map<String, dynamic> payload;
  final String? pdfPath;
  final String? pdfName;
  final String? overrideReason;
  final String? createdBy;
  final DateTime createdAt;

  const QgNocDocument({
    required this.id,
    required this.pipelineId,
    this.quotationId,
    this.customerId,
    this.installationId,
    required this.nocNo,
    this.version = 1,
    this.isCurrent = true,
    required this.issuedOn,
    this.payload = const {},
    this.pdfPath,
    this.pdfName,
    this.overrideReason,
    this.createdBy,
    required this.createdAt,
  });

  factory QgNocDocument.fromMap(Map<String, dynamic> map) {
    return QgNocDocument(
      id: map['id']?.toString() ?? '',
      pipelineId: map['pipeline_id']?.toString() ?? '',
      quotationId: map['quotation_id']?.toString(),
      customerId: map['customer_id']?.toString(),
      installationId: map['installation_id']?.toString(),
      nocNo: map['noc_no']?.toString() ?? '',
      version: (map['version'] as num?)?.toInt() ?? 1,
      isCurrent: map['is_current'] as bool? ?? true,
      issuedOn: map['issued_on'] != null
          ? DateTime.tryParse(map['issued_on'].toString()) ?? DateTime.now()
          : DateTime.now(),
      payload: map['payload'] is Map ? Map<String, dynamic>.from(map['payload'] as Map) : {},
      pdfPath: map['pdf_path']?.toString(),
      pdfName: map['pdf_name']?.toString(),
      overrideReason: map['override_reason']?.toString(),
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pipeline_id': pipelineId,
      'quotation_id': quotationId,
      'customer_id': customerId,
      'installation_id': installationId,
      'noc_no': nocNo,
      'version': version,
      'is_current': isCurrent,
      'issued_on': issuedOn.toIso8601String().split('T').first,
      'payload': payload,
      'pdf_path': pdfPath,
      'pdf_name': pdfName,
      'override_reason': overrideReason,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Convenience getters for UI presentation
  String get nocNumber => nocNo;
  DateTime get issuedDate => issuedOn;
  NocStatus get status {
    final s = payload['status']?.toString();
    if (s == 'draft') return NocStatus.draft;
    if (s == 'signed') return NocStatus.signed;
    if (s == 'archived') return NocStatus.archived;
    return NocStatus.issued;
  }
  String get customerName => payload['customer_name']?.toString() ?? 'Customer';
  String get siteAddress => payload['site_address']?.toString() ?? '';
  String get productName => payload['product_name']?.toString() ?? 'Equipment';
  String? get quotationNumber => payload['quotation_number']?.toString() ?? quotationId;
  NocWordingMode get wordingMode => payload['wording_mode'] == 'enhanced' ? NocWordingMode.enhanced : NocWordingMode.templateExact;
  Map<String, dynamic> get companySnapshot => payload['company_snapshot'] is Map ? Map<String, dynamic>.from(payload['company_snapshot'] as Map) : const {};
  List<NocEquipmentLine> get equipmentLines {
    final raw = payload['equipment_lines'];
    if (raw is List) {
      return raw.map((e) => NocEquipmentLine.fromMap(e is Map ? Map<String, dynamic>.from(e) : {})).toList();
    }
    return const [];
  }
  List<String> get confirmations {
    final raw = payload['confirmations'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }
  String? get customerSignatureUrl => payload['customer_signature_url']?.toString();
  String? get customerSignatoryName => payload['customer_signatory_name']?.toString();
  String? get technicianSignatureUrl => payload['technician_signature_url']?.toString();
  String? get technicianName => payload['technician_name']?.toString();
  String? get closingSentence => payload['closing_sentence']?.toString();
  String get equipmentSummary => equipmentLines.isNotEmpty
      ? equipmentLines.map((e) => '${e.model} (${e.quantity} ${e.uom})').join(', ')
      : productName;

  QgNocPayload toPayload() {
    return QgNocPayload(
      companyName: companySnapshot['company_name']?.toString() ?? 'INSIYA TRADING CORPORATION',
      companyAddress: companySnapshot['short_address']?.toString() ?? companySnapshot['company_address']?.toString() ?? '',
      companyEmail: companySnapshot['email']?.toString() ?? companySnapshot['company_email']?.toString() ?? '',
      companyPhone: companySnapshot['phone']?.toString() ?? companySnapshot['company_phone']?.toString() ?? '',
      companyWebsite: companySnapshot['website']?.toString() ?? companySnapshot['company_website']?.toString() ?? '',
      logoUrl: companySnapshot['logo_url']?.toString(),
      stampImagePath: companySnapshot['stamp_url']?.toString() ?? companySnapshot['stamp_image_path']?.toString(),
      salutation: payload['salutation']?.toString() ?? 'M/s',
      customerName: customerName,
      recipient: payload['recipient']?.toString() ?? 'The Project Mannager.',
      address: siteAddress,
      productName: productName,
      subject: payload['subject']?.toString() ?? 'No Objection Certificate for Installation & Commissioning of $productName.',
      date: issuedOn,
      quotationNumber: quotationNumber,
      installationTicketNo: payload['installation_ticket_no']?.toString(),
      installationDate: payload['installation_date'] != null ? DateTime.tryParse(payload['installation_date'].toString()) : null,
      equipmentLabel: payload['equipment_label']?.toString() ?? productName,
      equipmentLines: equipmentLines,
      workType: payload['work_type']?.toString() ?? '$productName Installation work',
      leakage: payload['leakage']?.toString() ?? 'Done',
      wiring: payload['wiring']?.toString() ?? 'Done',
      testing: payload['testing']?.toString() ?? 'Done',
      remark: payload['remark']?.toString() ?? 'All Installation & Commissioning work Completed as per work order',
      confirmations: confirmations,
      closingSentence: closingSentence ?? '',
      customerSignatureUrl: customerSignatureUrl,
      customerSignatoryName: customerSignatoryName,
      technicianSignatureUrl: technicianSignatureUrl,
      technicianName: technicianName,
      wordingMode: wordingMode,
    );
  }
}
