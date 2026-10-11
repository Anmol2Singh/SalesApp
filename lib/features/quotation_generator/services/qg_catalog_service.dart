// lib/features/quotation_generator/services/qg_catalog_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/catalog_repository.dart';

class QgSpecMatchResult {
  final String modelNo;
  final int kw;
  final Map<String, String> specs;
  final String? specsCopiedFrom;
  final bool isFallback;

  const QgSpecMatchResult({
    required this.modelNo,
    required this.kw,
    required this.specs,
    this.specsCopiedFrom,
    this.isFallback = false,
  });
}

class QgCategoryInfo {
  final String id;
  final String label;
  final String defaultProductImage;

  const QgCategoryInfo({
    required this.id,
    required this.label,
    required this.defaultProductImage,
  });
}

/// Service handling category determination, whole-number specification matching,
/// and tank specification presets.
class QgCatalogService {
  final SupabaseClient? _supabase;

  QgCatalogService([this._supabase]);

  /// Resolves the category based on the highest Heat Pump kW or system type.
  static QgCategoryInfo resolveCategory({
    required int? hpKw,
    bool isAllInOne = false,
    bool isWallMounted = false,
    bool isPool = false,
  }) {
    if (isWallMounted) {
      return const QgCategoryInfo(
        id: 'wall_mounted',
        label: 'All in One Wall Mounted',
        defaultProductImage: 'assets/images/all_in_one_wall.png',
      );
    }
    if (isAllInOne) {
      return const QgCategoryInfo(
        id: 'all_in_one',
        label: 'All in One Floor Mounted',
        defaultProductImage: 'assets/images/all_in_one_floor.png',
      );
    }
    if (isPool) {
      return const QgCategoryInfo(
        id: 'pool',
        label: 'Swimming Pool Heat Pump',
        defaultProductImage: 'assets/images/pool_hp.png',
      );
    }

    final kw = hpKw ?? 8;
    if (kw >= 4 && kw <= 8) {
      return const QgCategoryInfo(
        id: 'hp_4_8',
        label: 'Domestic Heat Pump 4 - 8 kW',
        defaultProductImage: 'assets/images/hp_4_8.png',
      );
    } else if (kw >= 9 && kw <= 24) {
      return const QgCategoryInfo(
        id: 'hp_9_24',
        label: 'Commercial Heat Pump 9 - 24 kW',
        defaultProductImage: 'assets/images/hp_9_24.png',
      );
    } else if (kw >= 38 && kw <= 100) {
      return const QgCategoryInfo(
        id: 'hp_38_100',
        label: 'Industrial Heat Pump 38 - 100 kW',
        defaultProductImage: 'assets/images/hp_38_100.png',
      );
    }

    return const QgCategoryInfo(
      id: 'other',
      label: 'Other Heat Pump Systems',
      defaultProductImage: 'assets/images/hp_other.png',
    );
  }

  /// Finds matching specifications for a whole-number kW from qg_catalog or local fallback.
  Future<QgSpecMatchResult> matchSpecifications(int targetKw) async {
    final derivedModel = 'IZ-${targetKw}C';

    // 1. Try querying qg_catalog table from Supabase if connected
    if (_supabase != null) {
      try {
        final rows = await _supabase!
            .from('qg_catalog')
            .select('*')
            .eq('kind', 'domestic');

        if (rows.isNotEmpty) {
          final catalogList = List<Map<String, dynamic>>.from(rows);

          // Rule A: match exact integer kw where data_flags does not have non_integer_kw
          final exactMatches = catalogList.where((r) {
            final kwVal = (r['kw'] as num?)?.toDouble();
            final flags = List<String>.from(r['data_flags'] as List? ?? []);
            return kwVal != null &&
                kwVal.toInt() == targetKw &&
                !flags.contains('non_integer_kw');
          }).toList();

          if (exactMatches.isNotEmpty) {
            final match = exactMatches.first;
            final specs = Map<String, dynamic>.from(match['specs'] as Map? ?? {});
            return QgSpecMatchResult(
              modelNo: derivedModel,
              kw: targetKw,
              specs: _normalize13Specs(targetKw, derivedModel, specs),
            );
          }

          // Fallback (1): match by model_no == derivedModel
          final modelMatches = catalogList.where((r) {
            return (r['model_no'] as String? ?? '').toLowerCase() == derivedModel.toLowerCase();
          }).toList();

          if (modelMatches.isNotEmpty) {
            final match = modelMatches.first;
            final specs = Map<String, dynamic>.from(match['specs'] as Map? ?? {});
            final sourceModel = match['model_no'] as String? ?? derivedModel;
            final sourceKw = (match['kw'] as num?)?.toString() ?? '${targetKw}';
            return QgSpecMatchResult(
              modelNo: derivedModel,
              kw: targetKw,
              specs: _normalize13Specs(targetKw, derivedModel, specs),
              specsCopiedFrom: 'Specs copied from $sourceModel (${sourceKw}kW)',
              isFallback: true,
            );
          }

          // Fallback (2): nearest whole-number-kW row
          Map<String, dynamic>? nearest;
          num minDiff = 999999;
          for (final r in catalogList) {
            final kwVal = (r['kw'] as num?)?.toDouble();
            if (kwVal != null) {
              final diff = (kwVal - targetKw).abs();
              if (diff < minDiff) {
                minDiff = diff;
                nearest = r;
              }
            }
          }

          if (nearest != null) {
            final specs = Map<String, dynamic>.from(nearest['specs'] as Map? ?? {});
            final sourceModel = nearest['model_no'] as String? ?? 'Catalog';
            final sourceKw = (nearest['kw'] as num?)?.toString() ?? '';
            return QgSpecMatchResult(
              modelNo: derivedModel,
              kw: targetKw,
              specs: _normalize13Specs(targetKw, derivedModel, specs),
              specsCopiedFrom: 'Specs copied from $sourceModel (${sourceKw}kW)',
              isFallback: true,
            );
          }
        }
      } catch (e) {
        debugPrint('QgCatalogService: Supabase qg_catalog lookup failed, falling back to local: $e');
      }
    }

    // 2. Local bundled models fallback
    final bundled = await CatalogRepository.loadBundledModels();
    final bundledMatch = bundled.firstWhere(
      (m) => m.displayCapacityKw.toInt() == targetKw,
      orElse: () => bundled.first,
    );

    final isFallback = bundledMatch.displayCapacityKw.toInt() != targetKw;
    final fallbackNote = isFallback
        ? 'Specs copied from ${bundledMatch.modelName} (${bundledMatch.displayCapacityKw.toInt()}kW)'
        : null;

    return QgSpecMatchResult(
      modelNo: derivedModel,
      kw: targetKw,
      specs: _normalize13Specs(targetKw, derivedModel, bundledMatch.specs),
      specsCopiedFrom: fallbackNote,
      isFallback: isFallback,
    );
  }

  /// Normalizes specs map into the standard 13-row Annexure II Technical Specification format
  static Map<String, String> _normalize13Specs(
    int kw,
    String derivedModel,
    Map<String, dynamic> raw,
  ) {
    final powerSupply = kw <= 8 ? '220V - 1Phase' : '415V - 3Phase';
    final compressor = kw <= 24 ? 'Single' : 'Double';

    // Blank condenser fix
    String condenser = raw['Condenser']?.toString().trim() ?? '';
    if (condenser.isEmpty || condenser == '-') {
      condenser = 'Shell and tube heat exchanger';
    }

    return {
      'Heat Pump Model': derivedModel,
      'Size (W x D x H) mm': raw['Size (W x D x H)']?.toString() ?? '1410x748x1000mm',
      'Rated Heating Capacity': '${kw}kw',
      'Power Supply': raw['Power Supply']?.toString() ?? powerSupply,
      'Rated Input Power': raw['Rated Input Power']?.toString() ?? '${(kw * 0.23).toStringAsFixed(2)}kw',
      'Rated COP': raw['Rated COP']?.toString() ?? '4.29',
      'Rated Water Yield': raw['Rated Water Yield']?.toString() ?? '${(kw * 21.5).round()} L/h',
      'Max Outlet Water Temperature': raw['Max Outlet water Temperature']?.toString() ?? '60°C',
      'Water Flow Noise': raw['Water Flow Noise']?.toString() ?? '<=57dB(A)',
      'Condenser': condenser,
      'Refrigerant': raw['Refrigerant']?.toString() ?? 'R134A/410A',
      'Operating ambient Temp': raw['Operating ambient Temp']?.toString() ?? '-15~43°C',
      'Compressor': raw['Compressor']?.toString() ?? compressor,
    };
  }

  /// Tank Presets
  static Map<String, dynamic> getTankPreset(String material) {
    switch (material.toUpperCase()) {
      case 'ENAMEL':
        return {
          'material': 'Enamel',
          'label': 'Enamel Coated Tank',
          'shellThickness': '2mm',
          'dishThickness': '2mm',
          'operatingPressure': '6 bar',
          'testingPressure': '9 bar',
          'warrantyYears': 15,
          'isUnconfirmed': false,
        };
      case 'MS':
        return {
          'material': 'MS',
          'label': 'MS Pressurized Tank',
          'shellThickness': '5mm',
          'dishThickness': '6mm',
          'operatingPressure': '6 bar',
          'testingPressure': '9 bar',
          'warrantyYears': 5,
          'isUnconfirmed': false,
        };
      case 'SS':
        return {
          'material': 'SS',
          'label': 'SS 304 Tank',
          'shellThickness': '3mm',
          'dishThickness': '3mm',
          'operatingPressure': '6 bar',
          'testingPressure': '9 bar',
          'warrantyYears': 5,
          'isUnconfirmed': true,
        };
      case 'GI':
      default:
        return {
          'material': 'GI',
          'label': 'GI Pressurized Tank',
          'shellThickness': '3mm',
          'dishThickness': '3mm',
          'operatingPressure': '6 bar',
          'testingPressure': '9 bar',
          'warrantyYears': 5,
          'isUnconfirmed': false,
        };
    }
  }

  /// Insulation text resolution
  static String getInsulationText(String type, {String customText = ''}) {
    switch (type.toLowerCase()) {
      case 'puff':
        return '50 mm with Puff Insulation';
      case 'rockwool':
        return '100 mm Rockwool Insulation 24 Gauge Aluminium Cladding & other Provisions for stand';
      case 'custom':
        return customText.isNotEmpty ? customText : '50 mm with Puff Insulation';
      default:
        return '50 mm with Puff Insulation';
    }
  }
}
