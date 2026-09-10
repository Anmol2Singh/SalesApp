// lib/features/amc/screens/service_visit_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/service_visit.dart';
import '../../../core/models/customer.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/widgets/pdf_preview_screen.dart';

class ServiceVisitFormScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String? contractId;
  final String? pipelineId;

  const ServiceVisitFormScreen({
    super.key,
    required this.customerId,
    this.contractId,
    this.pipelineId,
  });

  @override
  ConsumerState<ServiceVisitFormScreen> createState() => _ServiceVisitFormScreenState();
}

class _ServiceVisitFormScreenState extends ConsumerState<ServiceVisitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _techController = TextEditingController();
  final _notesController = TextEditingController();
  final _laborController = TextEditingController(text: '0');
  
  final List<Map<String, TextEditingController>> _parts = [];
  bool _isSaving = false;
  Customer? _customer;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
    _addSparePartRow(); // initial part line
  }

  @override
  void dispose() {
    _techController.dispose();
    _notesController.dispose();
    _laborController.dispose();
    for (final p in _parts) {
      p['name']!.dispose();
      p['qty']!.dispose();
      p['price']!.dispose();
    }
    super.dispose();
  }

  void _addSparePartRow() {
    setState(() {
      _parts.add({
        'name': TextEditingController(),
        'qty': TextEditingController(text: '1'),
        'price': TextEditingController(text: '0'),
      });
    });
  }

  void _removeSparePartRow(int index) {
    if (_parts.length <= 1) return;
    setState(() {
      final removed = _parts.removeAt(index);
      removed['name']!.dispose();
      removed['qty']!.dispose();
      removed['price']!.dispose();
    });
  }

  Future<void> _loadCustomer() async {
    final supabase = ref.read(supabaseClientProvider);
    final data = await supabase.from('customers').select().eq('id', widget.customerId).single();
    setState(() {
      _customer = Customer.fromJson(data);
    });
  }

  double get _calculatedTotal {
    double total = double.tryParse(_laborController.text) ?? 0.0;
    for (final p in _parts) {
      final qty = double.tryParse(p['qty']!.text) ?? 0.0;
      final price = double.tryParse(p['price']!.text) ?? 0.0;
      total += (qty * price);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Log Service Visit & Spare Parts'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_customer != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Customer: ${_customer!.companyName}', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _techController,
              decoration: const InputDecoration(labelText: 'Technician Name *', hintText: 'e.g. John Doe'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Service Notes / Inspection Findings', hintText: 'Compressor check completed...'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Spare Parts Added', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700)),
                TextButton.icon(
                  onPressed: _addSparePartRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Part'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ..._parts.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: p['name'],
                            decoration: const InputDecoration(labelText: 'Part Name (e.g. Gas Refill, Compressor)'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        if (_parts.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            onPressed: () => _removeSparePartRow(idx),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: p['qty'],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: p['price'],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Unit Rate (INR)'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),
            TextFormField(
              controller: _laborController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Labor & Visiting Charges (INR)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Service Visit Cost:', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    'Rs. ${NumberFormat('#,##,##0.00', 'en_IN').format(_calculatedTotal)}',
                    style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAndGeneratePdf,
              icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.picture_as_pdf),
              label: Text(_isSaving ? 'Saving...' : 'Generate Service Receipt PDF'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndGeneratePdf() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final items = _parts.map((p) {
        final name = p['name']!.text.trim();
        final qty = double.tryParse(p['qty']!.text) ?? 1.0;
        final price = double.tryParse(p['price']!.text) ?? 0.0;
        return SparePartItem(partName: name, qty: qty, unitPrice: price, total: qty * price);
      }).toList();

      final labor = double.tryParse(_laborController.text) ?? 0.0;
      final visit = ServiceVisit(
        id: '',
        contractId: widget.contractId,
        pipelineId: widget.pipelineId,
        customerId: widget.customerId,
        visitDate: DateTime.now(),
        technicianName: _techController.text.trim(),
        serviceNotes: _notesController.text.trim(),
        items: items,
        laborCharge: labor,
        totalCost: _calculatedTotal,
        createdAt: DateTime.now(),
      );

      final res = await supabase.from('service_visits').insert(visit.toJson()).select('id').single();
      final visitId = res['id'] as String;

      // Generate PDF
      final pdfBytes = await PdfService.generateAmcVisitPdf(
        visit: visit,
        customer: _customer!,
        templateConfig: {'company_name': 'INSIYA SOLAR INDUSTRY'},
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => PdfPreviewScreen(pdfBytes: pdfBytes, fileName: 'ServiceVisit_$visitId.pdf'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving visit: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
