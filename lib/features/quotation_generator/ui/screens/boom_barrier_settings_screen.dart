// lib/features/quotation_generator/ui/screens/boom_barrier_settings_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/boom_barrier_catalog_model.dart';
import '../../models/boom_barrier_proposal_draft.dart';
import '../../models/qg_product_profile.dart';

class BoomBarrierSettingsScreen extends ConsumerStatefulWidget {
  const BoomBarrierSettingsScreen({super.key});

  @override
  ConsumerState<BoomBarrierSettingsScreen> createState() =>
      _BoomBarrierSettingsScreenState();
}

class _BoomBarrierSettingsScreenState
    extends ConsumerState<BoomBarrierSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Models list
  final List<String> _models = ['IZ-2001', 'IZ-2026', 'IZ-2004', 'NPRS'];
  String _selectedModel = 'IZ-2001';

  // Specs map per model: model -> list of {label, value, visible}
  final Map<String, List<Map<String, dynamic>>> _modelSpecs = {};

  // Image path per model: model -> image_path
  final Map<String, String> _modelImages = {};

  // Display names per model
  final Map<String, String> _modelDisplayNames = {
    'IZ-2001': 'Sefdor Fast Speed Boom Barrier (IZ-2001)',
    'IZ-2026': 'Sefdor Heavy Duty Commercial Boom Barrier (IZ-2026)',
    'IZ-2004': 'Sefdor Commercial Boom Barrier (IZ-2004)',
    'NPRS': 'License Plate Recognition Camera (LPR / NPRS)',
  };

  // Company Profile for Boom Barrier
  QgProductProfile? _profile;
  String? _coverImagePath;
  String? _logoImagePath;
  String? _stampImagePath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseClientProvider);
    final prefs = await SharedPreferences.getInstance();

    // Initialize defaults from BoomBarrierProposalDraft
    for (final m in _models) {
      final defaultSpecs = BoomBarrierProposalDraft.defaultSpecsForModel(m);
      _modelSpecs[m] = List<Map<String, dynamic>>.from(
        defaultSpecs.map((e) => Map<String, dynamic>.from(e)),
      );
      _modelImages[m] = _getDefaultImagePath(m);
    }

    try {
      // 1. Try fetching from Supabase qg_catalog
      final catalogRes = await supabase
          .from('qg_catalog')
          .select('*')
          .eq('kind', 'boom_barrier')
          .eq('is_active', true);

      for (final row in catalogRes) {
        final model = BoomBarrierCatalogModel.fromJson(row);
        if (_models.contains(model.modelNo)) {
          if (model.specRows.isNotEmpty) {
            _modelSpecs[model.modelNo] = List<Map<String, dynamic>>.from(
              model.specRows.map((e) => Map<String, dynamic>.from(e)),
            );
          }
          if (model.imagePath.isNotEmpty) {
            _modelImages[model.modelNo] = model.imagePath;
          }
        }
      }

      // 2. Try fetching company profile
      final profileRes = await supabase
          .from('qg_product_profiles')
          .select('*')
          .eq('key', 'boom_barrier')
          .maybeSingle();

      if (profileRes != null) {
        _profile = QgProductProfile.fromJson(Map<String, dynamic>.from(profileRes));
        _coverImagePath = _profile?.defaultCoverPath;
        _logoImagePath = _profile?.logoPath;
        _stampImagePath = _profile?.stampPath;
      } else {
        _profile = QgProductProfile.defaultBoomBarrier();
      }
    } catch (e) {
      debugPrint('BoomBarrierSettings: error loading remote catalog: $e');
      // Fallback to local SharedPreferences
      for (final m in _models) {
        final cachedSpecsJson = prefs.getString('bb_specs_$m');
        if (cachedSpecsJson != null) {
          try {
            final list = (jsonDecode(cachedSpecsJson) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            if (list.isNotEmpty) _modelSpecs[m] = list;
          } catch (_) {}
        }
        final cachedImg = prefs.getString('bb_image_$m');
        if (cachedImg != null && cachedImg.isNotEmpty) {
          _modelImages[m] = cachedImg;
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _getDefaultImagePath(String model) {
    switch (model) {
      case 'IZ-2001':
        return 'assets/images/boom_barrier/product_iz_2001.png';
      case 'IZ-2026':
        return 'assets/images/boom_barrier/product_iz_2026.png';
      case 'IZ-2004':
        return 'assets/images/boom_barrier/product_iz_2004.png';
      case 'NPRS':
        return 'assets/images/boom_barrier/product_nprs.png';
      default:
        return 'assets/images/boom_barrier/product_iz_2001.png';
    }
  }

  Future<void> _pickModelImage(String model) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      final bytes = await picked.readAsBytes();
      final filename = 'bb_${model.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'boom_barrier/$filename';

      await supabase.storage.from('quotation_templates').uploadBinary(path, bytes);
      final publicUrl = supabase.storage.from('quotation_templates').getPublicUrl(path);

      setState(() {
        _modelImages[model] = publicUrl;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bb_image_$model', publicUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Image updated for $model'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      // Use local path as fallback
      setState(() {
        _modelImages[model] = picked.path;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bb_image_$model', picked.path);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final supabase = ref.read(supabaseClientProvider);
    final prefs = await SharedPreferences.getInstance();

    try {
      // 1. Save specs and image for each model into local prefs and Supabase
      for (final m in _models) {
        final specs = _modelSpecs[m] ?? [];
        final imagePath = _modelImages[m] ?? _getDefaultImagePath(m);

        // Local cache
        await prefs.setString('bb_specs_$m', jsonEncode(specs));
        await prefs.setString('bb_image_$m', imagePath);

        // Remote Supabase qg_catalog
        try {
          await supabase.from('qg_catalog').upsert(
            {
              'kind': 'boom_barrier',
              'model_no': m,
              'display_name': _modelDisplayNames[m] ?? m,
              'image_path': imagePath,
              'specs': {'rows': specs},
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'kind,model_no',
          );
        } catch (remoteError) {
          debugPrint('Supabase catalog upsert warning for $m: $remoteError');
        }
      }

      // 2. Save Boom Barrier Profile if updated
      try {
        if (_coverImagePath != null || _logoImagePath != null || _stampImagePath != null) {
          await supabase.from('qg_product_profiles').upsert(
            {
              'key': 'boom_barrier',
              'label': 'Boom Barrier Proposal',
              'product_type': 'boom_barrier',
              'default_cover_path': _coverImagePath ?? '',
              'logo_path': _logoImagePath ?? '',
              'stamp_path': _stampImagePath ?? '',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'key',
          );
        }
      } catch (profileError) {
        debugPrint('Supabase profile upsert warning: $profileError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Boom Barrier specifications saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save specifications: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addSpecRow() {
    final keyCtrl = TextEditingController();
    final valCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Specification Row'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Specification Label / Parameter',
                hintText: 'e.g. Arm Length, Power Supply, Motor Type',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valCtrl,
              decoration: const InputDecoration(
                labelText: 'Value',
                hintText: 'e.g. Up to 6 Meters, AC 220V, Brushless DC',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final k = keyCtrl.text.trim();
              final v = valCtrl.text.trim();
              if (k.isNotEmpty) {
                setState(() {
                  _modelSpecs[_selectedModel] ??= [];
                  _modelSpecs[_selectedModel]!.add({
                    'label': k,
                    'value': v,
                    'visible': true,
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add Row'),
          ),
        ],
      ),
    );
  }

  void _resetToDefaultSpecs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset $_selectedModel to Defaults?'),
        content: Text(
          'This will restore standard factory specifications for $_selectedModel. Any custom rows will be replaced with defaults.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              final defaultSpecs =
                  BoomBarrierProposalDraft.defaultSpecsForModel(_selectedModel);
              setState(() {
                _modelSpecs[_selectedModel] = List<Map<String, dynamic>>.from(
                  defaultSpecs.map((e) => Map<String, dynamic>.from(e)),
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentSpecs = _modelSpecs[_selectedModel] ?? [];
    final currentImage = _modelImages[_selectedModel] ?? _getDefaultImagePath(_selectedModel);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Model Selector Header
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.shield_outlined, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text(
                                'Boom Barrier Models Configuration',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Configure technical specifications and product image per model. These specs automatically populate on generated quotations.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _models.map((m) {
                              final isSelected = m == _selectedModel;
                              return ChoiceChip(
                                label: Text(
                                  m,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _selectedModel = m);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Model Details & Image Upload Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Image Preview
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? Colors.white12 : Colors.grey.shade300,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: currentImage.startsWith('http')
                                  ? Image.network(
                                      currentImage,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.image_not_supported,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : Image.asset(
                                      currentImage,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.shield_outlined,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _modelDisplayNames[_selectedModel] ?? _selectedModel,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Model Code: $_selectedModel',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.upload_file, size: 16),
                                  label: const Text('Upload Product Image'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => _pickModelImage(_selectedModel),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Technical Specifications Table Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Technical Specifications ($_selectedModel)',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.restore, size: 16),
                                    label: const Text('Reset Defaults'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: _resetToDefaultSpecs,
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add Row'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: _addSpecRow,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (currentSpecs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  'No specifications configured. Tap "Reset Defaults" or "Add Row".',
                                  style: TextStyle(
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: currentSpecs.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final row = currentSpecs[idx];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      // Visible toggle
                                      IconButton(
                                        icon: Icon(
                                          row['visible'] == false
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          size: 18,
                                          color: row['visible'] == false
                                              ? Colors.grey
                                              : AppColors.primary,
                                        ),
                                        tooltip: 'Toggle Visibility in PDF',
                                        onPressed: () {
                                          setState(() {
                                            row['visible'] = !(row['visible'] ?? true);
                                          });
                                        },
                                      ),
                                      // Parameter Label
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          initialValue: row['label']?.toString() ?? '',
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 10,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            hintText: 'Parameter',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          onChanged: (val) => row['label'] = val,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Value
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          initialValue: row['value']?.toString() ?? '',
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 10,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            hintText: 'Specification Value',
                                          ),
                                          style: const TextStyle(fontSize: 12),
                                          onChanged: (val) => row['value'] = val,
                                        ),
                                      ),
                                      // Delete button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: AppColors.error,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            currentSpecs.removeAt(idx);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bottom Save Action
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, color: Colors.white),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save All Boom Barrier Settings',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: _isSaving ? null : _saveSettings,
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
