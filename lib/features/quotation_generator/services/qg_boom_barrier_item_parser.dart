// lib/features/quotation_generator/services/qg_boom_barrier_item_parser.dart

import '../models/boom_barrier_line_item.dart';
import '../models/deal_quotation_item.dart';

class BoomBarrierParseResult {
  final String detectedModelNo; // 'IZ-2001', 'IZ-2026', 'IZ-2004', 'NPRS'
  final List<BoomBarrierLineItem> lineItems;
  final bool hasLpr;
  final List<String> warnings;

  const BoomBarrierParseResult({
    required this.detectedModelNo,
    required this.lineItems,
    this.hasLpr = false,
    this.warnings = const [],
  });
}

/// Intelligent line-item parser for Boom Barrier deals.
class QgBoomBarrierItemParser {
  static const List<String> defaultBarrierInclusions = [
    '1)Manual Push Button',
    '2)Remote control with receiver',
    '3)Arm Length -Telescopic',
    'All above:- Included',
  ];

  /// Parses a deal quotation into a structured Boom Barrier quotation table.
  static BoomBarrierParseResult parse(DealQuotationItem deal) {
    final rawLines = deal.lineItems;
    final warnings = <String>[];

    String detectedModel = 'IZ-2001';
    bool hasLpr = false;

    // Detect model from deal line items or product name
    for (final line in rawLines) {
      final desc = (line['description'] ?? line['item_name'] ?? '').toString();
      final upper = desc.toUpperCase();

      if (upper.contains('IZ-2026') || upper.contains('IZ2026') || upper.contains('2026')) {
        detectedModel = 'IZ-2026';
      } else if (upper.contains('IZ-2004') || upper.contains('IZ2004') || upper.contains('2004')) {
        detectedModel = 'IZ-2004';
      } else if (upper.contains('IZ-2001') || upper.contains('IZ2001') || upper.contains('2001')) {
        detectedModel = 'IZ-2001';
      }

      if (upper.contains('NPRS') || upper.contains('LPR') || upper.contains('NUMBER PLATE') || upper.contains('ANPR')) {
        hasLpr = true;
      }
    }

    final parsedItems = <BoomBarrierLineItem>[];
    int srCounter = 1;

    // Track standard accessories detected in CRM lines
    bool foundBarrier = false;
    bool foundArmRest = false;
    bool foundPhotoCell = false;
    bool foundTransportation = false;
    bool foundInstallation = false;
    bool foundWiring = false;
    bool foundCivil = false;

    for (final raw in rawLines) {
      final desc = (raw['description'] ?? raw['item_name'] ?? '').toString().trim();
      if (desc.isEmpty || desc == ':-' || desc == '-' || desc == ':') continue;

      final qty = (raw['quantity'] ?? raw['qty'] as num?)?.toInt() ?? 1;
      final rate = (raw['unit_price'] ?? raw['rate'] as num?)?.toDouble() ?? 0.0;
      final price = (raw['amount'] ?? raw['total'] ?? raw['total_amount'] as num?)?.toDouble() ?? (qty * rate);

      final upper = desc.toUpperCase();

      if (_isBarrierLine(upper)) {
        foundBarrier = true;
        parsedItems.add(BoomBarrierLineItem(
          srNo: srCounter++,
          description: 'Sefdor Boom Barriers Basic Model- $detectedModel',
          modelNo: detectedModel,
          inclusions: defaultBarrierInclusions,
          qty: qty,
          rate: rate,
          price: price,
        ));
      } else if (upper.contains('ARM REST') || upper.contains('STAND')) {
        foundArmRest = true;
        parsedItems.add(BoomBarrierLineItem(
          srNo: srCounter++,
          description: 'Arm Rest Stand:-',
          qty: qty,
          rate: rate,
          price: price,
        ));
      } else if (upper.contains('PHOTO CELL') || upper.contains('PHOTOCELL') || upper.contains('SAFETY SENSOR')) {
        foundPhotoCell = true;
        parsedItems.add(BoomBarrierLineItem(
          srNo: srCounter++,
          description: 'Photo Cell Pair:-',
          qty: qty,
          rate: rate,
          price: price,
        ));
      } else if (upper.contains('TRANSPORT') || upper.contains('FREIGHT')) {
        foundTransportation = true;
        parsedItems.add(BoomBarrierLineItem(
          srNo: srCounter++,
          description: 'Transportation:-',
          qty: qty,
          rate: rate,
          price: price,
        ));
      } else if (upper.contains('INSTALLATION') || upper.contains('ERECTION') || upper.contains('COMMISSIONING')) {
        foundInstallation = true;
        parsedItems.add(BoomBarrierLineItem(
          srNo: srCounter++,
          description: 'Installation:-',
          qty: qty,
          rate: rate,
          price: price,
        ));
      } else if (upper.contains('WIRING') || upper.contains('CABLE') || upper.contains('CABLING')) {
        foundWiring = true;
        final isExtra = price == 0 || rate == 0;
        parsedItems.add(BoomBarrierLineItem(
          srNo: srCounter++,
          description: 'Wiring:-',
          qty: qty,
          rate: rate,
          price: price,
          isExtra: isExtra,
        ));
      } else if (upper.contains('CIVIL') || upper.contains('FOUNDATION')) {
        foundCivil = true;
        final isExtra = price == 0 || rate == 0;
        parsedItems.add(BoomBarrierLineItem(
          srNo: srCounter++,
          description: 'Civil Works:-',
          qty: qty,
          rate: rate,
          price: price,
          isExtra: isExtra,
        ));
      } else {
        // Generic custom item
        parsedItems.add(BoomBarrierLineItem(
          srNo: srCounter++,
          description: desc,
          qty: qty,
          rate: rate,
          price: price,
          isExtra: price == 0 && rate == 0,
        ));
      }
    }

    // If no barrier was found among lines, add primary barrier line using deal subtotal or default
    if (!foundBarrier) {
      final baseRate = deal.subtotal > 0 ? deal.subtotal : 45000.0;
      parsedItems.insert(
        0,
        BoomBarrierLineItem(
          srNo: 1,
          description: 'Sefdor Boom Barriers Basic Model- $detectedModel',
          modelNo: detectedModel,
          inclusions: defaultBarrierInclusions,
          qty: 1,
          rate: baseRate,
          price: baseRate,
        ),
      );
      // Re-number
      srCounter = 2;
      for (int i = 1; i < parsedItems.length; i++) {
        parsedItems[i] = parsedItems[i].copyWith(srNo: srCounter++);
      }
    }

    // Ensure standard accessory rows exist per the template if only a simple deal was quoted
    if (!foundArmRest && parsedItems.length <= 3) {
      parsedItems.add(BoomBarrierLineItem(
        srNo: srCounter++,
        description: 'Arm Rest Stand:-',
        qty: 1,
        rate: 1500.0,
        price: 1500.0,
      ));
    }
    if (!foundPhotoCell && parsedItems.length <= 4) {
      parsedItems.add(BoomBarrierLineItem(
        srNo: srCounter++,
        description: 'Photo Cell Pair:-',
        qty: 1,
        rate: 1500.0,
        price: 1500.0,
      ));
    }
    if (!foundTransportation && parsedItems.length <= 5) {
      parsedItems.add(BoomBarrierLineItem(
        srNo: srCounter++,
        description: 'Transportation:-',
        qty: 1,
        rate: 5000.0,
        price: 5000.0,
      ));
    }
    if (!foundInstallation && parsedItems.length <= 6) {
      parsedItems.add(BoomBarrierLineItem(
        srNo: srCounter++,
        description: 'Installation:-',
        qty: 1,
        rate: 7000.0,
        price: 7000.0,
      ));
    }
    if (!foundWiring) {
      parsedItems.add(BoomBarrierLineItem(
        srNo: srCounter++,
        description: 'Wiring:-',
        qty: 1,
        rate: 0.0,
        price: 0.0,
        isExtra: true,
      ));
    }
    if (!foundCivil) {
      parsedItems.add(BoomBarrierLineItem(
        srNo: srCounter++,
        description: 'Civil Works:-',
        qty: 1,
        rate: 0.0,
        price: 0.0,
        isExtra: true,
      ));
    }

    return BoomBarrierParseResult(
      detectedModelNo: detectedModel,
      lineItems: parsedItems,
      hasLpr: hasLpr,
      warnings: warnings,
    );
  }

  static bool _isBarrierLine(String upper) {
    if (upper.contains('BOOM BARRIER') || upper.contains('BARRIER')) return true;
    if (upper.contains('SEFDOR')) return true;
    if (upper.contains('IZ-2001') || upper.contains('IZ-2026') || upper.contains('IZ-2004')) return true;
    return false;
  }
}
