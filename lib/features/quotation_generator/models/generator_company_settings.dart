// lib/features/quotation_generator/models/generator_company_settings.dart

import 'heat_pump_model.dart';
import 'sales_person.dart';
import 'pool_heat_pump_model.dart';
import 'all_in_one_model.dart';
import '../../../core/models/app_company.dart';

class GeneratorCompanySettings {
  final String companyName;
  final String brandName;
  final String companyAddress;
  final String shortAddress;
  final String companyEmail;
  final String companyPhone;
  final String companyPhone2;
  final String companyWebsite;

  // Bank details
  final String bankAccountName;
  final String bankName;
  final String bankAccountNumber;
  final String bankBranch;
  final String bankIfsc;

  // Defaults
  final double defaultGstPercent;
  final int defaultValidityDays;
  final int defaultWarrantyHpYears;
  final int defaultWarrantyTankYears;
  final String quotePrefix;
  final int nextRunningNumber;

  // Images
  final String? stampImagePath;
  final String? defaultCoverImagePath;
  final String? defaultBannerImagePath;
  // Type images for the last page of multi-page quotation
  final String? domesticHpImagePath;
  final String? allInOneImagePath;
  final String? allInOneWallImagePath;
  final String? swimmingPoolImagePath;

  // Terms and conditions
  final List<String> defaultTerms;
  final Map<String, List<String>> termsByType;
  final Map<String, int> warrantyHpByType;
  final Map<String, int> warrantyTankByType;

  // Catalogs
  final List<HeatPumpModel> models;
  final List<PoolHeatPumpModel> poolModels;
  final List<AllInOneModel> allInOneModels;

  // Sales team
  final List<SalesPerson> salesPersons;

  const GeneratorCompanySettings({
    this.companyName = 'INSIYA SOLAR INDUSTRY',
    this.brandName = 'IZYHEAT',
    this.companyAddress = 'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra - 411014',
    this.shortAddress = 'Finswell, Behind Hyatt Hotel, Viman Nagar, Pune 411014',
    this.companyEmail = 'info@insiyacorp.com',
    this.companyPhone = '+91 9292922992',
    this.companyPhone2 = '7588874019',
    this.companyWebsite = 'www.insiyacorp.com',
    this.bankAccountName = 'Insiya Solar Industry',
    this.bankName = 'HDFC Bank',
    this.bankAccountNumber = '50200067774561',
    this.bankBranch = 'Vadgaonsheri, Pune',
    this.bankIfsc = 'HDFC0009351',
    this.defaultGstPercent = 18.0,
    this.defaultValidityDays = 7,
    this.defaultWarrantyHpYears = 2,
    this.defaultWarrantyTankYears = 5,
    this.quotePrefix = 'IN/HP/SS',
    this.nextRunningNumber = 1406,
    this.stampImagePath,
    this.defaultCoverImagePath,
    this.defaultBannerImagePath,
    this.domesticHpImagePath,
    this.allInOneImagePath,
    this.allInOneWallImagePath,
    this.swimmingPoolImagePath,
    this.defaultTerms = const [
      'Proper 1 / 3 Phase power should be arranged where you install the heat pump.',
      'Electrical/civil/plumbing work materials – Customer Scope.',
      'Safe storage place need to be provided by you to keep our material & tools.',
      'All Interconnected pipe lines between system and Tank Your Scope but our team will do the installation. (If applicable): Extra',
    ],
    this.termsByType = const {},
    this.warrantyHpByType = const {},
    this.warrantyTankByType = const {},
    this.models = const [],
    this.poolModels = const [],
    this.allInOneModels = const [],
    this.salesPersons = const [],
  });

  GeneratorCompanySettings copyWith({
    String? companyName,
    String? brandName,
    String? companyAddress,
    String? shortAddress,
    String? companyEmail,
    String? companyPhone,
    String? companyPhone2,
    String? companyWebsite,
    String? bankAccountName,
    String? bankName,
    String? bankAccountNumber,
    String? bankBranch,
    String? bankIfsc,
    double? defaultGstPercent,
    int? defaultValidityDays,
    int? defaultWarrantyHpYears,
    int? defaultWarrantyTankYears,
    String? quotePrefix,
    int? nextRunningNumber,
    String? stampImagePath,
    String? defaultCoverImagePath,
    String? defaultBannerImagePath,
    String? domesticHpImagePath,
    String? allInOneImagePath,
    String? allInOneWallImagePath,
    String? swimmingPoolImagePath,
    List<String>? defaultTerms,
    Map<String, List<String>>? termsByType,
    Map<String, int>? warrantyHpByType,
    Map<String, int>? warrantyTankByType,
    List<HeatPumpModel>? models,
    List<PoolHeatPumpModel>? poolModels,
    List<AllInOneModel>? allInOneModels,
    List<SalesPerson>? salesPersons,
  }) {
    return GeneratorCompanySettings(
      companyName: companyName ?? this.companyName,
      brandName: brandName ?? this.brandName,
      companyAddress: companyAddress ?? this.companyAddress,
      shortAddress: shortAddress ?? this.shortAddress,
      companyEmail: companyEmail ?? this.companyEmail,
      companyPhone: companyPhone ?? this.companyPhone,
      companyPhone2: companyPhone2 ?? this.companyPhone2,
      companyWebsite: companyWebsite ?? this.companyWebsite,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankBranch: bankBranch ?? this.bankBranch,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      defaultGstPercent: defaultGstPercent ?? this.defaultGstPercent,
      defaultValidityDays: defaultValidityDays ?? this.defaultValidityDays,
      defaultWarrantyHpYears: defaultWarrantyHpYears ?? this.defaultWarrantyHpYears,
      defaultWarrantyTankYears: defaultWarrantyTankYears ?? this.defaultWarrantyTankYears,
      quotePrefix: quotePrefix ?? this.quotePrefix,
      nextRunningNumber: nextRunningNumber ?? this.nextRunningNumber,
      stampImagePath: stampImagePath ?? this.stampImagePath,
      defaultCoverImagePath: defaultCoverImagePath ?? this.defaultCoverImagePath,
      defaultBannerImagePath: defaultBannerImagePath ?? this.defaultBannerImagePath,
      domesticHpImagePath: domesticHpImagePath ?? this.domesticHpImagePath,
      allInOneImagePath: allInOneImagePath ?? this.allInOneImagePath,
      allInOneWallImagePath: allInOneWallImagePath ?? this.allInOneWallImagePath,
      swimmingPoolImagePath: swimmingPoolImagePath ?? this.swimmingPoolImagePath,
      defaultTerms: defaultTerms ?? this.defaultTerms,
      termsByType: termsByType ?? this.termsByType,
      warrantyHpByType: warrantyHpByType ?? this.warrantyHpByType,
      warrantyTankByType: warrantyTankByType ?? this.warrantyTankByType,
      models: models ?? this.models,
      poolModels: poolModels ?? this.poolModels,
      allInOneModels: allInOneModels ?? this.allInOneModels,
      salesPersons: salesPersons ?? this.salesPersons,
    );
  }

  Map<String, dynamic> toJson() => {
    'companyName': companyName,
    'brandName': brandName,
    'companyAddress': companyAddress,
    'shortAddress': shortAddress,
    'companyEmail': companyEmail,
    'companyPhone': companyPhone,
    'companyPhone2': companyPhone2,
    'companyWebsite': companyWebsite,
    'bankAccountName': bankAccountName,
    'bankName': bankName,
    'bankAccountNumber': bankAccountNumber,
    'bankBranch': bankBranch,
    'bankIfsc': bankIfsc,
    'defaultGstPercent': defaultGstPercent,
    'defaultValidityDays': defaultValidityDays,
    'defaultWarrantyHpYears': defaultWarrantyHpYears,
    'defaultWarrantyTankYears': defaultWarrantyTankYears,
    'quotePrefix': quotePrefix,
    'nextRunningNumber': nextRunningNumber,
    'stampImagePath': stampImagePath,
    'defaultCoverImagePath': defaultCoverImagePath,
    'defaultBannerImagePath': defaultBannerImagePath,
    'domesticHpImagePath': domesticHpImagePath,
    'allInOneImagePath': allInOneImagePath,
    'allInOneWallImagePath': allInOneWallImagePath,
    'swimmingPoolImagePath': swimmingPoolImagePath,
    'defaultTerms': defaultTerms,
    'termsByType': termsByType,
    'warrantyHpByType': warrantyHpByType,
    'warrantyTankByType': warrantyTankByType,
    'models': models.map((m) => m.toJson()).toList(),
    'poolModels': poolModels.map((m) => m.toJson()).toList(),
    'allInOneModels': allInOneModels.map((m) => m.toJson()).toList(),
    'salesPersons': salesPersons.map((s) => s.toJson()).toList(),
  };

  factory GeneratorCompanySettings.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>> parsedTermsByType = {};
    if (json['termsByType'] is Map) {
      final tMap = json['termsByType'] as Map;
      tMap.forEach((k, v) {
        if (v is List) {
          parsedTermsByType[k.toString()] = v.map((e) => e.toString()).toList();
        }
      });
    }

    Map<String, int> parsedHpWarranty = {};
    if (json['warrantyHpByType'] is Map) {
      final wMap = json['warrantyHpByType'] as Map;
      wMap.forEach((k, v) {
        parsedHpWarranty[k.toString()] = (v as num).toInt();
      });
    }

    Map<String, int> parsedTankWarranty = {};
    if (json['warrantyTankByType'] is Map) {
      final wMap = json['warrantyTankByType'] as Map;
      wMap.forEach((k, v) {
        parsedTankWarranty[k.toString()] = (v as num).toInt();
      });
    }

    return GeneratorCompanySettings(
      companyName: json['companyName'] as String? ?? 'INSIYA SOLAR INDUSTRY',
      brandName: json['brandName'] as String? ?? 'IZYHEAT',
      companyAddress: json['companyAddress'] as String? ?? 'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra - 411014',
      shortAddress: json['shortAddress'] as String? ?? 'Finswell, Behind Hyatt Hotel, Viman Nagar, Pune 411014',
      companyEmail: json['companyEmail'] as String? ?? 'info@insiyacorp.com',
      companyPhone: json['companyPhone'] as String? ?? '+91 9292922992',
      companyPhone2: json['companyPhone2'] as String? ?? '7588874019',
      companyWebsite: json['companyWebsite'] as String? ?? 'www.insiyacorp.com',
      bankAccountName: json['bankAccountName'] as String? ?? 'Insiya Solar Industry',
      bankName: json['bankName'] as String? ?? 'HDFC Bank',
      bankAccountNumber: json['bankAccountNumber'] as String? ?? '50200067774561',
      bankBranch: json['bankBranch'] as String? ?? 'Vadgaonsheri, Pune',
      bankIfsc: json['bankIfsc'] as String? ?? 'HDFC0009351',
      defaultGstPercent: (json['defaultGstPercent'] as num? ?? 18.0).toDouble(),
      defaultValidityDays: (json['defaultValidityDays'] as num? ?? 7).toInt(),
      defaultWarrantyHpYears: (json['defaultWarrantyHpYears'] as num? ?? 2).toInt(),
      defaultWarrantyTankYears: (json['defaultWarrantyTankYears'] as num? ?? 5).toInt(),
      quotePrefix: json['quotePrefix'] as String? ?? 'IN/HP/SS',
      nextRunningNumber: (json['nextRunningNumber'] as num? ?? 1406).toInt(),
      stampImagePath: json['stampImagePath'] as String?,
      defaultCoverImagePath: json['defaultCoverImagePath'] as String?,
      defaultBannerImagePath: json['defaultBannerImagePath'] as String?,
      domesticHpImagePath: json['domesticHpImagePath'] as String?,
      allInOneImagePath: json['allInOneImagePath'] as String?,
      allInOneWallImagePath: json['allInOneWallImagePath'] as String?,
      swimmingPoolImagePath: json['swimmingPoolImagePath'] as String?,
      defaultTerms: (json['defaultTerms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [
        'Proper 1 / 3 Phase power should be arranged where you install the heat pump.',
        'Electrical/civil/plumbing work materials – Customer Scope.',
        'Safe storage place need to be provided by you to keep our material & tools.',
        'All Interconnected pipe lines between system and Tank Your Scope but our team will do the installation. (If applicable): Extra',
      ],
      termsByType: parsedTermsByType,
      warrantyHpByType: parsedHpWarranty,
      warrantyTankByType: parsedTankWarranty,
      models: (json['models'] as List<dynamic>?)
          ?.map((e) => HeatPumpModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList() ?? const [],
      poolModels: (json['poolModels'] as List<dynamic>?)
          ?.map((e) => PoolHeatPumpModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList() ?? const [],
      allInOneModels: (json['allInOneModels'] as List<dynamic>?)
          ?.map((e) => AllInOneModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList() ?? const [],
      salesPersons: (json['salesPersons'] as List<dynamic>?)
          ?.map((e) => SalesPerson.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList() ?? SalesPerson.defaultList(),
    );
  }

  factory GeneratorCompanySettings.fromAppCompany(
    AppCompany company, {
    GeneratorCompanySettings? base,
  }) {
    final b = base ?? const GeneratorCompanySettings();
    return b.copyWith(
      companyName: company.name.isNotEmpty ? company.name : b.companyName,
      companyAddress: company.address.isNotEmpty ? company.address : b.companyAddress,
      shortAddress: company.address.isNotEmpty ? company.address : b.shortAddress,
      companyEmail: company.email.isNotEmpty ? company.email : b.companyEmail,
      companyPhone: company.phone.isNotEmpty ? company.phone : b.companyPhone,
      companyWebsite: company.website.isNotEmpty ? company.website : b.companyWebsite,
      bankAccountName: company.bankAccountName.isNotEmpty ? company.bankAccountName : b.bankAccountName,
      bankName: company.bankName.isNotEmpty ? company.bankName : b.bankName,
      bankAccountNumber: company.bankAccountNo.isNotEmpty ? company.bankAccountNo : b.bankAccountNumber,
      bankBranch: company.bankBranch.isNotEmpty ? company.bankBranch : b.bankBranch,
      bankIfsc: company.bankIfsc.isNotEmpty ? company.bankIfsc : b.bankIfsc,
      stampImagePath: company.stampUrl != null && company.stampUrl!.isNotEmpty ? company.stampUrl : b.stampImagePath,
    );
  }
}
