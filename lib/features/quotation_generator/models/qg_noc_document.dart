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
  String? get closingSentence => payload['closing_sentence']?.toString();
  String get equipmentSummary => equipmentLines.isNotEmpty
      ? equipmentLines.map((e) => '${e.model} (${e.quantity} ${e.uom})').join(', ')
      : productName;
}
