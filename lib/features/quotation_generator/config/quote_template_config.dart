// lib/features/quotation_generator/config/quote_template_config.dart

import 'dynamic_annexure_resolver.dart';
import 'quote_type.dart';
import '../models/price_row.dart';

enum FooterMode {
  standard, // SubTotal -> GST -> Grand Total
  buyback,  // SubTotal -> GST -> Gross Total -> Buyback -> Net Payable
}

enum SpecMode {
  heatPumpAndTank,
  heatPumpOnly,
  tankOnly,
  swimmingPool,
  allInOne,
  none,
}

enum CatalogSource {
  heatPump,
  allInOne,
  pool,
  none,
}

enum WarrantyFieldType {
  heatPumpYears,
  tankYears,
  compressorYears,
  customText,
}

enum PaymentPresetType {
  standard70_20_10, // 70% advance, 20% delivery, 10% satisfactory commissioning
  advance100,       // 100% advance against PO
  installation70_20_10, // 70% advance, 20% delivery, 10% installation and commissioning (no "satisfactory")
  custom,
}

extension PaymentPresetTypeX on PaymentPresetType {
  String get label {
    switch (this) {
      case PaymentPresetType.standard70_20_10:
        return '70/20/10 Standard (with Satisfactory Commissioning)';
      case PaymentPresetType.advance100:
        return '100% Advance Against PO';
      case PaymentPresetType.installation70_20_10:
        return '70/20/10 (Against Installation & Commissioning)';
      case PaymentPresetType.custom:
        return 'Custom Payment Terms';
    }
  }

  String buildText({int advance = 70, int delivery = 20, int commissioning = 10, String? customText}) {
    switch (this) {
      case PaymentPresetType.standard70_20_10:
        return 'Advance will be $advance% against PO, and $delivery% against delivery, the balance $commissioning% against satisfactory installation and commissioning.';
      case PaymentPresetType.advance100:
        return '100% Advance against PO.';
      case PaymentPresetType.installation70_20_10:
        return 'Advance will be $advance% against PO, and $delivery% against delivery, the balance $commissioning% against installation and commissioning.';
      case PaymentPresetType.custom:
        return customText?.isNotEmpty == true
            ? customText!
            : 'Advance will be $advance% against PO, and $delivery% against delivery, the balance $commissioning% against satisfactory installation and commissioning.';
    }
  }
}

class FormRequiredInputs {
  final bool hasHpModel;
  final bool hasTankConfig;
  final bool hasPoolModel;
  final bool hasAllInOneModel;
  final bool hasProposalTitle;
  final bool hasPurposeSelector; // For tankOnly: Hot Water Storage vs Solar Water Heater
  final bool hasBuyback;
  final bool hasDiscount;

  const FormRequiredInputs({
    this.hasHpModel = false,
    this.hasTankConfig = false,
    this.hasPoolModel = false,
    this.hasAllInOneModel = false,
    this.hasProposalTitle = false,
    this.hasPurposeSelector = false,
    this.hasBuyback = false,
    this.hasDiscount = false,
  });
}

class QuoteTemplateConfig {
  final QuoteType quoteType;
  final List<DocSection> sections;
  final List<String> priceColumnKeys;
  final List<PriceRow> defaultRows;
  final FooterMode footerMode;
  final List<WarrantyFieldType> warrantyFields;
  final List<String> defaultTerms;
  final PaymentPresetType defaultPaymentPreset;
  final CatalogSource catalogSource;
  final FormRequiredInputs requiredInputs;
  final bool hasTechnicalSpecs;

  const QuoteTemplateConfig({
    required this.quoteType,
    required this.sections,
    required this.priceColumnKeys,
    required this.defaultRows,
    required this.footerMode,
    required this.warrantyFields,
    required this.defaultTerms,
    required this.defaultPaymentPreset,
    required this.catalogSource,
    required this.requiredInputs,
    this.hasTechnicalSpecs = true,
  });

  SpecMode get specMode {
    switch (quoteType) {
      case QuoteType.hpWithTank:
        return SpecMode.heatPumpAndTank;
      case QuoteType.hpOnly:
        return SpecMode.heatPumpOnly;
      case QuoteType.tankOnly:
        return SpecMode.tankOnly;
      case QuoteType.swimmingPool:
        return SpecMode.swimmingPool;
      case QuoteType.allInOneFloor:
      case QuoteType.allInOneWall:
        return SpecMode.allInOne;
      case QuoteType.partsOnly:
        return SpecMode.none;
    }
  }

  /// Factory creating configuration for any of the 7 QuoteTypes
  static QuoteTemplateConfig forType(QuoteType type) {
    switch (type) {
      case QuoteType.hpWithTank:
        return _buildHpWithTankConfig();
      case QuoteType.hpOnly:
        return _buildHpOnlyConfig();
      case QuoteType.tankOnly:
        return _buildTankOnlyConfig();
      case QuoteType.partsOnly:
        return _buildPartsOnlyConfig();
      case QuoteType.swimmingPool:
        return _buildSwimmingPoolConfig();
      case QuoteType.allInOneFloor:
        return _buildAllInOneFloorConfig();
      case QuoteType.allInOneWall:
        return _buildAllInOneWallConfig();
    }
  }

  // ─── 1. HP WITH TANK ───────────────────────────────────────────────────────
  static QuoteTemplateConfig _buildHpWithTankConfig() {
    return QuoteTemplateConfig(
      quoteType: QuoteType.hpWithTank,
      sections: const [
        DocSection.coverPage,
        DocSection.offerLetter,
        DocSection.priceSchedule,
        DocSection.specHeatPump,
        DocSection.specTank,
        DocSection.termsAndConditions,
        DocSection.acceptanceLetter,
        DocSection.productShowcase,
      ],
      priceColumnKeys: const ['sNo', 'description', 'lph', 'hpKw', 'qty', 'ratePerLtr', 'systemRate', 'amount'],
      defaultRows: [
        const PriceRow(id: 'r_hp', serialNo: '01', description: 'Air Source Heat Pump', status: PriceRowStatus.included),
        const PriceRow(id: 'r_tank', serialNo: '02', description: 'Hot Water Storage Tank', status: PriceRowStatus.priced, qty: 1, rate: 120000),
        const PriceRow(id: 'r_trans', serialNo: '03', description: 'Transportation to Site', status: PriceRowStatus.included),
        const PriceRow(id: 'r_lift', serialNo: '04', description: 'Lifting of System to Site', status: PriceRowStatus.included),
        const PriceRow(id: 'r_inst', serialNo: '05', description: 'Installation & Commissioning', status: PriceRowStatus.included),
        const PriceRow(id: 'r_pump', serialNo: '06', description: 'Circulation Pump (Kirloskar/Wilo)', status: PriceRowStatus.included),
        const PriceRow(id: 'r_plumb', serialNo: '07', description: 'Plumbing & Electrical Material', status: PriceRowStatus.extra),
        const PriceRow(id: 'r_load', serialNo: '08', description: 'Loading & Unloading', status: PriceRowStatus.included),
      ],
      footerMode: FooterMode.standard,
      warrantyFields: const [WarrantyFieldType.heatPumpYears, WarrantyFieldType.tankYears],
      defaultTerms: const [
        'Proper 1 / 3 Phase power should be arranged where you install the heat pump.',
        'Electrical/civil/plumbing work materials – Customer Scope.',
        'Safe storage place need to be provided by you to keep our material & tools.',
        'All Interconnected pipe lines between system and Tank Your Scope but our team will do the installation. (If applicable): Extra',
      ],
      defaultPaymentPreset: PaymentPresetType.standard70_20_10,
      catalogSource: CatalogSource.heatPump,
      requiredInputs: const FormRequiredInputs(
        hasHpModel: true,
        hasTankConfig: true,
        hasBuyback: true,
      ),
      hasTechnicalSpecs: true,
    );
  }

  // ─── 2. HP ONLY ────────────────────────────────────────────────────────────
  static QuoteTemplateConfig _buildHpOnlyConfig() {
    return QuoteTemplateConfig(
      quoteType: QuoteType.hpOnly,
      sections: const [
        DocSection.coverPage,
        DocSection.offerLetter,
        DocSection.priceSchedule,
        DocSection.specHeatPump,
        DocSection.termsAndConditions,
        DocSection.acceptanceLetter,
        DocSection.productShowcase,
      ],
      priceColumnKeys: const ['sNo', 'description', 'hpKw', 'ratePerKw', 'qty', 'systemRate', 'amount'],
      defaultRows: [
        const PriceRow(id: 'r_hp', serialNo: '01', description: 'Air Source Heat Pump with Stand', status: PriceRowStatus.priced, qty: 1, rate: 0),
        const PriceRow(id: 'r_trans', serialNo: '02', description: 'Transportation to Site', status: PriceRowStatus.included),
        const PriceRow(id: 'r_inst', serialNo: '03', description: 'Installation & Commissioning', status: PriceRowStatus.included),
        const PriceRow(id: 'r_pump', serialNo: '04', description: 'Circulation Pump (Wilo)', status: PriceRowStatus.included),
        const PriceRow(id: 'r_lift', serialNo: '05', description: 'Lifting of System to Site', status: PriceRowStatus.included),
        const PriceRow(id: 'r_other', serialNo: '06', description: 'Plumbing & wiring material - Extra', status: PriceRowStatus.extra),
      ],
      footerMode: FooterMode.standard,
      warrantyFields: const [WarrantyFieldType.heatPumpYears],
      defaultTerms: const [
        'Proper 1 / 3 Phase power should be arranged where you install the heat pump.',
        'Electricity voltage issue arrangement of stabilizer Customer Scope.',
        'Electrical/civil/plumbing work materials – Customer Scope.',
        'Safe storage place need to be provided by you to keep our material & tools.',
      ],
      defaultPaymentPreset: PaymentPresetType.standard70_20_10,
      catalogSource: CatalogSource.heatPump,
      requiredInputs: const FormRequiredInputs(
        hasHpModel: true,
        hasBuyback: true,
      ),
      hasTechnicalSpecs: true,
    );
  }

  // ─── 3. TANK ONLY ──────────────────────────────────────────────────────────
  static QuoteTemplateConfig _buildTankOnlyConfig() {
    return QuoteTemplateConfig(
      quoteType: QuoteType.tankOnly,
      sections: const [
        DocSection.coverPage,
        DocSection.offerLetter,
        DocSection.priceSchedule,
        DocSection.specTank,
        DocSection.termsAndConditions,
        DocSection.acceptanceLetter,
        DocSection.productShowcase,
      ],
      priceColumnKeys: const ['sNo', 'description', 'lph', 'qty', 'ratePerLtr', 'systemRate', 'amount'],
      defaultRows: [
        const PriceRow(id: 'r_tank', serialNo: '01', description: 'Hot Water Storage Tank', status: PriceRowStatus.priced, qty: 1, rate: 120000),
        const PriceRow(id: 'r_trans', serialNo: '02', description: 'Transportation to Site', status: PriceRowStatus.included),
        const PriceRow(id: 'r_lift', serialNo: '03', description: 'Lifting of System to Site', status: PriceRowStatus.included),
        const PriceRow(id: 'r_inst', serialNo: '04', description: 'Installation & Commissioning', status: PriceRowStatus.included),
        const PriceRow(id: 'r_plumb', serialNo: '05', description: 'Plumbing & Electrical Material', status: PriceRowStatus.extra),
        const PriceRow(id: 'r_load', serialNo: '06', description: 'Loading & Unloading', status: PriceRowStatus.included),
        const PriceRow(id: 'r_pump', serialNo: '07', description: 'Circulation Pump (Kirloskar/Wilo)', status: PriceRowStatus.na),
      ],
      footerMode: FooterMode.standard,
      warrantyFields: const [WarrantyFieldType.tankYears],
      defaultTerms: const [
        'Electrical/civil/plumbing work materials – Customer Scope.',
        'Safe storage place need to be provided by you to keep our material & tools.',
        'All Interconnected pipe lines between system and Tank Your Scope: Extra',
      ],
      defaultPaymentPreset: PaymentPresetType.standard70_20_10,
      catalogSource: CatalogSource.none,
      requiredInputs: const FormRequiredInputs(
        hasTankConfig: true,
        hasPurposeSelector: true,
      ),
      hasTechnicalSpecs: true,
    );
  }

  // ─── 4. PARTS ONLY ─────────────────────────────────────────────────────────
  static QuoteTemplateConfig _buildPartsOnlyConfig() {
    return QuoteTemplateConfig(
      quoteType: QuoteType.partsOnly,
      sections: const [
        DocSection.coverPage,
        DocSection.offerLetter,
        DocSection.priceSchedule,
        DocSection.termsAndConditions,
        DocSection.acceptanceLetter,
      ],
      priceColumnKeys: const ['sNo', 'description', 'qty', 'rate', 'amount'],
      defaultRows: [
        const PriceRow(id: 'r_part1', serialNo: '01', description: 'Return Line Circulation Pump', status: PriceRowStatus.priced, qty: 1, rate: 20000),
        const PriceRow(id: 'r_part2', serialNo: '02', description: 'Electrical Controller System', status: PriceRowStatus.priced, qty: 1, rate: 30000),
      ],
      footerMode: FooterMode.standard,
      warrantyFields: const [WarrantyFieldType.customText],
      defaultTerms: const [
        'Prices are strictly valid as per validity period.',
        'Safe storage place need to be provided by you to keep material & tools.',
        'Transportation and delivery as specified.',
      ],
      defaultPaymentPreset: PaymentPresetType.advance100,
      catalogSource: CatalogSource.none,
      requiredInputs: const FormRequiredInputs(
        hasProposalTitle: true,
        hasDiscount: true,
      ),
      hasTechnicalSpecs: false, // Notice: No specs page -> Terms becomes Annexure II!
    );
  }

  // ─── 5. SWIMMING POOL ──────────────────────────────────────────────────────
  static QuoteTemplateConfig _buildSwimmingPoolConfig() {
    return QuoteTemplateConfig(
      quoteType: QuoteType.swimmingPool,
      sections: const [
        DocSection.coverPage,
        DocSection.offerLetter,
        DocSection.priceSchedule,
        DocSection.specPool,
        DocSection.termsAndConditions,
        DocSection.acceptanceLetter,
        DocSection.productShowcase,
      ],
      priceColumnKeys: const ['sNo', 'description', 'hpKw', 'ratePerKw', 'qty', 'systemRate', 'amount'],
      defaultRows: [
        const PriceRow(id: 'r_pool', serialNo: '01', description: 'Air Source Heat Pump 35KW for Swimming Pool', status: PriceRowStatus.priced, qty: 1, rate: 312712),
        const PriceRow(id: 'r_trans', serialNo: '02', description: 'Transportation from Pune', status: PriceRowStatus.included),
        const PriceRow(id: 'r_lift', serialNo: '03', description: 'Lifting of the system to the allotted site', status: PriceRowStatus.extra),
        const PriceRow(id: 'r_inst', serialNo: '04', description: 'Installation & Commissioning', status: PriceRowStatus.included),
        const PriceRow(id: 'r_plumb', serialNo: '05', description: 'Plumbing & wiring material', status: PriceRowStatus.extra),
      ],
      footerMode: FooterMode.standard,
      warrantyFields: const [WarrantyFieldType.heatPumpYears],
      defaultTerms: const [
        'Proper 3 Phase power should be arranged where you install the swimming pool heat pump.',
        'Electrical/civil/plumbing work materials – Customer Scope.',
        'Transportation from Pune – Included.',
        'Lifting of the system to the allotted site – Extra.',
        'Safe storage place need to be provided by you to keep our material & tools.',
      ],
      defaultPaymentPreset: PaymentPresetType.installation70_20_10,
      catalogSource: CatalogSource.pool,
      requiredInputs: const FormRequiredInputs(
        hasPoolModel: true,
      ),
      hasTechnicalSpecs: true,
    );
  }

  // ─── 6. ALL IN ONE FLOOR ───────────────────────────────────────────────────
  static QuoteTemplateConfig _buildAllInOneFloorConfig() {
    return QuoteTemplateConfig(
      quoteType: QuoteType.allInOneFloor,
      sections: const [
        DocSection.coverPage,
        DocSection.offerLetter,
        DocSection.priceSchedule,
        DocSection.specAllInOne,
        DocSection.termsAndConditions,
        DocSection.acceptanceLetter,
        DocSection.productShowcase,
      ],
      priceColumnKeys: const ['sNo', 'description', 'qty', 'rate', 'amount'],
      defaultRows: [
        const PriceRow(id: 'r_aio', serialNo: '01', description: 'ALL IN ONE HEAT PUMP (TOP Blow) Make: IZYHEAT Heat Pump Model: IZ-200A', status: PriceRowStatus.priced, qty: 1, rate: 122881),
        const PriceRow(id: 'r_trans', serialNo: '02', description: 'Transportation from Pune', status: PriceRowStatus.extra),
        const PriceRow(id: 'r_lift', serialNo: '03', description: 'Lifting of the system to the allotted site', status: PriceRowStatus.extra),
        const PriceRow(id: 'r_inst', serialNo: '04', description: 'Installation & Commissioning', status: PriceRowStatus.included),
        const PriceRow(id: 'r_plumb', serialNo: '05', description: 'Plumbing & wiring material', status: PriceRowStatus.extra),
      ],
      footerMode: FooterMode.standard,
      warrantyFields: const [WarrantyFieldType.heatPumpYears, WarrantyFieldType.compressorYears],
      defaultTerms: const [
        'Proper 1 Phase power should be arranged where you install the heat pump.',
        'Electrical/civil/plumbing work materials – Customer Scope.',
        'Transportation from Pune – Extra.',
        'Lifting of the system to the allotted site – Extra.',
        'All interconnected pipe lines between system and tank: as per Annexure I.',
        'Safe storage place need to be provided by you to keep our material & tools.',
      ],
      defaultPaymentPreset: PaymentPresetType.standard70_20_10,
      catalogSource: CatalogSource.allInOne,
      requiredInputs: const FormRequiredInputs(
        hasAllInOneModel: true,
        hasDiscount: true,
      ),
      hasTechnicalSpecs: true,
    );
  }

  // ─── 7. ALL IN ONE WALL ────────────────────────────────────────────────────
  static QuoteTemplateConfig _buildAllInOneWallConfig() {
    return QuoteTemplateConfig(
      quoteType: QuoteType.allInOneWall,
      sections: const [
        DocSection.coverPage,
        DocSection.offerLetter,
        DocSection.priceSchedule,
        DocSection.specAllInOne,
        DocSection.termsAndConditions,
        DocSection.acceptanceLetter,
        DocSection.productShowcase,
      ],
      priceColumnKeys: const ['sNo', 'description', 'qty', 'rate', 'amount'],
      defaultRows: [
        const PriceRow(id: 'r_aio', serialNo: '01', description: 'ALL IN ONE WALL MOUNTED HEAT PUMP (TOP Blow) Make: IZYHEAT Heat Pump Model: IZ-100V', status: PriceRowStatus.priced, qty: 1, rate: 76271),
        const PriceRow(id: 'r_bracket', serialNo: '02', description: 'Wall Mounting Bracket', status: PriceRowStatus.included),
        const PriceRow(id: 'r_trans', serialNo: '03', description: 'Transportation from Pune', status: PriceRowStatus.extra),
        const PriceRow(id: 'r_lift', serialNo: '04', description: 'Lifting of the system to the allotted site', status: PriceRowStatus.extra),
        const PriceRow(id: 'r_inst', serialNo: '05', description: 'Installation & Commissioning', status: PriceRowStatus.included),
      ],
      footerMode: FooterMode.standard,
      warrantyFields: const [WarrantyFieldType.heatPumpYears, WarrantyFieldType.compressorYears],
      defaultTerms: const [
        'Proper 1 Phase power should be arranged where you install the heat pump.',
        'Electrical/civil/plumbing work materials – Customer Scope.',
        'Transportation from Pune – Extra.',
        'Lifting of the system to the allotted site – Extra.',
        'Safe storage place need to be provided by you to keep our material & tools.',
      ],
      defaultPaymentPreset: PaymentPresetType.standard70_20_10,
      catalogSource: CatalogSource.allInOne,
      requiredInputs: const FormRequiredInputs(
        hasAllInOneModel: true,
        hasDiscount: true,
      ),
      hasTechnicalSpecs: true,
    );
  }
}
