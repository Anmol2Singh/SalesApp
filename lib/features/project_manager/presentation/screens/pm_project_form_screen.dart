import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/models/customer.dart';
import '../theme/pm_tokens.dart';
import '../../providers/pm_mode_provider.dart';
import '../../providers/pm_company_provider.dart';
import '../../providers/pm_providers.dart';
import '../../data/models/pm_project.dart';
import '../../data/models/pm_purchase.dart';
import '../widgets/customer_search_picker.dart';
import '../widgets/pm_button.dart';
import '../widgets/pm_card.dart';

class PmProjectFormScreen extends ConsumerStatefulWidget {
  final String? editId;
  final bool isPurchase;

  const PmProjectFormScreen({
    super.key,
    this.editId,
    this.isPurchase = false,
  });

  @override
  ConsumerState<PmProjectFormScreen> createState() => _PmProjectFormScreenState();
}

class _PmProjectFormScreenState extends ConsumerState<PmProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();

  Customer? _selectedCustomer;
  int? _idNo;
  String _orderType = 'Heat Pump';
  final _siteNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _firmNameCtrl = TextEditingController();
  final _partyPrintNameCtrl = TextEditingController();
  final _salesmanNameCtrl = TextEditingController();
  final _hpTypeCtrl = TextEditingController();
  final _hpQtyCtrl = TextEditingController(text: '0');
  final _tankTypeCtrl = TextEditingController();
  final _tankQtyCtrl = TextEditingController(text: '0');
  final _glCtrl = TextEditingController(text: '0');
  final _orderValueCtrl = TextEditingController(text: '0');
  final _extraWorkValueCtrl = TextEditingController(text: '0');
  final _workRemarkCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isInit = true;

  final List<String> _orderTypes = [
    'Heat Pump',
    'SWH',
    'Solar Water Heater',
    'Solar System',
    'Commercial SWH',
    'Boom Barrier',
    'Vendor Supply',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _loadData();
      _isInit = false;
    }
  }

  Future<void> _loadData() async {
    if (widget.editId != null) {
      setState(() => _isLoading = true);
      if (widget.isPurchase) {
        final purchase = await ref.read(pmPurchasesRepositoryProvider).getPurchaseById(widget.editId!);
        if (purchase != null) {
          _idNo = purchase.idNo;
          _orderType = purchase.orderType;
          _siteNameCtrl.text = purchase.siteName;
          _mobileCtrl.text = purchase.mobileNumber ?? '';
          _addressCtrl.text = purchase.address ?? '';
          _firmNameCtrl.text = purchase.firmName ?? '';
          _partyPrintNameCtrl.text = purchase.partyPrintName ?? '';
          _orderValueCtrl.text = purchase.quotationValue.toStringAsFixed(0);
        }
      } else {
        final project = await ref.read(pmProjectsRepositoryProvider).getProjectById(widget.editId!);
        if (project != null) {
          _idNo = project.idNo;
          _selectedCustomer = project.customer;
          _orderType = project.orderType;
          _siteNameCtrl.text = project.siteName;
          _mobileCtrl.text = project.mobileNumber ?? '';
          _addressCtrl.text = project.address ?? '';
          _hpTypeCtrl.text = project.hpType ?? '';
          _hpQtyCtrl.text = project.hpQty.toString();
          _tankTypeCtrl.text = project.tankType ?? '';
          _tankQtyCtrl.text = project.tankQty.toString();
          _glCtrl.text = project.gl.toString();
          _orderValueCtrl.text = project.orderValue.toStringAsFixed(0);
          _extraWorkValueCtrl.text = project.extraWorkValue.toStringAsFixed(0);
          _workRemarkCtrl.text = project.workRemark ?? '';
          _salesmanNameCtrl.text = project.salesmanName ?? '';
        }
      }
      setState(() => _isLoading = false);
    } else {
      // Auto-assign next ID No
      final nextId = widget.isPurchase
          ? await ref.read(pmPurchasesRepositoryProvider).getNextIdNo()
          : await ref.read(pmProjectsRepositoryProvider).getNextIdNo();
      setState(() => _idNo = nextId);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!widget.isPurchase && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an existing customer from SalesApp')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final activeCompany = ref.read(pmActiveCompanyProvider);

    try {
      if (widget.isPurchase) {
        final data = {
          'id_no': _idNo ?? 1001,
          'order_type': _orderType,
          'site_name': _siteNameCtrl.text.trim(),
          'mobile_number': _mobileCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'firm_name': _firmNameCtrl.text.trim(),
          'party_print_name': _partyPrintNameCtrl.text.trim(),
          'quotation_value': double.tryParse(_orderValueCtrl.text) ?? 0.0,
          'company_id': activeCompany.id,
        };

        if (widget.editId != null) {
          await ref.read(pmPurchasesRepositoryProvider).updatePurchase(widget.editId!, data);
        } else {
          await ref.read(pmPurchasesRepositoryProvider).createPurchase(data);
        }
        ref.invalidate(pmPurchasesListProvider);
      } else {
        final data = {
          'id_no': _idNo ?? 1001,
          'customer_id': _selectedCustomer!.id,
          'order_type': _orderType,
          'site_name': _siteNameCtrl.text.trim().isNotEmpty
              ? _siteNameCtrl.text.trim()
              : _selectedCustomer!.companyName,
          'address': _addressCtrl.text.trim().isNotEmpty
              ? _addressCtrl.text.trim()
              : (_selectedCustomer!.address ?? ''),
          'hp_type': _hpTypeCtrl.text.trim(),
          'hp_qty': int.tryParse(_hpQtyCtrl.text) ?? 0,
          'tank_type': _tankTypeCtrl.text.trim(),
          'tank_qty': int.tryParse(_tankQtyCtrl.text) ?? 0,
          'gl': int.tryParse(_glCtrl.text) ?? 0,
          'order_value': double.tryParse(_orderValueCtrl.text) ?? 0.0,
          'extra_work_value': double.tryParse(_extraWorkValueCtrl.text) ?? 0.0,
          'work_remark': _workRemarkCtrl.text.trim(),
          'salesman_name': _salesmanNameCtrl.text.trim(),
          'company_id': activeCompany.id,
        };

        if (widget.editId != null) {
          await ref.read(pmProjectsRepositoryProvider).updateProject(widget.editId!, data);
        } else {
          await ref.read(pmProjectsRepositoryProvider).createProject(data);
        }
        ref.invalidate(pmProjectsListProvider);
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving record: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pm = context.pm;
    final isEdit = widget.editId != null;

    return Scaffold(
      backgroundColor: pm.background,
      appBar: AppBar(
        backgroundColor: pm.card,
        foregroundColor: pm.foreground,
        elevation: 0,
        title: Text(
          isEdit
              ? (widget.isPurchase ? 'Edit Vendor #$_idNo' : 'Edit Project #$_idNo')
              : (widget.isPurchase ? 'Add New Vendor' : 'Create New Project'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PmButton(
              size: PmButtonSize.sm,
              isLoading: _isLoading,
              onPressed: _save,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.check, size: 14),
                  SizedBox(width: 6),
                  Text('Save Record'),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading && isEdit
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Phase 2 Customer Picker (Sales mode)
                        if (!widget.isPurchase) ...[
                          PmCard(
                            child: CustomerSearchPicker(
                              selectedCustomer: _selectedCustomer,
                              onCustomerSelected: (cust) {
                                setState(() {
                                  _selectedCustomer = cust;
                                  if (_siteNameCtrl.text.isEmpty) {
                                    _siteNameCtrl.text = cust.companyName;
                                  }
                                  if (_addressCtrl.text.isEmpty && cust.address != null) {
                                    _addressCtrl.text = cust.address!;
                                  }
                                  if (_mobileCtrl.text.isEmpty && cust.phone != null) {
                                    _mobileCtrl.text = cust.phone!;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Main Details Card
                        PmCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Account & Site Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pm.foreground)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: _buildTextField('ID Number', TextEditingController(text: _idNo?.toString() ?? 'Auto'), readOnly: true),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: _buildDropdown('Order Type', _orderType, _orderTypes, (val) {
                                      if (val != null) setState(() => _orderType = val);
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                widget.isPurchase ? 'Vendor / Company Name*' : 'Site / Project Name*',
                                _siteNameCtrl,
                                validator: (v) => v?.trim().isEmpty == true ? 'Name is required' : null,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _buildTextField('Mobile Number', _mobileCtrl)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildTextField('Firm Name', _firmNameCtrl)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTextField('Address', _addressCtrl, maxLines: 2),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Technical Specifications Card (Sales mode)
                        if (!widget.isPurchase) ...[
                          PmCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Technical Specifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pm.foreground)),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(child: _buildTextField('Heat Pump Type', _hpTypeCtrl)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildTextField('HP Qty', _hpQtyCtrl, keyboardType: TextInputType.number)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _buildTextField('Tank Type', _tankTypeCtrl)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildTextField('Tank Qty', _tankQtyCtrl, keyboardType: TextInputType.number)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildTextField('GL (Glass Lining)', _glCtrl, keyboardType: TextInputType.number),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Financial Values Card
                        PmCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Commercial & Booking Values', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pm.foreground)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      widget.isPurchase ? 'Quotation Value (₹)' : 'Order Value (₹)',
                                      _orderValueCtrl,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  if (!widget.isPurchase) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                        'Extra Work Value (₹)',
                                        _extraWorkValueCtrl,
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (!widget.isPurchase) ...[
                                const SizedBox(height: 12),
                                _buildTextField('Initial Work Remark', _workRemarkCtrl, maxLines: 2),
                                const SizedBox(height: 12),
                                _buildTextField('Salesman Name', _salesmanNameCtrl),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        PmButton(
                          size: PmButtonSize.lg,
                          isLoading: _isLoading,
                          onPressed: _save,
                          child: Text(isEdit ? 'Update Record' : 'Save & Create Record'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final pm = context.pm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pm.mutedForeground)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(fontSize: 14, color: pm.foreground),
          decoration: InputDecoration(
            isDense: true,
            filled: readOnly,
            fillColor: readOnly ? pm.secondary.withOpacity(0.5) : pm.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(pm.radiusMd),
              borderSide: BorderSide(color: pm.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(pm.radiusMd),
              borderSide: BorderSide(color: pm.border),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    final pm = context.pm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pm.mutedForeground)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : items.first,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(pm.radiusMd),
              borderSide: BorderSide(color: pm.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(pm.radiusMd),
              borderSide: BorderSide(color: pm.border),
            ),
          ),
        ),
      ],
    );
  }
}
