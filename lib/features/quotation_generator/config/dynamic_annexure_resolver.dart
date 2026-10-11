// lib/features/quotation_generator/config/dynamic_annexure_resolver.dart

import 'quote_type.dart';

enum DocSection {
  coverPage,
  offerLetter,
  priceSchedule,
  specHeatPump,
  specTank,
  specPool,
  specAllInOne,
  termsAndConditions,
  acceptanceLetter,
  productShowcase,
}

class AnnexureEntry {
  final String romanNumeral; // 'Annexure I', 'Annexure II', 'Annexure III'
  final String title;
  final String pageLabel;
  final DocSection section;

  const AnnexureEntry({
    required this.romanNumeral,
    required this.title,
    required this.pageLabel,
    required this.section,
  });
}

class DynamicAnnexureResolver {
  final QuoteType quoteType;
  final bool hasSpecs;
  final String? customSpecTitle;

  const DynamicAnnexureResolver({
    required this.quoteType,
    required this.hasSpecs,
    this.customSpecTitle,
  });

  /// Resolves the list of Annexures shown in the Offer Letter table and headings
  List<AnnexureEntry> resolveEntries() {
    final list = <AnnexureEntry>[];

    // 1. Price Schedule is ALWAYS Annexure I
    list.add(
      const AnnexureEntry(
        romanNumeral: 'Annexure I',
        title: 'Price Schedule & System Details',
        pageLabel: 'Page 3',
        section: DocSection.priceSchedule,
      ),
    );

    // 2. Technical Specs (if present) is Annexure II
    if (hasSpecs) {
      String specTitle = 'Technical Specifications';
      switch (quoteType) {
        case QuoteType.hpWithTank:
          specTitle = 'Technical Specifications (Heat Pump & Tank)';
          break;
        case QuoteType.hpOnly:
          specTitle = 'Technical Specifications (Heat Pump)';
          break;
        case QuoteType.tankOnly:
          specTitle = 'Technical Specifications (Storage Tank)';
          break;
        case QuoteType.swimmingPool:
          specTitle = 'Technical Specifications (Swimming Pool Heat Pump)';
          break;
        case QuoteType.allInOneFloor:
        case QuoteType.allInOneWall:
          specTitle = 'Technical Specifications (All In One Heat Pump)';
          break;
        case QuoteType.partsOnly:
          specTitle = 'Technical Specifications';
          break;
      }
      if (customSpecTitle != null && customSpecTitle!.isNotEmpty) {
        specTitle = customSpecTitle!;
      }

      list.add(
        AnnexureEntry(
          romanNumeral: 'Annexure II',
          title: specTitle,
          pageLabel: 'Page 4',
          section: DocSection.specHeatPump,
        ),
      );
    }

    // 3. Terms & Conditions: Annexure III if specs exist, else Annexure II
    final termsNumeral = hasSpecs ? 'Annexure III' : 'Annexure II';
    final termsPage = hasSpecs ? 'Page 5' : 'Page 4';
    list.add(
      AnnexureEntry(
        romanNumeral: termsNumeral,
        title: 'Commercial Terms and Conditions & Warranty',
        pageLabel: termsPage,
        section: DocSection.termsAndConditions,
      ),
    );

    return list;
  }

  /// Returns the dynamic heading for Terms & Conditions (e.g. 'ANNEXURE III' or 'ANNEXURE II')
  String get termsHeading => hasSpecs
      ? 'Annexure III: Commercial Terms and Conditions & Warranty'
      : 'Annexure II: Commercial Terms and Conditions & Warranty';

  /// Returns the dynamic heading for Technical Specifications
  String get specsHeading {
    switch (quoteType) {
      case QuoteType.hpWithTank:
        return 'Annexure II: Technical Specifications (Heat Pump & Tank)';
      case QuoteType.hpOnly:
        return 'Annexure II: Technical Specifications (Heat Pump)';
      case QuoteType.tankOnly:
        return 'Annexure II: Technical Specifications (Storage Tank)';
      case QuoteType.swimmingPool:
        return 'Annexure II: Technical Specifications (Swimming Pool Heat Pump)';
      case QuoteType.allInOneFloor:
      case QuoteType.allInOneWall:
        return 'Annexure II: Technical Specifications (All In One System)';
      case QuoteType.partsOnly:
        return 'Annexure II: Technical Specifications';
    }
  }
}
