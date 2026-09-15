import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salesapp/core/providers/supabase_provider.dart';
import 'package:salesapp/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/features/support/screens/support_screen.dart';

class CompanyHelplineScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const CompanyHelplineScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<CompanyHelplineScreen> createState() => _CompanyHelplineScreenState();
}

class _CompanyHelplineScreenState extends ConsumerState<CompanyHelplineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadHelplineSettings();
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _hoursCtrl.dispose();
    _addressCtrl.dispose();
    _gstinCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHelplineSettings() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      
      // 1. Try company_settings
      final data = await supabase
          .from('company_settings')
          .select()
          .eq('id', 'default')
          .maybeSingle();

      if (data != null) {
        _companyNameCtrl.text = data['company_name'] as String? ?? 'Insiya Solar Industry';
        _phoneCtrl.text = data['phone'] as String? ?? '+91 99999 99999';
        _whatsappCtrl.text = data['whatsapp'] as String? ?? data['phone'] as String? ?? '+91 99999 99999';
        _emailCtrl.text = data['email'] as String? ?? 'info@insiyasolar.com';
        _hoursCtrl.text = data['working_hours'] as String? ?? 'Mon - Sat: 9:00 AM - 7:00 PM';
        _addressCtrl.text = data['address'] as String? ??
            'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra - 411014';
        _gstinCtrl.text = data['gstin'] as String? ?? '27AAAAA1111A1Z1';
      }

      // 2. Also check pdf_templates template_config for address/whatsapp/working_hours
      try {
        final tmplRes = await supabase.from('pdf_templates').select('template_config').limit(1).maybeSingle();
        if (tmplRes != null && tmplRes['template_config'] != null) {
          final cfg = tmplRes['template_config'] as Map<String, dynamic>;
          if (cfg['company_address'] != null && (data == null || data['address'] == null)) {
            _addressCtrl.text = cfg['company_address'] as String;
          }
          if (cfg['company_whatsapp'] != null && (data == null || data['whatsapp'] == null)) {
            _whatsappCtrl.text = cfg['company_whatsapp'] as String;
          }
          if (cfg['working_hours'] != null && (data == null || data['working_hours'] == null)) {
            _hoursCtrl.text = cfg['working_hours'] as String;
          }
          if (cfg['company_name'] != null && data == null) {
            _companyNameCtrl.text = cfg['company_name'] as String;
          }
          if (cfg['company_phone'] != null && data == null) {
            _phoneCtrl.text = cfg['company_phone'] as String;
          }
          if (cfg['company_email'] != null && data == null) {
            _emailCtrl.text = cfg['company_email'] as String;
          }
          if (cfg['company_gst'] != null && data == null) {
            _gstinCtrl.text = cfg['company_gst'] as String;
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading company helpline settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveHelplineSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      // 1. Try upserting to company_settings safely
      final basicData = <String, dynamic>{
        'id': 'default',
        'company_name': _companyNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'gstin': _gstinCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        final extendedData = {
          ...basicData,
          'whatsapp': _whatsappCtrl.text.trim(),
          'working_hours': _hoursCtrl.text.trim(),
        };
        await supabase.from('company_settings').upsert(extendedData);
      } catch (_) {
        try {
          await supabase.from('company_settings').upsert(basicData);
        } catch (_) {}
      }

      // 2. Sync to pdf_templates template_config so PDF footers and customer support screens match
      try {
        final existingTemplates = await supabase.from('pdf_templates').select('id, template_config');
        for (final tmpl in (existingTemplates as List? ?? [])) {
          final id = tmpl['id'] as String;
          final cfg = Map<String, dynamic>.from(tmpl['template_config'] as Map? ?? {});
          cfg['company_name'] = _companyNameCtrl.text.trim();
          cfg['company_phone'] = _phoneCtrl.text.trim();
          cfg['company_email'] = _emailCtrl.text.trim();
          cfg['company_address'] = _addressCtrl.text.trim();
          cfg['company_gst'] = _gstinCtrl.text.trim();
          cfg['company_whatsapp'] = _whatsappCtrl.text.trim();
          cfg['working_hours'] = _hoursCtrl.text.trim();
          await supabase.from('pdf_templates').update({'template_config': cfg}).eq('id', id);
        }
      } catch (_) {}

      // Invalidate customer support contact provider
      ref.invalidate(companyContactProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Company Helpline & Contact Details updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save helpline settings: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Company Helpline & Support Info',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'These details appear on customer "Contact Us & Support" page and PDF documents.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Company Name
          TextFormField(
            controller: _companyNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Company / Business Name *',
              prefixIcon: Icon(Icons.business_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          // Primary Phone
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Helpline Phone Number *',
              hintText: '+91 99999 99999',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          // WhatsApp Support Number
          TextFormField(
            controller: _whatsappCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp Helpline Number',
              hintText: '+91 99999 99999',
              prefixIcon: Icon(Icons.chat_bubble_outline, color: Colors.green),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Support Email *',
              hintText: 'support@insiyasolar.com',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          // Working Hours
          TextFormField(
            controller: _hoursCtrl,
            decoration: const InputDecoration(
              labelText: 'Support Working Hours',
              hintText: 'Mon - Sat: 9:00 AM - 7:00 PM',
              prefixIcon: Icon(Icons.access_time_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // GSTIN
          TextFormField(
            controller: _gstinCtrl,
            decoration: const InputDecoration(
              labelText: 'Company GSTIN',
              prefixIcon: Icon(Icons.receipt_long_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Company Address
          TextFormField(
            controller: _addressCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Registered Head Office Address *',
              hintText: 'Full company physical address...',
              prefixIcon: Icon(Icons.location_on_outlined),
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 24),

          // Save Button
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveHelplineSettings,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _isSaving ? 'Saving Changes...' : 'Save Helpline Settings',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
