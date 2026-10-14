// lib/features/quotation_generator/models/qg_noc_profile.dart

class QgNocProfile {
  final String id;
  final String productName;
  final String equipmentLabel;
  final String workTypeText;
  final String wiringDefault;
  final String testingDefault;
  final String remarkDefault;
  final List<String> confirmationLines;
  final String? closingSentence;
  final String? companyNameOverride;
  final String? companyAddressOverride;
  final String? companyEmailOverride;
  final String? companyMobileOverride;
  final String? companyWebOverride;
  final String? logoUrlOverride;
  final String? stampPathOverride;
  final bool isActive;

  const QgNocProfile({
    required this.id,
    required this.productName,
    required this.equipmentLabel,
    required this.workTypeText,
    this.wiringDefault = 'Done',
    this.testingDefault = 'Done',
    this.remarkDefault = 'All Installation & Commissioning work completed as per work order',
    this.confirmationLines = const [],
    this.closingSentence,
    this.companyNameOverride,
    this.companyAddressOverride,
    this.companyEmailOverride,
    this.companyMobileOverride,
    this.companyWebOverride,
    this.logoUrlOverride,
    this.stampPathOverride,
    this.isActive = true,
  });

  factory QgNocProfile.fromMap(Map<String, dynamic> map) {
    List<String> confirmations = [];
    if (map['confirmation_lines'] is List) {
      confirmations = (map['confirmation_lines'] as List).map((e) => e.toString()).toList();
    }

    return QgNocProfile(
      id: map['id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      equipmentLabel: map['equipment_label']?.toString() ?? '',
      workTypeText: map['work_type_text']?.toString() ?? '',
      wiringDefault: map['wiring_default']?.toString() ?? 'Done',
      testingDefault: map['testing_default']?.toString() ?? 'Done',
      remarkDefault: map['remark_default']?.toString() ?? 'All Installation & Commissioning work completed as per work order',
      confirmationLines: confirmations,
      closingSentence: map['closing_sentence']?.toString(),
      companyNameOverride: map['company_name_override']?.toString(),
      companyAddressOverride: map['company_address_override']?.toString(),
      companyEmailOverride: map['company_email_override']?.toString(),
      companyMobileOverride: map['company_mobile_override']?.toString(),
      companyWebOverride: map['company_web_override']?.toString(),
      logoUrlOverride: map['logo_url_override']?.toString(),
      stampPathOverride: map['stamp_path_override']?.toString(),
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_name': productName,
      'equipment_label': equipmentLabel,
      'work_type_text': workTypeText,
      'wiring_default': wiringDefault,
      'testing_default': testingDefault,
      'remark_default': remarkDefault,
      'confirmation_lines': confirmationLines,
      'closing_sentence': closingSentence,
      'company_name_override': companyNameOverride,
      'company_address_override': companyAddressOverride,
      'company_email_override': companyEmailOverride,
      'company_mobile_override': companyMobileOverride,
      'company_web_override': companyWebOverride,
      'logo_url_override': logoUrlOverride,
      'stamp_path_override': stampPathOverride,
      'is_active': isActive,
    };
  }

  QgNocProfile copyWith({
    String? id,
    String? productName,
    String? equipmentLabel,
    String? workTypeText,
    String? wiringDefault,
    String? testingDefault,
    String? remarkDefault,
    List<String>? confirmationLines,
    String? closingSentence,
    String? companyNameOverride,
    String? companyAddressOverride,
    String? companyEmailOverride,
    String? companyMobileOverride,
    String? companyWebOverride,
    String? logoUrlOverride,
    String? stampPathOverride,
    bool? isActive,
  }) {
    return QgNocProfile(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      equipmentLabel: equipmentLabel ?? this.equipmentLabel,
      workTypeText: workTypeText ?? this.workTypeText,
      wiringDefault: wiringDefault ?? this.wiringDefault,
      testingDefault: testingDefault ?? this.testingDefault,
      remarkDefault: remarkDefault ?? this.remarkDefault,
      confirmationLines: confirmationLines ?? this.confirmationLines,
      closingSentence: closingSentence ?? this.closingSentence,
      companyNameOverride: companyNameOverride ?? this.companyNameOverride,
      companyAddressOverride: companyAddressOverride ?? this.companyAddressOverride,
      companyEmailOverride: companyEmailOverride ?? this.companyEmailOverride,
      companyMobileOverride: companyMobileOverride ?? this.companyMobileOverride,
      companyWebOverride: companyWebOverride ?? this.companyWebOverride,
      logoUrlOverride: logoUrlOverride ?? this.logoUrlOverride,
      stampPathOverride: stampPathOverride ?? this.stampPathOverride,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Heat pump profile matching standard NOC template
  factory QgNocProfile.defaultHeatPumpProfile() {
    return const QgNocProfile(
      id: 'heat_pump',
      productName: 'Heat Pump',
      equipmentLabel: 'HEAT PUMP',
      workTypeText: 'Heat Pump Water Heater System Installation & Commissioning work',
      wiringDefault: 'Done',
      testingDefault: 'Done',
      remarkDefault: 'All Installation & Commissioning work Completed as per work order',
      confirmationLines: [
        '1. The installation of the heat pump system is permitted at the above location.',
        '2. The system installed as per standard safety norms and guidelines.',
        '3. Necessary precautions has been taken to avoid noise, vibration, or water leakage issues.',
      ],
      closingSentence: 'This NOC is issued upon request for installation and operation of the heat pump system.',
    );
  }

  /// Default fallback profile when no specific product match exists
  factory QgNocProfile.defaultProfile({String productName = 'System'}) {
    return QgNocProfile(
      id: 'default',
      productName: productName,
      equipmentLabel: productName,
      workTypeText: '$productName Installation work',
      wiringDefault: 'Done',
      testingDefault: 'Done',
      remarkDefault: 'All Installation & Commissioning work Completed as per work order',
      confirmationLines: [
        '1. The installation of the $productName system is permitted at the above location.',
        '2. The system installed as per standard safety norms and guidelines.',
        '3. Necessary precautions has been taken to avoid noise, vibration, or water leakage issues.',
      ],
      closingSentence: 'This NOC is issued upon request for installation and operation of the $productName system.',
    );
  }

  // Convenience getters
  String get profileName => productName;
  String get workType => workTypeText;
  String get wiring => wiringDefault;
  String get testing => testingDefault;
  String get remark => remarkDefault;
  String get defaultSubject => 'No Objection Certificate for Installation & Commissioning of $productName.';
  List<String> get defaultConfirmations => confirmationLines;
}
