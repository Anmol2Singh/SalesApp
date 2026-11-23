import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/sales_order.dart';
import '../../../core/models/pipeline.dart';
import '../../../core/widgets/inventory_autocomplete.dart';
import '../../../core/widgets/searchable_dropdown.dart';
import '../../../core/models/quotation.dart';
import '../../../core/models/supplementary_item.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../pipelines/providers/pipelines_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/providers/inventory_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/notification_backend_helper.dart';
import '../../../core/widgets/pdf_preview_screen.dart';

class SalesOrderFormScreen extends ConsumerStatefulWidget {
  final String pipelineId;

  const SalesOrderFormScreen({super.key, required this.pipelineId});

  @override
  ConsumerState<SalesOrderFormScreen> createState() =>
      _SalesOrderFormScreenState();
}

class _SalesOrderFormScreenState extends ConsumerState<SalesOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers for shipping metadata
  final _shippingCompanyController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _distanceController = TextEditingController();
  final _grLrNoController = TextEditingController();
  final _destinationController = TextEditingController();
  final _placeOfSupplyController = TextEditingController(text: 'Maharashtra');
  final _paymentTermsController = TextEditingController();
  final _billingAddressController = TextEditingController();
  final _shippingAddressController = TextEditingController();
  final _remarksController = TextEditingController();

  final _ewayBillNoController = TextEditingController();
  final _ewayBillDateController = TextEditingController();
  final _expectedDispatchDateController = TextEditingController();
  final _salesmanController = TextEditingController();
  final _partyContactPersonController = TextEditingController();
  String _billType = 'Credit';

  // Line items
  final List<Map<String, dynamic>> _lineItems = [];

  // Supplementary items
  final List<Map<String, dynamic>> _supplementaryItems = [];

  // Payment terms stages & controllers (identical to quotation)
  final List<Map<String, dynamic>> _paymentTerms = [];
  final List<TextEditingController> _paymentTermNameControllers = [];
  final List<TextEditingController> _paymentPercentControllers = [];
  final List<TextEditingController> _paymentAmountControllers = [];

  static final List<Map<String, dynamic>> _defaultPaymentTemplates = [
    {
      'name': '100% Advance',
      'stages': [
        {'term': 'Advance with Order', 'percent': 100.0},
      ],
    },
    {
      'name': '50% - 50%',
      'stages': [
        {'term': 'Advance with PO', 'percent': 50.0},
        {'term': 'Before Dispatch', 'percent': 50.0},
      ],
    },
    {
      'name': '30% - 60% - 10%',
      'stages': [
        {'term': 'Advance with PO', 'percent': 30.0},
        {'term': 'Against Proforma / Before Dispatch', 'percent': 60.0},
        {'term': 'After Installation / Handover', 'percent': 10.0},
      ],
    },
    {
      'name': '40% - 50% - 10%',
      'stages': [
        {'term': 'Advance with Order', 'percent': 40.0},
        {'term': 'Before Dispatch', 'percent': 50.0},
        {'term': 'After Testing & Commissioning', 'percent': 10.0},
      ],
    },
  ];

  // GST rates
  double _cgstRate = 9.0;
  double _sgstRate = 9.0;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  SalesOrder? _existingSalesOrder;
  SalesPipeline? _pipeline;
  Product? _product;
  Quotation? _quotation;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _shippingCompanyController.dispose();
    _vehicleNumberController.dispose();
    _distanceController.dispose();
    _grLrNoController.dispose();
    _destinationController.dispose();
    _placeOfSupplyController.dispose();
    _paymentTermsController.dispose();
    _billingAddressController.dispose();
    _shippingAddressController.dispose();
    _remarksController.dispose();
    _ewayBillNoController.dispose();
    _ewayBillDateController.dispose();
    _expectedDispatchDateController.dispose();
    _salesmanController.dispose();
    _partyContactPersonController.dispose();
    for (final item in _lineItems) {
      (item['description'] as TextEditingController).dispose();
      (item['hsn_sac'] as TextEditingController).dispose();
      (item['qty'] as TextEditingController).dispose();
      (item['gst_percent'] as TextEditingController?)?.dispose();
      (item['free_qty'] as TextEditingController?)?.dispose();
      (item['uom'] as TextEditingController).dispose();
      (item['rate'] as TextEditingController).dispose();
      (item['disc_percent'] as TextEditingController).dispose();
      (item['remark'] as TextEditingController?)?.dispose();
    }
    for (final item in _supplementaryItems) {
      (item['name'] as TextEditingController).dispose();
      (item['qty'] as TextEditingController).dispose();
      (item['rate'] as TextEditingController).dispose();
      (item['gst_percent'] as TextEditingController).dispose();
      (item['type'] as TextEditingController).dispose();
    }
    for (final c in _paymentTermNameControllers) {
      c.dispose();
    }
    for (final c in _paymentPercentControllers) {
      c.dispose();
    }
    for (final c in _paymentAmountControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final supabase = ref.read(supabaseClientProvider);

      // Load pipeline with customer and product
      final pipelineData = await supabase
          .from('sales_pipelines')
          .select('*, products(*), customers(*)')
          .eq('id', widget.pipelineId)
          .single();

      _pipeline = SalesPipeline.fromJson(pipelineData);
      _product = _pipeline?.product;

      // Load confirmed quotation to prefill items and addresses
      final quotationData = await supabase
          .from('quotations')
          .select()
          .eq('pipeline_id', widget.pipelineId)
          .eq('status', 'confirmed')
          .maybeSingle();

      if (quotationData != null) {
        _quotation = Quotation.fromJson(quotationData);
      }

      // Load existing sales order if it exists
      final soData = await supabase
          .from('sales_orders')
          .select()
          .eq('pipeline_id', widget.pipelineId)
          .maybeSingle();

      if (soData != null) {
        _existingSalesOrder = SalesOrder.fromJson(soData);
        _isEditing = !_existingSalesOrder!.isConfirmed;

        // Prefill shipping details
        _shippingCompanyController.text =
            _existingSalesOrder!.shippingCompany ?? '';
        _vehicleNumberController.text =
            _existingSalesOrder!.vehicleNumber ?? '';
        _distanceController.text = _existingSalesOrder!.distance ?? '';
        _grLrNoController.text = _existingSalesOrder!.grLrNo ?? '';
        _destinationController.text = _existingSalesOrder!.destination ?? '';
        _placeOfSupplyController.text =
            _existingSalesOrder!.placeOfSupply ?? 'Maharashtra';
        _paymentTermsController.text = _existingSalesOrder!.paymentTerms ?? '';
        _billingAddressController.text =
            _existingSalesOrder!.billingAddress ?? '';
        _shippingAddressController.text =
            _existingSalesOrder!.shippingAddress ?? '';
        _remarksController.text = _existingSalesOrder!.remarks ?? '';
        _ewayBillNoController.text = _existingSalesOrder!.ewayBillNo ?? '';
        _ewayBillDateController.text = _existingSalesOrder!.ewayBillDate ?? '';
        _expectedDispatchDateController.text =
            _existingSalesOrder!.expectedDispatchDate != null
                ? DateFormat('dd/MM/yyyy')
                    .format(_existingSalesOrder!.expectedDispatchDate!)
                : '';
        _salesmanController.text = _existingSalesOrder!.salesman ?? '';
        _partyContactPersonController.text =
            _existingSalesOrder!.partyContactPerson ?? '';
        _billType = _existingSalesOrder!.billType ?? 'Credit';

        // Prefill line items
        for (final item in _existingSalesOrder!.lineItems) {
          _lineItems.add({
            'description': TextEditingController(text: item.description),
            'hsn_sac': TextEditingController(text: item.hsnSac ?? ''),
            'qty': TextEditingController(text: item.qty.toInt().toString()),
            'gst_percent': TextEditingController(text: item.gstPercent.toString()),
            'free_qty': TextEditingController(text: '0'),
            'uom': TextEditingController(text: item.uom),
            'rate': TextEditingController(text: InventoryAutocomplete.formatIndianPrice(item.rate)),
            'disc_percent':
                TextEditingController(text: item.discPercent.toString()),
            'remark': TextEditingController(text: item.remark ?? ''),
          });
        }
        _cgstRate = _existingSalesOrder!.cgstRate;
        _sgstRate = _existingSalesOrder!.sgstRate;

        // Prefill supplementary items from existing sales order
        _supplementaryItems.clear();
        if (_existingSalesOrder!.supplementaryTerms != null &&
            _existingSalesOrder!.supplementaryTerms!.isNotEmpty) {
          for (final supp in _existingSalesOrder!.supplementaryTerms!) {
            _supplementaryItems.add({
              'name': TextEditingController(text: supp.name),
              'qty': TextEditingController(text: supp.qty.toInt().toString()),
              'rate': TextEditingController(text: supp.rate.toString()),
              'gst_percent': TextEditingController(text: supp.gstPercent.toString()),
              'type': TextEditingController(text: supp.type.isNotEmpty ? supp.type : 'Extra'),
            });
          }
        }

        // Prefill payment terms stages from existing sales order
        _paymentTerms.clear();
        if (_existingSalesOrder!.paymentTermsStages != null &&
            _existingSalesOrder!.paymentTermsStages!.isNotEmpty) {
          _paymentTerms.addAll(List<Map<String, dynamic>>.from(_existingSalesOrder!.paymentTermsStages!));
        }
      } else {
        // First-time prefill from customer and quotation
        _isEditing = true;
        if (_pipeline?.customer != null) {
          _billingAddressController.text = _pipeline!.customer!.address ?? '';
          _shippingAddressController.text = _pipeline!.customer!.address ?? '';
          _partyContactPersonController.text =
              _pipeline!.customer!.contactPerson ?? '';
        }
        final profile = ref.read(currentProfileProvider);
        if (profile != null) {
          _salesmanController.text = profile.fullName;
        }
        _billType = 'Credit';
        if (_quotation != null) {
          _paymentTermsController.text = _quotation!.termsText ?? '';
          _remarksController.text = _quotation!.termsText ?? '';
          _cgstRate = _quotation!.cgstRate;
          _sgstRate = _quotation!.sgstRate;

          // Prefill line items from quotation
          for (final item in _quotation!.lineItems) {
            _lineItems.add({
              'description': TextEditingController(text: item.description),
              'hsn_sac':
                  TextEditingController(text: item.hsnSac ?? '85308000'), // Default HSN code
              'qty': TextEditingController(text: item.qty.toInt().toString()),
              'gst_percent': TextEditingController(text: item.gstPercent.toString()),
              'free_qty': TextEditingController(text: '0'),
              'uom': TextEditingController(text: item.uom),
              'rate': TextEditingController(
                  text: InventoryAutocomplete.formatIndianPrice(item.unitPrice)),
              'disc_percent': TextEditingController(text: item.discPercent.toString()),
              'remark': TextEditingController(text: item.remark ?? ''),
            });
          }

          // Prefill supplementary items from quotation
          _supplementaryItems.clear();
          if (_quotation!.supplementaryTerms != null &&
              _quotation!.supplementaryTerms!.isNotEmpty) {
            for (final supp in _quotation!.supplementaryTerms!) {
              _supplementaryItems.add({
                'name': TextEditingController(text: supp.name),
                'qty': TextEditingController(text: supp.qty.toInt().toString()),
                'rate': TextEditingController(text: supp.rate.toString()),
                'gst_percent': TextEditingController(text: supp.gstPercent.toString()),
                'type': TextEditingController(text: supp.type.isNotEmpty ? supp.type : 'Extra'),
              });
            }
          }

          // Prefill payment terms stages from quotation
          _paymentTerms.clear();
          if (_quotation!.paymentTerms != null &&
              _quotation!.paymentTerms!.isNotEmpty) {
            _paymentTerms.addAll(List<Map<String, dynamic>>.from(_quotation!.paymentTerms!));
          }
        }
      }

      if (_paymentTerms.isEmpty) {
        _paymentTerms.add({'term': 'Advance with Order', 'percent': 100.0, 'amount': 0.0});
      }
      _syncPaymentTermControllers();

      if (_lineItems.isEmpty) _addLineItem();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading data: $e'),
              backgroundColor: AppColors.error),
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
        'hsn_sac': TextEditingController(text: '85308000'),
        'qty': TextEditingController(text: '1'),
        'gst_percent': TextEditingController(text: '18.0'),
        'free_qty': TextEditingController(text: '0'),
        'uom': TextEditingController(text: 'NOS'),
        'rate': TextEditingController(text: '0.00'),
        'disc_percent': TextEditingController(text: '0.0'),
        'remark': TextEditingController(),
      });
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      final item = _lineItems.removeAt(index);
      (item['description'] as TextEditingController).dispose();
      (item['hsn_sac'] as TextEditingController).dispose();
      (item['qty'] as TextEditingController).dispose();
      (item['gst_percent'] as TextEditingController?)?.dispose();
      (item['free_qty'] as TextEditingController?)?.dispose();
      (item['uom'] as TextEditingController).dispose();
      (item['rate'] as TextEditingController).dispose();
      (item['disc_percent'] as TextEditingController).dispose();
      (item['remark'] as TextEditingController?)?.dispose();
    });
  }

  void _addSupplementaryItem({
    String name = '',
    double rate = 0,
    double gst = 18.0,
    String type = 'Extra',
    int qty = 1,
  }) {
    setState(() {
      _supplementaryItems.add({
        'name': TextEditingController(text: name),
        'qty': TextEditingController(text: qty.toString()),
        'rate': TextEditingController(text: rate.toString()),
        'gst_percent': TextEditingController(text: gst.toString()),
        'type': TextEditingController(text: type),
      });
    });
  }

  void _removeSupplementaryItem(int index) {
    setState(() {
      final item = _supplementaryItems.removeAt(index);
      (item['name'] as TextEditingController).dispose();
      (item['qty'] as TextEditingController).dispose();
      (item['rate'] as TextEditingController).dispose();
      (item['gst_percent'] as TextEditingController).dispose();
      (item['type'] as TextEditingController).dispose();
    });
  }

  double _calcSubtotal() {
    double total = 0;
    for (final item in _lineItems) {
      final qty =
          num.tryParse((item['qty'] as TextEditingController).text.replaceAll(',', '').trim())?.toInt() ?? 0;
      final rate =
          double.tryParse((item['rate'] as TextEditingController).text.replaceAll(',', '').trim()) ?? 0;
      final disc = double.tryParse(
              (item['disc_percent'] as TextEditingController).text.replaceAll(',', '').trim()) ??
          0;
      total += (qty * rate) * (1 - disc / 100);
    }
    return total;
  }

  double _calcSupplementarySubtotal() {
    double total = 0;
    for (final item in _supplementaryItems) {
      final type = (item['type'] as TextEditingController).text.trim();
      if (type.toLowerCase() == 'included') continue;
      final qty = int.tryParse((item['qty'] as TextEditingController).text) ?? 0;
      final rate = double.tryParse((item['rate'] as TextEditingController).text) ?? 0;
      total += qty * rate;
    }
    return total;
  }

  void _syncPaymentTermAmounts() {
    for (int i = 0; i < _paymentTerms.length; i++) {
      final p = (_paymentTerms[i]['percent'] as num?)?.toDouble() ?? 0.0;
      _paymentTerms[i]['amount'] = (_grandTotal * (p / 100.0)).roundToDouble();
    }
  }

  void _syncPaymentTermControllers() {
    while (_paymentTermNameControllers.length < _paymentTerms.length) {
      final idx = _paymentTermNameControllers.length;
      final item = _paymentTerms[idx];
      final t = item['term']?.toString() ?? '';
      final p = (item['percent'] as num?)?.toDouble() ?? 0.0;
      final a = (item['amount'] as num?)?.toDouble() ??
          (_grandTotal * (p / 100.0)).roundToDouble();
      _paymentTermNameControllers.add(TextEditingController(text: t));
      _paymentPercentControllers.add(TextEditingController(
          text: p.toStringAsFixed(p == p.roundToDouble() ? 0 : 1)));
      _paymentAmountControllers.add(TextEditingController(
          text: a > 0 ? a.round().toString() : '0'));
    }
    while (_paymentTermNameControllers.length > _paymentTerms.length) {
      _paymentTermNameControllers.removeLast().dispose();
      _paymentPercentControllers.removeLast().dispose();
      _paymentAmountControllers.removeLast().dispose();
    }
    for (int i = 0; i < _paymentTerms.length; i++) {
      final item = _paymentTerms[i];
      final t = item['term']?.toString() ?? '';
      final p = (item['percent'] as num?)?.toDouble() ?? 0.0;
      final a = (item['amount'] as num?)?.toDouble() ??
          (_grandTotal * (p / 100.0)).roundToDouble();
      if (_paymentTermNameControllers[i].text != t) {
        _paymentTermNameControllers[i].text = t;
      }
      final pText = p.toStringAsFixed(p == p.roundToDouble() ? 0 : 1);
      if (_paymentPercentControllers[i].text != pText) {
        _paymentPercentControllers[i].text = pText;
      }
      final aText = a > 0 ? a.round().toString() : '0';
      if (_paymentAmountControllers[i].text != aText) {
        _paymentAmountControllers[i].text = aText;
      }
    }
    _syncPaymentTermsController();
  }

  void _syncPaymentTermsController() {
    if (_paymentTerms.isNotEmpty) {
      _paymentTermsController.text = _paymentTerms.map((t) {
        final p = (t['percent'] ?? t['percentage'] as num?)?.toDouble() ?? 0.0;
        final name = t['term'] ?? t['condition'] ?? t['stage'] ?? '';
        return '${p.toStringAsFixed(0)}% $name';
      }).join(', ');
    }
  }

  void _onPaymentPercentChanged(int idx, String val) {
    if (idx >= _paymentTerms.length) return;
    final parsed = double.tryParse(val) ?? 0.0;
    _paymentTerms[idx]['percent'] = parsed;
    final calcAmt = (_grandTotal * (parsed / 100.0)).roundToDouble();
    _paymentTerms[idx]['amount'] = calcAmt;
    if (idx < _paymentAmountControllers.length) {
      final aText = calcAmt > 0 ? calcAmt.round().toString() : '0';
      if (_paymentAmountControllers[idx].text != aText) {
        _paymentAmountControllers[idx].text = aText;
      }
    }
    _syncPaymentTermsController();
    setState(() {});
  }

  void _onPaymentAmountChanged(int idx, String val) {
    if (idx >= _paymentTerms.length) return;
    final clean = val.replaceAll(',', '').trim();
    final parsedAmt = double.tryParse(clean) ?? 0.0;
    _paymentTerms[idx]['amount'] = parsedAmt;
    final calcPct = _grandTotal > 0 ? (parsedAmt / _grandTotal * 100.0) : 0.0;
    final roundedPct = double.parse(calcPct.toStringAsFixed(2));
    _paymentTerms[idx]['percent'] = roundedPct;
    if (idx < _paymentPercentControllers.length) {
      final pText = roundedPct.toStringAsFixed(
          roundedPct == roundedPct.roundToDouble() ? 0 : 1);
      if (_paymentPercentControllers[idx].text != pText) {
        _paymentPercentControllers[idx].text = pText;
      }
    }
    _syncPaymentTermsController();
    setState(() {});
  }

  void _applyPaymentTemplate(Map<String, dynamic> t) {
    final stages = t['stages'] as List<dynamic>? ?? [];
    if (stages.isEmpty) return;
    setState(() {
      _paymentTerms.clear();
      for (final s in stages) {
        final st = Map<String, dynamic>.from(s as Map);
        final pct = (st['percent'] as num?)?.toDouble() ?? 0.0;
        final amt = (_grandTotal * (pct / 100.0)).roundToDouble();
        _paymentTerms.add({
          'term': st['term']?.toString() ?? '',
          'percent': pct,
          'amount': amt,
        });
      }
      _syncPaymentTermControllers();
    });
  }

  Widget _buildPaymentTermsCard(bool enabled) {
    _syncPaymentTermAmounts();
    final double totalPercent = _paymentTerms.fold<double>(
      0.0,
      (sum, item) => sum + ((item['percent'] as num?)?.toDouble() ?? 0.0),
    );
    final bool isFull100 = (totalPercent - 100.0).abs() < 0.01;

    final defaultStageNames = [
      'Advance',
      'Dispatch',
      'Installation',
      'Completion'
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                  child: const Icon(Icons.account_balance_wallet_outlined,
                      size: 20, color: AppColors.primary),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        isFull100
                            ? Icons.check_circle
                            : Icons.pie_chart_outline,
                        size: 13,
                        color: isFull100
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
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
                          color: isFull100
                              ? const Color(0xFF059669)
                              : const Color(0xFFD97706),
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
              color: AppColors.background.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.auto_awesome,
                          size: 14, color: AppColors.primary),
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
                        ..._defaultPaymentTemplates.map((t) {
                          final name = t['name'] as String;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => _applyPaymentTemplate(t),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_outline,
                                        size: 13, color: AppColors.primary),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  final amt = (_grandTotal * (pct / 100.0)).roundToDouble();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                                  controller: _paymentTermNameControllers.length > idx
                                      ? _paymentTermNameControllers[idx]
                                      : null,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: idx < defaultStageNames.length
                                        ? defaultStageNames[idx]
                                        : 'Stage ${idx + 1}',
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: AppColors.primary, width: 1.5),
                                    ),
                                  ),
                                  style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                  onChanged: (val) {
                                    item['term'] = val;
                                    _syncPaymentTermsController();
                                  },
                                )
                              : Text(
                                  termName,
                                  style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: enabled
                              ? TextFormField(
                                  controller: _paymentPercentControllers.length > idx
                                      ? _paymentPercentControllers[idx]
                                      : null,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    suffixText: '%',
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: AppColors.primary, width: 1.5),
                                    ),
                                  ),
                                  style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                  onChanged: (val) =>
                                      _onPaymentPercentChanged(idx, val),
                                )
                              : Text(
                                  '${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: enabled
                              ? TextFormField(
                                  controller: _paymentAmountControllers.length > idx
                                      ? _paymentAmountControllers[idx]
                                      : null,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textAlign: TextAlign.right,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    prefixText: '₹',
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: AppColors.primary, width: 1.5),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                  onChanged: (val) =>
                                      _onPaymentAmountChanged(idx, val),
                                )
                              : Text(
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
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 20, color: AppColors.error),
                            tooltip: 'Remove stage',
                            onPressed: _paymentTerms.length <= 1
                                ? null
                                : () {
                                    setState(() {
                                      _paymentTerms.removeAt(idx);
                                      _syncPaymentTermAmounts();
                                      _syncPaymentTermControllers();
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
                if (enabled && totalPercent < 99.99) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                            color: AppColors.primary, width: 1.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      onPressed: () {
                        final remaining =
                            (100.0 - totalPercent).clamp(0.0, 100.0);
                        final nextName =
                            _paymentTerms.length < defaultStageNames.length
                                ? defaultStageNames[_paymentTerms.length]
                                : 'Stage ${_paymentTerms.length + 1}';
                        setState(() {
                          _paymentTerms.add({
                            'term': nextName,
                            'percent': remaining,
                            'amount': (_grandTotal * (remaining / 100.0)).roundToDouble(),
                          });
                          _syncPaymentTermControllers();
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: Text(
                        'Add Stage (${_paymentTerms.length < defaultStageNames.length ? defaultStageNames[_paymentTerms.length] : "Stage ${_paymentTerms.length + 1}"}) • ${(100.0 - totalPercent).toStringAsFixed(0)}% Left',
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
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

  bool get _isLocalGst {
    final state = _placeOfSupplyController.text.trim().toLowerCase();
    return state == 'maharashtra' || state == '27' || state == 'mh';
  }

  double get _taxableSubtotal => _calcSubtotal() + _calcSupplementarySubtotal();

  double get _totalGstAmount {
    double gstSum = 0;
    for (final item in _lineItems) {
      final qty = int.tryParse((item['qty'] as TextEditingController).text) ?? 0;
      final rate = double.tryParse((item['rate'] as TextEditingController).text.replaceAll(',', '')) ?? 0;
      final disc = double.tryParse((item['disc_percent'] as TextEditingController).text) ?? 0;
      final gst = double.tryParse((item['gst_percent'] as TextEditingController?)?.text ?? '18') ?? 18.0;
      final taxable = (qty * rate) * (1 - disc / 100);
      gstSum += taxable * (gst / 100);
    }
    for (final item in _supplementaryItems) {
      final type = (item['type'] as TextEditingController).text.trim();
      if (type.toLowerCase() == 'included') continue;
      final qty = int.tryParse((item['qty'] as TextEditingController).text) ?? 0;
      final rate = double.tryParse((item['rate'] as TextEditingController).text) ?? 0;
      final gst = double.tryParse((item['gst_percent'] as TextEditingController).text) ?? 18.0;
      gstSum += (qty * rate) * (gst / 100);
    }
    return gstSum;
  }

  double get _cgstAmount => _isLocalGst ? _totalGstAmount / 2 : 0.0;
  double get _sgstAmount => _isLocalGst ? _totalGstAmount / 2 : 0.0;
  double get _igstAmount => !_isLocalGst ? _totalGstAmount : 0.0;
  double get _unroundedTotal =>
      _taxableSubtotal + _cgstAmount + _sgstAmount + _igstAmount;
  double get _grandTotal => _unroundedTotal.roundToDouble();
  double get _roundOffAmount => _grandTotal - _unroundedTotal;

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _upsertSalesOrder(confirmed: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Draft saved'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveConfirmedChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final lineItemsValid = _lineItems.every((item) {
      final desc = (item['description'] as TextEditingController).text.trim();
      final qty =
          num.tryParse((item['qty'] as TextEditingController).text.replaceAll(',', '').trim())?.toInt() ?? 0;
      final rate =
          double.tryParse((item['rate'] as TextEditingController).text.replaceAll(',', '').trim()) ?? -1;
      return desc.isNotEmpty && qty > 0 && rate >= 0;
    });

    if (!lineItemsValid) {
      _showError(
          'All line items must have description, quantity > 0, and rate >= 0.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final soId = await _upsertSalesOrder(confirmed: true);
      final supabase = ref.read(supabaseClientProvider);

      // Audit log
      await supabase.from('step_audit_log').insert({
        'pipeline_id': widget.pipelineId,
        'step_name': 'sales_order',
        'action': 'updated',
        'performed_by': supabase.auth.currentUser!.id,
      });

      // Prompt to choose variant for layout print
      if (mounted) {
        await _showVariantPickerDialog(soId);
      }

      ref.invalidate(pipelineDetailProvider(widget.pipelineId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Sales Order changes saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmSalesOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final lineItemsValid = _lineItems.every((item) {
      final desc = (item['description'] as TextEditingController).text.trim();
      final qty =
          num.tryParse((item['qty'] as TextEditingController).text.replaceAll(',', '').trim())?.toInt() ?? 0;
      final rate =
          double.tryParse((item['rate'] as TextEditingController).text.replaceAll(',', '').trim()) ?? -1;
      return desc.isNotEmpty && qty > 0 && rate >= 0;
    });

    if (!lineItemsValid) {
      _showError(
          'All line items must have description, quantity > 0, and rate >= 0.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Sales Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Once confirmed, this will generate the Sales Order PDF and unlock the BOQ step. Continue?',
              style: TextStyle(fontFamily: 'Inter', height: 1.5),
            ),
            const SizedBox(height: 16),
            _SummaryRow('Subtotal', _calcSubtotal()),
            if (_isLocalGst) ...[
              _SummaryRow('CGST Amount', _cgstAmount),
              _SummaryRow('SGST Amount', _sgstAmount),
            ] else ...[
              _SummaryRow('IGST Amount', _igstAmount),
            ],
            if (_roundOffAmount.abs() >= 0.005) ...[
              _SummaryRow(
                'Round Off',
                _roundOffAmount,
                customValue:
                    'Rs. ${_roundOffAmount > 0 ? '+' : ''}${_roundOffAmount.toStringAsFixed(2)}',
              ),
            ],
            const Divider(),
            _SummaryRow('Grand Total', _grandTotal, bold: true),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Print'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final soId = await _upsertSalesOrder(confirmed: true);
      final supabase = ref.read(supabaseClientProvider);

      // Advance pipeline to BOQ
      await supabase
          .from('sales_pipelines')
          .update({'current_step': 'boq'}).eq('id', widget.pipelineId);

      // Audit log
      await supabase.from('step_audit_log').insert({
        'pipeline_id': widget.pipelineId,
        'step_name': 'sales_order',
        'action': 'confirmed',
        'performed_by': supabase.auth.currentUser!.id,
      });

      // Notification
      final custName = _pipeline?.customer?.companyName ?? '';
      final prodName = _product?.name ?? _pipeline?.product?.name ?? 'deal';
      final custSuffix = custName.isNotEmpty ? ' for $custName ($prodName)' : '';
      await NotificationBackendHelper.notifyWorkflowStep(
        supabase: supabase,
        targetRoles: ['boq', 'service_head'],
        dealOwnerId: _pipeline?.createdBy,
        title: 'BOQ Stage Unlocked',
        body: 'Sales Order confirmed$custSuffix. BOQ step is now available.',
        type: 'step_unlocked',
        relatedPipelineId: widget.pipelineId,
      );

      // Prompt to choose variant for layout print
      if (mounted) {
        await _showVariantPickerDialog(soId);
      }

      ref.invalidate(pipelineDetailProvider(widget.pipelineId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Sales Order confirmed! BOQ step unlocked.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go(AppRoutes.pipelineDetail.replaceAll(':id', widget.pipelineId));
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showVariantPickerDialog(String soId) async {
    final variant = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select PDF Variant'),
        content: const Text(
          'Choose the variant of Sales Order you want to print / preview:',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'commercial'),
              child: const Text('Commercial (Main)')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'technical'),
              child: const Text('Technical (BOQ)')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'production'),
              child: const Text('Production (Factory)')),
        ],
      ),
    );

    if (variant != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
      try {
        final result = await _generatePdfBytes(soId, variant);
        if (mounted) Navigator.pop(context); // pop loading dialog
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfPreviewScreen(
                pdfBytes: result.bytes,
                fileName: result.fileName,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        _showError('Failed to print PDF: $e');
      }
    }
  }

  Future<({Uint8List bytes, String fileName})> _generatePdfBytes(String soId, String variant) async {
    final supabase = ref.read(supabaseClientProvider);
    final soData =
        await supabase.from('sales_orders').select().eq('id', soId).single();
    final so = SalesOrder.fromJson(soData);

    // Fetch latest pipeline data with customer and product details
    final pipelineData = await supabase
        .from('sales_pipelines')
        .select('*, customers(*), products(*)')
        .eq('id', so.pipelineId)
        .single();
    final pipeline = SalesPipeline.fromJson(pipelineData);

    final customer = pipeline.customer ?? Customer(
      id: pipeline.customerId,
      companyName: 'Default Customer',
      contactPerson: 'Contact Person',
      phone: '',
      email: '',
      createdBy: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final product = pipeline.product ?? Product(
      id: pipeline.productId,
      name: 'Default Product',
      category: 'HVAC',
      baseSpecs: const ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Map<String, dynamic> templateConfig;
    try {
      final templateData = await supabase
          .from('pdf_templates')
          .select()
          .eq('document_type', 'sales_order')
          .single();
      templateConfig =
          (templateData)['template_config'] as Map<String, dynamic>;
    } catch (_) {
      templateConfig = {
        'company_name': 'INSIYA TRADING CORPORATION',
        'company_address':
            'Office No 807, 8th Floor, Finswell Building, Behind Hyatt Hotel, Viman Nagar, Pune, Maharashtra 411014',
        'company_phone': '+91 92929 22992',
        'company_email': 'insiyasolarindustry@gmail.com',
        'company_gst': '27CFTPS5292A1ZY',
        'footer_text':
            'We declare that this invoice shows the actual price of the goods described.',
      };
    }

    final bytes = await PdfService.generateSalesOrderPdf(
      salesOrder: so,
      customer: customer,
      product: product,
      variant: variant,
      templateConfig: templateConfig,
      quotation: _quotation,
    );

    final String formattedSoNum = PdfService.formatSalesOrderNumber(so.salesOrderNumber, so.orderDate);
    final String cleanOrderNum = formattedSoNum.replaceAll('/', '_');
    final String fileName = variant == 'production' ? '${cleanOrderNum}_Production.pdf' : '$cleanOrderNum.pdf';
    return (bytes: bytes, fileName: fileName);
  }

  Future<String> _upsertSalesOrder({required bool confirmed}) async {
    final supabase = ref.read(supabaseClientProvider);

    final lineItemsJson = _lineItems.map((item) {
      final qty =
          num.tryParse((item['qty'] as TextEditingController).text.replaceAll(',', '').trim())?.toInt() ?? 0;
      final rate =
          double.tryParse((item['rate'] as TextEditingController).text.replaceAll(',', '').trim()) ?? 0;
      final gstPercent = double.tryParse(
              (item['gst_percent'] as TextEditingController?)?.text.replaceAll(',', '').trim() ?? '18') ??
          18.0;
      final freeQty =
          num.tryParse((item['free_qty'] as TextEditingController?)?.text.replaceAll(',', '').trim() ?? '0')?.toInt() ??
              0;
      final disc = double.tryParse(
              (item['disc_percent'] as TextEditingController).text.replaceAll(',', '').trim()) ??
          0;
      return {
        'description':
            (item['description'] as TextEditingController).text.trim(),
        'hsn_sac': (item['hsn_sac'] as TextEditingController).text.trim(),
        'qty': qty,
        'free_qty': freeQty,
        'gst_percent': gstPercent,
        'uom': (item['uom'] as TextEditingController).text.trim().toUpperCase(),
        'rate': rate,
        'disc_percent': disc,
        'amount': (qty * rate) * (1 - disc / 100),
        'remark': (item['remark'] as TextEditingController?)?.text.trim().isNotEmpty == true
            ? (item['remark'] as TextEditingController).text.trim()
            : null,
      };
    }).toList();

    final supplementaryTermsJson = _supplementaryItems.map((item) {
      final name = (item['name'] as TextEditingController).text.trim();
      final qty = int.tryParse((item['qty'] as TextEditingController).text) ?? 1;
      final rate = double.tryParse((item['rate'] as TextEditingController).text) ?? 0.0;
      final gst = double.tryParse((item['gst_percent'] as TextEditingController).text) ?? 18.0;
      final type = (item['type'] as TextEditingController).text.trim();
      final isInc = type.toLowerCase() == 'included';
      return {
        'name': name,
        'qty': qty,
        'rate': rate,
        'gst_percent': gst,
        'type': type.isEmpty ? 'Extra' : type,
        'amount': isInc ? 0.0 : (qty * rate),
      };
    }).toList();

    final subtotal = _calcSubtotal();
    final data = {
      'pipeline_id': widget.pipelineId,
      'shipping_company': _shippingCompanyController.text.trim().isEmpty
          ? null
          : _shippingCompanyController.text.trim(),
      'vehicle_number': _vehicleNumberController.text.trim().isEmpty
          ? null
          : _vehicleNumberController.text.trim(),
      'distance': _distanceController.text.trim().isEmpty
          ? null
          : _distanceController.text.trim(),
      'gr_lr_no': _grLrNoController.text.trim().isEmpty
          ? null
          : _grLrNoController.text.trim(),
      'destination': _destinationController.text.trim().isEmpty
          ? null
          : _destinationController.text.trim(),
      'place_of_supply': _placeOfSupplyController.text.trim().isEmpty
          ? 'Maharashtra'
          : _placeOfSupplyController.text.trim(),
      'payment_terms': _paymentTermsController.text.trim().isEmpty
          ? (_paymentTerms.isNotEmpty
              ? _paymentTerms.map((t) => '${(t['percent'] ?? t['percentage'] as num?)?.toDouble().toStringAsFixed(0) ?? "0"}% ${t['term'] ?? t['condition'] ?? t['stage'] ?? ""}').join(', ')
              : null)
          : _paymentTermsController.text.trim(),
      'payment_terms_stages': _paymentTerms,
      'supplementary_terms': supplementaryTermsJson,
      'supplementary_subtotal': _calcSupplementarySubtotal(),
      'billing_address': _billingAddressController.text.trim().isEmpty
          ? null
          : _billingAddressController.text.trim(),
      'shipping_address': _shippingAddressController.text.trim().isEmpty
          ? null
          : _shippingAddressController.text.trim(),
      'expected_dispatch_date': _expectedDispatchDateController.text.trim().isEmpty
          ? null
          : () {
              try {
                return DateFormat('dd/MM/yyyy')
                    .parseStrict(_expectedDispatchDateController.text.trim())
                    .toIso8601String();
              } catch (_) {
                return null;
              }
            }(),
      'eway_bill_no': _ewayBillNoController.text.trim().isEmpty
          ? null
          : _ewayBillNoController.text.trim(),
      'eway_bill_date': _ewayBillDateController.text.trim().isEmpty
          ? null
          : _ewayBillDateController.text.trim(),
      'bill_type': _billType,
      'salesman': _salesmanController.text.trim().isEmpty
          ? null
          : _salesmanController.text.trim(),
      'party_contact_person': _partyContactPersonController.text.trim().isEmpty
          ? null
          : _partyContactPersonController.text.trim(),
      'line_items': lineItemsJson,
      'subtotal': subtotal,
      'cgst_rate': _cgstRate,
      'sgst_rate': _sgstRate,
      'cgst_amount': _cgstAmount,
      'sgst_amount': _sgstAmount,
      'igst_amount': _igstAmount,
      'grand_total': _grandTotal,
      'remarks': _remarksController.text.trim().isEmpty
          ? null
          : _remarksController.text.trim(),
      'status': confirmed ? 'confirmed' : 'draft',
    };

    if (_existingSalesOrder != null) {
      try {
        await supabase
            .from('sales_orders')
            .update(data)
            .eq('id', _existingSalesOrder!.id);
      } catch (err) {
        final errStr = err.toString();
        final fallbackData = Map<String, dynamic>.from(data);
        if (errStr.contains('expected_dispatch_date')) fallbackData.remove('expected_dispatch_date');
        if (errStr.contains('supplementary_terms')) fallbackData.remove('supplementary_terms');
        if (errStr.contains('supplementary_subtotal')) fallbackData.remove('supplementary_subtotal');
        if (errStr.contains('payment_terms_stages')) fallbackData.remove('payment_terms_stages');
        await supabase
            .from('sales_orders')
            .update(fallbackData)
            .eq('id', _existingSalesOrder!.id);
      }
      return _existingSalesOrder!.id;
    } else {
      try {
        final response = await supabase
            .from('sales_orders')
            .insert(data)
            .select('id')
            .single();
        return (response as Map)['id'] as String;
      } catch (err) {
        final errStr = err.toString();
        final fallbackData = Map<String, dynamic>.from(data);
        if (errStr.contains('expected_dispatch_date')) fallbackData.remove('expected_dispatch_date');
        if (errStr.contains('supplementary_terms')) fallbackData.remove('supplementary_terms');
        if (errStr.contains('supplementary_subtotal')) fallbackData.remove('supplementary_subtotal');
        if (errStr.contains('payment_terms_stages')) fallbackData.remove('payment_terms_stages');
        final response = await supabase
            .from('sales_orders')
            .insert(fallbackData)
            .select('id')
            .single();
        return (response as Map)['id'] as String;
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
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

    final isConfirmed = _existingSalesOrder?.isConfirmed == true;
    final enabled = _isEditing;
    final currencyFormat = NumberFormat('#,##,##0.00', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(!enabled ? 'Sales Order (Confirmed)' : 'Sales Order Form'),
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
          if (enabled)
            TextButton(
              onPressed: _isSaving
                  ? null
                  : (isConfirmed ? _saveConfirmedChanges : _saveDraft),
              child: Text(isConfirmed ? 'Save Changes' : 'Save Draft',
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Inter')),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            // Details Banner
            if (isConfirmed && !enabled)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
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
                        'This Sales Order is confirmed. Tap "Edit Details" in the top bar to modify.',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          _showVariantPickerDialog(_existingSalesOrder!.id),
                      child: const Text('Print PDF'),
                    ),
                  ],
                ),
              ),

            // Metadata card
            if (_pipeline?.customer != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pipeline!.customer!.companyName,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                    if (_pipeline!.customer!.phone != null && _pipeline!.customer!.phone!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              _pipeline!.customer!.phone!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(_product?.name ?? '',
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.textSecondary)),
                    if (_existingSalesOrder != null)
                      Text(
                        'Order No: ${PdfService.formatSalesOrderNumber(_existingSalesOrder!.salesOrderNumber, _existingSalesOrder!.orderDate)}',
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Shipping Metadata Section
            _SectionHeader('Shipping Metadata'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _shippingCompanyController,
                    enabled: enabled,
                    decoration:
                        const InputDecoration(labelText: 'Shipping Company'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _vehicleNumberController,
                    enabled: enabled,
                    decoration:
                        const InputDecoration(labelText: 'Vehicle Number'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _distanceController,
                    enabled: enabled,
                    decoration: const InputDecoration(
                        labelText: 'Distance (e.g. 120km)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _grLrNoController,
                    enabled: enabled,
                    decoration:
                        const InputDecoration(labelText: 'GR/LR Number'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _destinationController,
                    enabled: enabled,
                    decoration: const InputDecoration(labelText: 'Destination'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _placeOfSupplyController,
                    enabled: enabled,
                    decoration: const InputDecoration(
                        labelText: 'Place of Supply (State)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ewayBillNoController,
                    enabled: enabled,
                    decoration:
                        const InputDecoration(labelText: 'Eway Bill No'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: !enabled
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              _ewayBillDateController.text =
                                  DateFormat('dd/MM/yyyy').format(date);
                            }
                          },
                    child: IgnorePointer(
                      child: TextFormField(
                        controller: _ewayBillDateController,
                        enabled: enabled,
                        decoration: const InputDecoration(
                          labelText: 'Eway Bill Date',
                          suffixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: !enabled
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (date != null) {
                              _expectedDispatchDateController.text =
                                  DateFormat('dd/MM/yyyy').format(date);
                            }
                          },
                    child: IgnorePointer(
                      child: TextFormField(
                        controller: _expectedDispatchDateController,
                        enabled: enabled,
                        decoration: const InputDecoration(
                          labelText: 'Expected Dispatch Date',
                          suffixIcon: Icon(Icons.event_available, size: 18),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _billType,
                    decoration: const InputDecoration(labelText: 'Bill Type'),
                    items: const [
                      DropdownMenuItem(value: 'Credit', child: Text('Credit')),
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    ],
                    onChanged: !enabled
                        ? null
                        : (v) {
                            if (v != null) {
                              setState(() => _billType = v);
                            }
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _salesmanController,
                    enabled: enabled,
                    decoration: const InputDecoration(labelText: 'Salesman'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _partyContactPersonController,
                    enabled: enabled,
                    decoration:
                        const InputDecoration(labelText: 'Party Contact Person'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Addresses
            _SectionHeader('Addresses'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _billingAddressController,
              enabled: enabled,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Customer Billing Address'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _shippingAddressController,
              enabled: enabled,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Shipping Address'),
            ),
            const SizedBox(height: 20),

            // Item grid
            _SectionHeader('Line Items'),
            const SizedBox(height: 12),
            ..._lineItems.asMap().entries.map(
                  (entry) => _SalesOrderLineItemRow(
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
            const SizedBox(height: 20),

            // Supplementary Terms
            _SectionHeader('Supplementary Terms'),
            const SizedBox(height: 12),
            ..._supplementaryItems.asMap().entries.map(
                  (entry) => _SalesOrderSupplementaryRow(
                    index: entry.key,
                    item: entry.value,
                    onRemove: !enabled
                        ? null
                        : () => _removeSupplementaryItem(entry.key),
                    onChanged: () => setState(() {}),
                    enabled: enabled,
                  ),
                ),
            if (_supplementaryItems.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Supplementary Total',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '₹${currencyFormat.format(_calcSupplementarySubtotal())}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (enabled)
              TextButton.icon(
                onPressed: () => _addSupplementaryItem(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Supplementary Term'),
              ),
            const SizedBox(height: 20),

            // Totals block
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  _TotalRow(
                      'Subtotal', '₹${currencyFormat.format(_calcSubtotal())}'),
                  if (_calcSupplementarySubtotal() > 0) ...[
                    const SizedBox(height: 4),
                    _TotalRow('Supplementary Subtotal',
                        '₹${currencyFormat.format(_calcSupplementarySubtotal())}'),
                    const SizedBox(height: 4),
                    _TotalRow('Taxable Amount',
                        '₹${currencyFormat.format(_taxableSubtotal)}'),
                  ],
                  const SizedBox(height: 10),
                  if (_isLocalGst) ...[
                    _TotalRow(
                        'CGST Amount', '₹${currencyFormat.format(_cgstAmount)}'),
                    const SizedBox(height: 4),
                    _TotalRow(
                        'SGST Amount', '₹${currencyFormat.format(_sgstAmount)}'),
                  ] else ...[
                    _TotalRow(
                        'IGST Amount', '₹${currencyFormat.format(_igstAmount)}'),
                  ],
                  if (_roundOffAmount.abs() >= 0.005) ...[
                    const SizedBox(height: 4),
                    _TotalRow(
                      'Round Off',
                      'Rs. ${_roundOffAmount > 0 ? '+' : ''}${_roundOffAmount.toStringAsFixed(2)}',
                    ),
                  ],
                  const Divider(height: 16),
                  _TotalRow(
                      'Grand Total', '₹${currencyFormat.format(_grandTotal)}',
                      bold: true),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment Terms Section (Same as Quotation UI)
            _SectionHeader('Payment Terms'),
            const SizedBox(height: 8),
            _buildPaymentTermsCard(enabled),
            const SizedBox(height: 20),

            // Remarks
            _SectionHeader('Milestone Remarks'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _remarksController,
              enabled: enabled,
              maxLines: 2,
              decoration: const InputDecoration(
                  hintText: 'e.g. Advance: 80% Other: 20% after dispatch'),
            ),
            const SizedBox(height: 24),

            if (enabled)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : (isConfirmed
                          ? _saveConfirmedChanges
                          : _confirmSalesOrder),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isSaving
                      ? 'Processing...'
                      : (isConfirmed
                          ? 'Save Changes & Print'
                          : 'Confirm Sales Order & Print')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
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
          color: AppColors.textPrimary),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _TotalRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary)),
        Text(value,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                color: AppColors.primary)),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  final String? customValue;
  const _SummaryRow(this.label, this.amount, {this.bold = false, this.customValue});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : null)),
        Text(
          customValue ?? 'Rs. ${NumberFormat('#,##,##0.00', 'en_IN').format(amount)}',
          style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : null),
        ),
      ],
    );
  }
}

class _SalesOrderLineItemRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> item;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;
  final bool enabled;

  const _SalesOrderLineItemRow({
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
              final rateController = item['rate'] as TextEditingController;
              final gstController = item['gst_percent'] as TextEditingController?;
              
              if (hsnController.text.isEmpty) hsnController.text = selection.hsnSac ?? '';
              if (uomController.text.isEmpty) uomController.text = selection.uom ?? '';
              if (gstController != null) {
                gstController.text = selection.gstRate.truncateToDouble() == selection.gstRate
                    ? selection.gstRate.toInt().toString()
                    : selection.gstRate.toString();
              }
              if (rateController.text.isEmpty || rateController.text == '0.00' || rateController.text == '0') {
                rateController.text = InventoryAutocomplete.formatIndianPrice(selection.price);
              }
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item['hsn_sac'] as TextEditingController,
                  enabled: enabled,
                  decoration: const InputDecoration(labelText: 'HSN/SAC'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: item['uom'] as TextEditingController,
                  enabled: enabled,
                  decoration: const InputDecoration(labelText: 'UOM'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item['qty'] as TextEditingController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(labelText: 'Qty *'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final val = int.tryParse(v);
                    if (val == null || val <= 0) return '> 0';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: item['gst_percent'] as TextEditingController?,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    labelText: 'GST % *',
                    suffixText: '%',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = double.tryParse(v.replaceAll(',', '').trim());
                    if (n == null || n < 0 || n > 100) return 'Invalid';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      final val = double.tryParse((item['rate'] as TextEditingController).text.replaceAll(',', '').trim());
                      if (val != null) {
                        (item['rate'] as TextEditingController).text = InventoryAutocomplete.formatIndianPrice(val);
                      }
                    }
                  },
                  child: TextFormField(
                    controller: item['rate'] as TextEditingController,
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(labelText: 'Rate (₹) *'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final clean = v.replaceAll(',', '').trim();
                      if ((double.tryParse(clean) ?? -1) < 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: item['disc_percent'] as TextEditingController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(labelText: 'Disc %'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: item['remark'] as TextEditingController?,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Remark (Optional)',
              hintText: 'Item notes printed under item name',
              isDense: true,
            ),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _SalesOrderSupplementaryRow extends ConsumerWidget {
  final int index;
  final Map<String, dynamic> item;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;
  final bool enabled;

  const _SalesOrderSupplementaryRow({
    required this.index,
    required this.item,
    this.onRemove,
    required this.onChanged,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qtyCtrl = item['qty'] as TextEditingController;
    final rateCtrl = item['rate'] as TextEditingController;
    final gstCtrl = item['gst_percent'] as TextEditingController;
    final nameCtrl = item['name'] as TextEditingController;
    final typeCtrl = item['type'] as TextEditingController;

    final isIncluded = typeCtrl.text == 'Included';

    final q = double.tryParse(qtyCtrl.text) ?? 0;
    final r = double.tryParse(rateCtrl.text) ?? 0;
    final total = isIncluded ? 0.0 : q * r;

    final suppAsync = ref.watch(supplementaryItemsProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Term #${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete,
                      color: AppColors.error, size: 20),
                  onPressed: onRemove,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: SearchableDropdown<String>(
                  label: 'Supplementary Term',
                  hint: 'Search term...',
                  value: nameCtrl.text.isEmpty ? null : nameCtrl.text,
                  items: (suppAsync.value ?? []).map((e) => e.name).toList(),
                  itemLabel: (item) => item,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Supplementary Term',
                    hintText: 'Search term...',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      nameCtrl.text = val;
                      final suppList = suppAsync.value ?? [];
                      final found = suppList
                          .cast<SupplementaryItem?>()
                          .firstWhere((e) => e?.name == val, orElse: () => null);
                      if (found != null) {
                        rateCtrl.text = found.rate.toString();
                        gstCtrl.text = found.gstPercent.toString();
                      }
                      onChanged();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: typeCtrl.text.isEmpty ? 'Extra' : typeCtrl.text,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Extra', child: Text('Extra')),
                    DropdownMenuItem(value: 'Included', child: Text('Included')),
                  ],
                  onChanged: enabled
                      ? (val) {
                          if (val != null) {
                            typeCtrl.text = val;
                            onChanged();
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
          if (isIncluded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF047857)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Included in base package (No extra charge)',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                  Text(
                    'Included',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: qtyCtrl,
                    enabled: enabled && !isIncluded,
                    decoration:
                        const InputDecoration(labelText: 'Qty', isDense: true),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: rateCtrl,
                    enabled: enabled && !isIncluded,
                    decoration:
                        const InputDecoration(labelText: 'Rate', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: gstCtrl,
                    enabled: enabled && !isIncluded,
                    decoration:
                        const InputDecoration(labelText: 'GST %', isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: ₹${NumberFormat('#,##,##0.00', 'en_IN').format(total)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
