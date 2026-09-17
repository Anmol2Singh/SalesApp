// lib/features/customers/screens/create_customer_screen.dart
// Includes fuzzy dedupe check before allowing creation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/models/customer.dart';
import '../providers/customers_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/services/offline_queue_service.dart';

class CreateCustomerScreen extends ConsumerStatefulWidget {
  const CreateCustomerScreen({super.key});

  @override
  ConsumerState<CreateCustomerScreen> createState() =>
      _CreateCustomerScreenState();
}

class _CreateCustomerScreenState extends ConsumerState<CreateCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();

  bool _isLoading = false;
  bool _dedupeChecked = false;
  List<Map<String, dynamic>> _duplicateSuggestions = [];
  bool _isGstRegistered = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _checkForDuplicates() async {
    final name = _companyNameController.text.trim();
    if (name.length < 3) return;

    try {
      final List<Map<String, dynamic>> results = await ref.read(
        customerSearchProvider(name).future,
      );

      if (results.isNotEmpty) {
        setState(() => _duplicateSuggestions = results);
        _showDuplicateDialog();
      } else {
        setState(() {
          _dedupeChecked = true;
          _duplicateSuggestions = [];
        });
      }
    } catch (_) {
      setState(() {
        _dedupeChecked = true;
        _duplicateSuggestions = [];
      });
    }
  }

  void _showDuplicateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Similar Customers Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The following customers look similar. Would you like to add a product to an existing customer?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ..._duplicateSuggestions.take(5).map((c) => ListTile(
                  title: Text(
                    c['customer_name'] as String? ?? c['company_name'] as String? ?? '',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    [c['contact_person'], c['phone']]
                        .where((v) => v != null && v.toString().isNotEmpty)
                        .join(' • '),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.go(
                      AppRoutes.customerDetail
                          .replaceAll(':id', c['id'] as String? ?? ''),
                    );
                  },
                  contentPadding: EdgeInsets.zero,
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _dedupeChecked = true;
                _duplicateSuggestions = [];
              });
            },
            child: const Text('Create New Anyway'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_dedupeChecked) {
      await _checkForDuplicates();
      if (!_dedupeChecked) return; // User chose existing or went back
    }

    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser!.id;
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();

      // Block duplicate phone or email
      if (phone.isNotEmpty || email.isNotEmpty) {
        String filterStr = '';
        if (phone.isNotEmpty && email.isNotEmpty) {
          filterStr = 'phone.eq.$phone,email.eq.$email';
        } else if (phone.isNotEmpty) {
          filterStr = 'phone.eq.$phone';
        } else {
          filterStr = 'email.eq.$email';
        }
        final duplicateCheck = await supabase
            .from('customers')
            .select('id, customer_name, company_name')
            .or(filterStr)
            .isFilter('deleted_at', null)
            .maybeSingle();

        if (duplicateCheck != null) {
          setState(() => _isLoading = false);
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Duplicate Blocked'),
                content: Text(
                  'A customer with this phone number or email already exists: "${duplicateCheck['customer_name'] ?? duplicateCheck['company_name']}". Duplicate entries are blocked.',
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.customerDetail.replaceAll(':id', duplicateCheck['id'] as String));
                    },
                    child: const Text('View Existing'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      final customerName = _companyNameController.text.trim();
      final contactPerson = _contactPersonController.text.trim().isEmpty
          ? customerName
          : _contactPersonController.text.trim();

      final data = {
        'customer_name': customerName,
        'company_name': customerName,
        'contact_person': contactPerson,
        'phone': phone.isEmpty ? null : phone,
        'email': email.isEmpty ? null : email,
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'gst_number': _gstController.text.trim().isEmpty
            ? null
            : _gstController.text.trim(),
        'created_by': userId,
      };

      final isOnline = ref.read(isOnlineProvider);
      
      if (!isOnline) {
        final id = const Uuid().v4();
        data['id'] = id;
        
        await ref.read(offlineQueueProvider).queueWrite('create_customer', data);
        ref.invalidate(customersNotifierProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer created locally. Will sync when online.'),
              backgroundColor: Colors.amber,
            ),
          );
          context.pop();
        }
        return;
      }

      final response =
          await supabase.from('customers').insert(data).select().single();

      final customer = Customer.fromJson(response);

      // Ensure customer_profiles does not store synthetic/random emails when email is omitted
      if (phone.isNotEmpty) {
        try {
          final cleanEmail = email.isNotEmpty ? email : null;
          await supabase
              .from('customer_profiles')
              .update({'email': cleanEmail})
              .eq('phone', phone);
        } catch (_) {}
      }

      // Invalidate list
      ref.invalidate(customersNotifierProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        // Navigate to customer detail to immediately add a pipeline
        context.go(AppRoutes.customerDetail.replaceAll(':id', customer.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Customer'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(title: 'Customer Details'),
              TextFormField(
                controller: _companyNameController,
                textInputAction: TextInputAction.next,
                onEditingComplete: _checkForDuplicates,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  hintText: 'e.g. John Doe or ABC Industries',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Customer name is required'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contactPersonController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Contact Person (Optional)',
                  hintText: 'Primary contact name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => null,
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: 'Contact Information'),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '+91 XXXXXXXXXX',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  if (!RegExp(r'^[+]?[\d\s\-()]{8,15}$').hasMatch(v)) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email Address (Optional)',
                  hintText: 'contact@company.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return null;
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(v.trim())) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: 'Other Details'),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  hintText: 'Full business address',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.location_on_outlined),
                  ),
                  alignLabelWithHint: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Address is required'
                    : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Checkbox(
                    value: _isGstRegistered,
                    onChanged: (val) {
                      setState(() {
                        _isGstRegistered = val ?? false;
                        if (!_isGstRegistered) {
                          _gstController.clear();
                        }
                      });
                    },
                  ),
                  const Text(
                    'Is GST Registered?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _gstController,
                enabled: _isGstRegistered,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: _isGstRegistered
                      ? 'GST Number *'
                      : 'GST Number (Disabled)',
                  hintText: '22AAAAA0000A1Z5',
                  prefixIcon: const Icon(Icons.receipt_long_outlined),
                ),
                validator: (v) {
                  if (_isGstRegistered) {
                    if (v == null || v.trim().isEmpty) {
                      return 'GST Number is required';
                    }
                    if (!RegExp(
                            r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$')
                        .hasMatch(v)) {
                      return 'Enter a valid GSTIN (15 characters)';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Customer'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
