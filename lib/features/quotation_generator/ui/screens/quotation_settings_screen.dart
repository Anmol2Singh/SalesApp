// lib/features/quotation_generator/ui/screens/quotation_settings_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../config/qg_noc_flags.dart';
import '../../models/all_in_one_model.dart';
import '../../models/generator_company_settings.dart';
import '../../models/heat_pump_model.dart';
import '../../models/pool_heat_pump_model.dart';
import '../../providers/quotation_generator_providers.dart';
import '../../services/quotation_storage_service.dart';
import '../../../admin/screens/noc_certificate_settings_screen.dart';

enum HpTypeCategory {
  domestic('domestic', 'Domestic (in kW)', 'IZ-#C', 'Heat Pump - 4KW'),
  allInOne('allInOne', 'All in One (in Ltr)', 'All in One #Ltr or #D', 'All in one 200Ltr'),
  allInOneWall('allInOneWall', 'All in One Wall Mounted', 'All in One WM #Ltr (80-100L)', 'All in one Wall Mounted 100Ltr'),
  swimmingPool('swimmingPool', 'Swimming Pool', 'Swimming Pool #KW', 'Swimming Pool Heat Pump - 35KW');

  final String key;
  final String label;
  final String pattern;
  final String example;
  const HpTypeCategory(this.key, this.label, this.pattern, this.example);
}

class SpecRowController {
  final TextEditingController keyController;
  final TextEditingController valController;

  SpecRowController({String key = '', String value = ''})
      : keyController = TextEditingController(text: key),
        valController = TextEditingController(text: value);

  void dispose() {
    keyController.dispose();
    valController.dispose();
  }
}

class QuotationSettingsScreen extends ConsumerStatefulWidget {
  const QuotationSettingsScreen({super.key});

  @override
  ConsumerState<QuotationSettingsScreen> createState() => _QuotationSettingsScreenState();
}

class _QuotationSettingsScreenState extends ConsumerState<QuotationSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Defaults & numbering controllers
  final _quotePrefixCtrl = TextEditingController();
  final _nextRunningNumCtrl = TextEditingController();
  final _gstPercentCtrl = TextEditingController();
  final _hpWarrantyCtrl = TextEditingController();
  final _tankWarrantyCtrl = TextEditingController();
  final _validityDaysCtrl = TextEditingController();

  // Selected Category
  HpTypeCategory _currentCategory = HpTypeCategory.domestic;

  // Domestic Model state
  HeatPumpModel? _selectedDomesticModel;
  final _domesticModelNameCtrl = TextEditingController();
  final _domesticKwCtrl = TextEditingController();
  final _domesticRatedHeatingCtrl = TextEditingController();
  final _domesticDescLineCtrl = TextEditingController();
  final _domesticMakeModelCtrl = TextEditingController();
  final _domesticPowerInputCtrl = TextEditingController();
  final List<SpecRowController> _domesticSpecs = [];

  // All In One (Floor) state
  AllInOneModel? _selectedAioModel;
  final _aioModelNameCtrl = TextEditingController();
  final _aioVolumeCtrl = TextEditingController();
  final _aioDescCtrl = TextEditingController();
  final List<SpecRowController> _aioSpecs = [];

  // All In One Wall Mounted state
  AllInOneModel? _selectedWallModel;
  final _wallModelNameCtrl = TextEditingController();
  final _wallVolumeCtrl = TextEditingController();
  final _wallDescCtrl = TextEditingController();
  final List<SpecRowController> _wallSpecs = [];

  // Swimming Pool state
  PoolHeatPumpModel? _selectedPoolModel;
  final _poolModelNameCtrl = TextEditingController();
  final _poolKwCtrl = TextEditingController();
  final _poolDescCtrl = TextEditingController();
  final List<SpecRowController> _poolSpecs = [];

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kQgNocEnabled ? 4 : 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quotePrefixCtrl.dispose();
    _nextRunningNumCtrl.dispose();
    _gstPercentCtrl.dispose();
    _hpWarrantyCtrl.dispose();
    _tankWarrantyCtrl.dispose();
    _validityDaysCtrl.dispose();

    _domesticModelNameCtrl.dispose();
    _domesticKwCtrl.dispose();
    _domesticRatedHeatingCtrl.dispose();
    _domesticDescLineCtrl.dispose();
    _domesticMakeModelCtrl.dispose();
    _domesticPowerInputCtrl.dispose();
    for (final c in _domesticSpecs) {
      c.dispose();
    }

    _aioModelNameCtrl.dispose();
    _aioVolumeCtrl.dispose();
    _aioDescCtrl.dispose();
    for (final c in _aioSpecs) {
      c.dispose();
    }

    _wallModelNameCtrl.dispose();
    _wallVolumeCtrl.dispose();
    _wallDescCtrl.dispose();
    for (final c in _wallSpecs) {
      c.dispose();
    }

    _poolModelNameCtrl.dispose();
    _poolKwCtrl.dispose();
    _poolDescCtrl.dispose();
    for (final c in _poolSpecs) {
      c.dispose();
    }

    super.dispose();
  }

  void _populateFromSettings(GeneratorCompanySettings s) {
    if (_initialized) return;
    _initialized = true;

    _quotePrefixCtrl.text = s.quotePrefix;
    _nextRunningNumCtrl.text = s.nextRunningNumber.toString();
    _gstPercentCtrl.text = s.defaultGstPercent.toString();
    _hpWarrantyCtrl.text = s.defaultWarrantyHpYears.toString();
    _tankWarrantyCtrl.text = s.defaultWarrantyTankYears.toString();
    _validityDaysCtrl.text = s.defaultValidityDays.toString();

    // Domestic
    if (s.models.isNotEmpty) {
      _selectDomesticModel(s.models.first);
    }

    // All In One Floor
    final aioFloorList = s.allInOneModels.where((m) => !m.isWallMounted).toList();
    if (aioFloorList.isNotEmpty) {
      _selectAioModel(aioFloorList.first);
    } else {
      _selectAioModel(AllInOneModel.defaultFloor());
    }

    // All In One Wall
    final aioWallList = s.allInOneModels.where((m) => m.isWallMounted).toList();
    if (aioWallList.isNotEmpty) {
      _selectWallModel(aioWallList.first);
    } else {
      _selectWallModel(AllInOneModel.defaultWall());
    }

    // Swimming Pool
    if (s.poolModels.isNotEmpty) {
      _selectPoolModel(s.poolModels.first);
    } else {
      _selectPoolModel(PoolHeatPumpModel.defaultModel());
    }
  }

  void _selectDomesticModel(HeatPumpModel m) {
    setState(() {
      _selectedDomesticModel = m;
      _domesticModelNameCtrl.text = m.modelName;
      _domesticKwCtrl.text = m.displayCapacityKw.toString();
      _domesticRatedHeatingCtrl.text = m.ratedHeatingCapacity;
      _domesticDescLineCtrl.text = m.descriptionLine;
      _domesticMakeModelCtrl.text = m.makeModelLine;
      _domesticPowerInputCtrl.text = m.powerInputText;

      for (final c in _domesticSpecs) {
        c.dispose();
      }
      _domesticSpecs.clear();
      m.specs.forEach((k, v) {
        _domesticSpecs.add(SpecRowController(key: k, value: v));
      });
    });
  }

  void _selectAioModel(AllInOneModel m) {
    setState(() {
      _selectedAioModel = m;
      _aioModelNameCtrl.text = m.modelName;
      _aioVolumeCtrl.text = m.tankVolumeLitres.toString();
      _aioDescCtrl.text = m.description;

      for (final c in _aioSpecs) {
        c.dispose();
      }
      _aioSpecs.clear();
      m.specs.forEach((k, v) {
        _aioSpecs.add(SpecRowController(key: k, value: v));
      });
    });
  }

  void _selectWallModel(AllInOneModel m) {
    setState(() {
      _selectedWallModel = m;
      _wallModelNameCtrl.text = m.modelName;
      _wallVolumeCtrl.text = m.tankVolumeLitres.toString();
      _wallDescCtrl.text = m.description;

      for (final c in _wallSpecs) {
        c.dispose();
      }
      _wallSpecs.clear();
      m.specs.forEach((k, v) {
        _wallSpecs.add(SpecRowController(key: k, value: v));
      });
    });
  }

  void _selectPoolModel(PoolHeatPumpModel m) {
    setState(() {
      _selectedPoolModel = m;
      _poolModelNameCtrl.text = m.modelName;
      _poolKwCtrl.text = m.capacityKw.toString();
      _poolDescCtrl.text = m.description;

      for (final c in _poolSpecs) {
        c.dispose();
      }
      _poolSpecs.clear();
      m.specs.forEach((k, v) {
        _poolSpecs.add(SpecRowController(key: k, value: v));
      });
    });
  }

  Future<void> _pickImage(
    ImageSource source,
    Function(String path) onPicked, {
    String bucket = 'company-assets',
    String folder = 'branding',
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
    if (picked != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Uploading to Supabase Storage...'),
              ],
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      try {
        final supabase = ref.read(supabaseClientProvider);
        final bytes = await picked.readAsBytes();

        final publicUrl = await QuotationStorageService.uploadImageBytes(
          supabase: supabase,
          bytes: bytes,
          fileName: picked.name,
          bucket: bucket,
          folder: folder,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        if (publicUrl != null) {
          onPicked(publicUrl);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✓ Image saved to Supabase Storage!'), backgroundColor: AppColors.success),
            );
          }
        } else {
          onPicked(picked.path);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
      }
    }
  }

  Future<void> _saveDefaultsSettings() async {
    final sAsync = ref.read(quotationSettingsProvider);
    final current = sAsync.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(
      defaultWarrantyHpYears: int.tryParse(_hpWarrantyCtrl.text.trim()) ?? current.defaultWarrantyHpYears,
      defaultWarrantyTankYears: int.tryParse(_tankWarrantyCtrl.text.trim()) ?? current.defaultWarrantyTankYears,
      defaultValidityDays: int.tryParse(_validityDaysCtrl.text.trim()) ?? current.defaultValidityDays,
    );

    await ref.read(quotationSettingsProvider.notifier).updateSettings(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Quotation Defaults saved!'), backgroundColor: AppColors.success),
      );
    }
  }

  // ─── SAVE SPECIFICATIONS PER CATEGORY ──────────────────────────────────────

  Future<void> _saveDomesticModel() async {
    if (_selectedDomesticModel == null) return;
    final specsMap = <String, String>{};
    for (final s in _domesticSpecs) {
      final k = s.keyController.text.trim();
      final v = s.valController.text.trim();
      if (k.isNotEmpty) {
        specsMap[k] = v;
      }
    }

    final updated = _selectedDomesticModel!.copyWith(
      modelName: _domesticModelNameCtrl.text.trim(),
      displayCapacityKw: double.tryParse(_domesticKwCtrl.text.trim()) ?? _selectedDomesticModel!.displayCapacityKw,
      ratedHeatingCapacity: _domesticRatedHeatingCtrl.text.trim(),
      descriptionLine: _domesticDescLineCtrl.text.trim(),
      makeModelLine: _domesticMakeModelCtrl.text.trim(),
      powerInputText: _domesticPowerInputCtrl.text.trim(),
      specs: specsMap,
    );

    await ref.read(quotationSettingsProvider.notifier).saveModel(updated);
    _selectDomesticModel(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ Domestic Model ${updated.modelName} saved to Supabase!'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _saveAioModel() async {
    if (_selectedAioModel == null) return;
    final specsMap = <String, String>{};
    for (final s in _aioSpecs) {
      final k = s.keyController.text.trim();
      final v = s.valController.text.trim();
      if (k.isNotEmpty) {
        specsMap[k] = v;
      }
    }

    final vol = int.tryParse(_aioVolumeCtrl.text.trim()) ?? _selectedAioModel!.tankVolumeLitres;
    if (specsMap.containsKey('Tank Volume')) {
      specsMap['Tank Volume'] = '$vol Ltr';
    }

    final updated = AllInOneModel(
      id: _selectedAioModel!.id,
      modelName: _aioModelNameCtrl.text.trim(),
      mountType: 'floor',
      tankVolumeLitres: vol,
      description: _aioDescCtrl.text.trim(),
      defaultImagePath: _selectedAioModel!.defaultImagePath,
      specs: specsMap,
    );

    await ref.read(quotationSettingsProvider.notifier).saveAllInOneModel(updated);
    _selectAioModel(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ All in One Model ${updated.modelName} saved to Supabase!'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _saveWallModel() async {
    if (_selectedWallModel == null) return;
    final specsMap = <String, String>{};
    for (final s in _wallSpecs) {
      final k = s.keyController.text.trim();
      final v = s.valController.text.trim();
      if (k.isNotEmpty) {
        specsMap[k] = v;
      }
    }

    final vol = int.tryParse(_wallVolumeCtrl.text.trim()) ?? _selectedWallModel!.tankVolumeLitres;
    if (specsMap.containsKey('Tank Volume')) {
      specsMap['Tank Volume'] = '$vol Ltr';
    }

    final updated = AllInOneModel(
      id: _selectedWallModel!.id,
      modelName: _wallModelNameCtrl.text.trim(),
      mountType: 'wall',
      tankVolumeLitres: vol,
      description: _wallDescCtrl.text.trim(),
      defaultImagePath: _selectedWallModel!.defaultImagePath,
      specs: specsMap,
    );

    await ref.read(quotationSettingsProvider.notifier).saveAllInOneModel(updated);
    _selectWallModel(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ Wall Mounted Model ${updated.modelName} saved to Supabase!'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _savePoolModel() async {
    if (_selectedPoolModel == null) return;
    final specsMap = <String, String>{};
    for (final s in _poolSpecs) {
      final k = s.keyController.text.trim();
      final v = s.valController.text.trim();
      if (k.isNotEmpty) {
        specsMap[k] = v;
      }
    }

    final kw = double.tryParse(_poolKwCtrl.text.trim()) ?? _selectedPoolModel!.capacityKw;
    if (specsMap.containsKey('Capacity in kW')) {
      specsMap['Capacity in kW'] = '${kw.round()}KW';
    }

    final updated = PoolHeatPumpModel(
      id: _selectedPoolModel!.id,
      modelName: _poolModelNameCtrl.text.trim(),
      capacityKw: kw,
      description: _poolDescCtrl.text.trim(),
      defaultImagePath: _selectedPoolModel!.defaultImagePath,
      specs: specsMap,
    );

    await ref.read(quotationSettingsProvider.notifier).savePoolModel(updated);
    _selectPoolModel(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ Swimming Pool Model ${updated.modelName} saved to Supabase!'), backgroundColor: AppColors.success),
      );
    }
  }

  // ─── ADD MODEL FOLLOWING STRICT TEMPLATES ONLY ─────────────────────────────

  Future<void> _showAddTemplateModelDialog(GeneratorCompanySettings settings) async {
    final formKey = GlobalKey<FormState>();

    // For Domestic
    final domesticKwCtrl = TextEditingController(text: '4.0');
    // For All in One Floor
    final aioLtrCtrl = TextEditingController(text: '200');
    String aioNamingStyle = 'All in One #Ltr'; // or '#D'
    // For Wall Mounted
    final wallLtrCtrl = TextEditingController(text: '100');
    // For Swimming Pool
    final poolKwCtrl = TextEditingController(text: '35');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String dialogTitle;
          String templateExplanation;

          switch (_currentCategory) {
            case HpTypeCategory.domestic:
              dialogTitle = 'Add Domestic Heat Pump Model';
              templateExplanation = 'Model Name follows standard template: "IZ-#C" (e.g. IZ-4C, IZ-8C).';
              break;
            case HpTypeCategory.allInOne:
              dialogTitle = 'Add All in One Model';
              templateExplanation = 'Model Name follows standard template: "All in One #Ltr" or "#D" (e.g. All in One 200Ltr, 200D).';
              break;
            case HpTypeCategory.allInOneWall:
              dialogTitle = 'Add Wall Mounted All in One';
              templateExplanation = 'Model Name follows template: "All in One WM #Ltr" (Standard range: 80 to 100 Ltr).';
              break;
            case HpTypeCategory.swimmingPool:
              dialogTitle = 'Add Swimming Pool Model';
              templateExplanation = 'Model Name follows standard template: "Swimming Pool #KW" (e.g. Swimming Pool 35KW).';
              break;
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.add_circle_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(dialogTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        templateExplanation,
                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_currentCategory == HpTypeCategory.domestic) ...[
                      TextFormField(
                        controller: domesticKwCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Capacity (in kW) *',
                          hintText: 'e.g. 4, 6, 8, 12, 19, 38',
                          suffixText: 'kW',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter kW capacity';
                          final num = double.tryParse(val.trim());
                          if (num == null || num <= 0) return 'Enter a valid positive number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Generated Model:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              'IZ-${(double.tryParse(domesticKwCtrl.text.trim()) ?? 4).round()}C',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_currentCategory == HpTypeCategory.allInOne) ...[
                      TextFormField(
                        controller: aioLtrCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tank Volume (in Ltr) *',
                          hintText: 'e.g. 200, 250, 300, 500',
                          suffixText: 'Ltr',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter tank volume';
                          final n = int.tryParse(val.trim());
                          if (n == null || n <= 0) return 'Enter a valid volume in litres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text('Model Naming Style:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All in One #Ltr', style: TextStyle(fontSize: 12)),
                            selected: aioNamingStyle == 'All in One #Ltr',
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: aioNamingStyle == 'All in One #Ltr' ? Colors.white : AppColors.textPrimary,
                              fontWeight: aioNamingStyle == 'All in One #Ltr' ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (sel) {
                              if (sel) setDialogState(() => aioNamingStyle = 'All in One #Ltr');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('#D', style: TextStyle(fontSize: 12)),
                            selected: aioNamingStyle == '#D',
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: aioNamingStyle == '#D' ? Colors.white : AppColors.textPrimary,
                              fontWeight: aioNamingStyle == '#D' ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (sel) {
                              if (sel) setDialogState(() => aioNamingStyle = '#D');
                            },
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Generated Model:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              aioNamingStyle == '#D'
                                  ? '${(int.tryParse(aioLtrCtrl.text.trim()) ?? 200)}D'
                                  : 'All in One ${(int.tryParse(aioLtrCtrl.text.trim()) ?? 200)}Ltr',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_currentCategory == HpTypeCategory.allInOneWall) ...[
                      TextFormField(
                        controller: wallLtrCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tank Volume (80 to 100 Ltr) *',
                          hintText: 'e.g. 80 or 100',
                          suffixText: 'Ltr',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter tank volume';
                          final n = int.tryParse(val.trim());
                          if (n == null || n < 50 || n > 150) return 'Standard range is 80 to 100 Ltr';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Generated Model:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              'All in One WM ${(int.tryParse(wallLtrCtrl.text.trim()) ?? 100)}Ltr',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_currentCategory == HpTypeCategory.swimmingPool) ...[
                      TextFormField(
                        controller: poolKwCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Pool Heat Pump Capacity (kW) *',
                          hintText: 'e.g. 25, 35, 60',
                          suffixText: 'KW',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter pool heat pump kW';
                          final n = double.tryParse(val.trim());
                          if (n == null || n <= 0) return 'Enter a valid kW number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Generated Model:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              'Swimming Pool ${(double.tryParse(poolKwCtrl.text.trim()) ?? 35).round()}KW',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  if (_currentCategory == HpTypeCategory.domestic) {
                    final kwVal = double.tryParse(domesticKwCtrl.text.trim()) ?? 4.0;
                    final kwRound = kwVal.round();
                    final modelName = 'IZ-${kwRound}C';

                    final base = _selectedDomesticModel ?? (settings.models.isNotEmpty ? settings.models.first : null);
                    final clonedSpecs = base != null ? Map<String, String>.from(base.specs) : <String, String>{};
                    clonedSpecs['Rated Heating Capacity'] = '${(kwVal * 0.9).toStringAsFixed(1)}kw';
                    clonedSpecs['Rated Input Power'] = '${(kwVal * 0.23).toStringAsFixed(2)}kw';
                    clonedSpecs['Rated Water Yield'] = '${(kwVal * 21.5).round()} L/h';

                    final newModel = HeatPumpModel(
                      id: 'CUSTOM-${DateTime.now().millisecondsSinceEpoch}',
                      modelName: modelName,
                      displayCapacityKw: kwVal,
                      ratedHeatingCapacity: '${(kwVal * 0.9).toStringAsFixed(1)}kw',
                      descriptionLine: 'Air Source Heat pump ${(kwVal * 0.9).toStringAsFixed(1)}kw',
                      makeModelLine: 'Make: IZYHEAT Heat Pump Model: $modelName ${(kwVal * 0.9).toStringAsFixed(1)}kw',
                      powerInputText: 'Power Input ${(kwVal * 0.23).toStringAsFixed(2)}kw, output ${(kwVal * 0.9).toStringAsFixed(1)}kw, 220V - 1Phase, 50Hz With Auto Defrost.',
                      defaultImagePath: base?.defaultImagePath ?? 'assets/images/product_iz_38c.png',
                      specs: clonedSpecs,
                    );

                    await ref.read(quotationSettingsProvider.notifier).saveModel(newModel);
                    _selectDomesticModel(newModel);
                  } else if (_currentCategory == HpTypeCategory.allInOne) {
                    final vol = int.tryParse(aioLtrCtrl.text.trim()) ?? 200;
                    final modelName = aioNamingStyle == '#D' ? '${vol}D' : 'All in One ${vol}Ltr';
                    final base = _selectedAioModel ?? AllInOneModel.defaultFloor();

                    final clonedSpecs = Map<String, String>.from(base.specs);
                    clonedSpecs['Tank Volume'] = '$vol Ltr';

                    final newModel = AllInOneModel(
                      id: 'AIO-${DateTime.now().millisecondsSinceEpoch}',
                      modelName: modelName,
                      mountType: 'floor',
                      tankVolumeLitres: vol,
                      description: 'ALL IN ONE HEAT PUMP ($vol Ltr) Make: IZYHEAT Heat Pump Model: $modelName',
                      specs: clonedSpecs,
                    );

                    await ref.read(quotationSettingsProvider.notifier).saveAllInOneModel(newModel);
                    _selectAioModel(newModel);
                  } else if (_currentCategory == HpTypeCategory.allInOneWall) {
                    final vol = int.tryParse(wallLtrCtrl.text.trim()) ?? 100;
                    final modelName = 'All in One WM ${vol}Ltr';
                    final base = _selectedWallModel ?? AllInOneModel.defaultWall();

                    final clonedSpecs = Map<String, String>.from(base.specs);
                    clonedSpecs['Tank Volume'] = '$vol Ltr';

                    final newModel = AllInOneModel(
                      id: 'WM-${DateTime.now().millisecondsSinceEpoch}',
                      modelName: modelName,
                      mountType: 'wall',
                      tankVolumeLitres: vol,
                      description: 'ALL IN ONE WALL MOUNTED HEAT PUMP ($vol Ltr) Make: IZYHEAT Heat Pump Model: $modelName',
                      specs: clonedSpecs,
                    );

                    await ref.read(quotationSettingsProvider.notifier).saveAllInOneModel(newModel);
                    _selectWallModel(newModel);
                  } else if (_currentCategory == HpTypeCategory.swimmingPool) {
                    final kw = double.tryParse(poolKwCtrl.text.trim()) ?? 35.0;
                    final modelName = 'Swimming Pool ${kw.round()}KW';
                    final base = _selectedPoolModel ?? PoolHeatPumpModel.defaultModel();

                    final clonedSpecs = Map<String, String>.from(base.specs);
                    clonedSpecs['Capacity in kW'] = '${kw.round()}KW';

                    final newModel = PoolHeatPumpModel(
                      id: 'POOL-${DateTime.now().millisecondsSinceEpoch}',
                      modelName: modelName,
                      capacityKw: kw,
                      description: 'Air Source Heat Pump ${kw.round()}KW for Swimming Pool. Make: IZYHEAT Heat Pump Model: $modelName',
                      specs: clonedSpecs,
                    );

                    await ref.read(quotationSettingsProvider.notifier).savePoolModel(newModel);
                    _selectPoolModel(newModel);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✓ New model added from template to Supabase!'), backgroundColor: AppColors.success),
                    );
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Model'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── BUILD SCREEN ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(quotationSettingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading settings: $e')),
      data: (settings) {
        _populateFromSettings(settings);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Column(
          children: [
            // Pill Tab Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.white70 : AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.heat_pump_outlined, size: 18),
                      text: 'Heat Pump Models',
                      iconMargin: EdgeInsets.only(bottom: 2),
                    ),
                    const Tab(
                      icon: Icon(Icons.tune_outlined, size: 18),
                      text: 'Defaults',
                      iconMargin: EdgeInsets.only(bottom: 2),
                    ),
                    const Tab(
                      icon: Icon(Icons.image_outlined, size: 18),
                      text: 'Cover, Banner & Stamp',
                      iconMargin: EdgeInsets.only(bottom: 2),
                    ),
                    if (kQgNocEnabled)
                      const Tab(
                        icon: Icon(Icons.verified_outlined, size: 18),
                        text: 'NOC Certificates',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProductModelsTab(settings),
                  _buildDefaultsAndNumberingTab(settings),
                  _buildCoverAndStampTab(settings),
                  if (kQgNocEnabled) _buildNocSettingsTab(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── TAB 1: HEAT PUMP MODELS & TYPE SHOWCASE IMAGES ───────────────────────

  Widget _buildProductModelsTab(GeneratorCompanySettings settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 4-Category Segmented Selector
        const Text(
          'Select Heat Pump Type:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: HpTypeCategory.values.map((cat) {
              final isSel = _currentCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat.label),
                  selected: isSel,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _currentCategory = cat);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Type Summary & Rule Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Naming Template: ${_currentCategory.pattern}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                    ),
                    Text(
                      'Inventory Example: ${_currentCategory.example}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Models Selection & Specifications Editor
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${_currentCategory.label} Models:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showAddTemplateModelDialog(settings),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Model'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Active Category Model Editor
        if (_currentCategory == HpTypeCategory.domestic)
          _buildDomesticEditor(settings)
        else if (_currentCategory == HpTypeCategory.allInOne)
          _buildAioEditor(settings)
        else if (_currentCategory == HpTypeCategory.allInOneWall)
          _buildWallEditor(settings)
        else if (_currentCategory == HpTypeCategory.swimmingPool)
          _buildPoolEditor(settings),

        const SizedBox(height: 32),
      ],
    );
  }

  // ─── MODEL SHOWCASE IMAGE WIDGET (PER-MODEL IMAGE ON LAST PAGE) ───────────

  Widget _buildModelShowcaseCard({
    required String modelName,
    required String? imagePath,
    required VoidCallback onUpload,
    required VoidCallback onRemove,
    required VoidCallback onApplyRange,
    String rangeButtonLabel = 'Apply to Range...',
  }) {
    final hasImage = imagePath != null && imagePath.isNotEmpty;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showcase Image: $modelName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'This image appears on the Product Showcase page when this model is selected.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasImage
                    ? (imagePath.startsWith('http') || imagePath.startsWith('blob:') || imagePath.startsWith('data:')
                        ? Image.network(
                            imagePath,
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, p) => p == null ? child : const Center(child: CircularProgressIndicator()),
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          )
                        : (imagePath.startsWith('assets/')
                            ? Image.asset(imagePath, fit: BoxFit.contain)
                            : (!kIsWeb ? Image.file(File(imagePath), fit: BoxFit.contain) : const SizedBox.shrink())))
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 36, color: Colors.grey),
                            SizedBox(height: 6),
                            Text('No image set for this model yet', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
              ),
            ),
            if (hasImage) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                    label: const Text('Remove Image', style: TextStyle(fontSize: 12, color: AppColors.error)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                  ),
                  OutlinedButton.icon(
                    onPressed: onApplyRange,
                    icon: const Icon(Icons.copy_all, size: 15),
                    label: Text(rangeButtonLabel, style: const TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                label: Text(hasImage ? 'Change Image' : 'Upload Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RANGE APPLICATION DIALOGS & CHIP HELPERS ────────────────────────────

  Widget _buildDialogPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFBFDBFE),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF1E40AF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchingModelChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Future<void> _showApplyDomesticImageRangeDialog(
    String imagePath,
    GeneratorCompanySettings settings,
  ) async {
    if (imagePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload or set an image for this model first.')),
      );
      return;
    }

    final curKw = _selectedDomesticModel?.displayCapacityKw ?? 4.0;
    double initialMin = curKw <= 8.0 ? 4.0 : (curKw <= 20.0 ? 10.0 : 25.0);
    double initialMax = curKw <= 8.0 ? 8.0 : (curKw <= 20.0 ? 20.0 : 45.0);

    final minCtrl = TextEditingController(text: initialMin.toStringAsFixed(1));
    final maxCtrl = TextEditingController(text: initialMax.toStringAsFixed(1));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final minVal = double.tryParse(minCtrl.text.trim()) ?? 0.0;
          final maxVal = double.tryParse(maxCtrl.text.trim()) ?? 100.0;
          final matchingModels = settings.models.where((m) => m.displayCapacityKw >= minVal && m.displayCapacityKw <= maxVal).toList();

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.copy_all, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Apply Image to kW Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Presets:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDialogPresetChip(
                        label: '4 - 8 kW',
                        isSelected: minCtrl.text == '4.0' && maxCtrl.text == '8.0',
                        onTap: () => setDlgState(() {
                          minCtrl.text = '4.0';
                          maxCtrl.text = '8.0';
                        }),
                      ),
                      _buildDialogPresetChip(
                        label: '10 - 20 kW',
                        isSelected: minCtrl.text == '10.0' && maxCtrl.text == '20.0',
                        onTap: () => setDlgState(() {
                          minCtrl.text = '10.0';
                          maxCtrl.text = '20.0';
                        }),
                      ),
                      _buildDialogPresetChip(
                        label: '25 - 45 kW',
                        isSelected: minCtrl.text == '25.0' && maxCtrl.text == '45.0',
                        onTap: () => setDlgState(() {
                          minCtrl.text = '25.0';
                          maxCtrl.text = '45.0';
                        }),
                      ),
                      _buildDialogPresetChip(
                        label: 'All Domestic',
                        isSelected: minCtrl.text == '0.0' && maxCtrl.text == '100.0',
                        onTap: () => setDlgState(() {
                          minCtrl.text = '0.0';
                          maxCtrl.text = '100.0';
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: minCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Min kW', isDense: true, border: OutlineInputBorder()),
                          onChanged: (_) => setDlgState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: maxCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Max kW', isDense: true, border: OutlineInputBorder()),
                          onChanged: (_) => setDlgState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Matching Models (${matchingModels.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  if (matchingModels.isEmpty)
                    const Text('No models match this kW range.', style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: matchingModels.map((m) {
                        return _buildMatchingModelChip('${m.modelName} (${m.displayCapacityKw}kW)');
                      }).toList(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: matchingModels.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final count = await ref.read(quotationSettingsProvider.notifier).applyDomesticImageToRange(
                              imagePath: imagePath,
                              minKw: minVal,
                              maxKw: maxVal,
                            );
                        if (_selectedDomesticModel != null &&
                            _selectedDomesticModel!.displayCapacityKw >= minVal &&
                            _selectedDomesticModel!.displayCapacityKw <= maxVal) {
                          _selectDomesticModel(_selectedDomesticModel!.copyWith(defaultImagePath: imagePath));
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✓ Showcase image copied to $count Domestic model(s)!'), backgroundColor: AppColors.success),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: Text('Apply to ${matchingModels.length} Model(s)'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showApplyAioImageRangeDialog(
    String imagePath,
    GeneratorCompanySettings settings, {
    required bool isWallMounted,
  }) async {
    if (imagePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload or set an image for this model first.')),
      );
      return;
    }

    final curVol = (isWallMounted ? _selectedWallModel?.tankVolumeLitres : _selectedAioModel?.tankVolumeLitres) ?? (isWallMounted ? 100 : 200);
    int initialMin = isWallMounted ? 80 : (curVol <= 250 ? 150 : (curVol <= 350 ? 250 : 350));
    int initialMax = isWallMounted ? 100 : (curVol <= 250 ? 250 : (curVol <= 350 ? 350 : 550));

    final minCtrl = TextEditingController(text: initialMin.toString());
    final maxCtrl = TextEditingController(text: initialMax.toString());

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final minVal = int.tryParse(minCtrl.text.trim()) ?? 0;
          final maxVal = int.tryParse(maxCtrl.text.trim()) ?? 5000;
          final matchingModels = settings.allInOneModels
              .where((m) => m.isWallMounted == isWallMounted && m.tankVolumeLitres >= minVal && m.tankVolumeLitres <= maxVal)
              .toList();

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.copy_all, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isWallMounted ? 'Apply Image to Wall Models' : 'Apply Image to Floor Range',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Presets:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: isWallMounted
                        ? [
                            _buildDialogPresetChip(
                              label: '80 - 100 Ltr',
                              isSelected: minCtrl.text == '80' && maxCtrl.text == '100',
                              onTap: () => setDlgState(() {
                                minCtrl.text = '80';
                                maxCtrl.text = '100';
                              }),
                            ),
                            _buildDialogPresetChip(
                              label: 'All Wall Models',
                              isSelected: minCtrl.text == '0' && maxCtrl.text == '500',
                              onTap: () => setDlgState(() {
                                minCtrl.text = '0';
                                maxCtrl.text = '500';
                              }),
                            ),
                          ]
                        : [
                            _buildDialogPresetChip(
                              label: '150 - 250 Ltr',
                              isSelected: minCtrl.text == '150' && maxCtrl.text == '250',
                              onTap: () => setDlgState(() {
                                minCtrl.text = '150';
                                maxCtrl.text = '250';
                              }),
                            ),
                            _buildDialogPresetChip(
                              label: '250 - 350 Ltr',
                              isSelected: minCtrl.text == '250' && maxCtrl.text == '350',
                              onTap: () => setDlgState(() {
                                minCtrl.text = '250';
                                maxCtrl.text = '350';
                              }),
                            ),
                            _buildDialogPresetChip(
                              label: '350 - 550 Ltr',
                              isSelected: minCtrl.text == '350' && maxCtrl.text == '550',
                              onTap: () => setDlgState(() {
                                minCtrl.text = '350';
                                maxCtrl.text = '550';
                              }),
                            ),
                            _buildDialogPresetChip(
                              label: 'All Floor Models',
                              isSelected: minCtrl.text == '0' && maxCtrl.text == '2000',
                              onTap: () => setDlgState(() {
                                minCtrl.text = '0';
                                maxCtrl.text = '2000';
                              }),
                            ),
                          ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: minCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min Ltr', isDense: true, border: OutlineInputBorder()),
                          onChanged: (_) => setDlgState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: maxCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Max Ltr', isDense: true, border: OutlineInputBorder()),
                          onChanged: (_) => setDlgState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Matching Models (${matchingModels.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  if (matchingModels.isEmpty)
                    const Text('No models match this volume range.', style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: matchingModels.map((m) {
                        return _buildMatchingModelChip('${m.modelName} (${m.tankVolumeLitres}L)');
                      }).toList(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: matchingModels.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final count = await ref.read(quotationSettingsProvider.notifier).applyAioImageToRange(
                              imagePath: imagePath,
                              minLtr: minVal,
                              maxLtr: maxVal,
                              isWallMounted: isWallMounted,
                            );
                        if (isWallMounted &&
                            _selectedWallModel != null &&
                            _selectedWallModel!.tankVolumeLitres >= minVal &&
                            _selectedWallModel!.tankVolumeLitres <= maxVal) {
                          _selectWallModel(_selectedWallModel!.copyWith(defaultImagePath: imagePath));
                        } else if (!isWallMounted &&
                            _selectedAioModel != null &&
                            _selectedAioModel!.tankVolumeLitres >= minVal &&
                            _selectedAioModel!.tankVolumeLitres <= maxVal) {
                          _selectAioModel(_selectedAioModel!.copyWith(defaultImagePath: imagePath));
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✓ Showcase image copied to $count model(s)!'), backgroundColor: AppColors.success),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: Text('Apply to ${matchingModels.length} Model(s)'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showApplyPoolImageRangeDialog(
    String imagePath,
    GeneratorCompanySettings settings,
  ) async {
    if (imagePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload or set an image for this model first.')),
      );
      return;
    }

    final curKw = _selectedPoolModel?.capacityKw ?? 35.0;
    double initialMin = curKw <= 25.0 ? 10.0 : (curKw <= 45.0 ? 25.0 : 45.0);
    double initialMax = curKw <= 25.0 ? 25.0 : (curKw <= 45.0 ? 45.0 : 80.0);

    final minCtrl = TextEditingController(text: initialMin.toStringAsFixed(1));
    final maxCtrl = TextEditingController(text: initialMax.toStringAsFixed(1));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final minVal = double.tryParse(minCtrl.text.trim()) ?? 0.0;
          final maxVal = double.tryParse(maxCtrl.text.trim()) ?? 200.0;
          final matchingModels = settings.poolModels.where((m) => m.capacityKw >= minVal && m.capacityKw <= maxVal).toList();

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.copy_all, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Apply Image to Pool Models', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Presets:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDialogPresetChip(
                        label: '10 - 25 kW',
                        isSelected: minCtrl.text == '10.0' && maxCtrl.text == '25.0',
                        onTap: () => setDlgState(() {
                          minCtrl.text = '10.0';
                          maxCtrl.text = '25.0';
                        }),
                      ),
                      _buildDialogPresetChip(
                        label: '25 - 45 kW',
                        isSelected: minCtrl.text == '25.0' && maxCtrl.text == '45.0',
                        onTap: () => setDlgState(() {
                          minCtrl.text = '25.0';
                          maxCtrl.text = '45.0';
                        }),
                      ),
                      _buildDialogPresetChip(
                        label: '45 - 80 kW',
                        isSelected: minCtrl.text == '45.0' && maxCtrl.text == '80.0',
                        onTap: () => setDlgState(() {
                          minCtrl.text = '45.0';
                          maxCtrl.text = '80.0';
                        }),
                      ),
                      _buildDialogPresetChip(
                        label: 'All Pool Models',
                        isSelected: minCtrl.text == '0.0' && maxCtrl.text == '200.0',
                        onTap: () => setDlgState(() {
                          minCtrl.text = '0.0';
                          maxCtrl.text = '200.0';
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: minCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Min kW', isDense: true, border: OutlineInputBorder()),
                          onChanged: (_) => setDlgState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: maxCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Max kW', isDense: true, border: OutlineInputBorder()),
                          onChanged: (_) => setDlgState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Matching Models (${matchingModels.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  if (matchingModels.isEmpty)
                    const Text('No pool models match this kW range.', style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: matchingModels.map((m) {
                        return _buildMatchingModelChip('${m.modelName} (${m.capacityKw}kW)');
                      }).toList(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: matchingModels.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final count = await ref.read(quotationSettingsProvider.notifier).applyPoolImageToRange(
                              imagePath: imagePath,
                              minKw: minVal,
                              maxKw: maxVal,
                            );
                        if (_selectedPoolModel != null &&
                            _selectedPoolModel!.capacityKw >= minVal &&
                            _selectedPoolModel!.capacityKw <= maxVal) {
                          _selectPoolModel(_selectedPoolModel!.copyWith(defaultImagePath: imagePath));
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✓ Showcase image copied to $count Pool model(s)!'), backgroundColor: AppColors.success),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: Text('Apply to ${matchingModels.length} Model(s)'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── SEARCHABLE MODEL DROPDOWN & BOTTOM SHEET ─────────────────────────────

  Widget _buildSearchableModelDropdown<T>({
    required String label,
    required String selectedTitle,
    required String selectedSubtitle,
    required List<T> items,
    required String Function(T) getTitle,
    required String Function(T) getSubtitle,
    required bool Function(T) isSelected,
    required void Function(T) onSelected,
  }) {
    return InkWell(
      onTap: () {
        _openSearchableModelBottomSheet<T>(
          label: label,
          items: items,
          getTitle: getTitle,
          getSubtitle: getSubtitle,
          isSelected: isSelected,
          onSelected: onSelected,
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedTitle.isNotEmpty ? selectedTitle : label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: selectedTitle.isNotEmpty ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (selectedSubtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      selectedSubtitle,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 22, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _openSearchableModelBottomSheet<T>({
    required String label,
    required List<T> items,
    required String Function(T) getTitle,
    required String Function(T) getSubtitle,
    required bool Function(T) isSelected,
    required void Function(T) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = items.where((item) {
              if (query.trim().isEmpty) return true;
              final q = query.toLowerCase().trim();
              final title = getTitle(item).toLowerCase();
              final subtitle = getSubtitle(item).toLowerCase();
              return title.contains(q) || subtitle.contains(q);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                top: 12,
                left: 16,
                right: 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.65,
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by model name or capacity...',
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setSheetState(() => query = ''),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                      onChanged: (val) => setSheetState(() => query = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'No matching models found',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final item = filtered[i];
                                final sel = isSelected(item);
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  title: Text(
                                    getTitle(item),
                                    style: TextStyle(
                                      fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                                      color: sel ? AppColors.primary : AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    getSubtitle(item),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  trailing: sel ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20) : null,
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    onSelected(item);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── REUSABLE EDITABLE SPECIFICATIONS LIST (ADD / REMOVE / RENAME) ────────

  Widget _buildEditableSpecsList({
    required String title,
    required List<SpecRowController> specs,
    required VoidCallback onAdd,
    required void Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Add Row', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (specs.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
            ),
            child: const Center(
              child: Text(
                'No specifications yet. Tap "+ Add Row" above.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...specs.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: item.keyController,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Spec Title',
                        hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: item.valController,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Value',
                        hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                    tooltip: 'Remove',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => onRemove(idx),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ─── 1. DOMESTIC HEAT PUMP EDITOR ──────────────────────────────────────────

  Widget _buildDomesticEditor(GeneratorCompanySettings settings) {
    final list = settings.models;
    if (_selectedDomesticModel == null && list.isNotEmpty) {
      _selectedDomesticModel = list.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchableModelDropdown<HeatPumpModel>(
          label: 'Select Domestic Model',
          selectedTitle: _selectedDomesticModel != null
              ? '${_selectedDomesticModel!.modelName} (${_selectedDomesticModel!.displayCapacityKw} KW)'
              : '',
          selectedSubtitle: _selectedDomesticModel?.ratedHeatingCapacity.isNotEmpty == true
              ? 'Rated: ${_selectedDomesticModel!.ratedHeatingCapacity}'
              : '',
          items: list,
          getTitle: (m) => '${m.modelName} (${m.displayCapacityKw} KW)',
          getSubtitle: (m) => 'Rated: ${m.ratedHeatingCapacity} | Make: ${m.makeModelLine}',
          isSelected: (m) => m.id == _selectedDomesticModel?.id,
          onSelected: (m) => _selectDomesticModel(m),
        ),
        const SizedBox(height: 14),

        if (_selectedDomesticModel != null) ...[
          _buildModelShowcaseCard(
            modelName: _selectedDomesticModel!.modelName,
            imagePath: _selectedDomesticModel!.defaultImagePath,
            onUpload: () => _pickImage(
              ImageSource.gallery,
              (url) async {
                final updated = _selectedDomesticModel!.copyWith(defaultImagePath: url);
                await ref.read(quotationSettingsProvider.notifier).saveModel(updated);
                _selectDomesticModel(updated);
              },
              bucket: 'company-assets',
              folder: 'product_showcase',
            ),
            onRemove: () async {
              final updated = _selectedDomesticModel!.copyWith(defaultImagePath: '');
              await ref.read(quotationSettingsProvider.notifier).saveModel(updated);
              _selectDomesticModel(updated);
            },
            onApplyRange: () => _showApplyDomesticImageRangeDialog(
              _selectedDomesticModel!.defaultImagePath,
              settings,
            ),
            rangeButtonLabel: 'Apply to kW Range...',
          ),
          Row(
            children: [
              Expanded(child: _textInput('Model Name', _domesticModelNameCtrl, hint: 'IZ-4C')),
              const SizedBox(width: 10),
              Expanded(child: _textInput('Capacity (kW)', _domesticKwCtrl, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 10),
          _textInput('Rated Heating Capacity', _domesticRatedHeatingCtrl, hint: '3.6kw'),
          const SizedBox(height: 10),
          _textInput('Description Line', _domesticDescLineCtrl),
          const SizedBox(height: 10),
          _textInput('Make & Model Line', _domesticMakeModelCtrl),
          const SizedBox(height: 10),
          _textInput('Power Input & Defrost', _domesticPowerInputCtrl),
          const SizedBox(height: 16),

          _buildEditableSpecsList(
            title: 'Annexure II Specifications (Domestic HP):',
            specs: _domesticSpecs,
            onAdd: () {
              setState(() {
                _domesticSpecs.add(SpecRowController(key: '', value: ''));
              });
            },
            onRemove: (idx) {
              setState(() {
                _domesticSpecs[idx].dispose();
                _domesticSpecs.removeAt(idx);
              });
            },
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _saveDomesticModel,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save Domestic Specifications'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ],
    );
  }

  // ─── 2. ALL IN ONE FLOOR EDITOR ───────────────────────────────────────────

  Widget _buildAioEditor(GeneratorCompanySettings settings) {
    final list = settings.allInOneModels.where((m) => !m.isWallMounted).toList();
    if (_selectedAioModel == null && list.isNotEmpty) {
      _selectedAioModel = list.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchableModelDropdown<AllInOneModel>(
          label: 'Select All in One Model',
          selectedTitle: _selectedAioModel != null
              ? '${_selectedAioModel!.modelName} (${_selectedAioModel!.tankVolumeLitres} Ltr)'
              : '',
          selectedSubtitle: _selectedAioModel?.description.isNotEmpty == true
              ? _selectedAioModel!.description
              : '',
          items: list,
          getTitle: (m) => '${m.modelName} (${m.tankVolumeLitres} Ltr)',
          getSubtitle: (m) => m.description.isNotEmpty ? m.description : 'Tank Volume: ${m.tankVolumeLitres} Ltr',
          isSelected: (m) => m.id == _selectedAioModel?.id,
          onSelected: (m) => _selectAioModel(m),
        ),
        const SizedBox(height: 14),

        if (_selectedAioModel != null) ...[
          _buildModelShowcaseCard(
            modelName: _selectedAioModel!.modelName,
            imagePath: _selectedAioModel!.defaultImagePath,
            onUpload: () => _pickImage(
              ImageSource.gallery,
              (url) async {
                final updated = _selectedAioModel!.copyWith(defaultImagePath: url);
                await ref.read(quotationSettingsProvider.notifier).saveAllInOneModel(updated);
                _selectAioModel(updated);
              },
              bucket: 'company-assets',
              folder: 'product_showcase',
            ),
            onRemove: () async {
              final updated = _selectedAioModel!.copyWith(defaultImagePath: '');
              await ref.read(quotationSettingsProvider.notifier).saveAllInOneModel(updated);
              _selectAioModel(updated);
            },
            onApplyRange: () => _showApplyAioImageRangeDialog(
              _selectedAioModel!.defaultImagePath,
              settings,
              isWallMounted: false,
            ),
            rangeButtonLabel: 'Apply to Litre Range...',
          ),
          Row(
            children: [
              Expanded(child: _textInput('Model Name', _aioModelNameCtrl, hint: 'All in One 200Ltr / 200D')),
              const SizedBox(width: 10),
              Expanded(child: _textInput('Tank Volume (Ltr)', _aioVolumeCtrl, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 10),
          _textInput('Description', _aioDescCtrl),
          const SizedBox(height: 16),

          _buildEditableSpecsList(
            title: 'Annexure II Specifications (All in One Floor):',
            specs: _aioSpecs,
            onAdd: () {
              setState(() {
                _aioSpecs.add(SpecRowController(key: '', value: ''));
              });
            },
            onRemove: (idx) {
              setState(() {
                _aioSpecs[idx].dispose();
                _aioSpecs.removeAt(idx);
              });
            },
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _saveAioModel,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save All in One Specifications'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ],
    );
  }

  // ─── 3. ALL IN ONE WALL MOUNTED EDITOR ─────────────────────────────────────

  Widget _buildWallEditor(GeneratorCompanySettings settings) {
    final list = settings.allInOneModels.where((m) => m.isWallMounted).toList();
    if (_selectedWallModel == null && list.isNotEmpty) {
      _selectedWallModel = list.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchableModelDropdown<AllInOneModel>(
          label: 'Select Wall Mounted Model',
          selectedTitle: _selectedWallModel != null
              ? '${_selectedWallModel!.modelName} (${_selectedWallModel!.tankVolumeLitres} Ltr)'
              : '',
          selectedSubtitle: _selectedWallModel?.description.isNotEmpty == true
              ? _selectedWallModel!.description
              : '',
          items: list,
          getTitle: (m) => '${m.modelName} (${m.tankVolumeLitres} Ltr)',
          getSubtitle: (m) => m.description.isNotEmpty ? m.description : 'Tank Volume: ${m.tankVolumeLitres} Ltr',
          isSelected: (m) => m.id == _selectedWallModel?.id,
          onSelected: (m) => _selectWallModel(m),
        ),
        const SizedBox(height: 14),

        if (_selectedWallModel != null) ...[
          _buildModelShowcaseCard(
            modelName: _selectedWallModel!.modelName,
            imagePath: _selectedWallModel!.defaultImagePath,
            onUpload: () => _pickImage(
              ImageSource.gallery,
              (url) async {
                final updated = _selectedWallModel!.copyWith(defaultImagePath: url);
                await ref.read(quotationSettingsProvider.notifier).saveAllInOneModel(updated);
                _selectWallModel(updated);
              },
              bucket: 'company-assets',
              folder: 'product_showcase',
            ),
            onRemove: () async {
              final updated = _selectedWallModel!.copyWith(defaultImagePath: '');
              await ref.read(quotationSettingsProvider.notifier).saveAllInOneModel(updated);
              _selectWallModel(updated);
            },
            onApplyRange: () => _showApplyAioImageRangeDialog(
              _selectedWallModel!.defaultImagePath,
              settings,
              isWallMounted: true,
            ),
            rangeButtonLabel: 'Apply to Litre Range...',
          ),
          Row(
            children: [
              Expanded(child: _textInput('Model Name', _wallModelNameCtrl, hint: 'All in One WM 100Ltr')),
              const SizedBox(width: 10),
              Expanded(child: _textInput('Tank Volume (80-100 Ltr)', _wallVolumeCtrl, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 10),
          _textInput('Description', _wallDescCtrl),
          const SizedBox(height: 16),

          _buildEditableSpecsList(
            title: 'Annexure II Specifications (Wall Mounted):',
            specs: _wallSpecs,
            onAdd: () {
              setState(() {
                _wallSpecs.add(SpecRowController(key: '', value: ''));
              });
            },
            onRemove: (idx) {
              setState(() {
                _wallSpecs[idx].dispose();
                _wallSpecs.removeAt(idx);
              });
            },
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _saveWallModel,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save Wall Mounted Specifications'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ],
    );
  }

  // ─── 4. SWIMMING POOL EDITOR ──────────────────────────────────────────────

  Widget _buildPoolEditor(GeneratorCompanySettings settings) {
    final list = settings.poolModels;
    if (_selectedPoolModel == null && list.isNotEmpty) {
      _selectedPoolModel = list.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchableModelDropdown<PoolHeatPumpModel>(
          label: 'Select Swimming Pool Model',
          selectedTitle: _selectedPoolModel != null
              ? '${_selectedPoolModel!.modelName} (${_selectedPoolModel!.capacityKw} KW)'
              : '',
          selectedSubtitle: _selectedPoolModel?.description.isNotEmpty == true
              ? _selectedPoolModel!.description
              : '',
          items: list,
          getTitle: (m) => '${m.modelName} (${m.capacityKw} KW)',
          getSubtitle: (m) => m.description.isNotEmpty ? m.description : 'Capacity: ${m.capacityKw} KW',
          isSelected: (m) => m.id == _selectedPoolModel?.id,
          onSelected: (m) => _selectPoolModel(m),
        ),
        const SizedBox(height: 14),

        if (_selectedPoolModel != null) ...[
          _buildModelShowcaseCard(
            modelName: _selectedPoolModel!.modelName,
            imagePath: _selectedPoolModel!.defaultImagePath,
            onUpload: () => _pickImage(
              ImageSource.gallery,
              (url) async {
                final updated = _selectedPoolModel!.copyWith(defaultImagePath: url);
                await ref.read(quotationSettingsProvider.notifier).savePoolModel(updated);
                _selectPoolModel(updated);
              },
              bucket: 'company-assets',
              folder: 'product_showcase',
            ),
            onRemove: () async {
              final updated = _selectedPoolModel!.copyWith(defaultImagePath: '');
              await ref.read(quotationSettingsProvider.notifier).savePoolModel(updated);
              _selectPoolModel(updated);
            },
            onApplyRange: () => _showApplyPoolImageRangeDialog(
              _selectedPoolModel!.defaultImagePath,
              settings,
            ),
            rangeButtonLabel: 'Apply to kW Range...',
          ),
          Row(
            children: [
              Expanded(child: _textInput('Model Name', _poolModelNameCtrl, hint: 'Swimming Pool 35KW')),
              const SizedBox(width: 10),
              Expanded(child: _textInput('Capacity (kW)', _poolKwCtrl, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 10),
          _textInput('Description', _poolDescCtrl),
          const SizedBox(height: 16),

          _buildEditableSpecsList(
            title: 'Annexure II Specifications (Swimming Pool):',
            specs: _poolSpecs,
            onAdd: () {
              setState(() {
                _poolSpecs.add(SpecRowController(key: '', value: ''));
              });
            },
            onRemove: (idx) {
              setState(() {
                _poolSpecs[idx].dispose();
                _poolSpecs.removeAt(idx);
              });
            },
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _savePoolModel,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save Swimming Pool Specifications'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ],
    );
  }

  // ─── TAB 2: DEFAULTS (COMPANY/BANK SOURCED FROM PDF TEMPLATES) ─────────────

  Widget _buildDefaultsAndNumberingTab(GeneratorCompanySettings settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Information Card explaining removal of company & bank inputs
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF81C784)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Company & Bank Details Handled Centrally',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20)),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Company Name, Address, Contact, Logo, Stamp and Bank Account Details (Annexure III) are now taken directly from Admin Panel > PDF Templates / Companies. Quotation numbers are automatically synced with Deal Quotation numbers.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF2E7D32)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text('Quotation Defaults', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        const Text('Default validity and warranty terms for generated proposals.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _textInput('Validity (Days)', _validityDaysCtrl, keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _textInput('HP Warranty (Years)', _hpWarrantyCtrl, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _textInput('Tank Warranty (Years)', _tankWarrantyCtrl, keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _saveDefaultsSettings,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save Defaults'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── TAB 3: COVER PAGE, BANNER & STAMP IMAGES ───────────────────────────

  Widget _buildCoverAndStampTab(GeneratorCompanySettings settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Default Cover Page Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        const Text('Full-bleed cover background for Page 1 of all generated proposals.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        _buildImageCard(
          title: 'Cover Image',
          imagePath: settings.defaultCoverImagePath ?? 'assets/images/cover_proposal.png',
          onUpload: (path) => ref.read(quotationSettingsProvider.notifier).setCoverImage(path),
          onReset: () => ref.read(quotationSettingsProvider.notifier).setCoverImage(null),
        ),
        const SizedBox(height: 24),
        const Text('Quotation Showcase Banner Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        const Text('Rendered on Page 4 below the Technical Specifications table.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        _buildImageCard(
          title: 'Banner Image',
          imagePath: settings.defaultBannerImagePath ?? 'assets/images/insiya_banner.png',
          onUpload: (path) => ref.read(quotationSettingsProvider.notifier).setBannerImage(path),
          onReset: () => ref.read(quotationSettingsProvider.notifier).setBannerImage(null),
        ),
        const SizedBox(height: 24),
        const Text('Company Stamp Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        const Text('Rendered on Page 5 under the "Thanks & Regards" signoff block.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        _buildImageCard(
          title: 'Official Stamp',
          imagePath: settings.stampImagePath ?? 'assets/images/company_stamp.png',
          onUpload: (path) => ref.read(quotationSettingsProvider.notifier).setStampImage(path),
          onReset: () => ref.read(quotationSettingsProvider.notifier).setStampImage(null),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildImageCard({
    required String title,
    required String imagePath,
    required Function(String) onUpload,
    required VoidCallback onReset,
    String bucket = 'company-assets',
    String folder = 'branding',
  }) {
    final isCustom = !imagePath.startsWith('assets/');

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isCustom
                    ? (imagePath.startsWith('http') || imagePath.startsWith('blob:') || imagePath.startsWith('data:')
                        ? Image.network(
                            imagePath,
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, progress) => progress == null
                                ? child
                                : const Center(child: CircularProgressIndicator()),
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          )
                        : (!kIsWeb ? Image.file(File(imagePath), fit: BoxFit.contain) : const SizedBox.shrink()))
                    : Image.asset(imagePath, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isCustom) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      imagePath.startsWith('http') ? 'Supabase Storage' : 'Custom',
                      style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onReset,
                    child: const Text('Reset to Default', style: TextStyle(color: AppColors.error)),
                  ),
                ],
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery, onUpload, bucket: bucket, folder: folder),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                  label: Text('Upload $title'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _textInput(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: const OutlineInputBorder(),
      ),
    );
  }

  // ─── TAB 4: NOC SETTINGS & PROFILES ──────────────────────────────────────

  Widget _buildNocSettingsTab() {
    return const NocCertificateSettingsScreen(isEmbedded: true);
  }
}

