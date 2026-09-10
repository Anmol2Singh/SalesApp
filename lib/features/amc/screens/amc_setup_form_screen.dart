// lib/features/amc/screens/amc_setup_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/amc_contract.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/amc_provider.dart';

class AmcSetupFormScreen extends ConsumerStatefulWidget {
  final String? amcId;
  final String? customerId;
  final String? productId;
  final String? pipelineId;

  const AmcSetupFormScreen({
    super.key,
    this.amcId,
    this.customerId,
    this.productId,
    this.pipelineId,
  });

  @override
  ConsumerState<AmcSetupFormScreen> createState() => _AmcSetupFormScreenState();
}

class _AmcSetupFormScreenState extends ConsumerState<AmcSetupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _visitsController = TextEditingController(text: '4');
  final _yearsController = TextEditingController(text: '1');
  final _termsController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));

  void _onYearsChanged(String val) {
    final yrs = int.tryParse(val) ?? 1;
    if (yrs > 0) {
      setState(() {
        _endDate = DateTime(_startDate.year + yrs, _startDate.month, _startDate.day);
      });
    }
  }
  bool _isLoading = false;
  bool _isSaving = false;
  AmcContract? _existingContract;

  String? _selectedCustomerId;
  String? _selectedProductId;
  String? _customerName;
  String? _productName;
  List<Map<String, dynamic>> _customersList = [];
  List<Map<String, dynamic>> _productsList = [];

  @override
  void initState() {
    super.initState();
    if (widget.amcId != null) {
      _loadExistingContract();
    } else {
      _loadContextInfo();
    }
  }

  Future<void> _loadContextInfo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await _loadDefaultTerms();
      final supabase = ref.read(supabaseClientProvider);
      final validCustId = (widget.customerId != null && widget.customerId!.isNotEmpty && widget.customerId != 'null')
          ? widget.customerId
          : null;
      final validProdId = (widget.productId != null && widget.productId!.isNotEmpty && widget.productId != 'null')
          ? widget.productId
          : null;

      if (validCustId != null) {
        _selectedCustomerId = validCustId;
        try {
          final res = await supabase.from('customers').select().eq('id', validCustId).maybeSingle();
          if (res != null) {
            _customerName = res['customer_name'] ?? res['company_name'] ?? res['contact_person'] ?? 'Selected Customer';
          }
        } catch (_) {}
      }
      
      try {
        final cRes = await supabase.from('customers').select('id, customer_name').limit(50);
        if (cRes != null && mounted) {
          _customersList = (cRes as List).cast<Map<String, dynamic>>();
          if (_selectedCustomerId == null && _customersList.isNotEmpty) {
            _selectedCustomerId = _customersList.first['id'] as String?;
            _customerName = _customersList.first['customer_name'] as String?;
          }
        }
      } catch (_) {}

      if (validProdId != null) {
        _selectedProductId = validProdId;
        try {
          final res = await supabase.from('products').select('name').eq('id', validProdId).maybeSingle();
          if (res != null) {
            _productName = res['name'] ?? 'Selected Product';
          }
        } catch (_) {}
      }

      try {
        final pRes = await supabase.from('products').select('id, name').limit(50);
        if (pRes != null && mounted) {
          _productsList = (pRes as List).cast<Map<String, dynamic>>();
          if (_selectedProductId == null && _productsList.isNotEmpty) {
            _selectedProductId = _productsList.first['id'] as String?;
            _productName = _productsList.first['name'] as String?;
          }
        }
      } catch (_) {}
    } catch (e) {
      print('AMC Context Load Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDefaultTerms() async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final templateData = await supabase
          .from('pdf_templates')
          .select()
          .eq('document_type', 'amc_contract')
          .maybeSingle();
      if (templateData != null && mounted) {
        final config = templateData['template_config'] as Map<String, dynamic>?;
        if (config != null && config['terms_default'] != null) {
          _termsController.text = config['terms_default'] as String;
        }
      }
    } catch (_) {}
  }

  Future<void> _loadExistingContract() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('amc_contracts')
          .select('*, customers(customer_name), products(name)')
          .eq('id', widget.amcId!)
          .single();

      final contract = AmcContract.fromJson(response);
      if (mounted) {
        setState(() {
          _existingContract = contract;
          if (contract.startDate != null) _startDate = contract.startDate!;
          if (contract.endDate != null) _endDate = contract.endDate!;
          if (contract.contractAmount != null) {
            _amountController.text =
                contract.contractAmount!.toStringAsFixed(2);
          }
          if (contract.numberOfVisitsIncluded != null) {
            _visitsController.text = '${contract.numberOfVisitsIncluded}';
          }
          if (contract.termsText != null && contract.termsText!.isNotEmpty) {
            _termsController.text = contract.termsText!;
          } else {
            _loadDefaultTerms();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading contract: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _visitsController.dispose();
    _yearsController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/deals');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: const Color(0xFF6D28D9),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/deals');
              }
            },
          ),
          title: Text(
            _existingContract != null
                ? 'Finalize AMC Contract'
                : 'New AMC Contract',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Context info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _existingContract?.customer?.customerName ??
                              _existingContract?.customer?.companyName ??
                              _customerName ??
                              'Contract Setup',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _existingContract?.product?.name ?? _productName ?? 'Product AMC',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_selectedCustomerId == null && _customersList.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedCustomerId,
                      decoration: const InputDecoration(labelText: 'Select Customer *', border: OutlineInputBorder()),
                      items: _customersList.map((c) {
                        final name = c['customer_name'] ?? c['company_name'] ?? c['contact_person'] ?? 'Customer';
                        return DropdownMenuItem(value: c['id'] as String, child: Text(name));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCustomerId = val),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _yearsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Contract / Warranty Duration (Years)',
                      hintText: 'e.g. 1, 2, 3, 5 years',
                      prefixIcon: Icon(Icons.timer_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _onYearsChanged,
                  ),
                  const SizedBox(height: 16),

                  // Contract Period
                  const Text(
                    'Contract Period',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerField(
                          label: 'Start Date',
                          value: _startDate,
                          formattedValue: dateFormat.format(_startDate),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 90)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                _startDate = picked;
                                // Auto-adjust end date to be 1 year later
                                _endDate = DateTime(
                                    picked.year + 1, picked.month, picked.day);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DatePickerField(
                          label: 'End Date',
                          value: _endDate,
                          formattedValue: dateFormat.format(_endDate),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: _startDate,
                              lastDate:
                                  _startDate.add(const Duration(days: 365 * 5)),
                            );
                            if (picked != null) {
                              setState(() => _endDate = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Amount & Visits
                  const Text(
                    'Contract Terms',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Contract Amount (₹)',
                            prefixText: '₹ ',
                            hintText: '0.00',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Required';
                            }
                            final amount = double.tryParse(val.trim());
                            if (amount == null || amount <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _visitsController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Visits',
                            hintText: '4',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Required';
                            }
                            final n = int.tryParse(val.trim());
                            if (n == null || n < 1 || n > 52) {
                              return '1-52';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Terms
                  const Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _termsController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: 'Enter terms and conditions...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Activate AMC Contract',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id ?? ref.read(currentProfileProvider)?.id ?? 'system_admin';
      final amount = double.parse(_amountController.text.trim());
      final numVisits = int.parse(_visitsController.text.trim());
      final terms = _termsController.text.trim();

      String amcId;

      if (_existingContract != null) {
        // Update existing contract
        await supabase.from('amc_contracts').update({
          'status': 'active',
          'start_date': _startDate.toIso8601String().split('T').first,
          'end_date': _endDate.toIso8601String().split('T').first,
          'contract_amount': amount,
          'number_of_visits_included': numVisits,
          'terms_text': terms.isEmpty ? null : terms,
        }).eq('id', _existingContract!.id);
        amcId = _existingContract!.id;
      } else {
        // Create new contract
        final response = await supabase
            .from('amc_contracts')
            .insert({
              'customer_id': _selectedCustomerId ?? widget.customerId ?? '',
              'pipeline_id': widget.pipelineId,
              'product_id': _selectedProductId ?? widget.productId ?? '',
              'status': 'active',
              'start_date': _startDate.toIso8601String().split('T').first,
              'end_date': _endDate.toIso8601String().split('T').first,
              'contract_amount': amount,
              'number_of_visits_included': numVisits,
              'terms_text': terms.isEmpty ? null : terms,
              'created_by': userId,
            })
            .select('id')
            .single();
        amcId = (response as Map)['id'] as String;
      }

      // Generate service visits evenly spaced across contract period
      final totalDays = _endDate.difference(_startDate).inDays;
      final interval = totalDays / numVisits;

      final visits = <Map<String, dynamic>>[];
      for (int i = 0; i < numVisits; i++) {
        final visitDate =
            _startDate.add(Duration(days: (interval * (i + 0.5)).round()));
        visits.add({
          'amc_contract_id': amcId,
          'visit_number': i + 1,
          'scheduled_date': visitDate.toIso8601String().split('T').first,
          'status': 'scheduled',
        });
      }

      // Delete any existing visits first (in case of re-setup)
      await supabase
          .from('amc_service_visits')
          .delete()
          .eq('amc_contract_id', amcId);

      // Insert new visits
      await supabase.from('amc_service_visits').insert(visits);

      // Write audit log
      await supabase.from('step_audit_log').insert({
        'amc_contract_id': amcId,
        'step_name': 'amc_contract',
        'action': _existingContract != null ? 'amc_activated' : 'amc_created',
        'performed_by': userId,
        'notes':
            'AMC activated. Amount: ₹${NumberFormat('#,##,##0.00', 'en_IN').format(amount)}, $numVisits visits.',
      });

      // Invalidate providers
      ref.invalidate(amcNotifierProvider);
      ref.invalidate(amcDetailProvider(amcId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ AMC contract activated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        // Navigate to detail
        context.go(AppRoutes.amcDetail.replaceAll(':id', amcId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime value;
  final String formattedValue;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.formattedValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          formattedValue,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
