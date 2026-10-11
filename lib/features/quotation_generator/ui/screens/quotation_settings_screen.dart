// lib/features/quotation_generator/ui/screens/quotation_settings_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/generator_company_settings.dart';
import '../../models/heat_pump_model.dart';
import '../../providers/quotation_generator_providers.dart';
import '../../services/quotation_storage_service.dart';

class QuotationSettingsScreen extends ConsumerStatefulWidget {
  const QuotationSettingsScreen({super.key});

  @override
  ConsumerState<QuotationSettingsScreen> createState() => _QuotationSettingsScreenState();
}

class _QuotationSettingsScreenState extends ConsumerState<QuotationSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers for company & bank
  final _companyNameCtrl = TextEditingController();
  final _shortAddressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phone2Ctrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _bankAccountNameCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccountNumCtrl = TextEditingController();
  final _bankBranchCtrl = TextEditingController();
  final _bankIfscCtrl = TextEditingController();
  final _quotePrefixCtrl = TextEditingController();
  final _nextRunningNumCtrl = TextEditingController();
  final _gstPercentCtrl = TextEditingController();
  final _hpWarrantyCtrl = TextEditingController();
  final _tankWarrantyCtrl = TextEditingController();
  final _validityDaysCtrl = TextEditingController();

  // Selected model to view/edit
  HeatPumpModel? _selectedModel;
  final _modelNameCtrl = TextEditingController();
  final _kwCtrl = TextEditingController();
  final _ratedHeatingCtrl = TextEditingController();
  final _descLineCtrl = TextEditingController();
  final _makeModelCtrl = TextEditingController();
  final _powerInputCtrl = TextEditingController();
  final Map<String, TextEditingController> _specControllers = {};

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameCtrl.dispose();
    _shortAddressCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _phone2Ctrl.dispose();
    _websiteCtrl.dispose();
    _bankAccountNameCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountNumCtrl.dispose();
    _bankBranchCtrl.dispose();
    _bankIfscCtrl.dispose();
    _quotePrefixCtrl.dispose();
    _nextRunningNumCtrl.dispose();
    _gstPercentCtrl.dispose();
    _hpWarrantyCtrl.dispose();
    _tankWarrantyCtrl.dispose();
    _validityDaysCtrl.dispose();
    _modelNameCtrl.dispose();
    _kwCtrl.dispose();
    _ratedHeatingCtrl.dispose();
    _descLineCtrl.dispose();
    _makeModelCtrl.dispose();
    _powerInputCtrl.dispose();
    for (final c in _specControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _populateFromSettings(GeneratorCompanySettings s) {
    if (_initialized) return;
    _initialized = true;

    _companyNameCtrl.text = s.companyName;
    _shortAddressCtrl.text = s.shortAddress;
    _emailCtrl.text = s.companyEmail;
    _phoneCtrl.text = s.companyPhone;
    _phone2Ctrl.text = s.companyPhone2;
    _websiteCtrl.text = s.companyWebsite;
    _bankAccountNameCtrl.text = s.bankAccountName;
    _bankNameCtrl.text = s.bankName;
    _bankAccountNumCtrl.text = s.bankAccountNumber;
    _bankBranchCtrl.text = s.bankBranch;
    _bankIfscCtrl.text = s.bankIfsc;
    _quotePrefixCtrl.text = s.quotePrefix;
    _nextRunningNumCtrl.text = s.nextRunningNumber.toString();
    _gstPercentCtrl.text = s.defaultGstPercent.toString();
    _hpWarrantyCtrl.text = s.defaultWarrantyHpYears.toString();
    _tankWarrantyCtrl.text = s.defaultWarrantyTankYears.toString();
    _validityDaysCtrl.text = s.defaultValidityDays.toString();

    if (s.models.isNotEmpty) {
      _selectModel(s.models.first);
    }
  }

  void _selectModel(HeatPumpModel m) {
    setState(() {
      _selectedModel = m;
      _modelNameCtrl.text = m.modelName;
      _kwCtrl.text = m.displayCapacityKw.toString();
      _ratedHeatingCtrl.text = m.ratedHeatingCapacity;
      _descLineCtrl.text = m.descriptionLine;
      _makeModelCtrl.text = m.makeModelLine;
      _powerInputCtrl.text = m.powerInputText;

      for (final c in _specControllers.values) {
        c.dispose();
      }
      _specControllers.clear();

      m.specs.forEach((k, v) {
        _specControllers[k] = TextEditingController(text: v);
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
        final publicUrl = await QuotationStorageService.uploadImageFile(
          supabase: supabase,
          file: File(picked.path),
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
        if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
        onPicked(picked.path);
      }
    }
  }

  Future<void> _saveGeneralSettings() async {
    final sAsync = ref.read(quotationSettingsProvider);
    final current = sAsync.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(
      companyName: _companyNameCtrl.text.trim(),
      shortAddress: _shortAddressCtrl.text.trim(),
      companyEmail: _emailCtrl.text.trim(),
      companyPhone: _phoneCtrl.text.trim(),
      companyPhone2: _phone2Ctrl.text.trim(),
      companyWebsite: _websiteCtrl.text.trim(),
      bankAccountName: _bankAccountNameCtrl.text.trim(),
      bankName: _bankNameCtrl.text.trim(),
      bankAccountNumber: _bankAccountNumCtrl.text.trim(),
      bankBranch: _bankBranchCtrl.text.trim(),
      bankIfsc: _bankIfscCtrl.text.trim(),
      quotePrefix: _quotePrefixCtrl.text.trim(),
      nextRunningNumber: int.tryParse(_nextRunningNumCtrl.text.trim()) ?? current.nextRunningNumber,
      defaultGstPercent: double.tryParse(_gstPercentCtrl.text.trim()) ?? current.defaultGstPercent,
      defaultWarrantyHpYears: int.tryParse(_hpWarrantyCtrl.text.trim()) ?? current.defaultWarrantyHpYears,
      defaultWarrantyTankYears: int.tryParse(_tankWarrantyCtrl.text.trim()) ?? current.defaultWarrantyTankYears,
      defaultValidityDays: int.tryParse(_validityDaysCtrl.text.trim()) ?? current.defaultValidityDays,
    );

    await ref.read(quotationSettingsProvider.notifier).updateSettings(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Company & Bank Settings saved!'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _saveCurrentModel() async {
    if (_selectedModel == null) return;

    final specsMap = <String, String>{};
    _specControllers.forEach((k, ctrl) {
      specsMap[k] = ctrl.text.trim();
    });

    final updatedModel = _selectedModel!.copyWith(
      modelName: _modelNameCtrl.text.trim(),
      displayCapacityKw: double.tryParse(_kwCtrl.text.trim()) ?? _selectedModel!.displayCapacityKw,
      ratedHeatingCapacity: _ratedHeatingCtrl.text.trim(),
      descriptionLine: _descLineCtrl.text.trim(),
      makeModelLine: _makeModelCtrl.text.trim(),
      powerInputText: _powerInputCtrl.text.trim(),
      specs: specsMap,
    );

    await ref.read(quotationSettingsProvider.notifier).saveModel(updatedModel);
    _selectModel(updatedModel);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ Model ${updatedModel.modelName} specifications saved!'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _showAddModelDialog(GeneratorCompanySettings settings) async {
    final nameCtrl = TextEditingController();
    final kwCtrl = TextEditingController(text: '4.0');
    final ratedCtrl = TextEditingController(text: '3.6kw');
    HeatPumpModel baseModel = _selectedModel ?? settings.models.first;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_circle_outline, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Add Heat Pump Model', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Create a new model for quotations and catalog.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Model Name *',
                        hintText: 'e.g. IZ-8C',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter a model name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: kwCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Display Capacity (KW) *',
                        hintText: 'e.g. 8.0',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter KW capacity';
                        if (double.tryParse(val.trim()) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ratedCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Rated Heating Capacity',
                        hintText: 'e.g. 7.2kw',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Copy Initial Specs From:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: baseModel.id,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: settings.models.map((m) {
                        return DropdownMenuItem(
                          value: m.id,
                          child: Text('${m.modelName} (${m.displayCapacityKw} KW)'),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id != null) {
                          setDialogState(() {
                            baseModel = settings.models.firstWhere((m) => m.id == id);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final newName = nameCtrl.text.trim();
                  final newKw = double.tryParse(kwCtrl.text.trim()) ?? 4.0;
                  final newRated = ratedCtrl.text.trim().isNotEmpty ? ratedCtrl.text.trim() : '${newKw}kw';

                  final clonedSpecs = Map<String, String>.from(baseModel.specs);
                  clonedSpecs['Rated Heating Capacity'] = newRated;

                  final newModel = HeatPumpModel(
                    id: 'CUSTOM-${DateTime.now().millisecondsSinceEpoch}',
                    modelName: newName,
                    displayCapacityKw: newKw,
                    ratedHeatingCapacity: newRated,
                    descriptionLine: 'Air Source Heat pump $newRated',
                    makeModelLine: 'Make: IZYHEAT Heat Pump Model: $newName $newRated',
                    powerInputText: 'Power Input ${(newKw * 0.25).toStringAsFixed(2)}kw, output $newRated, 220V - 1Phase, 50Hz With Auto Defrost.',
                    defaultImagePath: baseModel.defaultImagePath,
                    specs: clonedSpecs,
                  );

                  await ref.read(quotationSettingsProvider.notifier).saveModel(newModel);
                  _selectModel(newModel);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✓ Model $newName added successfully!'), backgroundColor: AppColors.success),
                    );
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Model'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteCurrentModel(GeneratorCompanySettings settings) async {
    if (_selectedModel == null || settings.models.length <= 1) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Model?'),
        content: Text('Are you sure you want to delete model "${_selectedModel!.modelName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final delId = _selectedModel!.id;
      final remaining = settings.models.where((m) => m.id != delId).toList();
      await ref.read(quotationSettingsProvider.notifier).deleteModel(delId);
      if (remaining.isNotEmpty) {
        _selectModel(remaining.first);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model deleted')),
        );
      }
    }
  }

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
            // Modern in-page pill tab bar (replaces bulky second AppBar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
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
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.heat_pump_outlined, size: 18),
                      text: 'Product Models',
                      iconMargin: EdgeInsets.only(bottom: 2),
                    ),
                    Tab(
                      icon: Icon(Icons.account_balance_outlined, size: 18),
                      text: 'Company & Bank',
                      iconMargin: EdgeInsets.only(bottom: 2),
                    ),
                    Tab(
                      icon: Icon(Icons.image_outlined, size: 18),
                      text: 'Cover, Banner & Stamp',
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
                  _buildCompanyAndBankTab(settings),
                  _buildCoverAndStampTab(settings),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── TAB 1: PRODUCT MODELS & SPECIFICATIONS ───────────────────────────────

  Widget _buildProductModelsTab(GeneratorCompanySettings settings) {
    // Ensure selected model exists in settings
    if (_selectedModel == null && settings.models.isNotEmpty) {
      _selectedModel = settings.models.first;
    } else if (_selectedModel != null && !settings.models.any((m) => m.id == _selectedModel!.id)) {
      _selectedModel = settings.models.isNotEmpty ? settings.models.first : null;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Heat Pump Model to Edit:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddModelDialog(settings),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Model'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Model Selection Dropdown with Delete button
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: settings.models.any((m) => m.id == _selectedModel?.id)
                        ? _selectedModel?.id
                        : (settings.models.isNotEmpty ? settings.models.first.id : null),
                    hint: const Text('Select Model'),
                    items: settings.models.map((m) {
                      return DropdownMenuItem(
                        value: m.id,
                        child: Text('${m.modelName} (${m.displayCapacityKw} KW)'),
                      );
                    }).toList(),
                    onChanged: (id) {
                      if (id != null) {
                        final found = settings.models.firstWhere((m) => m.id == id);
                        _selectModel(found);
                      }
                    },
                  ),
                ),
              ),
            ),
            if (settings.models.length > 1) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Delete this model',
                onPressed: () => _deleteCurrentModel(settings),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedModel != null) ...[
          // Product Image preview & upload
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey.shade100,
                      child: _selectedModel!.defaultImagePath.startsWith('http')
                          ? Image.network(
                              _selectedModel!.defaultImagePath,
                              fit: BoxFit.contain,
                              loadingBuilder: (_, child, progress) => progress == null
                                  ? child
                                  : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                            )
                          : (_selectedModel!.defaultImagePath.startsWith('assets/')
                              ? Image.asset(_selectedModel!.defaultImagePath, fit: BoxFit.contain)
                              : Image.file(File(_selectedModel!.defaultImagePath), fit: BoxFit.contain)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Product Image for ${_selectedModel!.modelName}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text('Stored in Supabase Storage and shown on the quotation.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(
                            ImageSource.gallery,
                            (url) {
                              final updated = _selectedModel!.copyWith(defaultImagePath: url);
                              ref.read(quotationSettingsProvider.notifier).saveModel(updated);
                              _selectModel(updated);
                            },
                            bucket: 'product-images',
                            folder: 'models',
                          ),
                          icon: const Icon(Icons.upload, size: 14),
                          label: const Text('Upload Product Image', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Model Details Form
          const Text('Basic Model Attributes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _textInput('Model Name', _modelNameCtrl, hint: 'IZ-4C'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _textInput('Display KW', _kwCtrl, hint: '4.0', keyboardType: TextInputType.number),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _textInput('Rated Heating Capacity', _ratedHeatingCtrl, hint: '3.6kw'),
          const SizedBox(height: 10),
          _textInput('Description Line', _descLineCtrl, hint: 'Air Source Heat pump 3.6kw'),
          const SizedBox(height: 10),
          _textInput('Make & Model Line', _makeModelCtrl, hint: 'Make: IZYHEAT Heat Pump Model: IZ-4C 3.6kw'),
          const SizedBox(height: 10),
          _textInput('Power Input & Defrost Text', _powerInputCtrl, hint: 'Power Input 0.86kw, output 3.6kw, 220V...'),
          const SizedBox(height: 16),
          // Specifications table editor
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Technical Specifications (Annexure II)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  final keyCtrl = TextEditingController();
                  final valCtrl = TextEditingController();
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Add Specification Row'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'Spec Name')),
                          const SizedBox(height: 8),
                          TextField(controller: valCtrl, decoration: const InputDecoration(labelText: 'Spec Value')),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () {
                            if (keyCtrl.text.isNotEmpty) {
                              setState(() {
                                _specControllers[keyCtrl.text.trim()] = TextEditingController(text: valCtrl.text.trim());
                              });
                            }
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Add Spec'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._specControllers.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: TextFormField(
                      controller: entry.value,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppColors.error),
                    tooltip: 'Remove ${entry.key}',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _specControllers[entry.key]?.dispose();
                        _specControllers.remove(entry.key);
                      });
                    },
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _saveCurrentModel,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Save Model & Specifications'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  // ─── TAB 2: COMPANY & BANK SETTINGS ───────────────────────────────────────

  Widget _buildCompanyAndBankTab(GeneratorCompanySettings settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Company Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        _textInput('Company Name', _companyNameCtrl),
        const SizedBox(height: 10),
        _textInput('Header Address', _shortAddressCtrl),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _textInput('Phone 1', _phoneCtrl)),
            const SizedBox(width: 10),
            Expanded(child: _textInput('Phone 2', _phone2Ctrl)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _textInput('Email', _emailCtrl)),
            const SizedBox(width: 10),
            Expanded(child: _textInput('Website', _websiteCtrl)),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Bank Account Details (Annexure III)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        _textInput('Account Name', _bankAccountNameCtrl),
        const SizedBox(height: 10),
        _textInput('Bank Name', _bankNameCtrl),
        const SizedBox(height: 10),
        _textInput('Account Number', _bankAccountNumCtrl),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _textInput('Branch', _bankBranchCtrl)),
            const SizedBox(width: 10),
            Expanded(child: _textInput('IFSC Code', _bankIfscCtrl)),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Quotation Numbering & Defaults', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _textInput('Quote Ref Prefix', _quotePrefixCtrl, hint: 'IN/HP/SS')),
            const SizedBox(width: 10),
            Expanded(child: _textInput('Next Running Number', _nextRunningNumCtrl, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _textInput('Default GST %', _gstPercentCtrl, keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _textInput('Validity (Days)', _validityDaysCtrl, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _textInput('HP Warranty (Years)', _hpWarrantyCtrl, keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _textInput('Tank Warranty (Years)', _tankWarrantyCtrl, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _saveGeneralSettings,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Save Company & Bank Settings'),
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
                    ? (imagePath.startsWith('http')
                        ? Image.network(
                            imagePath,
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, progress) => progress == null
                                ? child
                                : const Center(child: CircularProgressIndicator()),
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          )
                        : Image.file(File(imagePath), fit: BoxFit.contain))
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
                      color: AppColors.accent.withOpacity(0.12),
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
}
