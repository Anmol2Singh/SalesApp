// lib/features/quotation_generator/models/qg_product_profile.dart

import '../../../../core/models/app_company.dart';
import 'generator_company_settings.dart';

class QgProductProfile {
  final String? id;
  final String key;
  final String label;
  final List<String> matchNames;
  final String templateKey;
  
  // Company block
  final String companyName;
  final List<String> companyAddressLines;
  final String companyEmail;
  final String companyMobile;
  final String companyWebsite;

  // Bank block
  final String bankName;
  final String bankAccountName;
  final String bankAccountNo;
  final String bankBranch;
  final String bankIfsc;

  // Images
  final String logoPath;
  final String defaultCoverPath;
  final String? stampPath;

  // Reference number strategy
  final String refMode; // 'deal_number' | 'legacy_pattern'
  final String refPattern; // e.g. 'SD/SS/{FY}/{n}'
  final int nextRefNumber;

  // Number format mode
  final String numberFormatMode; // 'template_exact' | 'indian_grouping'

  // Default lists
  final List<String> defaultTerms;
  final List<String> defaultNotes;
  final List<Map<String, dynamic>> defaultAtActualCharges;

  // Commercial defaults
  final int warrantyYears;
  final String deliveryDays;
  final String installationPeriod;
  final String onsiteServicePeriod;
  final double amcRatePercent;

  final bool isActive;

  const QgProductProfile({
    this.id,
    required this.key,
    required this.label,
    required this.matchNames,
    required this.templateKey,
    required this.companyName,
    required this.companyAddressLines,
    required this.companyEmail,
    required this.companyMobile,
    required this.companyWebsite,
    required this.bankName,
    required this.bankAccountName,
    required this.bankAccountNo,
    required this.bankBranch,
    required this.bankIfsc,
    required this.logoPath,
    required this.defaultCoverPath,
    this.stampPath,
    this.refMode = 'deal_number',
    this.refPattern = 'SD/SS/{FY}/{n}',
    this.nextRefNumber = 442,
    this.numberFormatMode = 'template_exact',
    this.defaultTerms = const [],
    this.defaultNotes = const [],
    this.defaultAtActualCharges = const [],
    this.warrantyYears = 2,
    this.deliveryDays = '7 days',
    this.installationPeriod = '1-2 Week',
    this.onsiteServicePeriod = '1 year',
    this.amcRatePercent = 15.0,
    this.isActive = true,
  });

  /// Default profile for Boom Barrier (Insiya Trading Corporation / Sefdor)
  factory QgProductProfile.defaultBoomBarrier() {
    return const QgProductProfile(
      key: 'boom_barrier',
      label: 'Boom Barrier',
      matchNames: ['Boom Barrier', 'Boom barrier', 'boom barrier', 'BoomBarrier', 'Barrier'],
      templateKey: 'boom_barrier_quotation',
      companyName: 'INSIYA TRADING CORPORATION',
      companyAddressLines: [
        'Office No 807, 8th Floor, Finswell Building',
        'Behind Hyatt Hotel, Viman NagarPune, 411014',
      ],
      companyEmail: 'insiyaindia@gmail.com    info@insiyacorp.com',
      companyMobile: '+91 7588874019 & +91 9292922992',
      companyWebsite: 'www.insiyacorp.com',
      bankName: 'KOTAK MAHINDRA BANK',
      bankAccountName: 'INSIYA TRADING CORPORATION',
      bankAccountNo: '9446865227',
      bankBranch: 'VIMAN NAGAR PUNE',
      bankIfsc: 'KKBK0001804',
      logoPath: 'assets/images/boom_barrier/sefdor_logo.png',
      defaultCoverPath: 'assets/images/boom_barrier/cover_artwork.png',
      refMode: 'deal_number',
      refPattern: 'SD/SS/{FY}/{n}',
      nextRefNumber: 442,
      numberFormatMode: 'template_exact',
      defaultTerms: [
        '1. Quotation Validity: 7 Days from the date of submission.',
        '2. Payment Terms: {payment_terms_sentence}',
        '3. Warranty: 2 years on-site warranty against manufacturing defects from the date of handover.',
        '4. Delivery: Within 7 days from the date of confirmed PO with advance payment.',
        '5. Installation: 1-2 Week from the date of delivery and site readiness.',
        '6. Taxes: GST 18% extra as applicable.',
        '7. AMC: Annual Maintenance Contract available @ 15% per annum after warranty expiry.',
      ],
      defaultNotes: [
        ': In 100 Meter Civil, Plumber, Earthling, Electrical work done by Clint side.',
        ': 1 Phase 230V AC, 5 Amp with proper earthing Power Supply at Entry Gate/Barrier',
        ': Cabling will be through 25mm 2 kg PVC conduit only.',
        ': Loop wire will be installed in 25mm 6 kg PVC conduit.',
        ': In case of open cabling it will be charged as per actual.',
        ': Any other work apart from the above will be charged extra.',
        ': Standard delivery & installation will depends up on site conditions.',
      ],
      defaultAtActualCharges: [
        {
          'sr_no': 1,
          'description': 'Wiring charges CAT6 + 3 core Power cable',
          'qty': '1 mtr',
          'rate': '150.00',
          'total': 'At Actual',
        }
      ],
      warrantyYears: 2,
      deliveryDays: '7 days',
      installationPeriod: '1-2 Week',
      onsiteServicePeriod: '1 year',
      amcRatePercent: 15.0,
      isActive: true,
    );
  }

  /// Virtual profile for Heat Pump delegating to existing GeneratorCompanySettings
  factory QgProductProfile.virtualHeatPump([GeneratorCompanySettings? settings]) {
    final s = settings ?? const GeneratorCompanySettings();
    return QgProductProfile(
      key: 'heat_pump',
      label: 'Heat Pump',
      matchNames: const ['Heat Pump', 'Heatpump', 'Heat pump'],
      templateKey: 'heat_pump_proposal',
      companyName: s.companyName,
      companyAddressLines: [s.companyAddress],
      companyEmail: s.companyEmail,
      companyMobile: s.companyPhone,
      companyWebsite: s.companyWebsite,
      bankName: s.bankName,
      bankAccountName: s.bankAccountName,
      bankAccountNo: s.bankAccountNumber,
      bankBranch: s.bankBranch,
      bankIfsc: s.bankIfsc,
      logoPath: 'assets/images/izyheat_logo.png',
      defaultCoverPath: 'assets/images/company_stamp.png',
      refMode: 'legacy_fiscal',
      refPattern: '${s.quotePrefix}/{FY}/{n}',
      nextRefNumber: s.nextRunningNumber,
      numberFormatMode: 'indian_grouping',
      defaultTerms: const [],
      defaultNotes: const [],
      defaultAtActualCharges: const [],
      warrantyYears: s.defaultWarrantyHpYears,
      deliveryDays: '15-20 days',
      installationPeriod: '1-2 Week',
      onsiteServicePeriod: '1 year',
      amcRatePercent: 10.0,
      isActive: true,
    );
  }

  factory QgProductProfile.fromJson(Map<String, dynamic> json) {
    return QgProductProfile(
      id: json['id'] as String?,
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      matchNames: (json['match_names'] as List?)?.map((e) => e.toString()).toList() ?? [],
      templateKey: json['template_key'] as String? ?? 'heat_pump_proposal',
      companyName: json['company_name'] as String? ?? '',
      companyAddressLines: (json['company_address_lines'] as List?)?.map((e) => e.toString()).toList() ?? [],
      companyEmail: json['company_email'] as String? ?? '',
      companyMobile: json['company_mobile'] as String? ?? '',
      companyWebsite: json['company_website'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      bankAccountName: json['bank_account_name'] as String? ?? '',
      bankAccountNo: json['bank_account_no'] as String? ?? '',
      bankBranch: json['bank_branch'] as String? ?? '',
      bankIfsc: json['bank_ifsc'] as String? ?? '',
      logoPath: json['logo_path'] as String? ?? '',
      defaultCoverPath: json['default_cover_path'] as String? ?? '',
      stampPath: json['stamp_path'] as String?,
      refMode: json['ref_mode'] as String? ?? 'deal_number',
      refPattern: json['ref_pattern'] as String? ?? 'SD/SS/{FY}/{n}',
      nextRefNumber: (json['next_ref_number'] as num?)?.toInt() ?? 1,
      numberFormatMode: json['number_format_mode'] as String? ?? 'template_exact',
      defaultTerms: (json['default_terms'] as List?)?.map((e) => e.toString()).toList() ?? [],
      defaultNotes: (json['default_notes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      defaultAtActualCharges: (json['default_at_actual_charges'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      warrantyYears: (json['warranty_years'] as num?)?.toInt() ?? 2,
      deliveryDays: json['delivery_days'] as String? ?? '7 days',
      installationPeriod: json['installation_period'] as String? ?? '1-2 Week',
      onsiteServicePeriod: json['onsite_service_period'] as String? ?? '1 year',
      amcRatePercent: (json['amc_rate_percent'] as num?)?.toDouble() ?? 15.0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  QgProductProfile withAppCompany(AppCompany company) {
    return copyWith(
      companyName: company.name.isNotEmpty ? company.name : companyName,
      companyAddressLines: company.addressLines.isNotEmpty ? company.addressLines : companyAddressLines,
      companyEmail: company.email.isNotEmpty ? company.email : companyEmail,
      companyMobile: company.phone.isNotEmpty ? company.phone : companyMobile,
      companyWebsite: company.website.isNotEmpty ? company.website : companyWebsite,
      bankName: company.bankName.isNotEmpty ? company.bankName : bankName,
      bankAccountName: company.bankAccountName.isNotEmpty ? company.bankAccountName : bankAccountName,
      bankAccountNo: company.bankAccountNo.isNotEmpty ? company.bankAccountNo : bankAccountNo,
      bankBranch: company.bankBranch.isNotEmpty ? company.bankBranch : bankBranch,
      bankIfsc: company.bankIfsc.isNotEmpty ? company.bankIfsc : bankIfsc,
      logoPath: company.logoUrl ?? logoPath,
      stampPath: company.stampUrl ?? stampPath,
    );
  }

  QgProductProfile copyWith({
    String? id,
    String? key,
    String? label,
    List<String>? matchNames,
    String? templateKey,
    String? companyName,
    List<String>? companyAddressLines,
    String? companyEmail,
    String? companyMobile,
    String? companyWebsite,
    String? bankName,
    String? bankAccountName,
    String? bankAccountNo,
    String? bankBranch,
    String? bankIfsc,
    String? logoPath,
    String? defaultCoverPath,
    String? stampPath,
    String? refMode,
    String? refPattern,
    int? nextRefNumber,
    String? numberFormatMode,
    List<String>? defaultTerms,
    List<String>? defaultNotes,
    List<Map<String, dynamic>>? defaultAtActualCharges,
    int? warrantyYears,
    String? deliveryDays,
    String? installationPeriod,
    String? onsiteServicePeriod,
    double? amcRatePercent,
    bool? isActive,
  }) {
    return QgProductProfile(
      id: id ?? this.id,
      key: key ?? this.key,
      label: label ?? this.label,
      matchNames: matchNames ?? this.matchNames,
      templateKey: templateKey ?? this.templateKey,
      companyName: companyName ?? this.companyName,
      companyAddressLines: companyAddressLines ?? this.companyAddressLines,
      companyEmail: companyEmail ?? this.companyEmail,
      companyMobile: companyMobile ?? this.companyMobile,
      companyWebsite: companyWebsite ?? this.companyWebsite,
      bankName: bankName ?? this.bankName,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNo: bankAccountNo ?? this.bankAccountNo,
      bankBranch: bankBranch ?? this.bankBranch,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      logoPath: logoPath ?? this.logoPath,
      defaultCoverPath: defaultCoverPath ?? this.defaultCoverPath,
      stampPath: stampPath ?? this.stampPath,
      refMode: refMode ?? this.refMode,
      refPattern: refPattern ?? this.refPattern,
      nextRefNumber: nextRefNumber ?? this.nextRefNumber,
      numberFormatMode: numberFormatMode ?? this.numberFormatMode,
      defaultTerms: defaultTerms ?? this.defaultTerms,
      defaultNotes: defaultNotes ?? this.defaultNotes,
      defaultAtActualCharges: defaultAtActualCharges ?? this.defaultAtActualCharges,
      warrantyYears: warrantyYears ?? this.warrantyYears,
      deliveryDays: deliveryDays ?? this.deliveryDays,
      installationPeriod: installationPeriod ?? this.installationPeriod,
      onsiteServicePeriod: onsiteServicePeriod ?? this.onsiteServicePeriod,
      amcRatePercent: amcRatePercent ?? this.amcRatePercent,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'key': key,
      'label': label,
      'match_names': matchNames,
      'template_key': templateKey,
      'company_name': companyName,
      'company_address_lines': companyAddressLines,
      'company_email': companyEmail,
      'company_mobile': companyMobile,
      'company_website': companyWebsite,
      'bank_name': bankName,
      'bank_account_name': bankAccountName,
      'bank_account_no': bankAccountNo,
      'bank_branch': bankBranch,
      'bank_ifsc': bankIfsc,
      'logo_path': logoPath,
      'default_cover_path': defaultCoverPath,
      'stamp_path': stampPath,
      'ref_mode': refMode,
      'ref_pattern': refPattern,
      'next_ref_number': nextRefNumber,
      'number_format_mode': numberFormatMode,
      'default_terms': defaultTerms,
      'default_notes': defaultNotes,
      'default_at_actual_charges': defaultAtActualCharges,
      'warranty_years': warrantyYears,
      'delivery_days': deliveryDays,
      'installation_period': installationPeriod,
      'onsite_service_period': onsiteServicePeriod,
      'amc_rate_percent': amcRatePercent,
      'is_active': isActive,
    };
  }
}
