// lib/features/quotation_generator/models/generator_quotation.dart

import '../config/quote_type.dart';
import 'heat_pump_model.dart';
import 'tank_spec.dart';
import 'price_item.dart';
import 'price_row.dart';
import 'tank_line_item.dart';
import 'all_in_one_model.dart';
import 'pool_heat_pump_model.dart';

class GeneratorQuotation {
  final String id;
  final QuoteType quoteType;
  final String salutation; // 'M/s.', 'Mr.', 'Ms.'
  final String customerName;
  final String customerAddress;
  final String customerMobile;

  final DateTime date;
  final String quoteRefNo;
  final String salesRef;
  final String salesMobile;
  final String? salesPersonId;

  // Type specific title / purpose / subject
  final String? subjectOverride;
  final String? proposalTitle; // for partsOnly
  final String? purpose; // for tankOnly

  // Heat pump standard model (for hpWithTank, hpOnly)
  final HeatPumpModel model;
  final int heatPumpQty;
  final PriceRowType heatPumpAmountType;
  final int heatPumpNumericPrice;

  // Single Tank legacy fields (backward compatibility)
  final int tankCapacityLitres;
  final int tankQty;
  final bool isTankPressurized;
  final int tankRate; // In rupees
  final TankSpec tankSpec;

  // Multi tank lines (Phase 2)
  final List<TankLineItem> tankLines;

  // Specialized Models
  final AllInOneModel? allInOneModel;
  final PoolHeatPumpModel? poolModel;

  // Price rows
  final List<PriceRow> priceRows;
  final List<PriceItem> extraPriceRows; // Legacy

  // Pricing & Tax
  final String priceEntryMode; // 'exclusive' | 'inclusive'
  final int? targetTotal;
  final int subtotal;
  final double gstPercent;
  final int gstAmount;
  final int grossTotal;

  // Buyback
  final bool hasBuyback;
  final String? buybackDescription;
  final int buybackRate;
  final int buybackQty;
  final int buybackTotal;
  final int netPayable;
  final int grandTotal; // = netPayable

  final int? discountAmount;
  final String? specialOfferLabel;

  // Payment splits
  final int paymentSplitAdvance;
  final int paymentSplitDelivery;
  final int paymentSplitCommissioning;

  // Warranties & Validity
  final int warrantyHpYears;
  final int warrantyTankYears;
  final int validityDays;
  final List<String> termsAndConditions;

  // Media & Attachments
  final String? coverImagePath;
  final String? bannerImagePath;
  final List<String> productImagePaths;
  final bool includeProductImagePage;
  final bool includeBanner;
  final String? pdfUrl;

  final String status; // 'Draft', 'Sent', 'Accepted'
  final DateTime createdAt;
  final DateTime updatedAt;

  const GeneratorQuotation({
    required this.id,
    this.quoteType = QuoteType.hpWithTank,
    this.salutation = 'M/s.',
    required this.customerName,
    required this.customerAddress,
    required this.customerMobile,
    required this.date,
    required this.quoteRefNo,
    required this.salesRef,
    required this.salesMobile,
    this.salesPersonId,
    this.subjectOverride,
    this.proposalTitle,
    this.purpose,
    required this.model,
    this.heatPumpQty = 1,
    this.heatPumpAmountType = PriceRowType.included,
    this.heatPumpNumericPrice = 0,
    this.tankCapacityLitres = 500,
    this.tankQty = 1,
    this.isTankPressurized = true,
    required this.tankRate,
    required this.tankSpec,
    this.tankLines = const [],
    this.allInOneModel,
    this.poolModel,
    this.priceRows = const [],
    required this.extraPriceRows,
    this.priceEntryMode = 'exclusive',
    this.targetTotal,
    required this.subtotal,
    this.gstPercent = 18.0,
    required this.gstAmount,
    int? grossTotal,
    this.hasBuyback = false,
    this.buybackDescription,
    this.buybackRate = 0,
    this.buybackQty = 1,
    int? buybackTotal,
    int? netPayable,
    required this.grandTotal,
    this.discountAmount,
    this.specialOfferLabel,
    this.paymentSplitAdvance = 70,
    this.paymentSplitDelivery = 20,
    this.paymentSplitCommissioning = 10,
    this.warrantyHpYears = 2,
    this.warrantyTankYears = 5,
    this.validityDays = 7,
    required this.termsAndConditions,
    this.coverImagePath,
    this.bannerImagePath,
    this.productImagePaths = const [],
    this.includeProductImagePage = true,
    this.includeBanner = true,
    this.pdfUrl,
    this.status = 'Draft',
    required this.createdAt,
    required this.updatedAt,
  })  : grossTotal = grossTotal ?? (subtotal + gstAmount),
        buybackTotal = buybackTotal ?? (hasBuyback ? (buybackRate * buybackQty) : 0),
        netPayable = netPayable ??
            ((grossTotal ?? (subtotal + gstAmount)) -
                (buybackTotal ?? (hasBuyback ? (buybackRate * buybackQty) : 0)));

  String get paymentTermsText {
    if (paymentSplitAdvance == 100 && paymentSplitDelivery == 0 && paymentSplitCommissioning == 0) {
      return '100% advance along with Purchase Order.';
    }
    if (paymentSplitCommissioning == 0) {
      return 'Advance will be $paymentSplitAdvance% against PO, and $paymentSplitDelivery% against delivery.';
    }
    return 'Advance will be $paymentSplitAdvance% against PO, and $paymentSplitDelivery% against delivery, the balance $paymentSplitCommissioning% against satisfactory installation and commissioning.';
  }

  String get customerNameTitleCase {
    if (customerName.isEmpty) return '';
    return customerName
        .split(' ')
        .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  String get customerNameUppercase => customerName.toUpperCase();

  bool get isFinalized => status.toLowerCase() == 'finalized';

  String get displayProductName {
    if (proposalTitle != null && proposalTitle!.trim().isNotEmpty) {
      final clean = proposalTitle!
          .replaceAll(RegExp(r'PROPOSAL FOR SUPPLY OF', caseSensitive: false), '')
          .replaceAll(RegExp(r'PROPOSAL FOR', caseSensitive: false), '')
          .trim();
      if (clean.isNotEmpty) return clean;
    }
    if (model.modelName.isNotEmpty) return 'Heat Pump (${model.modelName})';
    return 'Heat Pump System';
  }

  String get safePdfFileName {
    final cleanName = customerName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final cleanRef = quoteRefNo.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return 'Quotation_${cleanName}_$cleanRef.pdf';
  }

  String get subjectLine {
    if (subjectOverride != null && subjectOverride!.trim().isNotEmpty) {
      return subjectOverride!.trim();
    }

    switch (quoteType) {
      case QuoteType.hpWithTank:
        if (tankLines.isNotEmpty) {
          final effectiveTanks = tankLines.map((t) => t.toTankSpec()).toList();
          return TankSpec.generateMultiTankSubjectLine(model.displayCapacityKw, effectiveTanks);
        }
        return TankSpec.generateSubjectLine(
          kw: model.displayCapacityKw,
          litres: tankCapacityLitres,
          innerMaterial: tankSpec.innerTankMaterial,
          isPressurized: isTankPressurized,
        );

      case QuoteType.hpOnly:
        return 'Proposal for air Source Heat pump Model: ${model.modelName} for your Project.';

      case QuoteType.tankOnly:
        final cap = tankLines.isNotEmpty ? tankLines.first.capacityLitres : tankCapacityLitres;
        final moc = tankLines.isNotEmpty ? tankLines.first.innerTankMaterial : tankSpec.innerTankMaterial;
        final press = tankLines.isNotEmpty ? (tankLines.first.isPressurized ? 'PRESSURIZED' : 'NON-PRESSURIZED') : (isTankPressurized ? 'PRESSURIZED' : 'NON-PRESSURIZED');
        final purp = purpose?.trim().isNotEmpty == true ? purpose!.trim().toUpperCase() : 'HOT WATER STORAGE';
        return 'Proposal for $cap Ltr / $purp / $moc / $press TANK for your Project.';

      case QuoteType.partsOnly:
        final title = proposalTitle?.trim().isNotEmpty == true ? proposalTitle!.trim() : 'Heat Pump Spare Parts & Accessories';
        return 'Proposal for $title for your Project.';

      case QuoteType.swimmingPool:
        final poolName = poolModel?.modelName ?? 'IZ-35SP';
        return 'Proposal For SWIMMING POOL Heat Pump Model: $poolName for your Project.';

      case QuoteType.allInOneFloor:
        final cap = allInOneModel?.tankVolumeLtr ?? 200;
        return 'Proposal For air Source Heat Pump Water Heating System All in One $cap LTR for your Project.';

      case QuoteType.allInOneWall:
        final cap = allInOneModel?.tankVolumeLtr ?? 100;
        return 'Proposal For air Source Heat Pump Water Heating System All in One $cap LTR for your Project.';
    }
  }

  String get acceptanceSubjectLine {
    switch (quoteType) {
      case QuoteType.hpWithTank:
        final cap = tankLines.isNotEmpty ? tankLines.first.capacityLitres : tankCapacityLitres;
        return 'Proposal For air Source Heat pump with $cap Ltr Hot Water Storage Tank for your Project.';
      case QuoteType.allInOneFloor:
      case QuoteType.allInOneWall:
        final cap = allInOneModel?.tankVolumeLtr ?? (quoteType == QuoteType.allInOneFloor ? 200 : 100);
        return 'Proposal For air Source Heat Pump Water Heating System $cap LTR for your Project.';
      case QuoteType.swimmingPool:
        final poolName = poolModel?.modelName ?? 'IZ-35SP';
        return 'Proposal For SWIMMING POOL Heat Pump Model: $poolName for your Project.';
      case QuoteType.hpOnly:
        return 'Proposal for air Source Heat pump Model: ${model.modelName} for your Project.';
      case QuoteType.tankOnly:
      case QuoteType.partsOnly:
        return subjectLine;
    }
  }

  GeneratorQuotation copyWith({
    String? id,
    QuoteType? quoteType,
    String? salutation,
    String? customerName,
    String? customerAddress,
    String? customerMobile,
    DateTime? date,
    String? quoteRefNo,
    String? salesRef,
    String? salesMobile,
    String? salesPersonId,
    String? subjectOverride,
    String? proposalTitle,
    String? purpose,
    HeatPumpModel? model,
    int? heatPumpQty,
    PriceRowType? heatPumpAmountType,
    int? heatPumpNumericPrice,
    int? tankCapacityLitres,
    int? tankQty,
    bool? isTankPressurized,
    int? tankRate,
    TankSpec? tankSpec,
    List<TankLineItem>? tankLines,
    AllInOneModel? allInOneModel,
    PoolHeatPumpModel? poolModel,
    List<PriceRow>? priceRows,
    List<PriceItem>? extraPriceRows,
    String? priceEntryMode,
    int? targetTotal,
    int? subtotal,
    double? gstPercent,
    int? gstAmount,
    int? grossTotal,
    bool? hasBuyback,
    String? buybackDescription,
    int? buybackRate,
    int? buybackQty,
    int? buybackTotal,
    int? netPayable,
    int? grandTotal,
    int? discountAmount,
    String? specialOfferLabel,
    int? paymentSplitAdvance,
    int? paymentSplitDelivery,
    int? paymentSplitCommissioning,
    int? warrantyHpYears,
    int? warrantyTankYears,
    int? validityDays,
    List<String>? termsAndConditions,
    String? coverImagePath,
    String? bannerImagePath,
    List<String>? productImagePaths,
    bool? includeProductImagePage,
    bool? includeBanner,
    String? pdfUrl,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GeneratorQuotation(
      id: id ?? this.id,
      quoteType: quoteType ?? this.quoteType,
      salutation: salutation ?? this.salutation,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      customerMobile: customerMobile ?? this.customerMobile,
      date: date ?? this.date,
      quoteRefNo: quoteRefNo ?? this.quoteRefNo,
      salesRef: salesRef ?? this.salesRef,
      salesMobile: salesMobile ?? this.salesMobile,
      salesPersonId: salesPersonId ?? this.salesPersonId,
      subjectOverride: subjectOverride ?? this.subjectOverride,
      proposalTitle: proposalTitle ?? this.proposalTitle,
      purpose: purpose ?? this.purpose,
      model: model ?? this.model,
      heatPumpQty: heatPumpQty ?? this.heatPumpQty,
      heatPumpAmountType: heatPumpAmountType ?? this.heatPumpAmountType,
      heatPumpNumericPrice: heatPumpNumericPrice ?? this.heatPumpNumericPrice,
      tankCapacityLitres: tankCapacityLitres ?? this.tankCapacityLitres,
      tankQty: tankQty ?? this.tankQty,
      isTankPressurized: isTankPressurized ?? this.isTankPressurized,
      tankRate: tankRate ?? this.tankRate,
      tankSpec: tankSpec ?? this.tankSpec,
      tankLines: tankLines ?? this.tankLines,
      allInOneModel: allInOneModel ?? this.allInOneModel,
      poolModel: poolModel ?? this.poolModel,
      priceRows: priceRows ?? this.priceRows,
      extraPriceRows: extraPriceRows ?? this.extraPriceRows,
      priceEntryMode: priceEntryMode ?? this.priceEntryMode,
      targetTotal: targetTotal ?? this.targetTotal,
      subtotal: subtotal ?? this.subtotal,
      gstPercent: gstPercent ?? this.gstPercent,
      gstAmount: gstAmount ?? this.gstAmount,
      grossTotal: grossTotal ?? this.grossTotal,
      hasBuyback: hasBuyback ?? this.hasBuyback,
      buybackDescription: buybackDescription ?? this.buybackDescription,
      buybackRate: buybackRate ?? this.buybackRate,
      buybackQty: buybackQty ?? this.buybackQty,
      buybackTotal: buybackTotal ?? this.buybackTotal,
      netPayable: netPayable ?? this.netPayable,
      grandTotal: grandTotal ?? this.grandTotal,
      discountAmount: discountAmount ?? this.discountAmount,
      specialOfferLabel: specialOfferLabel ?? this.specialOfferLabel,
      paymentSplitAdvance: paymentSplitAdvance ?? this.paymentSplitAdvance,
      paymentSplitDelivery: paymentSplitDelivery ?? this.paymentSplitDelivery,
      paymentSplitCommissioning: paymentSplitCommissioning ?? this.paymentSplitCommissioning,
      warrantyHpYears: warrantyHpYears ?? this.warrantyHpYears,
      warrantyTankYears: warrantyTankYears ?? this.warrantyTankYears,
      validityDays: validityDays ?? this.validityDays,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      bannerImagePath: bannerImagePath ?? this.bannerImagePath,
      productImagePaths: productImagePaths ?? this.productImagePaths,
      includeProductImagePage: includeProductImagePage ?? this.includeProductImagePage,
      includeBanner: includeBanner ?? this.includeBanner,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quote_type': quoteType.id,
      'quoteType': quoteType.id,
      'salutation': salutation,
      'customer_name': customerName,
      'customerName': customerName,
      'customer_address': customerAddress,
      'customerAddress': customerAddress,
      'customer_mobile': customerMobile,
      'customerMobile': customerMobile,
      'date': date.toIso8601String(),
      'quote_ref_no': quoteRefNo,
      'quoteRefNo': quoteRefNo,
      'sales_ref': salesRef,
      'salesRef': salesRef,
      'sales_mobile': salesMobile,
      'salesMobile': salesMobile,
      'sales_person_id': salesPersonId,
      'salesPersonId': salesPersonId,
      'subject_override': subjectOverride,
      'proposal_title': proposalTitle,
      'purpose': purpose,
      'model': model.toJson(),
      'heat_pump_qty': heatPumpQty,
      'heatPumpQty': heatPumpQty,
      'heat_pump_amount_type': heatPumpAmountType.name,
      'heatPumpAmountType': heatPumpAmountType.name,
      'heat_pump_numeric_price': heatPumpNumericPrice,
      'heatPumpNumericPrice': heatPumpNumericPrice,
      'tank_capacity_litres': tankCapacityLitres,
      'tankCapacityLitres': tankCapacityLitres,
      'tank_qty': tankQty,
      'tankQty': tankQty,
      'is_tank_pressurized': isTankPressurized,
      'isTankPressurized': isTankPressurized,
      'tank_rate': tankRate,
      'tankRate': tankRate,
      'tank_spec': tankSpec.toJson(),
      'tankSpec': tankSpec.toJson(),
      'tank_lines': tankLines.map((e) => e.toJson()).toList(),
      'tankLines': tankLines.map((e) => e.toJson()).toList(),
      'all_in_one_model': allInOneModel?.toJson(),
      'pool_model': poolModel?.toJson(),
      'price_rows': priceRows.map((e) => e.toJson()).toList(),
      'extra_price_rows': extraPriceRows.map((e) => e.toJson()).toList(),
      'price_entry_mode': priceEntryMode,
      'target_total': targetTotal,
      'targetTotal': targetTotal,
      'subtotal': subtotal,
      'gst_percent': gstPercent,
      'gstPercent': gstPercent,
      'gst_amount': gstAmount,
      'gstAmount': gstAmount,
      'gross_total': grossTotal,
      'grossTotal': grossTotal,
      'has_buyback': hasBuyback,
      'hasBuyback': hasBuyback,
      'buyback_description': buybackDescription,
      'buyback_rate': buybackRate,
      'buyback_qty': buybackQty,
      'buyback_total': buybackTotal,
      'net_payable': netPayable,
      'netPayable': netPayable,
      'grand_total': grandTotal,
      'grandTotal': grandTotal,
      'discount_amount': discountAmount,
      'special_offer_label': specialOfferLabel,
      'payment_split_advance': paymentSplitAdvance,
      'paymentSplitAdvance': paymentSplitAdvance,
      'payment_split_delivery': paymentSplitDelivery,
      'paymentSplitDelivery': paymentSplitDelivery,
      'payment_split_commissioning': paymentSplitCommissioning,
      'paymentSplitCommissioning': paymentSplitCommissioning,
      'warranty_hp_years': warrantyHpYears,
      'warrantyHpYears': warrantyHpYears,
      'warranty_tank_years': warrantyTankYears,
      'warrantyTankYears': warrantyTankYears,
      'validity_days': validityDays,
      'validityDays': validityDays,
      'terms_and_conditions': termsAndConditions,
      'termsAndConditions': termsAndConditions,
      'cover_image_path': coverImagePath,
      'coverImagePath': coverImagePath,
      'banner_image_path': bannerImagePath,
      'bannerImagePath': bannerImagePath,
      'product_image_paths': productImagePaths,
      'productImagePaths': productImagePaths,
      'include_product_image_page': includeProductImagePage,
      'includeProductImagePage': includeProductImagePage,
      'include_banner': includeBanner,
      'includeBanner': includeBanner,
      'pdf_url': pdfUrl,
      'pdfUrl': pdfUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory GeneratorQuotation.fromJson(Map<String, dynamic> json) {
    final typeId = (json['quote_type'] ?? json['quoteType'])?.toString() ?? 'hpWithTank';
    final qType = QuoteTypeExtension.fromId(typeId);

    // Heat Pump Model
    final hpModel = json['model'] != null
        ? HeatPumpModel.fromJson(Map<String, dynamic>.from(json['model'] as Map))
        : const HeatPumpModel(
            id: 'IZ-4C',
            modelName: 'IZ-4C',
            displayCapacityKw: 4.0,
            ratedHeatingCapacity: '3.6kw',
            descriptionLine: 'Air Source Heat pump 3.6kw',
            makeModelLine: 'Make: IZYHEAT Heat Pump Model: IZ-4C 3.6kw',
            powerInputText: 'Power Input 0.86kw, output 3.6kw, 220V - 1Phase, 50Hz With Auto Defrost.',
            defaultImagePath: 'assets/images/model_iz_4c.png',
          );

    final legacyTankSpec = json['tank_spec'] != null
        ? TankSpec.fromJson(Map<String, dynamic>.from(json['tank_spec'] as Map))
        : const TankSpec();

    final legacyTankRate = (json['tank_rate'] as num?)?.toInt() ?? 0;
    final legacyTankQty = (json['tank_qty'] as num?)?.toInt() ?? 1;
    final legacyTankCap = (json['tank_capacity_litres'] as num?)?.toInt() ?? 500;
    final legacyTankPress = (json['is_tank_pressurized'] as bool?) ?? true;

    // Parse Tank Lines (Phase 2)
    List<TankLineItem> tankLinesList = [];
    if (json['tank_lines'] is List) {
      tankLinesList = (json['tank_lines'] as List)
          .map((e) => TankLineItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (tankLinesList.isEmpty && (qType == QuoteType.hpWithTank || qType == QuoteType.tankOnly)) {
      tankLinesList = [
        TankLineItem(
          id: 'tank_1',
          capacityLitres: legacyTankCap,
          qty: legacyTankQty,
          isPressurized: legacyTankPress,
          rate: legacyTankRate,
          innerTankMaterial: legacyTankSpec.innerTankMaterial,
          innerTankThickness: legacyTankSpec.innerTankThickness,
          outerCladdingMaterial: legacyTankSpec.outerCladdingMaterial,
          insulationMaterial: legacyTankSpec.insulationMaterial,
        )
      ];
    }

    // Parse Price Rows (Phase 2)
    List<PriceRow> pRows = [];
    if (json['price_rows'] is List) {
      pRows = (json['price_rows'] as List)
          .map((e) => PriceRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    // Legacy extra price rows
    final extraRows = (json['extra_price_rows'] as List<dynamic>? ?? [])
        .map((e) => PriceItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    // If priceRows is empty (legacy quote), synthesize it
    if (pRows.isEmpty) {
      pRows = _buildLegacyPriceRows(
        hpModel: hpModel,
        hpQty: (json['heat_pump_qty'] as num?)?.toInt() ?? 1,
        hpAmountType: PriceRowType.values.firstWhere(
          (e) => e.name == json['heat_pump_amount_type'],
          orElse: () => PriceRowType.included,
        ),
        hpPrice: (json['heat_pump_numeric_price'] as num?)?.toInt() ?? 0,
        tankRate: legacyTankRate,
        tankQty: legacyTankQty,
        tankCap: legacyTankCap,
        extraRows: extraRows,
      );
    }

    // All-In-One & Pool Models
    AllInOneModel? aioModel;
    if (json['all_in_one_model'] != null) {
      aioModel = AllInOneModel.fromJson(Map<String, dynamic>.from(json['all_in_one_model'] as Map));
    }

    PoolHeatPumpModel? pModel;
    if (json['pool_model'] != null) {
      pModel = PoolHeatPumpModel.fromJson(Map<String, dynamic>.from(json['pool_model'] as Map));
    }

    final subtotal = (json['subtotal'] as num?)?.toInt() ?? 0;
    final gstPercent = (json['gst_percent'] as num?)?.toDouble() ?? 18.0;
    final gstAmount = (json['gst_amount'] as num?)?.toInt() ?? 0;
    final grossTotal = (json['gross_total'] as num?)?.toInt() ?? (subtotal + gstAmount);
    final hasBuyback = (json['has_buyback'] as bool?) ?? false;
    final buybackRate = (json['buyback_rate'] as num?)?.toInt() ?? 0;
    final buybackQty = (json['buyback_qty'] as num?)?.toInt() ?? 1;
    final buybackTotal = (json['buyback_total'] as num?)?.toInt() ?? (hasBuyback ? buybackRate * buybackQty : 0);
    final netPayable = (json['net_payable'] as num?)?.toInt() ?? (grossTotal - buybackTotal);
    final grandTotal = (json['grand_total'] as num?)?.toInt() ?? netPayable;

    return GeneratorQuotation(
      id: json['id'] as String,
      quoteType: qType,
      salutation: json['salutation'] as String? ?? 'M/s.',
      customerName: json['customer_name'] as String? ?? '',
      customerAddress: json['customer_address'] as String? ?? '',
      customerMobile: json['customer_mobile'] as String? ?? '',
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      quoteRefNo: json['quote_ref_no'] as String? ?? '',
      salesRef: json['sales_ref'] as String? ?? '',
      salesMobile: json['sales_mobile'] as String? ?? '',
      salesPersonId: json['sales_person_id'] as String?,
      subjectOverride: json['subject_override'] as String?,
      proposalTitle: json['proposal_title'] as String?,
      purpose: json['purpose'] as String?,
      model: hpModel,
      heatPumpQty: (json['heat_pump_qty'] as num?)?.toInt() ?? 1,
      heatPumpAmountType: PriceRowType.values.firstWhere(
        (e) => e.name == json['heat_pump_amount_type'],
        orElse: () => PriceRowType.included,
      ),
      heatPumpNumericPrice: (json['heat_pump_numeric_price'] as num?)?.toInt() ?? 0,
      tankCapacityLitres: legacyTankCap,
      tankQty: legacyTankQty,
      isTankPressurized: legacyTankPress,
      tankRate: legacyTankRate,
      tankSpec: legacyTankSpec,
      tankLines: tankLinesList,
      allInOneModel: aioModel,
      poolModel: pModel,
      priceRows: pRows,
      extraPriceRows: extraRows,
      priceEntryMode: json['price_entry_mode'] as String? ?? 'exclusive',
      targetTotal: (json['target_total'] as num?)?.toInt(),
      subtotal: subtotal,
      gstPercent: gstPercent,
      gstAmount: gstAmount,
      grossTotal: grossTotal,
      hasBuyback: hasBuyback,
      buybackDescription: json['buyback_description'] as String?,
      buybackRate: buybackRate,
      buybackQty: buybackQty,
      buybackTotal: buybackTotal,
      netPayable: netPayable,
      grandTotal: grandTotal,
      discountAmount: (json['discount_amount'] as num?)?.toInt(),
      specialOfferLabel: json['special_offer_label'] as String?,
      paymentSplitAdvance: (json['payment_split_advance'] as num?)?.toInt() ?? 70,
      paymentSplitDelivery: (json['payment_split_delivery'] as num?)?.toInt() ?? 20,
      paymentSplitCommissioning: (json['payment_split_commissioning'] as num?)?.toInt() ?? 10,
      warrantyHpYears: (json['warranty_hp_years'] as num?)?.toInt() ?? 2,
      warrantyTankYears: (json['warranty_tank_years'] as num?)?.toInt() ?? 5,
      validityDays: (json['validity_days'] as num?)?.toInt() ?? 7,
      termsAndConditions: (json['terms_and_conditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      coverImagePath: json['cover_image_path'] as String?,
      bannerImagePath: json['banner_image_path'] as String?,
      productImagePaths: (json['product_image_paths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      includeProductImagePage: json['include_product_image_page'] as bool? ?? true,
      includeBanner: json['include_banner'] as bool? ?? true,
      pdfUrl: json['pdf_url'] as String?,
      status: json['status'] as String? ?? 'Draft',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }

  static List<PriceRow> _buildLegacyPriceRows({
    required HeatPumpModel hpModel,
    required int hpQty,
    required PriceRowType hpAmountType,
    required int hpPrice,
    required int tankRate,
    required int tankQty,
    required int tankCap,
    required List<PriceItem> extraRows,
  }) {
    final rows = <PriceRow>[];

    // 01 Heat pump
    rows.add(PriceRow(
      id: 'row_hp',
      serialNo: '01',
      description: 'Air Source Heat Pump Model: ${hpModel.modelName}',
      unitLabel: 'SET',
      qty: hpQty,
      status: hpAmountType == PriceRowType.included ? PriceRowStatus.included : PriceRowStatus.priced,
      rate: hpPrice,
      amount: hpAmountType == PriceRowType.included ? 0 : (hpPrice * hpQty),
    ));

    // 02 Tank
    rows.add(PriceRow(
      id: 'row_tank',
      serialNo: '02',
      description: 'Hot Water Storage Tank ($tankCap Ltr)',
      unitLabel: 'NOS',
      qty: tankQty,
      status: PriceRowStatus.priced,
      rate: tankRate,
      amount: tankRate * tankQty,
    ));

    // Extra rows
    int idx = 3;
    for (final ex in extraRows) {
      PriceRowStatus st;
      if (ex.amountType == PriceRowType.included) {
        st = PriceRowStatus.included;
      } else if (ex.amountType == PriceRowType.extra) {
        st = PriceRowStatus.extra;
      } else if (ex.amountType == PriceRowType.amount) {
        st = PriceRowStatus.priced;
      } else {
        st = PriceRowStatus.customText;
      }

      rows.add(PriceRow(
        id: 'row_extra_${ex.serialNo}',
        serialNo: (idx < 10) ? '0$idx' : '$idx',
        description: ex.description,
        unitLabel: 'LOT',
        qty: 1,
        status: st,
        rate: ex.numericAmount,
        amount: st == PriceRowStatus.priced ? ex.numericAmount : 0,
      ));
      idx++;
    }

    return rows;
  }
}
