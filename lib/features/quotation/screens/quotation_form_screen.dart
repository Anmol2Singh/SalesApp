// lib/features/quotation/screens/quotation_form_screen.dart
// Step 1: Dynamic quotation form with line items, CGST/SGST/IGST, confirm gate

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/quotation.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/pipeline.dart';
import '../../../core/models/user_role.dart';
import '../../../core/widgets/inventory_autocomplete.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pipelines/providers/pipelines_provider.dart';
import '../../crm/providers/crm_providers.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/widgets/pdf_preview_screen.dart';

class QuotationFormScreen extends ConsumerStatefulWidget {
  final String? pipelineId;
  final String? leadId;
  final Quotation? initialQuotation;
  final int? revisionNumber;

  const QuotationFormScreen({
    super.key,
    this.pipelineId,
    this.leadId,
    this.initialQuotation,
    this.revisionNumber,
  }) : assert(pipelineId != null || leadId != null, 'Either pipelineId or leadId must be provided');

  @override
  ConsumerState<QuotationFormScreen> createState() =>
      _QuotationFormScreenState();
}

class _QuotationFormScreenState extends ConsumerState<QuotationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _termsController = TextEditingController();

  // New document meta controllers
  final _salesOrderNoController = TextEditingController();
  final _placeOfSupplyController = TextEditingController();
  final _distanceController = TextEditingController();
  final _grLrNoController = TextEditingController();
  final _destinationController = TextEditingController();
  final _remarksController =
      TextEditingController(text: 'Being Quotation Generated');
  DateTime _orderDate = DateTime.now();
  String _billType = 'Credit';

  // New billing/customer controllers
  final _customerNameController = TextEditingController();
  final _billingAddressController = TextEditingController();
  final _customerGstinController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _partyContactPersonController = TextEditingController();

  // New shipping controllers
  final _shippingNameController = TextEditingController();
  final _shippingAddressController = TextEditingController();
  final _stateCodeController = TextEditingController(text: '27');
  final _salesmanController = TextEditingController();

  // Dynamic product spec fields
  final Map<String, TextEditingController> _specControllers = {};
  final Map<String, String?> _specDropdownValues = {};

  // Line items
  final List<Map<String, dynamic>> _lineItems = [];

  // GST rates
  double _cgstRate = 9.0;
  double _sgstRate = 9.0;

  int _currentRevision = 1;
  final List<Map<String, dynamic>> _paymentTerms = [
    {'term': 'Advance', 'percent': 50.0, 'amount': 0.0},
    {'term': 'Dispatch', 'percent': 40.0, 'amount': 0.0},
    {'term': 'Installation', 'percent': 5.0, 'amount': 0.0},
    {'term': 'Completion', 'percent': 5.0, 'amount': 0.0},
  ];

  static final List<Map<String, dynamic>> _defaultPaymentTemplates = [
    {
      'name': 'Standard (50 / 40 / 5 / 5)',
      'terms': [
        {'term': 'Advance', 'percent': 50.0},
        {'term': 'Dispatch', 'percent': 40.0},
        {'term': 'Installation', 'percent': 5.0},
        {'term': 'Completion', 'percent': 5.0},
      ],
    },
    {
      'name': 'Milestone (30 / 60 / 10)',
      'terms': [
        {'term': 'Advance', 'percent': 30.0},
        {'term': 'Dispatch', 'percent': 60.0},
        {'term': 'Completion', 'percent': 10.0},
      ],
    },
    {
      'name': '100% Full Advance',
      'terms': [
        {'term': 'Advance', 'percent': 100.0},
      ],
    },
    {
      'name': 'Custom (4 Stages)',
      'terms': [
        {'term': 'Advance', 'percent': 0.0},
        {'term': 'Dispatch', 'percent': 0.0},
        {'term': 'Installation', 'percent': 0.0},
        {'term': 'Completion', 'percent': 0.0},
      ],
    },
  ];

  static final List<Map<String, dynamic>> _customPaymentTemplates = [];
  bool _isCustomTermsEditing = false;

  void _applyPaymentTemplate(Map<String, dynamic> template) {
    final terms = template['terms'] as List<dynamic>;
    setState(() {
      _paymentTerms.clear();
      for (final t in terms) {
        final pct = (t['percent'] as num).toDouble();
        _paymentTerms.add({
          'term': t['term'].toString(),
          'percent': pct,
          'amount': _grandTotal * (pct / 100.0),
        });
      }
    });
  }

  void _showManageTemplatesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final allTemplates = [..._defaultPaymentTemplates, ..._customPaymentTemplates];
          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.tune, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Manage Payment Templates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: allTemplates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final t = allTemplates[idx];
                        final isDefault = idx < _defaultPaymentTemplates.length;
                        final terms = (t['terms'] as List<dynamic>)
                            .map((e) => '${e['term']}: ${(e['percent'] as num).toInt()}%')
                            .join(', ');
                        return ListTile(
                          title: Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(terms, style: const TextStyle(fontSize: 12)),
                          trailing: isDefault
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Default', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                  onPressed: () {
                                    setDialogState(() {
                                      _customPaymentTemplates.removeAt(idx - _defaultPaymentTemplates.length);
                                    });
                                    setState(() {});
                                  },
                                ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text('Create New Template', style: TextStyle(color: Colors.white)),
                      onPressed: () async {
                        await _showCreateTemplateDialog(ctx, () => setDialogState(() {}));
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateTemplateDialog(BuildContext parentCtx, VoidCallback onAdded) async {
    final nameCtrl = TextEditingController();
    final pctCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Template', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                hintText: 'e.g. [50, 30, 20] or Milestone',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pctCtrl,
              decoration: const InputDecoration(
                labelText: 'Percentages (comma separated)',
                hintText: '50, 30, 20',
              ),
              keyboardType: TextInputType.text,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final rawPcts = pctCtrl.text.split(',').map((e) => double.tryParse(e.trim()) ?? 0.0).where((p) => p >= 0).toList();
              if (name.isEmpty || rawPcts.isEmpty) return;

              final sum = rawPcts.fold<double>(0.0, (s, p) => s + p);
              if (sum > 100.0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Total cannot exceed 100%'), backgroundColor: AppColors.error),
                );
                return;
              }

              final terms = rawPcts.asMap().entries.map((e) {
                final defaultNames = ['Advance', 'Delivery', 'Installation', 'Commissioning', 'Final Handover'];
                final sName = e.key < defaultNames.length ? defaultNames[e.key] : 'Stage ${e.key + 1}';
                return {'term': sName, 'percent': e.value};
              }).toList();

              _customPaymentTemplates.add({
                'name': name.startsWith('[') ? name : '[$name]',
                'terms': terms,
              });
              Navigator.pop(ctx);
              onAdded();
              setState(() {});
            },
            child: const Text('Add Template', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAmcToggle(bool val) async {
    if (!val) {
      setState(() => _amcInterested = false);
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pill drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A5F), Color(0xFF2E5490)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'AMC Finalization',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'ADD-ON',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB45309),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Annual Maintenance Contract Options',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx, 'cancel'),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Explanatory banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Customer has opted for AMC coverage. Choose when you want to configure the contract parameters:',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Option 1: Finalize Now (Recommended Card)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, 'now'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Finalize AMC Now',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF064E3B),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF059669),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'RECOMMENDED',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Configure tenure, visits, pricing & contract terms immediately.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  color: Color(0xFF047857),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF059669)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Option 2: Finalize Later Card
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, 'later'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.schedule_rounded, color: Color(0xFF475569), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Mark Interest & Finalize Later',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Save AMC interest with quotation. Configure terms anytime via AMC Quick Action.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Cancel / Dismiss
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Cancel & Disable AMC',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == 'later') {
      setState(() => _amcInterested = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Customer marked as interested in AMC. You can finalize it later from AMC actions.'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    } else if (choice == 'now') {
      setState(() => _amcInterested = true);
      final customerId = _pipeline?.customerId ?? '';
      final productId = _pipeline?.productId ?? '';
      final pipelineId = widget.pipelineId ?? '';

      await context.push(
        '${AppRoutes.amcSetup}?pipelineId=$pipelineId&customerId=$customerId&productId=$productId',
      );

      // Check if AMC contract was saved; if user hit back without saving, toggle it off!
      if (mounted && widget.pipelineId != null) {
        final supabase = ref.read(supabaseClientProvider);
        final existingAmc = await supabase
            .from('amc_contracts')
            .select('id')
            .eq('pipeline_id', widget.pipelineId!)
            .maybeSingle();
        if (existingAmc == null) {
          setState(() => _amcInterested = false);
        } else {
          setState(() => _amcInterested = true);
        }
      }
    } else {
      // Cancelled
      setState(() => _amcInterested = false);
    }
  }
  Map<String, dynamic>? _leadData;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _amcInterested = false;
  Quotation? _existingQuotation;
  SalesPipeline? _pipeline;
  Product? _product;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _termsController.dispose();
    _salesOrderNoController.dispose();
    _placeOfSupplyController.dispose();
    _distanceController.dispose();
    _grLrNoController.dispose();
    _destinationController.dispose();
    _remarksController.dispose();
    _customerNameController.dispose();
    _billingAddressController.dispose();
    _customerGstinController.dispose();
    _customerPhoneController.dispose();
    _partyContactPersonController.dispose();
    _shippingNameController.dispose();
    _shippingAddressController.dispose();
    _stateCodeController.dispose();
    _salesmanController.dispose();
    for (final c in _specControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _populateFromQuotation(Quotation q) {
    _cgstRate = q.cgstRate;
    _sgstRate = q.sgstRate;
    _termsController.text = q.termsText ?? '';

    _salesOrderNoController.text = q.salesOrderNo ?? '';
    _orderDate = q.orderDate ?? DateTime.now();
    _billType = q.billType ?? 'Credit';
    _placeOfSupplyController.text = q.placeOfSupply ?? '';
    _distanceController.text = q.distance?.toString() ?? '';
    _grLrNoController.text = q.grLrNo ?? '';
    _destinationController.text = q.destination ?? '';
    _customerNameController.text = q.customerName ?? '';
    _billingAddressController.text = q.billingAddress ?? '';
    _customerGstinController.text = q.customerGstin ?? '';
    _customerPhoneController.text = q.customerPhone ?? '';
    _partyContactPersonController.text = q.partyContactPerson ?? '';
    _shippingNameController.text = q.shippingName ?? '';
    _shippingAddressController.text = q.shippingAddress ?? '';
    _stateCodeController.text = q.stateCode?.toString() ?? '27';
    _salesmanController.text = q.salesman ?? '';
    _remarksController.text = q.remarks ?? 'Being Quotation Generated';

    // Prefill spec values
    q.productSpecs.forEach((key, value) {
      if (_specControllers.containsKey(key)) {
        _specControllers[key]!.text = value?.toString() ?? '';
      } else if (_specDropdownValues.containsKey(key)) {
        _specDropdownValues[key] = value?.toString();
      }
    });

    // Prefill line items
    _lineItems.clear();
    _lineItems.addAll(
      q.lineItems.map((item) => {
            'description': TextEditingController(text: item.description),
            'hsn_sac': TextEditingController(text: item.hsnSac ?? ''),
            'qty': TextEditingController(text: item.qty.toInt().toString()),
            'gst_percent': TextEditingController(
                text: (item.gstPercent > 0 ? item.gstPercent : 18.0)
                    .toStringAsFixed(0)),
            'uom': TextEditingController(text: item.uom),
            'unit_price': TextEditingController(
                text: InventoryAutocomplete.formatIndianPrice(item.unitPrice)),
            'disc_percent':
                TextEditingController(text: item.discPercent.toString()),
          }),
    );

    // Prefill payment terms
    if (q.paymentTerms != null && q.paymentTerms!.isNotEmpty) {
      _paymentTerms.clear();
      _paymentTerms.addAll(
          q.paymentTerms!.map((e) => Map<String, dynamic>.from(e)));
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final profile = ref.read(currentProfileProvider);

      if (widget.initialQuotation != null) {
        // Mode 1: Revising an existing quotation (creates a new revision row)
        _populateFromQuotation(widget.initialQuotation!);
        _currentRevision = widget.revisionNumber ?? (widget.initialQuotation!.revision + 1);
        _isEditing = true;
        _existingQuotation = null; // Create new revision record on save
      } else if (widget.leadId != null) {
        // Mode 2: Generating quotation directly from a CRM Lead
        final leadData = await supabase
            .from('crm_leads')
            .select()
            .eq('id', widget.leadId!)
            .single();
        _leadData = leadData;

        final status = leadData['status'] as String? ?? '';
        if (status == 'Won' || status == 'Lost') {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: const Text('Quotations Locked'),
                  content: Text('This lead is marked as $status. Quotations cannot be created or modified for Won or Lost leads.'),
                  actions: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            });
          }
          return;
        }

        _customerNameController.text = leadData['prospect_name'] ?? '';
        _customerPhoneController.text = leadData['contact_phone'] ?? '';
        _shippingNameController.text = _customerNameController.text;
        _partyContactPersonController.text = leadData['prospect_name'] ?? '';
        _placeOfSupplyController.text = 'Maharashtra';
        if (profile != null) {
          _salesmanController.text = profile.fullName;
        }

        // Fetch Prospect address for Billing and Shipping Address
        String prospectAddress = '';
        if (leadData['prospect_id'] != null) {
          try {
            final pRes = await supabase
                .from('crm_prospects')
                .select('address')
                .eq('id', leadData['prospect_id'])
                .maybeSingle();
            if (pRes != null && pRes['address'] != null) {
              prospectAddress = pRes['address'].toString().trim();
            }
          } catch (_) {}
        }
        if (prospectAddress.isEmpty && leadData['prospect_name'] != null) {
          try {
            final pRes = await supabase
                .from('crm_prospects')
                .select('address')
                .eq('name', leadData['prospect_name'])
                .maybeSingle();
            if (pRes != null && pRes['address'] != null) {
              prospectAddress = pRes['address'].toString().trim();
            }
          } catch (_) {}
        }

        if (prospectAddress.isNotEmpty) {
          _billingAddressController.text = prospectAddress;
          _shippingAddressController.text = prospectAddress;
        }

        // Determine next revision number for this lead
        final leadQuots = await supabase
            .from('quotations')
            .select('revision, line_items, payment_terms')
            .eq('lead_id', widget.leadId!)
            .order('revision', ascending: false)
            .limit(1);

        if (leadQuots.isNotEmpty) {
          _currentRevision = ((leadQuots.first['revision'] as num?)?.toInt() ?? 1) + 1;
        } else {
          _currentRevision = 1;
        }
        _isEditing = true;

        if (_lineItems.isEmpty) {
          if (leadQuots.isNotEmpty && leadQuots.first['line_items'] != null) {
            // Revision 2+: Pre-fill line items directly from previous revision without mutating prices
            final prevLineItems = leadQuots.first['line_items'] as List;
            for (final item in prevLineItems) {
              if (item is Map) {
                _lineItems.add({
                  'description': TextEditingController(text: item['description']?.toString() ?? ''),
                  'hsn_sac': TextEditingController(text: item['hsn_sac']?.toString() ?? '84191920'),
                  'qty': TextEditingController(text: ((item['qty'] as num?)?.toInt() ?? 1).toString()),
                  'gst_percent': TextEditingController(
                      text: ((item['gst_percent'] as num?)?.toDouble() ?? 18.0).toStringAsFixed(0)),
                  'uom': TextEditingController(text: item['uom']?.toString() ?? 'NOS'),
                  'unit_price': TextEditingController(
                      text: InventoryAutocomplete.formatIndianPrice(
                          (item['unit_price'] as num?)?.toDouble() ?? 0.0)),
                  'disc_percent': TextEditingController(
                      text: (item['disc_percent'] as num?)?.toString() ?? '0.0'),
                });
              }
            }
          }

          if (_lineItems.isEmpty) {
            // Revision 1: Pre-fill line item 1 with product combo name and base price from inventory
            final prodName = leadData['product_name'] as String? ?? 'Solar System';
            final cap = leadData['capacity'] as String?;
            final desc = (cap != null && cap.isNotEmpty && !prodName.contains(cap))
                ? '$prodName ($cap)'
                : prodName;

            double unitPrice = 0.0;
            try {
              final invRes = await supabase
                  .from('inventory_items')
                  .select('selling_price')
                  .ilike('item_name', '%$prodName%')
                  .limit(1);
              if (invRes.isNotEmpty && invRes.first['selling_price'] != null) {
                unitPrice = (invRes.first['selling_price'] as num).toDouble();
              }
            } catch (_) {}

            if (unitPrice == 0.0 && (leadData['estimated_value'] as num?) != null) {
              unitPrice = (leadData['estimated_value'] as num).toDouble();
            }

            _lineItems.add({
              'description': TextEditingController(text: desc),
              'hsn_sac': TextEditingController(text: '84191920'),
              'qty': TextEditingController(text: '1'),
              'gst_percent': TextEditingController(text: '18'),
              'uom': TextEditingController(text: 'SET'),
              'unit_price': TextEditingController(
                  text: unitPrice > 0 ? InventoryAutocomplete.formatIndianPrice(unitPrice) : '0'),
              'disc_percent': TextEditingController(text: '0.0'),
            });
          }
        }
      } else if (widget.pipelineId != null) {
        // Mode 3: Traditional pipeline quotation
        final pipelineData = await supabase
            .from('sales_pipelines')
            .select('*, products(*), customers(*)')
            .eq('id', widget.pipelineId!)
            .single();

        _pipeline = SalesPipeline.fromJson(pipelineData);
        _product = _pipeline?.product;

        // Initialize spec controllers from product fields
        if (_product != null) {
          for (final field in _product!.baseSpecs.quotationFields) {
            if (field.type == 'text' ||
                field.type == 'number' ||
                field.type == 'textarea') {
              _specControllers[field.key] = TextEditingController();
            } else if (field.type == 'select') {
              _specDropdownValues[field.key] = null;
            }
          }
        }

        // Load existing quotation if exists
        final quotationData = await supabase
            .from('quotations')
            .select()
            .eq('pipeline_id', widget.pipelineId!)
            .maybeSingle();

        if (quotationData != null) {
          _existingQuotation = Quotation.fromJson(quotationData);
          final isSales = profile?.primaryRole == UserRole.sales;
          if (_existingQuotation!.status == QuotationStatus.pendingApproval) {
            _isEditing = !isSales;
          } else {
            _isEditing = !_existingQuotation!.isConfirmed;
          }
          _currentRevision = _existingQuotation!.revision;
          _populateFromQuotation(_existingQuotation!);
        } else {
          _isEditing = true;

          // Prefill from pipeline customer data
          if (_pipeline?.customer != null) {
            _customerNameController.text = _pipeline!.customer!.companyName;
            _billingAddressController.text = _pipeline!.customer!.address ?? '';
            _customerGstinController.text = _pipeline!.customer!.gstNumber ?? '';
            _customerPhoneController.text = _pipeline!.customer!.phone ?? '';
            _partyContactPersonController.text =
                _pipeline!.customer!.contactPerson ?? '';

            _shippingNameController.text = _pipeline!.customer!.companyName;
            _shippingAddressController.text = _pipeline!.customer!.address ?? '';

            final gstin = _pipeline!.customer!.gstNumber;
            _stateCodeController.text =
                gstin != null && gstin.length >= 2 ? gstin.substring(0, 2) : '27';
          }

          if (profile != null) {
            _salesmanController.text = profile.fullName;
          }
          _placeOfSupplyController.text = 'Maharashtra';
        }

        // Check if AMC contract exists for this pipeline
        final amcResponse = await supabase
            .from('amc_contracts')
            .select('id')
            .eq('pipeline_id', widget.pipelineId!)
            .maybeSingle();
        _amcInterested = amcResponse != null;
      }

      // Add at least one empty line item if none exist
      if (_lineItems.isEmpty) _addLineItem();

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add({
        'description': TextEditingController(),
        'hsn_sac': TextEditingController(),
        'qty': TextEditingController(text: '1'),
        'gst_percent': TextEditingController(text: '18'),
        'uom': TextEditingController(text: 'NOS'),
        'unit_price': TextEditingController(text: '0'),
        'disc_percent': TextEditingController(text: '0.0'),
      });
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      final item = _lineItems.removeAt(index);
      (item['description'] as TextEditingController).dispose();
      (item['hsn_sac'] as TextEditingController).dispose();
      (item['qty'] as TextEditingController).dispose();
      (item['gst_percent'] as TextEditingController).dispose();
      (item['uom'] as TextEditingController).dispose();
      (item['unit_price'] as TextEditingController).dispose();
      (item['disc_percent'] as TextEditingController).dispose();
    });
  }

  double _calcSubtotal() {
    double total = 0;
    for (final item in _lineItems) {
      final qty =
          int.tryParse((item['qty'] as TextEditingController).text) ?? 0;
      final price =
          double.tryParse((item['unit_price'] as TextEditingController).text.replaceAll(',', '')) ??
              0;
      final disc = double.tryParse(
              (item['disc_percent'] as TextEditingController).text) ??
          0;
      total += (qty * price) * (1 - disc / 100);
    }
    return total;
  }

  bool get _isInterstate {
    final clientStateCode =
        int.tryParse(_stateCodeController.text.trim()) ?? 27;
    return clientStateCode != 27; // Maharashtra is 27
  }

  double get _totalGstAmount {
    double gstSum = 0;
    for (final item in _lineItems) {
      final qty = int.tryParse((item['qty'] as TextEditingController).text) ?? 0;
      final price = double.tryParse((item['unit_price'] as TextEditingController).text.replaceAll(',', '')) ?? 0;
      final disc = double.tryParse((item['disc_percent'] as TextEditingController).text) ?? 0;
      final gst = double.tryParse((item['gst_percent'] as TextEditingController).text) ?? (_cgstRate + _sgstRate);
      final taxable = (qty * price) * (1 - disc / 100);
      gstSum += taxable * (gst / 100);
    }
    return gstSum;
  }

  double get _cgstAmount =>
      _isInterstate ? 0.0 : _totalGstAmount / 2;
  double get _sgstAmount =>
      _isInterstate ? 0.0 : _totalGstAmount / 2;
  double get _igstAmount =>
      _isInterstate ? _totalGstAmount : 0.0;
  double get _grandTotal =>
      _calcSubtotal() + _totalGstAmount;

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await _upsertQuotation(confirmed: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _approveQuotation() async {
    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final profile = ref.read(currentProfileProvider);

      if (profile?.primaryRole != UserRole.salesHead &&
          profile?.primaryRole != UserRole.admin) {
        throw Exception('Only Sales Head or Admin can approve quotations');
      }

      if (_existingQuotation == null) {
        throw Exception('No quotation to approve');
      }

      // Update status to confirmed
      await supabase.from('quotations').update({
        'status': 'confirmed',
        'confirmed_by': supabase.auth.currentUser!.id,
        'confirmed_at': DateTime.now().toIso8601String(),
      }).eq('id', _existingQuotation!.id);

      // Advance pipeline
      if (widget.pipelineId != null) {
        await supabase.from('sales_pipelines').update({
          'current_step': 'sales_order',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.pipelineId!);
      }

      // Generate PDF client-side
      await _generateAndUploadPdf(_existingQuotation!.id,
          showPrintDialog: false);

      // Handle AMC
      await _handleAmcInterest();

      // Write audit log
      if (widget.pipelineId != null) {
        await supabase.from('step_audit_log').insert({
          'pipeline_id': widget.pipelineId,
          'step_name': 'quotation',
          'action': 'confirmed',
          'performed_by': supabase.auth.currentUser!.id,
          'notes': 'Quotation approved by ${profile?.fullName}',
        });
      }

      // Notify Sales Executive
      if (_pipeline != null && widget.pipelineId != null) {
        await supabase.from('notifications').insert({
          'user_id': _pipeline!.createdBy,
          'title': 'Quotation Approved',
          'body':
              'Your quotation has been approved. Sales Order step is now unlocked.',
          'type': 'step_unlocked',
          'related_pipeline_id': widget.pipelineId,
        });
      }

      // Invalidate pipeline
      if (widget.pipelineId != null) {
        ref.invalidate(pipelineDetailProvider(widget.pipelineId!));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Quotation approved and confirmed!'),
            backgroundColor: AppColors.success,
          ),
        );
        if (widget.pipelineId != null) {
          context.go(AppRoutes.pipelineDetail.replaceAll(':id', widget.pipelineId!));
        } else {
          context.pop();
        }
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _rejectQuotation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Quotation'),
        content: const Text(
          'Are you sure you want to reject this quotation? '
          'This will permanently suspend the entire deal and prevent further progress.',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject & Suspend Deal',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final profile = ref.read(currentProfileProvider);

      if (profile?.primaryRole != UserRole.salesHead &&
          profile?.primaryRole != UserRole.admin) {
        throw Exception('Only Sales Head or Admin can reject quotations');
      }

      if (_existingQuotation == null) {
        throw Exception('No quotation to reject');
      }

      // Update quotation status to rejected
      await supabase.from('quotations').update({
        'status': 'rejected',
      }).eq('id', _existingQuotation!.id);

      if (widget.pipelineId != null) {
        // Update pipeline status to suspended
        await supabase.from('sales_pipelines').update({
          'status': 'suspended',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.pipelineId!);

        // Write audit log
        await supabase.from('step_audit_log').insert({
          'pipeline_id': widget.pipelineId,
          'step_name': 'quotation',
          'action': 'status_changed',
          'performed_by': supabase.auth.currentUser!.id,
          'notes':
              'Quotation rejected by Sales Head (${profile?.fullName}). Deal suspended.',
        });

        // Notify Sales Executive
        if (_pipeline != null) {
          await supabase.from('notifications').insert({
            'user_id': _pipeline!.createdBy,
            'title': 'Quotation Rejected & Deal Suspended',
            'body':
                'Your quotation for customer ${_pipeline?.customer?.companyName ?? ''} was rejected by ${profile?.fullName ?? 'Sales Head'}. The deal is suspended.',
            'type': 'admin_alert',
            'related_pipeline_id': widget.pipelineId,
          });
        }

        ref.invalidate(pipelineDetailProvider(widget.pipelineId!));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Quotation rejected. Deal suspended.'),
            backgroundColor: AppColors.error,
          ),
        );
        context.pop();
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmQuotation() async {
    final profile = ref.read(currentProfileProvider);
    if (profile?.primaryRole == UserRole.crmStaff) {
      _showError('CRM Staff is not authorized to issue quotations. Quotations must be given by sales personnel or administrators.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final lineItemsValid = _lineItems.every((item) {
      final desc = (item['description'] as TextEditingController).text.trim();
      final qty =
          double.tryParse((item['qty'] as TextEditingController).text) ?? 0;
      final price =
          double.tryParse((item['unit_price'] as TextEditingController).text) ??
              0;
      return desc.isNotEmpty && qty > 0 && price >= 0;
    });

    if (!lineItemsValid) {
      _showError(
          'All line items must have a description, quantity > 0, and a valid price.');
      return;
    }

    final isSales = profile?.primaryRole == UserRole.sales;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isSales ? 'Submit for Approval' : 'Confirm Quotation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSales
                  ? 'Submit this quotation to Sales Head / Admin for approval?'
                  : 'Once confirmed, a PDF will be generated and the Sales Order step will be unlocked. Are you sure?',
              style: const TextStyle(fontFamily: 'Inter', height: 1.5),
            ),
            const SizedBox(height: 16),
            _TotalRow('Subtotal', _calcSubtotal()),
            if (!_isInterstate) ...[
              _TotalRow('CGST ($_cgstRate%)', _cgstAmount),
              _TotalRow('SGST ($_sgstRate%)', _sgstAmount),
            ] else ...[
              _TotalRow('IGST (${_cgstRate + _sgstRate}%)', _igstAmount),
            ],
            const Divider(),
            _TotalRow('Grand Total', _grandTotal, bold: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isSales ? 'Submit' : 'Confirm & Generate PDF'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      // First save/upsert
      final quotationId = await _upsertQuotation(confirmed: true);
      final supabase = ref.read(supabaseClientProvider);      if (isSales) {
        if (widget.pipelineId != null) {
          // Write audit log for submission
          await supabase.from('step_audit_log').insert({
            'pipeline_id': widget.pipelineId,
            'step_name': 'quotation',
            'action': 'status_changed',
            'performed_by': supabase.auth.currentUser!.id,
            'notes': 'Quotation submitted for approval. Total: ₹$_grandTotal',
          });

          // Notify admins and sales heads
          final adminsAndHeads = await supabase
              .from('profiles')
              .select('id')
              .inFilter('role', ['admin', 'sales_head']).eq('is_active', true);

          if (adminsAndHeads.isNotEmpty) {
            final notifications = adminsAndHeads
                .map((recipient) => {
                      'user_id': recipient['id'],
                      'title': 'Quotation Pending Approval',
                      'body':
                          'A new quotation of ₹$_grandTotal has been submitted and requires approval.',
                      'type': 'admin_alert',
                      'related_pipeline_id': widget.pipelineId,
                    })
                .toList();

            await supabase.from('notifications').insert(notifications);
          }

          ref.invalidate(pipelineDetailProvider(widget.pipelineId!));
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Quotation submitted for approval!'),
              backgroundColor: AppColors.success,
            ),
          );
          if (widget.pipelineId != null) {
            context.go(AppRoutes.pipelineDetail.replaceAll(':id', widget.pipelineId!));
          } else {
            context.pop();
          }
        }
      } else {
        // Direct approval (Admin / Sales Head)
        // Update confirmed_by/confirmed_at
        await supabase.from('quotations').update({
          'confirmed_by': supabase.auth.currentUser!.id,
          'confirmed_at': DateTime.now().toIso8601String(),
        }).eq('id', quotationId);

        if (widget.pipelineId != null) {
          // Advance pipeline to sales_order
          await supabase.from('sales_pipelines').update({
            'current_step': 'sales_order',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', widget.pipelineId!);

          // Write audit log
          await supabase.from('step_audit_log').insert({
            'pipeline_id': widget.pipelineId,
            'step_name': 'quotation',
            'action': 'confirmed',
            'performed_by': supabase.auth.currentUser!.id,
            'notes': 'Quotation confirmed. Total: ₹$_grandTotal',
          });

          // Handle AMC
          await _handleAmcInterest();

          ref.invalidate(pipelineDetailProvider(widget.pipelineId!));
        }

        // Generate and upload PDF
        await _generateAndUploadPdf(quotationId, showPrintDialog: false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✓ Quotation (Rev $_currentRevision) confirmed!'),
              backgroundColor: AppColors.success,
            ),
          );
          if (widget.pipelineId != null) {
            context.go(AppRoutes.pipelineDetail.replaceAll(':id', widget.pipelineId!));
          } else {
            context.pop();
          }
        }
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateConfirmedQuotation() async {
    if (!_formKey.currentState!.validate()) return;

    final lineItemsValid = _lineItems.every((item) {
      final desc = (item['description'] as TextEditingController).text.trim();
      final qty =
          double.tryParse((item['qty'] as TextEditingController).text) ?? 0;
      final price =
          double.tryParse((item['unit_price'] as TextEditingController).text) ??
              0;
      return desc.isNotEmpty && qty > 0 && price >= 0;
    });

    if (!lineItemsValid) {
      _showError(
          'All line items must have a description, quantity > 0, and a valid price.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Directly upsert confirmed = true
      final quotationId = await _upsertQuotation(confirmed: true);

      final supabase = ref.read(supabaseClientProvider);
      if (widget.pipelineId != null) {
        // Write audit log for update
        await supabase.from('step_audit_log').insert({
          'pipeline_id': widget.pipelineId,
          'step_name': 'quotation',
          'action': 'updated',
          'performed_by': supabase.auth.currentUser!.id,
        });

        // Handle AMC interest
        await _handleAmcInterest();

        ref.invalidate(pipelineDetailProvider(widget.pipelineId!));
      }

      // Generate PDF client-side
      await _generateAndUploadPdf(quotationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Quotation updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        if (widget.pipelineId != null) {
          context.go(AppRoutes.pipelineDetail.replaceAll(':id', widget.pipelineId!));
        } else {
          context.pop();
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String> _upsertQuotation({required bool confirmed}) async {
    final supabase = ref.read(supabaseClientProvider);

    // Collect spec values
    final specs = <String, dynamic>{};
    for (final entry in _specControllers.entries) {
      specs[entry.key] =
          entry.value.text.trim().isEmpty ? null : entry.value.text.trim();
    }
    for (final entry in _specDropdownValues.entries) {
      specs[entry.key] = entry.value;
    }

    final totalTermsPct = _paymentTerms.fold<double>(
      0.0,
      (sum, item) => sum + ((item['percent'] as num?)?.toDouble() ?? 0.0),
    );
    if (totalTermsPct > 100.0) {
      throw Exception(
          'Payment terms total percentage cannot exceed 100% (currently ${totalTermsPct.toStringAsFixed(1)}%).');
    }

    // Build line items
    final lineItemsJson = _lineItems.map((item) {
      final qty =
          int.tryParse((item['qty'] as TextEditingController).text) ?? 1;
      final gstPercent =
          double.tryParse((item['gst_percent'] as TextEditingController).text) ??
              18.0;
      final price =
          double.tryParse((item['unit_price'] as TextEditingController).text.replaceAll(',', '')) ??
              0;
      final disc = double.tryParse(
              (item['disc_percent'] as TextEditingController).text) ??
          0;
      final hsn = (item['hsn_sac'] as TextEditingController).text.trim();
      final uom = (item['uom'] as TextEditingController).text.trim();
      final total = (qty * price) * (1 - disc / 100);
      return {
        'description':
            (item['description'] as TextEditingController).text.trim(),
        'hsn_sac': hsn.isEmpty ? null : hsn,
        'qty': qty.toDouble(),
        'free_qty': 0,
        'gst_percent': gstPercent,
        'uom': uom,
        'unit_price': price,
        'disc_percent': disc,
        'total': total,
      };
    }).toList();

    final subtotal = _calcSubtotal();
    final data = {
      if (widget.pipelineId != null) 'pipeline_id': widget.pipelineId,
      if (widget.leadId != null) 'lead_id': widget.leadId,
      'revision': _currentRevision,
      'payment_terms': _paymentTerms.map((t) => {
        'term': t['term']?.toString() ?? '',
        'percent': (t['percent'] as num?)?.toDouble() ?? 0.0,
        'amount': _grandTotal * (((t['percent'] as num?)?.toDouble() ?? 0.0) / 100.0),
      }).toList(),
      if (_pipeline?.productId != null) 'product_id': _pipeline!.productId,
      'line_items': lineItemsJson,
      'product_specs': specs,
      'subtotal': subtotal,
      'cgst_rate': _cgstRate,
      'sgst_rate': _sgstRate,
      'cgst_amount': _cgstAmount,
      'sgst_amount': _sgstAmount,
      'igst_amount': _igstAmount,
      'grand_total': _grandTotal,
      'terms_text': _termsController.text.trim().isEmpty
          ? null
          : _termsController.text.trim(),
      'status': confirmed
          ? (ref.read(currentProfileProvider)?.primaryRole == UserRole.sales
              ? 'pending_approval'
              : 'confirmed')
          : 'draft',
      'sales_order_no': null,
      'order_date': _orderDate.toIso8601String(),
      'bill_type': _billType,
      'place_of_supply': _placeOfSupplyController.text.trim().isEmpty
          ? null
          : _placeOfSupplyController.text.trim(),
      'distance': double.tryParse(_distanceController.text.trim()),
      'gr_lr_no': _grLrNoController.text.trim().isEmpty
          ? null
          : _grLrNoController.text.trim(),
      'destination': _destinationController.text.trim().isEmpty
          ? null
          : _destinationController.text.trim(),
      'customer_name': _customerNameController.text.trim().isEmpty
          ? null
          : _customerNameController.text.trim(),
      'billing_address': _billingAddressController.text.trim().isEmpty
          ? null
          : _billingAddressController.text.trim(),
      'customer_gstin': _customerGstinController.text.trim().isEmpty
          ? null
          : _customerGstinController.text.trim(),
      'customer_phone': _customerPhoneController.text.trim().isEmpty
          ? null
          : _customerPhoneController.text.trim(),
      'party_contact_person': _partyContactPersonController.text.trim().isEmpty
          ? null
          : _partyContactPersonController.text.trim(),
      'shipping_name': _shippingNameController.text.trim().isEmpty
          ? null
          : _shippingNameController.text.trim(),
      'shipping_address': _shippingAddressController.text.trim().isEmpty
          ? null
          : _shippingAddressController.text.trim(),
      'state_code': int.tryParse(_stateCodeController.text.trim()),
      'salesman': _salesmanController.text.trim().isEmpty
          ? null
          : _salesmanController.text.trim(),
      'remarks': _remarksController.text.trim().isEmpty
          ? 'Being Quotation Generated'
          : _remarksController.text.trim(),
    };

    String quotationId;
    if (_existingQuotation != null) {
      await supabase
          .from('quotations')
          .update(data)
          .eq('id', _existingQuotation!.id);
      quotationId = _existingQuotation!.id;
    } else {
      final response = await supabase
          .from('quotations')
          .insert(data)
          .select('id, quotation_number')
          .single();

      if (widget.pipelineId != null) {
        // Write audit log
        await supabase.from('step_audit_log').insert({
          'pipeline_id': widget.pipelineId,
          'step_name': 'quotation',
          'action': 'created',
          'performed_by': supabase.auth.currentUser!.id,
        });
      }

      final id = response['id'] as String;
      final qNum = response['quotation_number'] as String? ?? '';
      setState(() => _existingQuotation = Quotation.fromJson({
            'id': id,
            ...data,
            'quotation_number': qNum,
            'confirmed_by': null,
            'confirmed_at': null,
            'pdf_url': null,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }));
      quotationId = id;
    }

    if (widget.leadId != null) {
      try {
        final currentLeadRes = await supabase
            .from('crm_leads')
            .select('status, estimated_value')
            .eq('id', widget.leadId!)
            .maybeSingle();

        String? newStatus;
        if (currentLeadRes != null) {
          final curStatus = currentLeadRes['status'] as String? ?? 'New';
          final curEst = (currentLeadRes['estimated_value'] as num?)?.toDouble() ?? 0.0;
          if (curStatus == 'New') {
            newStatus = 'In Progress';
          } else if (curStatus != 'Won' && curStatus != 'Lost' && (curEst - _grandTotal).abs() > 0.01) {
            newStatus = 'Negotiating';
          }
        }

        await supabase.from('crm_leads').update({
          'estimated_value': _grandTotal,
          if (newStatus != null) 'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.leadId!);
        ref.read(leadsProvider.notifier).load(refresh: true);
      } catch (_) {}
    }

    return quotationId;
  }

  Future<void> _handleAmcInterest() async {
    if (widget.pipelineId == null || _pipeline == null) return;
    final supabase = ref.read(supabaseClientProvider);
    if (_amcInterested) {
      final existingAmc = await supabase
          .from('amc_contracts')
          .select('id')
          .eq('pipeline_id', widget.pipelineId!)
          .maybeSingle();

      if (existingAmc == null) {
        await supabase.from('amc_contracts').insert({
          'pipeline_id': widget.pipelineId,
          'customer_id': _pipeline!.customerId,
          'product_id': _pipeline!.productId,
          'status': 'interested',
          'created_by': supabase.auth.currentUser!.id,
        });

        await supabase.from('step_audit_log').insert({
          'pipeline_id': widget.pipelineId,
          'step_name': 'amc',
          'action': 'amc_created',
          'performed_by': supabase.auth.currentUser!.id,
          'notes': 'AMC interest registered during quotation confirmation.',
        });
      }
    } else {
      await supabase
          .from('amc_contracts')
          .delete()
          .eq('pipeline_id', widget.pipelineId!)
          .eq('status', 'interested');
    }
  }

  Future<void> _generateAndUploadPdf(String quotationId,
      {bool showPrintDialog = true}) async {
    final supabase = ref.read(supabaseClientProvider);

    // Fetch latest quotation data
    final quotationData = await supabase
        .from('quotations')
        .select()
        .eq('id', quotationId)
        .single();
    final quotation = Quotation.fromJson(quotationData);

    Customer customer;
    Product product;

    if (quotation.pipelineId.isNotEmpty) {
      try {
        final pipelineData = await supabase
            .from('sales_pipelines')
            .select('*, customers(*), products(*)')
            .eq('id', quotation.pipelineId)
            .single();
        final pipeline = SalesPipeline.fromJson(pipelineData);
        customer = pipeline.customer ??
            Customer(
              id: quotation.leadId ?? 'lead',
              companyName: quotation.customerName ?? 'Customer',
              phone: quotation.customerPhone ?? '',
              address: quotation.billingAddress ?? '',
              gstNumber: quotation.customerGstin,
              createdBy: supabase.auth.currentUser?.id ?? '',
              createdAt: quotation.createdAt,
              updatedAt: quotation.updatedAt,
            );
        product = pipeline.product ??
            Product(
              id: 'prod',
              name: _lineItems.isNotEmpty
                  ? (_lineItems.first['description'] as TextEditingController).text
                  : 'Solar System',
              category: 'Solar',
              baseSpecs: const ProductBaseSpecs(
                  quotationFields: [], boqRequiredFields: []),
              isActive: true,
              createdAt: quotation.createdAt,
              updatedAt: quotation.updatedAt,
            );
      } catch (_) {
        customer = Customer(
          id: quotation.leadId ?? 'lead',
          companyName: quotation.customerName ?? 'Customer',
          phone: quotation.customerPhone ?? '',
          address: quotation.billingAddress ?? '',
          gstNumber: quotation.customerGstin,
          createdBy: supabase.auth.currentUser?.id ?? '',
          createdAt: quotation.createdAt,
          updatedAt: quotation.updatedAt,
        );
        product = Product(
          id: 'prod',
          name: _lineItems.isNotEmpty
              ? (_lineItems.first['description'] as TextEditingController).text
              : 'Solar System',
          category: 'Solar',
          baseSpecs: const ProductBaseSpecs(
              quotationFields: [], boqRequiredFields: []),
          isActive: true,
          createdAt: quotation.createdAt,
          updatedAt: quotation.updatedAt,
        );
      }
    } else {
      customer = Customer(
        id: quotation.leadId ?? 'lead',
        companyName: quotation.customerName ?? 'Customer',
        phone: quotation.customerPhone ?? '',
        address: quotation.billingAddress ?? '',
        gstNumber: quotation.customerGstin,
        createdBy: supabase.auth.currentUser?.id ?? '',
        createdAt: quotation.createdAt,
        updatedAt: quotation.updatedAt,
      );
      product = Product(
        id: 'prod',
        name: _lineItems.isNotEmpty
            ? (_lineItems.first['description'] as TextEditingController).text
            : 'Solar System',
        category: 'Solar',
        baseSpecs: const ProductBaseSpecs(
            quotationFields: [], boqRequiredFields: []),
        isActive: true,
        createdAt: quotation.createdAt,
        updatedAt: quotation.updatedAt,
      );
    }

    Map<String, dynamic> templateConfig;
    try {
      final templateData = await supabase
          .from('pdf_templates')
          .select()
          .eq('document_type', 'quotation')
          .single();
      templateConfig =
          (templateData)['template_config'] as Map<String, dynamic>;
    } catch (_) {
      templateConfig = {
        'company_name': 'INSIYA SOLAR INDUSTRY',
        'company_address':
            'GAT NO 133/1, LAND AREA 10, KOREGAON BHIMA, SHIRUR, Ratnagiri, Maharashtra - 412216, India',
        'company_phone': '9292922992',
        'company_email': 'insiyasolarindustry@gmail.com',
        'company_gst': '27AAOPI2766H1ZE',
        'footer_text': 'Thank you for your business.',
        'terms_default':
            '1. Payment: 50% advance, 50% before delivery.\n2. Delivery: 2-3 weeks.',
      };
    }

    final pdfBytes = await PdfService.generateQuotationPdf(
      quotation: quotation,
      customer: customer,
      product: product,
      templateConfig: templateConfig,
    );

    if (widget.pipelineId != null) {
      // Write audit log
      await supabase.from('step_audit_log').insert({
        'pipeline_id': widget.pipelineId,
        'step_name': 'quotation',
        'action': 'pdf_generated',
        'performed_by': supabase.auth.currentUser!.id,
      });
    }

    if (showPrintDialog && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            fileName:
                'Quotation_${quotation.quotationNumber.replaceAll('/', '_')}.pdf',
          ),
        ),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isConfirmed = _existingQuotation?.isConfirmed == true;
    final isPendingApproval =
        _existingQuotation?.status == QuotationStatus.pendingApproval;
    final profile = ref.watch(currentProfileProvider);
    final isSales = profile?.primaryRole == UserRole.sales;
    final enabled = _isEditing;
    final currencyFormat = NumberFormat('#,##,##0.00', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isConfirmed
            ? 'Quotation (Confirmed - Rev $_currentRevision)'
            : isPendingApproval
                ? 'Quotation (Pending Approval - Rev $_currentRevision)'
                : 'Quotation (Rev $_currentRevision)'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isConfirmed && !enabled)
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit, color: Colors.white, size: 16),
              label: const Text('Edit Details',
                  style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
            ),
          if (enabled && !isConfirmed)
            TextButton(
              onPressed: _isSaving ? null : _saveDraft,
              child: const Text('Save Draft',
                  style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
            ),
          if (enabled && isConfirmed)
            TextButton(
              onPressed: _isSaving ? null : _updateConfirmedQuotation,
              child: const Text('Save Changes',
                  style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            // Pipeline / Lead info header
            if (_pipeline?.customer != null)
              _PipelineHeader(
                customerName: _pipeline!.customer!.companyName,
                productName: _product?.name ?? '',
                quotationNumber: _existingQuotation?.quotationNumber,
                status: _existingQuotation?.status,
              )
            else if (_leadData != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: const Icon(Icons.description_outlined, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _leadData!['prospect_name'] ?? 'Lead Customer',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Lead Deal: ${_leadData!['product_name'] ?? ''} • Revision $_currentRevision',
                            style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Meta Section
            _SectionHeader('Document Metadata'),
            const SizedBox(height: 12),
            _buildMetaFieldsCard(enabled),
            const SizedBox(height: 20),

            // Billing vs Shipping Addresses
            _SectionHeader('Billing & Shipping Details'),
            const SizedBox(height: 12),
            _buildAddressFieldsCard(enabled),
            const SizedBox(height: 20),

            // Line items
            _SectionHeader('Line Items'),
            const SizedBox(height: 12),
            ..._lineItems.asMap().entries.map(
                  (entry) => _LineItemRow(
                    index: entry.key,
                    item: entry.value,
                    onRemove: !enabled || _lineItems.length <= 1
                        ? null
                        : () => _removeLineItem(entry.key),
                    onChanged: () => setState(() {}),
                    enabled: enabled,
                  ),
                ),
            if (enabled)
              TextButton.icon(
                onPressed: _addLineItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Line Item'),
              ),
            const SizedBox(height: 16),

            // Totals Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  _TotalRowWidget(
                      'Subtotal', '₹${currencyFormat.format(_calcSubtotal())}'),
                  const SizedBox(height: 10),
                  if (enabled) ...[
                    Row(
                      children: [
                        const Text(
                          'GST Rate:',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<double>(
                            isExpanded: true,
                            value: [0.0, 5.0, 12.0, 18.0, 28.0].contains(_cgstRate + _sgstRate)
                                ? (_cgstRate + _sgstRate)
                                : null,
                            isDense: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              hintText: 'Select GST %',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 18.0,
                                child: Text('18% (Standard 9% + 9%)', overflow: TextOverflow.ellipsis),
                              ),
                              const DropdownMenuItem(
                                value: 12.0,
                                child: Text('12% (6% + 6%)', overflow: TextOverflow.ellipsis),
                              ),
                              const DropdownMenuItem(
                                value: 5.0,
                                child: Text('5% (2.5% + 2.5%)', overflow: TextOverflow.ellipsis),
                              ),
                              const DropdownMenuItem(
                                value: 28.0,
                                child: Text('28% (14% + 14%)', overflow: TextOverflow.ellipsis),
                              ),
                              const DropdownMenuItem(
                                value: 0.0,
                                child: Text('0% (Exempted)', overflow: TextOverflow.ellipsis),
                              ),
                              if (![0.0, 5.0, 12.0, 18.0, 28.0].contains(_cgstRate + _sgstRate))
                                DropdownMenuItem(
                                  value: _cgstRate + _sgstRate,
                                  child: Text(
                                    '${(_cgstRate + _sgstRate).toStringAsFixed((_cgstRate + _sgstRate) == (_cgstRate + _sgstRate).roundToDouble() ? 0 : 2)}% (Custom)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _cgstRate = val / 2;
                                  _sgstRate = val / 2;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Custom GST %',
                          icon: const Icon(Icons.edit_note, size: 22, color: AppColors.primary),
                          onPressed: () async {
                            final totalGst = _cgstRate + _sgstRate;
                            final customVal = await showDialog<double>(
                              context: context,
                              builder: (ctx) {
                                final controller = TextEditingController(
                                  text: totalGst.toStringAsFixed(totalGst == totalGst.roundToDouble() ? 0 : 2),
                                );
                                return AlertDialog(
                                  title: const Text('Custom GST Rate (%)'),
                                  content: TextField(
                                    controller: controller,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Enter Total GST %',
                                      suffixText: '%',
                                    ),
                                    autofocus: true,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        final parsed = double.tryParse(controller.text.trim());
                                        if (parsed != null && parsed >= 0) {
                                          Navigator.pop(ctx, parsed);
                                        }
                                      },
                                      child: const Text('Apply'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (customVal != null) {
                              setState(() {
                                _cgstRate = customVal / 2;
                                _sgstRate = customVal / 2;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (!_isInterstate) ...[
                    _TotalRowWidget(
                      'CGST (${_cgstRate.toStringAsFixed(_cgstRate == _cgstRate.roundToDouble() ? 0 : 2)}%)',
                      '₹${currencyFormat.format(_cgstAmount)}',
                    ),
                    const SizedBox(height: 4),
                    _TotalRowWidget(
                      'SGST (${_sgstRate.toStringAsFixed(_sgstRate == _sgstRate.roundToDouble() ? 0 : 2)}%)',
                      '₹${currencyFormat.format(_sgstAmount)}',
                    ),
                  ] else ...[
                    _TotalRowWidget(
                      'IGST (${(_cgstRate + _sgstRate).toStringAsFixed((_cgstRate + _sgstRate) == (_cgstRate + _sgstRate).roundToDouble() ? 0 : 2)}%)',
                      '₹${currencyFormat.format(_igstAmount)}',
                    ),
                  ],
                  const Divider(height: 16),
                  _TotalRowWidget(
                    'Grand Total',
                    '₹${currencyFormat.format(_grandTotal)}',
                    bold: true,
                  ),
                  const Divider(height: 16),
                  _TotalRowWidget(
                    'Tax in Words',
                    PdfService.numberToIndianWords(_isInterstate
                        ? _igstAmount
                        : (_cgstAmount + _sgstAmount)),
                  ),
                  const SizedBox(height: 6),
                  _TotalRowWidget(
                    'Total in Words',
                    PdfService.numberToIndianWords(_grandTotal),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment Terms Section (Shifted upwards above Remarks)
            _SectionHeader('Payment Terms'),
            const SizedBox(height: 8),
            _buildPaymentTermsCard(
              enabled,
              isAdmin: profile?.primaryRole == UserRole.admin ||
                  profile?.primaryRole == UserRole.salesHead,
            ),
            const SizedBox(height: 20),

            _SectionHeader('Remarks'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _remarksController,
              enabled: enabled,
              decoration: const InputDecoration(
                hintText: 'Enter remarks...',
              ),
            ),
            const SizedBox(height: 20),

            // AMC Interest Section
            if (enabled) ...[
              _SectionHeader('Annual Maintenance Contract (AMC)'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _amcInterested
                      ? const Color(0xFFF0FDF4)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _amcInterested
                        ? const Color(0xFF10B981).withValues(alpha: 0.5)
                        : AppColors.divider,
                  ),
                ),
                child: SwitchListTile(
                  secondary: Icon(
                    _amcInterested ? Icons.verified_user_rounded : Icons.shield_outlined,
                    color: _amcInterested ? const Color(0xFF059669) : AppColors.primary,
                  ),
                  title: const Text(
                    'Is the customer willing to avail AMC for this product?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _amcInterested
                        ? 'AMC coverage opted for this quotation.'
                        : 'If Yes, you will be prompted to finalize AMC now or finalize it later.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: _amcInterested ? const Color(0xFF047857) : AppColors.textSecondary,
                    ),
                  ),
                  value: _amcInterested,
                  activeThumbColor: const Color(0xFF059669),
                  onChanged: (val) => _handleAmcToggle(val),
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              _SectionHeader('Annual Maintenance Contract (AMC)'),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _amcInterested
                      ? AppColors.successLight
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _amcInterested
                        ? AppColors.success.withOpacity(0.2)
                        : AppColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _amcInterested
                          ? Icons.verified_user
                          : Icons.shield_outlined,
                      color: _amcInterested
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _amcInterested
                                ? 'Customer is willing to avail AMC'
                                : 'Customer is not interested in AMC',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _amcInterested
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _amcInterested
                                ? 'An AMC interest record has been logged for this product.'
                                : 'No AMC interest record was created.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: _amcInterested
                                  ? AppColors.success.withOpacity(0.8)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Terms
            _SectionHeader('Terms & Conditions'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _termsController,
              maxLines: 6,
              enabled: enabled,
              decoration: const InputDecoration(
                hintText:
                    'Enter payment terms, warranty, delivery conditions...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            if (enabled)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : (isPendingApproval
                              ? _approveQuotation
                              : (isConfirmed
                                  ? _updateConfirmedQuotation
                                  : _confirmQuotation)),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(isPendingApproval
                              ? Icons.thumb_up_outlined
                              : Icons.check_circle_outline),
                      label: Text(_isSaving
                          ? 'Processing...'
                          : (isPendingApproval
                              ? 'Approve & Confirm'
                              : (isConfirmed
                                  ? 'Update Quotation & Print PDF'
                                  : (isSales
                                      ? 'Submit for Approval'
                                      : 'Confirm Quotation & Generate PDF')))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPendingApproval
                            ? AppColors.success
                            : AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (isPendingApproval) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _rejectQuotation,
                        icon: const Icon(Icons.thumb_down_outlined,
                            color: AppColors.error),
                        label: const Text('Reject Quotation',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            )),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            if (isPendingApproval && isSales)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: AppColors.warning),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Quotation submitted. Pending approval from Sales Head / Admin.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_existingQuotation?.status == QuotationStatus.rejected)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: AppColors.error),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'This quotation has been rejected. The deal is suspended.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (isConfirmed && !enabled)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'This quotation has been confirmed. Sales Order step is now unlocked.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () =>
                          _generateAndUploadPdf(_existingQuotation!.id),
                      child: const Text('Print PDF'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _syncPaymentTermAmounts() {
    final gt = _grandTotal;
    for (final term in _paymentTerms) {
      final p = (term['percent'] as num?)?.toDouble() ?? 0.0;
      term['amount'] = gt * (p / 100.0);
    }
  }

  Widget _buildPaymentTermsCard(bool enabled, {required bool isAdmin}) {
    _syncPaymentTermAmounts();
    final double totalPercent = _paymentTerms.fold<double>(
      0.0,
      (sum, item) => sum + ((item['percent'] as num?)?.toDouble() ?? 0.0),
    );
    final bool isFull100 = (totalPercent - 100.0).abs() < 0.01;

    final defaultStageNames = ['Advance', 'Dispatch', 'Installation', 'Completion'];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Payment Terms & Milestones',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Default stages: Advance, Dispatch, Installation, Completion',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 100% Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFull100
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFull100
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFull100 ? Icons.check_circle : Icons.pie_chart_outline,
                        size: 13,
                        color: isFull100 ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFull100
                            ? '100%'
                            : '${totalPercent.toStringAsFixed(totalPercent == totalPercent.roundToDouble() ? 0 : 1)}%',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isFull100 ? const Color(0xFF059669) : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Template selector row
          if (enabled) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: AppColors.background.withOpacity(0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Payment Templates:',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...[..._defaultPaymentTemplates, ..._customPaymentTemplates].map((t) {
                          final name = t['name'] as String;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => _applyPaymentTemplate(t),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 13, color: AppColors.primary),
                                    const SizedBox(width: 5),
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isCustomTermsEditing = !_isCustomTermsEditing;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isCustomTermsEditing ? Icons.check : Icons.edit_note,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isCustomTermsEditing ? 'Done' : 'Custom Edit',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (isAdmin)
                          InkWell(
                            onTap: _showManageTemplatesDialog,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6D28D9).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF6D28D9).withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.tune, size: 14, color: Color(0xFF6D28D9)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Manage Templates',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: Color(0xFF6D28D9),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // Table Section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2744),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 30),
                      Expanded(
                        flex: 5,
                        child: Text(
                          'Payment Term / Stage',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Percentage (%)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Amount (₹)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(width: 36),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Table rows
                ..._paymentTerms.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final termName = item['term']?.toString() ?? '';
                  final pct = (item['percent'] as num?)?.toDouble() ?? 0.0;
                  final amt = _grandTotal * (pct / 100.0);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        // Milestone number badge
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F2744),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 5,
                          child: enabled
                              ? TextFormField(
                                  initialValue: termName,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: idx < defaultStageNames.length ? defaultStageNames[idx] : 'Stage ${idx + 1}',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                    ),
                                  ),
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600),
                                  onChanged: (val) {
                                    item['term'] = val;
                                  },
                                )
                              : Text(
                                  termName,
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: enabled
                              ? TextFormField(
                                  initialValue: pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    suffixText: '%',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                    ),
                                  ),
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold),
                                  onChanged: (val) {
                                    final parsed = double.tryParse(val);
                                    if (parsed != null) {
                                      final otherTotal = _paymentTerms
                                          .asMap()
                                          .entries
                                          .where((e) => e.key != idx)
                                          .fold<double>(0.0, (s, e) => s + ((e.value['percent'] as num?)?.toDouble() ?? 0.0));
                                      final capped = (parsed + otherTotal > 100.0) ? (100.0 - otherTotal) : parsed;
                                      setState(() {
                                        item['percent'] = capped < 0 ? 0.0 : capped;
                                        _syncPaymentTermAmounts();
                                      });
                                    }
                                  },
                                )
                              : Text(
                                  '${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: Text(
                            '₹${InventoryAutocomplete.formatIndianPrice(amt)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (enabled) ...[
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.error),
                            tooltip: 'Remove stage',
                            onPressed: _paymentTerms.length <= 1
                                ? null
                                : () {
                                    setState(() {
                                      _paymentTerms.removeAt(idx);
                                      _syncPaymentTermAmounts();
                                    });
                                  },
                          ),
                        ] else ...[
                          const SizedBox(width: 36),
                        ],
                      ],
                    ),
                  );
                }),

                // Add Stage Button
                if (enabled && totalPercent < 100.0) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () {
                        final remaining = (100.0 - totalPercent).clamp(0.0, 100.0);
                        final nextName = _paymentTerms.length < defaultStageNames.length
                            ? defaultStageNames[_paymentTerms.length]
                            : 'Stage ${_paymentTerms.length + 1}';
                        setState(() {
                          _paymentTerms.add({
                            'term': nextName,
                            'percent': remaining,
                            'amount': 0.0,
                          });
                          _syncPaymentTermAmounts();
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: Text(
                        'Add Stage (${_paymentTerms.length < defaultStageNames.length ? defaultStageNames[_paymentTerms.length] : "Stage ${_paymentTerms.length + 1}"}) • ${(100.0 - totalPercent).toStringAsFixed(0)}% Left',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaFieldsCard(bool enabled) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue:
                      _existingQuotation?.quotationNumber.isNotEmpty == true
                          ? _existingQuotation!.quotationNumber
                          : 'Auto-generated on Save',
                  key: ValueKey(_existingQuotation?.quotationNumber),
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Quotation No',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: !enabled
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _orderDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            setState(() => _orderDate = date);
                          }
                        },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Quotation Date *',
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(_orderDate),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: enabled
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _billType,
                  decoration: const InputDecoration(labelText: 'Bill Type *'),
                  items: const [
                    DropdownMenuItem(value: 'Credit', child: Text('Credit')),
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  ],
                  onChanged: !enabled
                      ? null
                      : (v) => setState(() => _billType = v ?? 'Credit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _placeOfSupplyController,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Place of Supply *',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _distanceController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Distance (KM)',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (double.tryParse(v) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _grLrNoController,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'GR/LR No.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _destinationController,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Destination',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressFieldsCard(bool enabled) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Billing Address',
            style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _customerNameController,
            enabled: enabled,
            decoration: const InputDecoration(labelText: 'Customer Name *'),
            onChanged: (val) {
              final valTrimmed = val.trim();
              if (valTrimmed.length > 1) {
                if (_shippingNameController.text.trim().isEmpty ||
                    _shippingNameController.text.trim() ==
                        valTrimmed.substring(0, valTrimmed.length - 1)) {
                  _shippingNameController.text = valTrimmed;
                }
              } else {
                _shippingNameController.text = valTrimmed;
              }
            },
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _billingAddressController,
            enabled: enabled,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Billing Address *'),
            onChanged: (val) {
              final valTrimmed = val.trim();
              if (valTrimmed.length > 1) {
                if (_shippingAddressController.text.trim().isEmpty ||
                    _shippingAddressController.text.trim() ==
                        valTrimmed.substring(0, valTrimmed.length - 1)) {
                  _shippingAddressController.text = valTrimmed;
                }
              } else {
                _shippingAddressController.text = valTrimmed;
              }
            },
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _customerGstinController,
                  enabled: enabled,
                  decoration:
                      const InputDecoration(labelText: 'Customer GSTIN'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _customerPhoneController,
                  enabled: enabled,
                  decoration:
                      const InputDecoration(labelText: 'Customer Phone'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _partyContactPersonController,
            enabled: enabled,
            decoration:
                const InputDecoration(labelText: 'Party Contact Person'),
          ),
          const Divider(height: 24),
          const Text(
            'Shipping Address',
            style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _shippingNameController,
            enabled: enabled,
            decoration: const InputDecoration(labelText: 'Shipping Name *'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _shippingAddressController,
            enabled: enabled,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Shipping Address *'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _stateCodeController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'State Code *'),
                  onChanged: (v) {
                    setState(() {});
                  },
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _salesmanController,
                  enabled: enabled,
                  decoration: const InputDecoration(labelText: 'Salesman'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PipelineHeader extends StatelessWidget {
  final String customerName;
  final String productName;
  final String? quotationNumber;
  final QuotationStatus? status;

  const _PipelineHeader({
    required this.customerName,
    required this.productName,
    this.quotationNumber,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customerName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            productName,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (quotationNumber != null && quotationNumber!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Quotation Ref: $quotationNumber',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> item;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;
  final bool enabled;

  const _LineItemRow({
    required this.index,
    required this.item,
    this.onRemove,
    required this.onChanged,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Item ${index + 1}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remove Item',
                ),
            ],
          ),
          const SizedBox(height: 8),
          InventoryAutocomplete(
            controller: item['description'] as TextEditingController,
            enabled: enabled,
            onChanged: onChanged,
            onItemSelected: (selection) {
              final hsnController = item['hsn_sac'] as TextEditingController;
              final uomController = item['uom'] as TextEditingController;
              final priceController = item['unit_price'] as TextEditingController;
              
              if (hsnController.text.isEmpty) hsnController.text = selection.hsnSac ?? '';
              if (uomController.text.isEmpty) uomController.text = selection.uom ?? '';
              if (priceController.text.isEmpty || priceController.text == '0.00' || priceController.text == '0') {
                priceController.text = InventoryAutocomplete.formatIndianPrice(selection.price);
              }
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item['hsn_sac'] as TextEditingController,
                  enabled: enabled,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'HSN / SAC'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: item['uom'] as TextEditingController,
                  enabled: enabled,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'UOM *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item['qty'] as TextEditingController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(labelText: 'Qty *'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = int.tryParse(v);
                    if (n == null || n <= 0) return 'Must be > 0';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: item['gst_percent'] as TextEditingController,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    labelText: 'GST % *',
                    suffixText: '%',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = double.tryParse(v);
                    if (n == null || n < 0 || n > 100) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: item['disc_percent'] as TextEditingController,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(labelText: 'Disc %'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final n = double.tryParse(v);
                    if (n == null || n < 0 || n > 100) return 'Invalid';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: item['unit_price'] as TextEditingController,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Item Rate (₹) *',
              prefixText: '₹ ',
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final clean = v.replaceAll(',', '').trim();
              final n = double.tryParse(clean);
              if (n == null || n < 0) return 'Invalid rate';
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _TotalRowWidget extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _TotalRowWidget(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? AppColors.primary : AppColors.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;

  const _TotalRow(this.label, this.amount, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,##,##0.00', 'en_IN');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: bold ? FontWeight.w700 : null)),
        Text('₹${f.format(amount)}',
            style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: bold ? FontWeight.w700 : null)),
      ],
    );
  }
}
