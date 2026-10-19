// lib/features/quotation_generator/services/qg_noc_extractor.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/qg_noc_builder_state.dart';
import '../models/qg_noc_profile.dart';
import 'qg_item_parser.dart';

class QgNocExtractor {
  /// Fetches the set of item names treated as products from the products table
  static Future<Set<String>> fetchItemsTreatedAsProducts(SupabaseClient supabase) async {
    final treated = <String>{};
    try {
      final res = await supabase.from('products').select('name, base_specs');
      for (final p in res) {
          final pName = p['name']?.toString().trim();
          if (pName != null && pName.isNotEmpty) {
            treated.add(pName.toLowerCase());
          }
          final specs = p['base_specs'] as Map<String, dynamic>? ?? {};
          final linked = specs['linked_items'] as List?;
          if (linked != null) {
            for (final item in linked) {
              final s = item?.toString().trim();
              if (s != null && s.isNotEmpty) {
                treated.add(s.toLowerCase());
              }
            }
          }
        }
    } catch (e) {
      debugPrint('fetchItemsTreatedAsProducts error: $e');
    }
    return treated;
  }

  static bool _isNonProductInventoryItem(String desc) {
    final lower = desc.toLowerCase();
    // Major sell products should never be considered non-product
    if (lower.contains('heat pump') || lower.contains('water heater') || lower.contains('storage tank')) {
      return false;
    }

    const nonProductKeywords = [
      'circulation pump',
      'circulating pump',
      'booster pump',
      'wilo',
      'inline pump',
      'water pump',
      'sensor',
      'contactor',
      'contractor',
      'thermostat',
      'cable',
      'wire',
      'breaker',
      'mcb',
      'valve',
      'strainer',
      'pipe',
      'piping',
      'fitting',
      'nipple',
      'union',
      'elbow',
      'flange',
      'stand',
      'bracket',
      'support',
      'hardware',
      'screw',
      'bolt',
      'nut',
      'insulation',
      'rubber',
      'tape',
      'gas',
      'refrigerant',
      'chemical',
      'freight',
      'transport',
      'labour',
      'installation charges',
    ];

    for (final kw in nonProductKeywords) {
      if (lower.contains(kw)) {
        return true;
      }
    }
    return false;
  }

  /// Extracts models and quantities from quotation line items,
  /// including ONLY items that are treated as products in inventory.
  static List<NocEquipmentLine> extractEquipmentLines({
    required List<Map<String, dynamic>> lineItems,
    String defaultProductName = 'System',
    Set<String>? itemsTreatedAsProducts,
  }) {
    final rawResults = <NocEquipmentLine>[];

    for (final item in lineItems) {
      // Ignore supplementary/extra terms lines
      final isSupplementary = item['is_supplementary'] == true || item['isSupplementary'] == true;
      if (isSupplementary) continue;

      final desc = (item['description'] ?? item['item_name'] ?? item['name'] ?? '').toString().trim();
      if (desc.isEmpty) continue;

      final isExplicitProduct = itemsTreatedAsProducts != null &&
          itemsTreatedAsProducts.contains(desc.toLowerCase());

      // If not an explicit product, check if it's a non-product inventory item to exclude
      if (!isExplicitProduct && _isNonProductInventoryItem(desc)) {
        continue;
      }

      final qty = (item['qty'] as num?)?.toInt() ?? 1;
      final rawUom = (item['uom'] ?? item['unit'] ?? '').toString().trim();
      final uom = rawUom.isNotEmpty && rawUom.toLowerCase() != 'set' ? rawUom : 'Nos';

      // 1. Heat Pump Detection via whole-number kW or parser
      final kwMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:kw)', caseSensitive: false).firstMatch(desc);
      final isHp = desc.toLowerCase().contains('heat pump') || desc.toLowerCase().contains('hp') || kwMatch != null;

      if (isHp && kwMatch != null) {
        final kwVal = double.tryParse(kwMatch.group(1)!);
        final wholeKw = kwVal?.round() ?? 0;
        final model = QgItemParser.deriveHpModelFromKw(wholeKw);
        rawResults.add(NocEquipmentLine(
          product: 'Heat Pump',
          model: model,
          quantity: qty,
          uom: uom,
        ));
        continue;
      }

      // 2. Storage Tank Detection
      final isTank = desc.toLowerCase().contains('tank') || desc.toLowerCase().contains('storage');
      final ltrMatch = RegExp(r'(\d+)\s*(?:ltr|l|liter|litre)', caseSensitive: false).firstMatch(desc);
      if (isTank && ltrMatch != null) {
        final litres = ltrMatch.group(1)!;
        final isSS = RegExp(r'\bss\b|stainless', caseSensitive: false).hasMatch(desc);
        final mat = isSS ? 'SS' : 'GI';
        final model = '$litres Ltr $mat Tank';
        rawResults.add(NocEquipmentLine(
          product: 'Storage Tank',
          model: model,
          quantity: qty,
          uom: uom,
        ));
        continue;
      }

      // 3. Boom Barrier / Code / Model Pattern Match (e.g. IZ-2001, IZ-35SP, IZ-200A, [A-Z]{1,4}-?\d[\w-]*)
      final tokenRegex = RegExp(r'\b(IZ-?\d+[A-Z0-9-]*|[A-Z]{1,4}-\d[\w-]*)\b', caseSensitive: false);
      final tokenMatch = tokenRegex.firstMatch(desc);
      if (tokenMatch != null) {
        final token = tokenMatch.group(1)!.toUpperCase();
        String prod = defaultProductName;
        if (token.startsWith('IZ-') && token.endsWith('C')) {
          prod = 'Heat Pump';
        } else if (token.contains('SP')) {
          prod = 'Swimming Pool Heat Pump';
        } else if (token.contains('2001') || token.contains('2026')) {
          prod = 'Boom Barrier';
        }
        rawResults.add(NocEquipmentLine(
          product: prod,
          model: token,
          quantity: qty,
          uom: uom,
        ));
        continue;
      }

      // 4. If explicit product from inventory
      if (isExplicitProduct) {
        rawResults.add(NocEquipmentLine(
          product: defaultProductName,
          model: desc,
          quantity: qty,
          uom: uom,
        ));
      }
    }

    // Aggregate identical equipment lines (e.g. same product & model)
    final aggregated = <String, NocEquipmentLine>{};
    for (final line in rawResults) {
      final key = '${line.product}::${line.model}'.toLowerCase();
      if (aggregated.containsKey(key)) {
        final prev = aggregated[key]!;
        aggregated[key] = NocEquipmentLine(
          product: prev.product,
          model: prev.model,
          quantity: prev.quantity + line.quantity,
          uom: prev.uom,
        );
      } else {
        aggregated[key] = line;
      }
    }

    final results = aggregated.values.toList();

    // Fallback if no equipment lines could be extracted
    if (results.isEmpty) {
      final fallbackDesc = lineItems.isNotEmpty
          ? (lineItems.first['description'] ?? lineItems.first['item_name'] ?? lineItems.first['name'] ?? 'Standard').toString().trim()
          : 'Standard';
      results.add(NocEquipmentLine(
        product: defaultProductName,
        model: fallbackDesc.isNotEmpty ? fallbackDesc : 'Standard',
        quantity: 1,
        uom: 'Nos',
        isAmbiguous: true,
        ambiguityReason: 'Check model',
      ));
    }

    return results;
  }

  /// Resolves the site / customer address using strict precedence:
  /// 1. installations.customer_address
  /// 2. quotations.shipping_address
  /// 3. quotations.billing_address
  /// 4. customers.address
  static String resolveSiteAddress({
    Map<String, dynamic>? installation,
    Map<String, dynamic>? quotation,
    Map<String, dynamic>? customer,
  }) {
    final instAddr = installation?['customer_address']?.toString().trim();
    if (instAddr != null && instAddr.isNotEmpty) return instAddr;

    final shipAddr = quotation?['shipping_address']?.toString().trim();
    if (shipAddr != null && shipAddr.isNotEmpty) return shipAddr;

    final billAddr = quotation?['billing_address']?.toString().trim();
    if (billAddr != null && billAddr.isNotEmpty) return billAddr;

    final custAddr = customer?['address']?.toString().trim();
    if (custAddr != null && custAddr.isNotEmpty) return custAddr;

    return '';
  }

  /// Resolves Customer / Site Name in UPPERCASE
  static String resolveCustomerName({
    Map<String, dynamic>? quotation,
    Map<String, dynamic>? customer,
    String salutation = 'M/s',
  }) {
    String name = (customer?['company_name'] ?? customer?['name'] ?? quotation?['customer_name'] ?? '').toString().trim();
    if (name.isEmpty) name = 'Valued Customer';

    // Remove redundant salutation if already part of name
    if (name.toLowerCase().startsWith('m/s ') || name.toLowerCase().startsWith('m/s. ')) {
      name = name.substring(4).trim();
    }

    return name.toUpperCase();
  }

  /// Builds a complete default QgNocPayload from all resolved entities
  static QgNocPayload buildPayload({
    required Map<String, dynamic> deal,
    Map<String, dynamic>? quotation,
    Map<String, dynamic>? customer,
    Map<String, dynamic>? installation,
    required QgNocProfile profile,
    required Map<String, dynamic> companyConfig,
    String? stampImagePath,
    NocWordingMode wordingMode = NocWordingMode.enhanced,
    NocDateSource dateSource = NocDateSource.generationDate,
    String salutation = 'M/s',
  }) {
    // 1. Product Name - take from quotation line items first for deals
    String prodName = '';
    final lineItemsRaw = quotation?['line_items'];
    if (lineItemsRaw is List && lineItemsRaw.isNotEmpty) {
      final first = lineItemsRaw.first;
      if (first is Map) {
        final desc = (first['description'] ?? first['item_name'] ?? first['name'])?.toString().trim() ?? '';
        if (desc.isNotEmpty) {
          prodName = desc;
        }
      }
    }
    if (prodName.isEmpty) {
      prodName = (deal['products'] is Map
              ? deal['products']['name']
              : (deal['product_name'] ?? profile.productName))
          .toString()
          .trim();
    }

    // 2. Equipment lines
    List<Map<String, dynamic>> items = [];
    if (lineItemsRaw is List) {
      items = lineItemsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    final equipmentLines = extractEquipmentLines(
      lineItems: items,
      defaultProductName: prodName,
    );

    // 3. Customer & Address
    final custName = resolveCustomerName(quotation: quotation, customer: customer, salutation: salutation);
    final address = resolveSiteAddress(installation: installation, quotation: quotation, customer: customer);

    // 4. Date determination
    DateTime nocDate = DateTime.now();
    if (dateSource == NocDateSource.installationCompletedDate && installation != null) {
      final dt = DateTime.tryParse(installation['updated_at']?.toString() ?? installation['created_at']?.toString() ?? '');
      if (dt != null) nocDate = dt;
    } else if (dateSource == NocDateSource.dealCompletedDate) {
      final dt = DateTime.tryParse(deal['updated_at']?.toString() ?? deal['created_at']?.toString() ?? '');
      if (dt != null) nocDate = dt;
    }

    // 5. Subject
    final subject = 'No Objection Certificate for Installation & Commissioning of $prodName.';

    // 6. Company Block
    final compName = profile.companyNameOverride ?? companyConfig['company_name']?.toString() ?? 'INSIYA TRADING CORPORATION';
    final compAddr = profile.companyAddressOverride ?? companyConfig['company_address']?.toString() ?? 'Office no.807,finswell,behind Hyatt Hotel,\nViman Nagar, Pune 411014';
    final compEmail = profile.companyEmailOverride ?? companyConfig['company_email']?.toString() ?? 'insiyaindia@gmail.com info@insiyacorp.com';
    final compPhone = profile.companyMobileOverride ?? companyConfig['company_phone']?.toString() ?? '+91 7588874019 & +91 9292922992';
    final compWeb = profile.companyWebOverride ?? companyConfig['company_website']?.toString() ?? 'www.insiyacorp.com';
    final logoUrl = profile.logoUrlOverride ?? companyConfig['logo_url']?.toString();
    final stampPath = profile.stampPathOverride ?? stampImagePath;

    return QgNocPayload(
      companyName: compName,
      companyAddress: compAddr,
      companyEmail: compEmail,
      companyPhone: compPhone,
      companyWebsite: compWeb,
      logoUrl: logoUrl,
      stampImagePath: stampPath,
      salutation: salutation,
      customerName: custName,
      address: address,
      productName: prodName,
      subject: subject,
      date: nocDate,
      quotationNumber: quotation?['quotation_number']?.toString(),
      installationTicketNo: installation?['ticket_number']?.toString(),
      installationDate: DateTime.tryParse(installation?['updated_at']?.toString() ?? installation?['created_at']?.toString() ?? ''),
      equipmentLabel: profile.equipmentLabel.replaceAll('{Product}', prodName),
      equipmentLines: equipmentLines,
      workType: profile.workTypeText.replaceAll('{Product}', prodName),
      wiring: profile.wiringDefault,
      testing: profile.testingDefault,
      remark: profile.remarkDefault,
      confirmations: profile.confirmationLines.map((l) => l.replaceAll('{Product}', prodName)).toList(),
      closingSentence: (profile.closingSentence ?? 'This NOC is issued upon request for installation and operation of the {Product} System.')
          .replaceAll('{Product}', prodName),
      wordingMode: wordingMode,
    );
  }
}
