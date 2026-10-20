// lib/features/admin/screens/pdf_template_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/app_company.dart';
import '../../../core/providers/company_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'product_catalog_screen.dart';

final pdfTemplatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('pdf_templates')
      .select()
      .order('document_type');

  return List<Map<String, dynamic>>.from(response as List);
});

class PdfTemplateScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const PdfTemplateScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<PdfTemplateScreen> createState() => _PdfTemplateScreenState();
}

class _PdfTemplateScreenState extends ConsumerState<PdfTemplateScreen> {
  final Map<String, Map<String, TextEditingController>> _controllers = {};

  @override
  void dispose() {
    for (final group in _controllers.values) {
      for (final c in group.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(pdfTemplatesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isEmbedded ? null : AppBar(
        title: const Text('PDF Templates & Company Profiles'),
      ),
      body: templatesAsync.when(
        data: (templates) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Multi-Company Profiles Manager
            const _MultiCompanyManagementCard(),
            const SizedBox(height: 20),

            // 2. Product-Company Association Section
            const _ProductCompanyAssignmentCard(),
            const SizedBox(height: 24),

            // 3. Document Template Customization Section
            const Text(
              'Document Template Customization',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            ...templates.map((template) {
              final docType = template['document_type'] as String;
              final config = template['template_config'] as Map<String, dynamic>? ?? {};

              // Initialize controllers for this doc type (only footer and terms)
              if (!_controllers.containsKey(docType)) {
                _controllers[docType] = {};
                final configFields = [
                  'footer_text',
                  'terms_default',
                ];
                for (final field in configFields) {
                  _controllers[docType]![field] =
                      TextEditingController(text: config[field] as String? ?? '');
                }
              }

              return _TemplateCard(
                docType: docType,
                templateId: template['id'] as String,
                controllers: _controllers[docType]!,
                onSave: () => _saveTemplate(template['id'] as String, docType),
              );
            }),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _saveTemplate(String templateId, String docType) async {
    final supabase = ref.read(supabaseClientProvider);
    final controllers = _controllers[docType]!;

    final config = {
      for (final entry in controllers.entries)
        entry.key: entry.value.text.trim().isEmpty ? null : entry.value.text.trim()
    };

    try {
      await supabase
          .from('pdf_templates')
          .update({'template_config': config})
          .eq('id', templateId);

      ref.invalidate(pdfTemplatesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Template updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _TemplateCard extends StatefulWidget {
  final String docType;
  final String templateId;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onSave;

  const _TemplateCard({
    required this.docType,
    required this.templateId,
    required this.controllers,
    required this.onSave,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              _formatDocType(widget.docType),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: IconButton(
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
          // Expanded fields
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...[
                    ('footer_text', 'Footer Text', false),
                    ('terms_default', 'Default Terms & Conditions', true),
                  ].map((field) {
                    final (key, label, multiline) = field;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: widget.controllers[key],
                        maxLines: multiline ? 5 : 1,
                        decoration: InputDecoration(
                          labelText: label,
                          alignLabelWithHint: multiline,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onSave,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      child: const Text('Save Template'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDocType(String type) {
    switch (type) {
      case 'quotation':
        return 'Quotation Template';
      case 'sales_order':
        return 'Sales Order Template';
      case 'boq':
        return 'Bill of Quantities Template';
      case 'factory_order':
        return 'Factory Order Template';
      case 'purchase_order':
        return 'Material Requisition Template';
      case 'amc_contract':
        return 'AMC Contract Template';
      default:
        return type;
    }
  }
}

// ============================================================================
// 1. MULTI-COMPANY MANAGEMENT CARD
// ============================================================================

class _MultiCompanyManagementCard extends ConsumerStatefulWidget {
  const _MultiCompanyManagementCard();

  @override
  ConsumerState<_MultiCompanyManagementCard> createState() =>
      _MultiCompanyManagementCardState();
}

class _MultiCompanyManagementCardState
    extends ConsumerState<_MultiCompanyManagementCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isUploadingLogo = false;
  bool _isUploadingStamp = false;
  bool _isSaving = false;
  bool _isExpanded = false;
  String? _selectedCompanyId;

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();

  // Bank details
  final _bankNameCtrl = TextEditingController();
  final _bankAccountNameCtrl = TextEditingController();
  final _bankAccountNoCtrl = TextEditingController();
  final _bankIfscCtrl = TextEditingController();
  final _bankBranchCtrl = TextEditingController();

  String? _logoUrl;
  String? _stampUrl;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _gstCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountNameCtrl.dispose();
    _bankAccountNoCtrl.dispose();
    _bankIfscCtrl.dispose();
    _bankBranchCtrl.dispose();
    super.dispose();
  }

  void _populateForm(AppCompany company) {
    _nameCtrl.text = company.name;
    _addressCtrl.text = company.address;
    _phoneCtrl.text = company.phone;
    _emailCtrl.text = company.email;
    _websiteCtrl.text = company.website;
    _gstCtrl.text = company.gstin;
    _bankNameCtrl.text = company.bankName;
    _bankAccountNameCtrl.text = company.bankAccountName;
    _bankAccountNoCtrl.text = company.bankAccountNo;
    _bankIfscCtrl.text = company.bankIfsc;
    _bankBranchCtrl.text = company.bankBranch;
    _logoUrl = company.logoUrl;
    _stampUrl = company.stampUrl;
  }

  Future<void> _pickAndUploadImage({required bool isLogo}) async {
    final picker = ImagePicker();
    final image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    setState(() {
      if (isLogo) {
        _isUploadingLogo = true;
      } else {
        _isUploadingStamp = true;
      }
    });

    try {
      final bytes = await image.readAsBytes();
      final supabase = ref.read(supabaseClientProvider);
      final filename =
          '${isLogo ? 'logo' : 'stamp'}_${DateTime.now().millisecondsSinceEpoch}.png';

      await supabase.storage.from('company-assets').uploadBinary(
            filename,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final publicUrl =
          supabase.storage.from('company-assets').getPublicUrl(filename);

      setState(() {
        if (isLogo) {
          _logoUrl = publicUrl;
        } else {
          _stampUrl = publicUrl;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✓ ${isLogo ? "Logo" : "Stamp/Signature"} uploaded! Press "Save Company Details" to persist.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isLogo) {
            _isUploadingLogo = false;
          } else {
            _isUploadingStamp = false;
          }
        });
      }
    }
  }

  void _showImagePreview(String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: url.startsWith('assets/')
                  ? Image.asset(url)
                  : Image.network(url, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 64)),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSelectedCompany(AppCompany current) async {
    setState(() => _isSaving = true);
    try {
      final updated = current.copyWith(
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        website:
            _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
        gstin: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
        logoUrl: _logoUrl,
        stampUrl: _stampUrl,
        bankName: _bankNameCtrl.text.trim().isEmpty
            ? null
            : _bankNameCtrl.text.trim(),
        bankAccountName: _bankAccountNameCtrl.text.trim().isEmpty
            ? null
            : _bankAccountNameCtrl.text.trim(),
        bankAccountNo: _bankAccountNoCtrl.text.trim().isEmpty
            ? null
            : _bankAccountNoCtrl.text.trim(),
        bankIfsc: _bankIfscCtrl.text.trim().isEmpty
            ? null
            : _bankIfscCtrl.text.trim(),
        bankBranch: _bankBranchCtrl.text.trim().isEmpty
            ? null
            : _bankBranchCtrl.text.trim(),
      );

      final service = ref.read(appCompanyServiceProvider);
      await service.saveCompany(updated);

      // If this is default company, also sync to legacy company_settings
      if (updated.isDefault) {
        try {
          final supabase = ref.read(supabaseClientProvider);
          await supabase.from('company_settings').upsert({
            'id': 'default',
            'company_name': updated.name,
            'address': updated.address,
            'phone': updated.phone,
            'email': updated.email,
            'gstin': updated.gstin,
            if (updated.logoUrl != null) 'logo_url': updated.logoUrl,
          });
        } catch (_) {}
      }

      ref.invalidate(pdfTemplatesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ "${updated.name}" details saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving company: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addNewCompanyDialog() async {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.add_business, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Add New Company',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Company Name *',
                  hintText: 'e.g. Insiya Security Corporation',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Company Address',
                  hintText: 'e.g. Office No 101, Business Bay, Pune',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);

              final newId =
                  'company_${DateTime.now().millisecondsSinceEpoch}';
              final newComp = AppCompany(
                id: newId,
                name: nameCtrl.text.trim(),
                address: addressCtrl.text.trim().isEmpty
                    ? 'Pune, Maharashtra'
                    : addressCtrl.text.trim(),
                isDefault: false,
              );

              final service = ref.read(appCompanyServiceProvider);
              await service.saveCompany(newComp);

              setState(() {
                _selectedCompanyId = newId;
                _populateForm(newComp);
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Created company "${newComp.name}"'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Create Company',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final companiesAsync = ref.watch(appCompaniesProvider);

    return companiesAsync.when(
      data: (companies) {
        if (companies.isEmpty) {
          companies = AppCompany.defaultCompanies;
        }

        // Active company resolution
        AppCompany activeCompany;
        try {
          activeCompany = companies.firstWhere((c) => c.id == _selectedCompanyId);
        } catch (_) {
          try {
            activeCompany = companies.firstWhere((c) => c.isDefault);
          } catch (_) {
            activeCompany = companies.first;
          }
          _selectedCompanyId = activeCompany.id;
          _populateForm(activeCompany);
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expandable Card Header
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.apartment_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'Company Profiles & Branding',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Manage companies, default status, bank accounts & logos for quotations',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              if (_isExpanded) ...[
                const Divider(height: 1),
                // Company Selector Tab / Chip Bar
                Container(
                  color: Colors.grey.shade50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...companies.map((c) {
                                final isSelected = c.id == activeCompany.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    selected: isSelected,
                                    selectedColor: AppColors.primary,
                                    backgroundColor: Colors.white,
                                    labelStyle: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                    avatar: Icon(
                                      c.isDefault
                                          ? Icons.star
                                          : Icons.business,
                                      size: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.primary,
                                    ),
                                    label: Text(
                                      c.isDefault
                                          ? '${c.name} (Default)'
                                          : c.name,
                                    ),
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() {
                                          _selectedCompanyId = c.id;
                                          _populateForm(c);
                                        });
                                      }
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _addNewCompanyDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Company',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Active Company Form Fields
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active company header with Default button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    activeCompany.name,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (activeCompany.isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.green.shade300),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle,
                                            size: 12,
                                            color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'DEFAULT',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!activeCompany.isDefault)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.amber.shade800,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final service =
                                    ref.read(appCompanyServiceProvider);
                                await service
                                    .setDefaultCompany(activeCompany.id);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '✓ "${activeCompany.name}" is now the default company!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.star_border, size: 16),
                              label: const Text('Mark as Default',
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Logos & Signatures
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo Section
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text('Company Logo',
                                      style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: _logoUrl != null &&
                                            _logoUrl!.isNotEmpty
                                        ? InkWell(
                                            onTap: () => _showImagePreview(
                                                _logoUrl!, 'Company Logo'),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: _logoUrl!.startsWith('assets/')
                                                  ? Image.asset(_logoUrl!, fit: BoxFit.contain)
                                                  : Image.network(_logoUrl!,
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 28, color: Colors.grey)),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.photo_library_outlined,
                                            color: AppColors.textSecondary,
                                            size: 24),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isUploadingLogo
                                          ? null
                                          : () => _pickAndUploadImage(
                                              isLogo: true),
                                      icon: _isUploadingLogo
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white))
                                          : const Icon(Icons.upload,
                                              size: 14),
                                      label: Text(
                                          _isUploadingLogo
                                              ? 'Uploading...'
                                              : 'Upload',
                                          style: const TextStyle(
                                              fontSize: 11)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 6),
                                        visualDensity:
                                            VisualDensity.compact,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Stamp Section
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text('Stamp / Sign',
                                      style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: _stampUrl != null &&
                                            _stampUrl!.isNotEmpty
                                        ? InkWell(
                                            onTap: () => _showImagePreview(
                                                _stampUrl!,
                                                'Stamp / Signature'),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: _stampUrl!.startsWith('assets/')
                                                  ? Image.asset(_stampUrl!, fit: BoxFit.contain)
                                                  : Image.network(_stampUrl!,
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 28, color: Colors.grey)),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.verified_outlined,
                                            color: AppColors.textSecondary,
                                            size: 24),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isUploadingStamp
                                          ? null
                                          : () => _pickAndUploadImage(
                                              isLogo: false),
                                      icon: _isUploadingStamp
                                          ? const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white))
                                          : const Icon(Icons.upload,
                                              size: 14),
                                      label: Text(
                                          _isUploadingStamp
                                              ? 'Uploading...'
                                              : 'Upload',
                                          style: const TextStyle(
                                              fontSize: 11)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 6),
                                        visualDensity:
                                            VisualDensity.compact,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Basic Details Form
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Company Name *',
                          prefixIcon: Icon(Icons.business),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Company Address *',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _websiteCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Website',
                                prefixIcon: Icon(Icons.language_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _gstCtrl,
                              decoration: const InputDecoration(
                                labelText: 'GSTIN',
                                prefixIcon: Icon(Icons.receipt_long_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Bank Details Section
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.account_balance,
                                    size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Bank Account Details (Used on Quotations & Invoices)',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _bankNameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Bank Name',
                                      hintText: 'e.g. Kotak Mahindra Bank',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _bankAccountNameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Account Holder Name',
                                      hintText: 'e.g. Insiya Trading Corporation',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _bankAccountNoCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Account Number',
                                      hintText: 'e.g. 5212574044',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _bankIfscCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'IFSC Code',
                                      hintText: 'e.g. KKBK0001768',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _bankBranchCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Branch',
                                      hintText: 'e.g. Viman Nagar',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Action buttons: Save & Delete
                      Row(
                        children: [
                          if (!activeCompany.isDefault &&
                              companies.length > 1)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Company?'),
                                    content: Text(
                                        'Are you sure you want to delete "${activeCompany.name}"?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.error),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete',
                                            style: TextStyle(
                                                color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref
                                      .read(appCompanyServiceProvider)
                                      .deleteCompany(activeCompany.id);
                                  setState(() => _selectedCompanyId = null);
                                }
                              },
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Delete Company'),
                            ),
                          if (!activeCompany.isDefault &&
                              companies.length > 1)
                            const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () => _saveSelectedCompany(activeCompany),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save),
                              label: Text(_isSaving
                                  ? 'Saving...'
                                  : 'Save "${activeCompany.name}" Details'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error loading companies: $e')),
    );
  }
}

// ============================================================================
// 2. PRODUCT-COMPANY ASSIGNMENT CARD
// ============================================================================

class _ProductCompanyAssignmentCard extends ConsumerWidget {
  const _ProductCompanyAssignmentCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final companiesAsync = ref.watch(appCompaniesProvider);
    final defaultCompany = ref.watch(defaultCompanyProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.link_rounded,
                      color: Colors.indigo.shade700, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Default Company for Sell Products',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Deals & quotations created for a product will automatically use its assigned company profile and bank details.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            productsAsync.when(
              data: (products) {
                final companies = companiesAsync.valueOrNull ?? AppCompany.defaultCompanies;

                if (products.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No sell products found in inventory.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    
                    // Determine current assigned company id
                    String? assignedCompanyId = product.companyId;
                    if (assignedCompanyId == null || assignedCompanyId.isEmpty) {
                      // Fallback heuristic for Boom Barrier if not set
                      if (product.name.toLowerCase().contains('boom') ||
                          product.name.toLowerCase().contains('barrier')) {
                        assignedCompanyId = 'insiya-trading';
                      } else {
                        assignedCompanyId = defaultCompany.id;
                      }
                    }

                    // Check if assigned company is valid in companies list
                    final currentCompExists = companies.any((c) => c.id == assignedCompanyId);
                    final effectiveValue = currentCompExists ? assignedCompanyId : defaultCompany.id;

                    Widget buildDropdown() {
                      return DropdownButtonFormField<String>(
                        initialValue: effectiveValue,
                        isDense: true,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.apartment, size: 18),
                        ),
                        items: companies.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(
                              c.isDefault ? '${c.name} ★' : c.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: c.isDefault
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (newCompanyId) async {
                          if (newCompanyId == null ||
                              newCompanyId == product.companyId) {
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          final service =
                              ref.read(appCompanyServiceProvider);
                          await service.assignProductCompany(
                              product.id, newCompanyId);

                          final companyName = companies
                              .where((c) => c.id == newCompanyId)
                              .firstOrNull
                              ?.name ?? newCompanyId;

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                  '✓ "${product.name}" will now use "$companyName" on deals & quotations.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 450;
                        if (isCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySurface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined,
                                        size: 20, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (product.category != null &&
                                            product.category!.isNotEmpty)
                                          Text(
                                            product.category!,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              buildDropdown(),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.inventory_2_outlined,
                                  size: 20, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (product.category != null &&
                                      product.category!.isNotEmpty)
                                    Text(
                                      product.category!,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: buildDropdown(),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primary),
              )),
              error: (e, _) => Text('Error loading products: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
