// lib/features/admin/screens/pdf_template_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/supabase_provider.dart';

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
        title: const Text('PDF Templates'),
      ),
      body: templatesAsync.when(
        data: (templates) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Unified Company Details & Logo Card
            const _CompanyDetailsCard(),
            const SizedBox(height: 20),
            const Text('Document Template Customization', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.picture_as_pdf_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formatDocType(widget.docType),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
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

class _CompanyDetailsCard extends ConsumerStatefulWidget {
  const _CompanyDetailsCard();

  @override
  ConsumerState<_CompanyDetailsCard> createState() => _CompanyDetailsCardState();
}

class _CompanyDetailsCardState extends ConsumerState<_CompanyDetailsCard> {
  bool _isUploading = false;
  bool _isSaving = false;
  bool _isExpanded = false;
  String? _logoUrl;

  final _nameCtrl = TextEditingController(text: 'INSIYA SOLAR INDUSTRY');
  final _addressCtrl = TextEditingController(text: 'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra 411014');
  final _phoneCtrl = TextEditingController(text: '+91 9292922992');
  final _emailCtrl = TextEditingController(text: 'insiyasolarindustry@gmail.com');
  final _gstCtrl = TextEditingController(text: '27CFTPS5292A1ZY');

  @override
  void initState() {
    super.initState();
    _fetchCompanyDetails();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _gstCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanyDetails() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final data = await supabase.from('company_settings').select().maybeSingle();
      if (data != null) {
        if (data['logo_url'] != null) setState(() => _logoUrl = data['logo_url'] as String);
        if (data['company_name'] != null) _nameCtrl.text = data['company_name'] as String;
        if (data['address'] != null) _addressCtrl.text = data['address'] as String;
        if (data['phone'] != null) _phoneCtrl.text = data['phone'] as String;
        if (data['email'] != null) _emailCtrl.text = data['email'] as String;
        if (data['gstin'] != null) _gstCtrl.text = data['gstin'] as String;
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await image.readAsBytes();
      final supabase = ref.read(supabaseClientProvider);
      final filename = 'logo_${DateTime.now().millisecondsSinceEpoch}.png';
      
      await supabase.storage.from('company-assets').uploadBinary(
        filename,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      final publicUrl = supabase.storage.from('company-assets').getPublicUrl(filename);

      setState(() => _logoUrl = publicUrl);

      // Sync to pdf_templates
      final templates = await supabase.from('pdf_templates').select();
      for (final t in templates as List) {
        final config = Map<String, dynamic>.from(t['template_config'] as Map? ?? {});
        config['logo_url'] = publicUrl;
        await supabase.from('pdf_templates').update({'template_config': config}).eq('id', t['id']);
      }

      // Try syncing to company_settings safely
      try {
        await supabase.from('company_settings').upsert({
          'id': 'default',
          'logo_url': publicUrl,
          'company_name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'gstin': _gstCtrl.text.trim(),
        });
      } catch (_) {}

      ref.invalidate(pdfTemplatesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Company Logo uploaded & updated across all PDF templates!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading logo: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showLogoPreview() {
    if (_logoUrl == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.network(_logoUrl!)),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCompanyDetails() async {
    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseClientProvider);

      // Update all pdf_templates template_config so it syncs globally
      final templates = await supabase.from('pdf_templates').select();
      for (final t in templates as List) {
        final config = Map<String, dynamic>.from(t['template_config'] as Map? ?? {});
        config['company_name'] = _nameCtrl.text.trim();
        config['company_address'] = _addressCtrl.text.trim();
        config['company_phone'] = _phoneCtrl.text.trim();
        config['company_email'] = _emailCtrl.text.trim();
        config['company_gst'] = _gstCtrl.text.trim();
        if (_logoUrl != null) config['logo_url'] = _logoUrl;

        await supabase.from('pdf_templates').update({'template_config': config}).eq('id', t['id']);
      }

      // Try updating company_settings safely
      try {
        await supabase.from('company_settings').upsert({
          'id': 'default',
          'company_name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'gstin': _gstCtrl.text.trim(),
          if (_logoUrl != null) 'logo_url': _logoUrl,
        });
      } catch (_) {}

      ref.invalidate(pdfTemplatesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Company Details saved globally across all templates!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving details: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          // Expandable Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.business_center_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company Details & Branding',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Global company name, address, phone, email & logo',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textSecondary),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo Upload Section
                  Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _logoUrl != null && _logoUrl!.isNotEmpty
                            ? InkWell(
                                onTap: () => _showLogoPreview(),
                                child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_logoUrl!, fit: BoxFit.contain)),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.photo_library_outlined, color: AppColors.textSecondary, size: 24),
                                  SizedBox(height: 2),
                                  Text('No Logo', style: TextStyle(fontFamily: 'Inter', fontSize: 9, color: AppColors.textSecondary)),
                                ],
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Official Company Logo', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            ElevatedButton.icon(
                              onPressed: _isUploading ? null : _pickAndUploadLogo,
                              icon: _isUploading
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.upload_file, size: 15),
                              label: Text(_isUploading ? 'Uploading...' : 'Upload Logo'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Text fields (Email on separate next line!)
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Company Name')),
                  const SizedBox(height: 10),
                  TextField(controller: _addressCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Company Address')),
                  const SizedBox(height: 10),
                  TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                  const SizedBox(height: 10),
                  TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email (Next Line)')),
                  const SizedBox(height: 10),
                  TextField(controller: _gstCtrl, decoration: const InputDecoration(labelText: 'GSTIN')),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveCompanyDetails,
                      icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving Details...' : 'Save Company Details Globally'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
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
}
