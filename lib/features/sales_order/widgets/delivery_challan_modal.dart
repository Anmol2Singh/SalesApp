// lib/features/sales_order/widgets/delivery_challan_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/pipeline.dart';
import '../../../core/models/sales_order.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pipelines/providers/pipelines_provider.dart';
import '../../pipelines/widgets/work_progress_box.dart';
import '../../complaints/providers/complaints_provider.dart';
import '../../complaints/data/models/complaint_model.dart';
import '../../../core/auth/role_access.dart';

class _ChallanItemRow {
  String name;
  String uom; // Fixed from inventory (NOS, Mtr, Set, etc.)
  double qty; // Selected quantity (min 1)
  double? requiredQty; // Total required quantity from SO or BOQ
  double sentQty; // Quantity already delivered in previous challans
  String? remark; // Note / serial number

  _ChallanItemRow({
    required this.name,
    this.uom = 'NOS',
    required this.qty,
    this.requiredQty,
    this.sentQty = 0.0,
    this.remark,
  });

  double get pendingQty => ((requiredQty ?? qty) - sentQty).clamp(0.0, 999999.0);
}

class DeliveryChallanModal extends ConsumerStatefulWidget {
  final String pipelineId;
  final Customer customer;

  const DeliveryChallanModal({
    super.key,
    required this.pipelineId,
    required this.customer,
  });

  static Future<void> show(
    BuildContext context, {
    required String pipelineId,
    required Customer customer,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliveryChallanModal(
        pipelineId: pipelineId,
        customer: customer,
      ),
    );
  }

  @override
  ConsumerState<DeliveryChallanModal> createState() =>
      _DeliveryChallanModalState();
}

class _DeliveryChallanModalState extends ConsumerState<DeliveryChallanModal> {
  DateTime _challanDate = DateTime.now();
  final _vehicleNumberController = TextEditingController();
  final _shippingCompanyController = TextEditingController();
  final _driverContactController = TextEditingController();
  final _deliveryPersonController = TextEditingController();
  String? _selectedDeliveryPerson;
  List<String> _customDeliveryPersons = [];

  final List<_ChallanItemRow> _items = [];
  final Map<int, TextEditingController> _remarkControllers = {};
  final Map<int, TextEditingController> _qtyControllers = {};

  String _currentSource = 'sales_order'; // 'sales_order', 'boq', 'both', or 'custom'
  bool _initialized = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadCustomDeliveryPersons();
    // Prefetch technicians immediately so they are cached before the user taps "Select person..."
    ref.read(availableTechniciansProvider.future).catchError((_) => <TechnicianInfo>[]);
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _shippingCompanyController.dispose();
    _driverContactController.dispose();
    _deliveryPersonController.dispose();
    for (final c in _remarkControllers.values) {
      c.dispose();
    }
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCustomDeliveryPersons() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase
          .from('qg_settings')
          .select('value')
          .eq('key', 'delivery_challan_persons')
          .maybeSingle();
      if (res != null && res['value'] is Map && res['value']['persons'] is List) {
        if (mounted) {
          setState(() {
            _customDeliveryPersons = List<String>.from(res['value']['persons'] as List);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCustomDeliveryPersons(List<String> list) async {
    setState(() {
      _customDeliveryPersons = list;
    });
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('qg_settings').upsert({
        'key': 'delivery_challan_persons',
        'value': {'persons': list},
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  void _openManageDeliveryPersonsDialog() {
    final newPersonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: const [
                  Icon(Icons.tune_outlined, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text('Manage Delivery Persons', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add or remove custom delivery receivers. These are kept strictly here and not added to technicians.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newPersonController,
                            decoration: InputDecoration(
                              hintText: 'Enter full name...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            final name = newPersonController.text.trim();
                            if (name.isEmpty) return;
                            if (!_customDeliveryPersons.contains(name)) {
                              final updated = [..._customDeliveryPersons, name];
                              await _saveCustomDeliveryPersons(updated);
                              setDialogState(() {});
                              newPersonController.clear();
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Custom Delivery Staff List:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    if (_customDeliveryPersons.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No custom persons added yet.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _customDeliveryPersons.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (c, idx) {
                            final person = _customDeliveryPersons[idx];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(0xFFE0F2FE),
                                child: Icon(Icons.person, size: 16, color: Color(0xFF0284C7)),
                              ),
                              title: Text(person, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () async {
                                  final updated = List<String>.from(_customDeliveryPersons)..removeAt(idx);
                                  await _saveCustomDeliveryPersons(updated);
                                  setDialogState(() {});
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openSelectDeliveryPersonSheet() async {
    List<TechnicianInfo> techs = [];
    try {
      final techsAsync = ref.read(availableTechniciansProvider);
      if (techsAsync.hasValue && techsAsync.value != null && techsAsync.value!.isNotEmpty) {
        techs = techsAsync.value!;
      } else {
        techs = await ref.read(availableTechniciansProvider.future);
      }
    } catch (_) {
      techs = [];
    }
    final List<Map<String, String>> allOptions = [];

    for (final t in techs) {
      allOptions.add({
        'name': t.name,
        'role': 'Technician',
        'phone': t.phone ?? '',
      });
    }
    for (final cp in _customDeliveryPersons) {
      allOptions.add({
        'name': cp,
        'role': 'Delivery Staff',
        'phone': '',
      });
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            final filtered = allOptions.where((opt) {
              final q = query.toLowerCase().trim();
              if (q.isEmpty) return true;
              return (opt['name'] ?? '').toLowerCase().contains(q) ||
                  (opt['phone'] ?? '').toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(dialogCtx).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.badge_outlined, color: AppColors.primary, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Select Person Taking Delivery',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search technician or delivery staff...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) => setSheetState(() => query = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_off_outlined, size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(
                                  query.isEmpty ? 'No persons available' : 'No match for "$query"',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                if (query.trim().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedDeliveryPerson = query.trim();
                                        _deliveryPersonController.text = query.trim();
                                      });
                                      Navigator.pop(ctx);
                                    },
                                    icon: const Icon(Icons.check, size: 16),
                                    label: Text('Use "$query"'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (c, idx) {
                              final item = filtered[idx];
                              final isTech = item['role'] == 'Technician';
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isTech ? const Color(0xFFEDE9FE) : const Color(0xFFE0F2FE),
                                  child: Icon(
                                    isTech ? Icons.handyman_outlined : Icons.local_shipping_outlined,
                                    size: 18,
                                    color: isTech ? const Color(0xFF7C3AED) : const Color(0xFF0284C7),
                                  ),
                                ),
                                title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: item['phone'] != null && item['phone']!.isNotEmpty
                                    ? Text('📞 ${item['phone']}')
                                    : null,
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isTech ? const Color(0xFFF3E8FF) : const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isTech ? const Color(0xFFD8B4FE) : const Color(0xFF86EFAC)),
                                  ),
                                  child: Text(
                                    item['role'] ?? '',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isTech ? const Color(0xFF6B21A8) : const Color(0xFF166534),
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedDeliveryPerson = item['name'];
                                    _deliveryPersonController.text = item['name'] ?? '';
                                  });
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _syncControllers() {
    for (int i = 0; i < _items.length; i++) {
      if (!_remarkControllers.containsKey(i)) {
        _remarkControllers[i] = TextEditingController(text: _items[i].remark ?? '');
      } else {
        _remarkControllers[i]!.text = _items[i].remark ?? '';
      }
      final qStr = _items[i].qty == _items[i].qty.roundToDouble()
          ? _items[i].qty.toInt().toString()
          : _items[i].qty.toString();
      if (!_qtyControllers.containsKey(i)) {
        _qtyControllers[i] = TextEditingController(text: qStr);
      } else {
        _qtyControllers[i]!.text = qStr;
      }
    }
  }

  Map<String, double> _getAlreadySentMap(SalesPipeline pipeline) {
    final existingChallans = WorkProgressService.getDeliveryChallans(pipeline);
    final map = <String, double>{};
    for (final ch in existingChallans) {
      final items = ch['items'];
      if (items is List) {
        for (final it in items) {
          if (it is Map) {
            final name = (it['name'] ?? '').toString().trim().toLowerCase();
            final qty = (it['qty'] as num?)?.toDouble() ?? 0.0;
            if (name.isNotEmpty) {
              map[name] = (map[name] ?? 0.0) + qty;
            }
          }
        }
      }
    }
    return map;
  }

  void _initFromPipeline(SalesPipeline pipeline) {
    if (_initialized) return;
    _initialized = true;

    _loadCustomDeliveryPersons();

    final so = pipeline.salesOrder;
    if (so != null) {
      _vehicleNumberController.text = so.vehicleNumber ?? '';
      _shippingCompanyController.text = so.shippingCompany ?? '';
    }

    if (so != null && so.lineItems.isNotEmpty) {
      _loadFromSalesOrder(pipeline);
    } else if (pipeline.boq != null && pipeline.boq!.items.isNotEmpty) {
      _loadFromBoq(pipeline);
    } else if (pipeline.quotation != null && pipeline.quotation!.lineItems.isNotEmpty) {
      _loadFromSalesOrder(pipeline);
    }
  }

  void _loadFromSalesOrder(SalesPipeline pipeline) {
    setState(() {
      _currentSource = 'sales_order';
      _items.clear();
      final alreadySent = _getAlreadySentMap(pipeline);
      if (pipeline.salesOrder != null && pipeline.salesOrder!.lineItems.isNotEmpty) {
        for (final item in pipeline.salesOrder!.lineItems) {
          final req = item.qty > 0 ? item.qty : 1.0;
          final sent = alreadySent[item.description.trim().toLowerCase()] ?? 0.0;
          final pending = (req - sent).clamp(0.0, req);
          if (pending <= 0) continue; // Don't show items with zero pending quantity
          _items.add(_ChallanItemRow(
            name: item.description,
            uom: item.uom.isNotEmpty ? item.uom : 'NOS',
            qty: pending,
            requiredQty: req,
            sentQty: sent,
            remark: item.remark,
          ));
        }
      } else if (pipeline.quotation != null) {
        for (final item in pipeline.quotation!.lineItems) {
          final req = item.qty > 0 ? item.qty : 1.0;
          final sent = alreadySent[item.description.trim().toLowerCase()] ?? 0.0;
          final pending = (req - sent).clamp(0.0, req);
          if (pending <= 0) continue; // Don't show items with zero pending quantity
          _items.add(_ChallanItemRow(
            name: item.description,
            uom: item.uom.isNotEmpty ? item.uom : 'NOS',
            qty: pending,
            requiredQty: req,
            sentQty: sent,
            remark: null,
          ));
        }
      }
      _syncControllers();
    });
  }

  void _loadFromBoq(SalesPipeline pipeline) {
    setState(() {
      _currentSource = 'boq';
      _items.clear();
      final alreadySent = _getAlreadySentMap(pipeline);
      final boqItems = (pipeline.boq?.items ?? [])
          .where((item) => item.scope.trim().toLowerCase() != 'customer')
          .toList();
      for (final item in boqItems) {
        final req = item.qty > 0 ? item.qty : 1.0;
        final sent = alreadySent[item.component.trim().toLowerCase()] ?? 0.0;
        final pending = (req - sent).clamp(0.0, req);
        if (pending <= 0) continue; // Don't show items with zero pending quantity
        _items.add(_ChallanItemRow(
          name: item.component,
          uom: item.unit.isNotEmpty ? item.unit : 'NOS',
          qty: pending,
          requiredQty: req,
          sentQty: sent,
          remark: item.remarks,
        ));
      }
      _syncControllers();
    });
  }

  void _loadFromBoqCustomerScope(SalesPipeline pipeline) {
    setState(() {
      _currentSource = 'boq_customer';
      _items.clear();
      final alreadySent = _getAlreadySentMap(pipeline);
      final boqItems = (pipeline.boq?.items ?? [])
          .where((item) => item.scope.trim().toLowerCase() == 'customer')
          .toList();
      for (final item in boqItems) {
        final req = item.qty > 0 ? item.qty : 1.0;
        final sent = alreadySent[item.component.trim().toLowerCase()] ?? 0.0;
        final pending = (req - sent).clamp(0.0, req);
        if (pending <= 0) continue; // Don't show items with zero pending quantity
        _items.add(_ChallanItemRow(
          name: item.component,
          uom: item.unit.isNotEmpty ? item.unit : 'NOS',
          qty: pending,
          requiredQty: req,
          sentQty: sent,
          remark: item.remarks,
        ));
      }
      _syncControllers();
    });
  }

  void _loadFromBoth(SalesPipeline pipeline) {
    setState(() {
      _currentSource = 'both';
      _items.clear();
      final alreadySent = _getAlreadySentMap(pipeline);
      final Map<String, _ChallanItemRow> combined = {};

      // 1. Sales order items
      if (pipeline.salesOrder != null && pipeline.salesOrder!.lineItems.isNotEmpty) {
        for (final item in pipeline.salesOrder!.lineItems) {
          final key = item.description.trim().toLowerCase();
          final req = item.qty > 0 ? item.qty : 1.0;
          final sent = alreadySent[key] ?? 0.0;
          final pending = (req - sent).clamp(0.0, req);
          if (pending <= 0) continue;
          combined[key] = _ChallanItemRow(
            name: item.description,
            uom: item.uom.isNotEmpty ? item.uom : 'NOS',
            qty: pending,
            requiredQty: req,
            sentQty: sent,
            remark: item.remark,
          );
        }
      } else if (pipeline.quotation != null) {
        for (final item in pipeline.quotation!.lineItems) {
          final key = item.description.trim().toLowerCase();
          final req = item.qty > 0 ? item.qty : 1.0;
          final sent = alreadySent[key] ?? 0.0;
          final pending = (req - sent).clamp(0.0, req);
          if (pending <= 0) continue;
          combined[key] = _ChallanItemRow(
            name: item.description,
            uom: item.uom.isNotEmpty ? item.uom : 'NOS',
            qty: pending,
            requiredQty: req,
            sentQty: sent,
            remark: null,
          );
        }
      }

      // 2. BOQ items (company scope only)
      final boqItems = (pipeline.boq?.items ?? [])
          .where((item) => item.scope.trim().toLowerCase() != 'customer')
          .toList();
      for (final item in boqItems) {
        final key = item.component.trim().toLowerCase();
        final req = item.qty > 0 ? item.qty : 1.0;
        final sent = alreadySent[key] ?? 0.0;

        if (combined.containsKey(key)) {
          final existing = combined[key]!;
          final totalReq = (existing.requiredQty ?? existing.qty) + req;
          final pending = (totalReq - sent).clamp(0.0, totalReq);
          existing.requiredQty = totalReq;
          existing.sentQty = sent;
          existing.qty = pending > 0 ? pending : 1.0;
          if (item.remarks != null && item.remarks!.isNotEmpty) {
            existing.remark = existing.remark != null ? '${existing.remark}; ${item.remarks}' : item.remarks;
          }
        } else {
          final pending = (req - sent).clamp(0.0, req);
          if (pending <= 0) continue;
          combined[key] = _ChallanItemRow(
            name: item.component,
            uom: item.unit.isNotEmpty ? item.unit : 'NOS',
            qty: pending,
            requiredQty: req,
            sentQty: sent,
            remark: item.remarks,
          );
        }
      }

      _items.addAll(combined.values.where((it) => it.pendingQty > 0));
      _syncControllers();
    });
  }



  void _updateItemQty(int idx, double delta) {
    setState(() {
      final current = _items[idx].qty;
      final newQty = (current + delta).clamp(1.0, 99999.0);
      _items[idx].qty = newQty;
      final qStr = newQty == newQty.roundToDouble()
          ? newQty.toInt().toString()
          : newQty.toString();
      _qtyControllers[idx]?.text = qStr;
    });
  }

  void _removeItem(int idx) {
    setState(() {
      _items.removeAt(idx);
      _remarkControllers.remove(idx)?.dispose();
      _qtyControllers.remove(idx)?.dispose();
      _syncControllers();
    });
  }

  Future<void> _generateChallan(SalesPipeline pipeline) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item to generate a delivery challan.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final profile = ref.read(currentProfileProvider);
    if (!RoleAccess.canGenerateDeliveryChallan(profile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission Denied: Delivery Challan generation is restricted to Administrators.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final supabase = ref.read(supabaseClientProvider);

      // Read remark from controllers into items
      for (int i = 0; i < _items.length; i++) {
        _items[i].remark = _remarkControllers[i]?.text.trim();
        final rawQty = double.tryParse(_qtyControllers[i]?.text.trim() ?? '');
        if (rawQty != null && rawQty > 0) {
          _items[i].qty = rawQty;
        }
      }

      // Convert items to SalesOrderLineItem for PDF generator
      final List<SalesOrderLineItem> customLineItems = _items.map((it) {
        return SalesOrderLineItem(
          description: it.name,
          qty: it.qty,
          uom: it.uom,
          remark: (it.remark != null && it.remark!.isNotEmpty) ? it.remark : null,
          rate: 0.0,
          discPercent: 0.0,
          amount: 0.0,
        );
      }).toList();

      // Determine next challan sequence number for this deal
      final existingChallans = WorkProgressService.getDeliveryChallans(pipeline);
      final existingCount = existingChallans.length;

      final so = pipeline.salesOrder;
      final baseDocRef = so?.salesOrderNumber.isNotEmpty == true
          ? PdfService.formatSalesOrderNumber(so!.salesOrderNumber, so.orderDate)
          : (pipeline.baseQuotationNumber.isNotEmpty ? pipeline.baseQuotationNumber : 'IZY/SO/0001');
      final baseChallanNo = PdfService.formatDeliveryChallanNumber(baseDocRef, _challanDate);

      final nextSuffix = (existingCount + 1).toString().padLeft(2, '0');
      final challanNo = existingCount == 0 ? '$baseChallanNo-01' : '$baseChallanNo-$nextSuffix';
      final fileName = '${challanNo.replaceAll('/', '_')}.pdf';

      // Fetch template config
      Map<String, dynamic> templateConfig = {};
      try {
        final res = await supabase
            .from('pdf_templates')
            .select()
            .eq('document_type', 'sales_order')
            .maybeSingle();
        if (res != null && res['template_config'] != null) {
          templateConfig = res['template_config'] as Map<String, dynamic>;
        }
      } catch (_) {}

      final product = pipeline.product ??
          Product(
            id: pipeline.productId,
            name: 'Product',
            category: 'Solar',
            baseSpecs: const ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      final effectiveSalesOrder = so != null
          ? so.copyWith(
              vehicleNumber: _vehicleNumberController.text.trim().isNotEmpty
                  ? _vehicleNumberController.text.trim()
                  : so.vehicleNumber,
              shippingCompany: _shippingCompanyController.text.trim().isNotEmpty
                  ? _shippingCompanyController.text.trim()
                  : so.shippingCompany,
              lineItems: customLineItems,
            )
          : SalesOrder(
              id: 'so_temp',
              pipelineId: pipeline.id,
              salesOrderNumber: baseDocRef.isNotEmpty ? baseDocRef : 'IZY/SO/0001',
              orderDate: _challanDate,
              vehicleNumber: _vehicleNumberController.text.trim(),
              shippingCompany: _shippingCompanyController.text.trim(),
              billingAddress: pipeline.customer?.address,
              shippingAddress: pipeline.customer?.address,
              lineItems: customLineItems,
              subtotal: 0,
              cgstRate: 0,
              sgstRate: 0,
              cgstAmount: 0,
              sgstAmount: 0,
              igstAmount: 0,
              grandTotal: 0,
              status: SalesOrderStatus.confirmed,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

      // Generate Delivery Challan PDF bytes
      final effectiveDeliveryTakenBy = _selectedDeliveryPerson != null && _selectedDeliveryPerson!.isNotEmpty
          ? _selectedDeliveryPerson
          : (_deliveryPersonController.text.trim().isNotEmpty ? _deliveryPersonController.text.trim() : null);

      final pdfBytes = await PdfService.generateDeliveryChallanPdf(
        salesOrder: effectiveSalesOrder,
        customer: widget.customer,
        product: product,
        templateConfig: templateConfig,
        quotationNumber: baseDocRef.isNotEmpty ? baseDocRef : pipeline.baseQuotationNumber,
        challanDate: _challanDate,
        customLineItems: customLineItems,
        customChallanNumber: challanNo,
        deliveryTakenBy: effectiveDeliveryTakenBy,
      );

      // Record this Delivery Challan in Work Progress metadata
      final challanRecord = {
        'id': 'dc_${DateTime.now().millisecondsSinceEpoch}',
        'challan_number': challanNo,
        'date': _challanDate.toIso8601String(),
        'vehicle_number': _vehicleNumberController.text.trim(),
        'shipping_company': _shippingCompanyController.text.trim(),
        'driver_contact': _driverContactController.text.trim(),
        'delivery_taken_by': effectiveDeliveryTakenBy,
        'source': _currentSource,
        'item_count': _items.length,
        'items': _items.map((it) => {
          'name': it.name,
          'qty': it.qty,
          'uom': it.uom,
          'required_qty': it.requiredQty,
          'sent_qty': it.sentQty,
          'pending_qty': it.pendingQty,
          'remark': it.remark,
        }).toList(),
        'created_at': DateTime.now().toIso8601String(),
        'created_by': profile?.fullName ?? 'Staff',
      };

      await WorkProgressService.recordDeliveryChallan(
        supabase,
        widget.pipelineId,
        challanRecord,
      );

      // Invalidate pipeline provider so the whole deal screen updates live!
      ref.invalidate(pipelineDetailProvider(widget.pipelineId));

      if (!mounted) return;
      Navigator.of(context).pop(); // Close modal

      // Open in standard preview screen with Download, Print, Share
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            pdfBytes: pdfBytes,
            fileName: fileName,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating Delivery Challan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pipelineAsync = ref.watch(pipelineDetailProvider(widget.pipelineId));
    final profile = ref.watch(currentProfileProvider);
    final isAdmin = RoleAccess.canGenerateDeliveryChallan(profile);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: pipelineAsync.when(
        data: (pipeline) {
          _initFromPipeline(pipeline);

          final rawSalesOrderNo = pipeline.salesOrder?.salesOrderNumber.isNotEmpty == true
              ? pipeline.salesOrder!.salesOrderNumber
              : (pipeline.baseQuotationNumber.isNotEmpty
                  ? pipeline.baseQuotationNumber
                  : (pipeline.quotation?.quotationNumber ?? '-'));
          final salesOrderNo = rawSalesOrderNo != '-'
              ? (pipeline.salesOrder?.salesOrderNumber.isNotEmpty == true
                  ? PdfService.formatSalesOrderNumber(
                      rawSalesOrderNo,
                      pipeline.salesOrder?.orderDate ?? pipeline.createdAt,
                    )
                  : rawSalesOrderNo)
              : '-';

          final existingChallans = WorkProgressService.getDeliveryChallans(pipeline);

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        size: 22,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Generate Delivery Challan',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (existingChallans.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    '#${existingChallans.length + 1}',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Customer: ${widget.customer.companyName}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Source selection pills
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Source:',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('From Sales Order', style: TextStyle(fontSize: 12)),
                      selected: _currentSource == 'sales_order',
                      onSelected: (selected) {
                        if (selected) _loadFromSalesOrder(pipeline);
                      },
                      selectedColor: const Color(0xFFDBEAFE),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _currentSource == 'sales_order' ? const Color(0xFF1E40AF) : AppColors.textSecondary,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('From BOQ', style: TextStyle(fontSize: 12)),
                      selected: _currentSource == 'boq',
                      onSelected: (selected) {
                        if (selected) _loadFromBoq(pipeline);
                      },
                      selectedColor: const Color(0xFFDBEAFE),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _currentSource == 'boq' ? const Color(0xFF1E40AF) : AppColors.textSecondary,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('BOQ - Customer Scope', style: TextStyle(fontSize: 12)),
                      selected: _currentSource == 'boq_customer',
                      onSelected: (selected) {
                        if (selected) _loadFromBoqCustomerScope(pipeline);
                      },
                      selectedColor: const Color(0xFFDBEAFE),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _currentSource == 'boq_customer' ? const Color(0xFF1E40AF) : AppColors.textSecondary,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('From Both', style: TextStyle(fontSize: 12)),
                      selected: _currentSource == 'both',
                      onSelected: (selected) {
                        if (selected) _loadFromBoth(pipeline);
                      },
                      selectedColor: const Color(0xFFDBEAFE),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _currentSource == 'both' ? const Color(0xFF1E40AF) : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Scrollable form body
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // Dispatch details card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Challan Date:',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _challanDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) {
                                        setState(() => _challanDate = picked);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            DateFormat('dd/MM/yyyy').format(_challanDate),
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Ref No. (Sales Order):',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    salesOrderNo,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Vehicle Number:',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _vehicleNumberController,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. MH 12 AB 1234',
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Shipping / Transport:',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _shippingCompanyController,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. VRL Logistics / Self',
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Delivery Taken By:',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: _openSelectDeliveryPersonSheet,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade400),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    _selectedDeliveryPerson != null && _selectedDeliveryPerson!.isNotEmpty
                                                        ? _selectedDeliveryPerson!
                                                        : 'Select person...',
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 12.5,
                                                      fontWeight: _selectedDeliveryPerson != null && _selectedDeliveryPerson!.isNotEmpty
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      color: _selectedDeliveryPerson != null && _selectedDeliveryPerson!.isNotEmpty
                                                          ? AppColors.textPrimary
                                                          : Colors.grey.shade500,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isAdmin) ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.tune_outlined, size: 20, color: AppColors.primary),
                                          tooltip: 'Manage List (Admins only)',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: _openManageDeliveryPersonsDialog,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Items Section Header with Add Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Challan Items',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_items.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Items fetched from deal orders. Rates and amounts are not printed on delivery challans.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_items.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 36, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text(
                                'No items available to dispatch from the selected source.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._items.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final remarkCtrl = _remarkControllers[idx]!;
                          final qtyCtrl = _qtyControllers[idx]!;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '#${idx + 1}',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                ),
                                                child: Text(
                                                  'Unit: ${item.uom}',
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                              if (item.requiredQty != null)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF6FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                                  ),
                                                  child: Text(
                                                    'Req: ${item.requiredQty == item.requiredQty!.roundToDouble() ? item.requiredQty!.toInt() : item.requiredQty} ${item.uom}',
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF1D4ED8),
                                                    ),
                                                  ),
                                                ),
                                              if (item.sentQty > 0) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF0FDF4),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                                  ),
                                                  child: Text(
                                                    'Sent: ${item.sentQty == item.sentQty.roundToDouble() ? item.sentQty.toInt() : item.sentQty}',
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF166534),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: item.pendingQty > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: item.pendingQty > 0 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Pending: ${item.pendingQty == item.pendingQty.roundToDouble() ? item.pendingQty.toInt() : item.pendingQty} ${item.uom}',
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: item.pendingQty > 0 ? const Color(0xFFB45309) : const Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 19),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _removeItem(idx),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Quantity Controls (+ & -)
                                Row(
                                  children: [
                                    const Text(
                                      'Dispatch Qty:',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          InkWell(
                                            onTap: () => _updateItemQty(idx, -1),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              child: Icon(Icons.remove, size: 16, color: AppColors.textPrimary),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 48,
                                            child: TextField(
                                              controller: qtyCtrl,
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.symmetric(vertical: 4),
                                              ),
                                              onChanged: (val) {
                                                final parsed = double.tryParse(val.trim());
                                                if (parsed != null && parsed > 0) {
                                                  item.qty = parsed;
                                                }
                                              },
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => _updateItemQty(idx, 1),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              child: Icon(Icons.add, size: 16, color: AppColors.primary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Optional Remark field
                                TextField(
                                  controller: remarkCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Remark / Serial number (optional)',
                                    hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    isDense: true,
                                    filled: true,
                                    fillColor: AppColors.background,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(color: AppColors.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Generate Challan Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: (_isGenerating || _items.isEmpty) ? 0 : 2,
                    ),
                    onPressed: (_isGenerating || _items.isEmpty) ? null : () => _generateChallan(pipeline),
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 20),
                    label: Text(
                      _isGenerating ? 'Generating Challan PDF...' : 'Generate Delivery Challan',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error loading pipeline: $err'),
        ),
      ),
    );
  }
}
