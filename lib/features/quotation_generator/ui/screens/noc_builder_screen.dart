// lib/features/quotation_generator/ui/screens/noc_builder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../data/qg_noc_repository.dart';
import '../../models/qg_noc_builder_state.dart';
import '../../models/qg_noc_document.dart';
import '../../models/qg_noc_profile.dart';
import '../../services/pdf_noc_builder.dart';
import '../../services/qg_noc_extractor.dart';

class NocBuilderScreen extends ConsumerStatefulWidget {
  final String? dealId;
  final String? quotationId;
  final String? documentId;
  final bool newVersion;

  const NocBuilderScreen({
    super.key,
    this.dealId,
    this.quotationId,
    this.documentId,
    this.newVersion = false,
  });

  @override
  ConsumerState<NocBuilderScreen> createState() => _NocBuilderScreenState();
}

class _NocBuilderScreenState extends ConsumerState<NocBuilderScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  List<QgNocProfile> _profiles = [];
  QgNocProfile? _selectedProfile;
  NocWordingMode _wordingMode = NocWordingMode.templateExact;

  // Controllers
  final _customerNameCtrl = TextEditingController();
  final _salutationCtrl = TextEditingController(text: 'M/s');
  final _addressCtrl = TextEditingController();
  final _productNameCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _equipmentLabelCtrl = TextEditingController();
  final _workTypeCtrl = TextEditingController();
  final _wiringCtrl = TextEditingController(text: 'Done');
  final _testingCtrl = TextEditingController(text: 'Done');
  final _remarkCtrl = TextEditingController(text: 'All Installation & Commissioning work Completed as per work order');
  final _closingSentenceCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController(text: 'INSIYA TRADING CORPORATION');
  final _companyAddressCtrl = TextEditingController(text: 'Office no.807,finswell,behind Hyatt Hotel,\n Viman Nagar, Pune 411014');
  final _companyEmailCtrl = TextEditingController(text: 'insiyaindia@gmail.com    info@insiyacorp.com');
  final _companyPhoneCtrl = TextEditingController(text: '+91 7588874019 & +91 9292922992');
  final _companyWebsiteCtrl = TextEditingController(text: 'www.insiyacorp.com');
  final _quotationNumberCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  List<NocEquipmentLine> _equipmentLines = [];
  List<TextEditingController> _confirmationControllers = [];
  bool _includeStamp = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _salutationCtrl.dispose();
    _addressCtrl.dispose();
    _productNameCtrl.dispose();
    _subjectCtrl.dispose();
    _equipmentLabelCtrl.dispose();
    _workTypeCtrl.dispose();
    _wiringCtrl.dispose();
    _testingCtrl.dispose();
    _remarkCtrl.dispose();
    _closingSentenceCtrl.dispose();
    _companyNameCtrl.dispose();
    _companyAddressCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyWebsiteCtrl.dispose();
    _quotationNumberCtrl.dispose();
    for (final c in _confirmationControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch company details strictly from pdf_template
      final supabase = ref.read(supabaseClientProvider);
      final comp = await QgNocRepository.fetchCompanyDetailsFromTemplate(supabase);
      if (comp['company_name'] != null) _companyNameCtrl.text = comp['company_name'];
      if (comp['company_address'] != null || comp['address'] != null) {
        _companyAddressCtrl.text = comp['company_address'] ?? comp['address'];
      }
      if (comp['company_email'] != null || comp['email'] != null) {
        _companyEmailCtrl.text = comp['company_email'] ?? comp['email'];
      }
      if (comp['company_phone'] != null || comp['phone'] != null) {
        _companyPhoneCtrl.text = comp['company_phone'] ?? comp['phone'];
      }
      if (comp['company_website'] != null || comp['website'] != null) {
        _companyWebsiteCtrl.text = comp['company_website'] ?? comp['website'];
      }

      // 2. Fetch available profiles
      _profiles = await QgNocRepository.fetchProfiles();
      _selectedProfile = _profiles.isNotEmpty ? _profiles.first : null;

      // 3. If editing existing document
      if (widget.documentId != null) {
        final doc = await QgNocRepository.fetchNocById(widget.documentId!);
        if (doc != null) {
          _populateFromDocument(doc);
          setState(() => _isLoading = false);
          return;
        }
      }

      // 4. If quotationId is provided, extract from quotation
      if (widget.quotationId != null && widget.quotationId!.isNotEmpty) {
        await _extractFromQuotation(widget.quotationId!);
      } else {
        // Apply default profile
        _applyProfile(_selectedProfile);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyProfile(QgNocProfile? profile) {
    if (profile == null) return;
    _productNameCtrl.text = profile.productName;
    _subjectCtrl.text = 'No Objection Certificate for Installation & Commissioning of ${profile.productName}.';
    _equipmentLabelCtrl.text = profile.equipmentLabel;
    _workTypeCtrl.text = '${profile.productName} Installation work';
    _wiringCtrl.text = profile.wiring;
    _testingCtrl.text = profile.testing;
    _remarkCtrl.text = profile.remark;
    _closingSentenceCtrl.text = profile.closingSentence ?? 'This NOC is issued upon request for installation and operation of the ${profile.productName} System.';

    _confirmationControllers = profile.defaultConfirmations
        .map((c) => TextEditingController(text: c))
        .toList();

    if (_equipmentLines.isEmpty) {
      _equipmentLines = [
        NocEquipmentLine(
          product: profile.productName,
          model: 'Standard',
          quantity: 1,
          uom: 'Nos',
        ),
      ];
    }
  }

  void _populateFromDocument(QgNocDocument doc) {
    _customerNameCtrl.text = doc.customerName;
    _addressCtrl.text = doc.siteAddress;
    _productNameCtrl.text = doc.productName;
    _subjectCtrl.text = 'No Objection Certificate for Installation & Commissioning of ${doc.productName}.';
    _equipmentLabelCtrl.text = doc.productName;
    _workTypeCtrl.text = '${doc.productName} Installation work';
    _wordingMode = doc.wordingMode;
    _selectedDate = doc.issuedDate;
    _equipmentLines = List.from(doc.equipmentLines);
    _quotationNumberCtrl.text = doc.quotationNumber ?? '';

    // Snapshot company
    final cs = doc.companySnapshot;
    if (cs['company_name'] != null) _companyNameCtrl.text = cs['company_name'];
    if (cs['company_address'] != null || cs['short_address'] != null) {
      _companyAddressCtrl.text = cs['company_address'] ?? cs['short_address'];
    }
    if (cs['company_email'] != null || cs['email'] != null) {
      _companyEmailCtrl.text = cs['company_email'] ?? cs['email'];
    }
    if (cs['company_phone'] != null || cs['phone'] != null) {
      _companyPhoneCtrl.text = cs['company_phone'] ?? cs['phone'];
    }
    if (cs['company_website'] != null || cs['website'] != null) {
      _companyWebsiteCtrl.text = cs['company_website'] ?? cs['website'];
    }

    _closingSentenceCtrl.text = 'This NOC is issued upon request for installation and operation of the ${doc.productName} System.';
    _confirmationControllers = [
      TextEditingController(text: '1. The installation of the ${doc.productName} is permitted at the above location.'),
      TextEditingController(text: '3. Necessary precautions has been taken.'),
    ];
  }

  Future<void> _extractFromQuotation(String qId) async {
    final supabase = ref.read(supabaseClientProvider);
    final res = await supabase.from('quotations').select('*').eq('id', qId).maybeSingle();
    if (res == null) return;

    _quotationNumberCtrl.text = res['quotation_number']?.toString() ?? '';
    _customerNameCtrl.text = res['customer_name']?.toString() ?? '';
    _addressCtrl.text = res['site_address']?.toString() ?? res['customer_address']?.toString() ?? '';

    final product = res['product_name']?.toString() ?? 'Heat Pump';
    _productNameCtrl.text = product;
    _equipmentLabelCtrl.text = product;
    _workTypeCtrl.text = '$product Installation work';
    _subjectCtrl.text = 'No Objection Certificate for Installation & Commissioning of $product.';
    _closingSentenceCtrl.text = 'This NOC is issued upon request for installation and operation of the $product System.';

    final rawItems = res['line_items'] ?? res['items'] ?? [];
    final itemsList = (rawItems is List)
        ? rawItems.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList()
        : <Map<String, dynamic>>[];
    final itemsTreatedAsProducts = await QgNocExtractor.fetchItemsTreatedAsProducts(supabase);
    final extractedLines = QgNocExtractor.extractEquipmentLines(
      lineItems: itemsList,
      defaultProductName: product,
      itemsTreatedAsProducts: itemsTreatedAsProducts,
    );
    if (extractedLines.isNotEmpty) {
      _equipmentLines = extractedLines;
    }

    _confirmationControllers = [
      TextEditingController(text: '1. The installation of the $product is permitted at the above location.'),
      TextEditingController(text: '3. Necessary precautions has been taken.'),
    ];
  }

  QgNocPayload _buildCurrentPayload() {
    return QgNocPayload(
      companyName: _companyNameCtrl.text.trim(),
      companyAddress: _companyAddressCtrl.text.trim(),
      companyEmail: _companyEmailCtrl.text.trim(),
      companyPhone: _companyPhoneCtrl.text.trim(),
      companyWebsite: _companyWebsiteCtrl.text.trim(),
      salutation: _salutationCtrl.text.trim(),
      customerName: _customerNameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      productName: _productNameCtrl.text.trim(),
      subject: _subjectCtrl.text.trim(),
      date: _selectedDate,
      equipmentLabel: _equipmentLabelCtrl.text.trim(),
      equipmentLines: _equipmentLines,
      workType: _workTypeCtrl.text.trim(),
      wiring: _wiringCtrl.text.trim(),
      testing: _testingCtrl.text.trim(),
      remark: _remarkCtrl.text.trim(),
      confirmations: _confirmationControllers.map((c) => c.text.trim()).where((c) => c.isNotEmpty).toList(),
      closingSentence: _closingSentenceCtrl.text.trim(),
      wordingMode: _wordingMode,
      quotationNumber: _quotationNumberCtrl.text.trim().isEmpty ? null : _quotationNumberCtrl.text.trim(),
    );
  }

  Future<void> _previewPdf() async {
    try {
      final payload = _buildCurrentPayload();
      final pdfBytes = await PdfNocBuilder.buildNocPdf(payload);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: 'noc_preview.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating preview: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _isSaving = true);
    try {
      final payload = _buildCurrentPayload();
      final savedDoc = await QgNocRepository.saveDraft(
        dealId: widget.dealId,
        quotationId: widget.quotationId,
        customerName: payload.customerName,
        siteAddress: payload.address,
        productName: payload.productName,
        wordingMode: payload.wordingMode,
        equipmentLines: payload.equipmentLines,
        companySnapshot: {
          'company_name': payload.companyName,
          'short_address': payload.companyAddress,
          'email': payload.companyEmail,
          'phone': payload.companyPhone,
          'website': payload.companyWebsite,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Draft saved: ${savedDoc.nocNumber}'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving draft: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _finalizeAndIssue() async {
    final payload = _buildCurrentPayload();
    if (payload.customerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer name is required'), backgroundColor: AppColors.error),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Issue Final NOC?'),
        content: const Text(
          'Finalizing will generate an official immutable NOC document number and issue the certificate. Proceed?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF286B37),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm & Issue'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      // 1. Build PDF bytes
      final pdfBytes = await PdfNocBuilder.buildNocPdf(payload);

      // 2. Finalize via RPC
      final finalDoc = await QgNocRepository.finalizeAndIssueNoc(
        dealId: widget.dealId,
        quotationId: widget.quotationId,
        customerName: payload.customerName,
        siteAddress: payload.address,
        productName: payload.productName,
        wordingMode: payload.wordingMode,
        equipmentLines: payload.equipmentLines,
        pdfBytes: pdfBytes,
        companySnapshot: {
          'company_name': payload.companyName,
          'short_address': payload.companyAddress,
          'email': payload.companyEmail,
          'phone': payload.companyPhone,
          'website': payload.companyWebsite,
        },
        overrideReason: 'Completed deal installation & commissioning verified for ${payload.productName}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ NOC Issued: ${finalDoc.nocNumber}'), backgroundColor: AppColors.success),
        );

        // Open preview screen immediately
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: '${finalDoc.nocNumber.replaceAll('/', '_')}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error issuing NOC: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('NOC Builder')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.documentId != null ? 'Edit NOC Certificate' : 'Generate New NOC',
          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility),
            tooltip: 'Preview PDF',
            onPressed: _previewPdf,
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: const Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : _saveDraft,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text('Save Draft'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _finalizeAndIssue,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle, size: 18),
                label: const Text('Finalize & Issue NOC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF286B37),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Certificate Date Card
            _buildSectionCard(
              title: 'Certificate Date',
              icon: Icons.calendar_today,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: Color(0xFF174895)),
                  title: Text('Certificate Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: const Text('Change Date'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Customer & Site Information Card
            _buildSectionCard(
              title: 'Customer & Site Information',
              icon: Icons.person_outline,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _salutationCtrl,
                        decoration: const InputDecoration(labelText: 'Salutation', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _customerNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer / Business Name *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Site Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subject Line',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Equipment Lines Card
            _buildSectionCard(
              title: 'Equipment & Scope Details',
              icon: Icons.build_outlined,
              children: [
                TextField(
                  controller: _productNameCtrl,
                  decoration: const InputDecoration(labelText: 'Product / System Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                const Text('Equipment Lines:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ..._equipmentLines.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final line = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            initialValue: line.model,
                            decoration: InputDecoration(
                              labelText: 'Model #${idx + 1}',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            onChanged: (v) => _equipmentLines[idx] = line.copyWith(model: v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: line.quantity.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Qty',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            onChanged: (v) => _equipmentLines[idx] = line.copyWith(quantity: int.tryParse(v) ?? 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: line.uom,
                            decoration: const InputDecoration(
                              labelText: 'UOM',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            onChanged: (v) => _equipmentLines[idx] = line.copyWith(uom: v),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                          onPressed: () {
                            if (_equipmentLines.length > 1) {
                              setState(() => _equipmentLines.removeAt(idx));
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _equipmentLines.add(
                          NocEquipmentLine(
                            product: _productNameCtrl.text.trim(),
                            model: 'Standard',
                            quantity: 1,
                            uom: 'Nos',
                          ),
                        );
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Equipment Line'),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),
                TextField(
                  controller: _workTypeCtrl,
                  decoration: const InputDecoration(labelText: 'Work Type', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _wiringCtrl,
                        decoration: const InputDecoration(labelText: 'Wiring Status', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _testingCtrl,
                        decoration: const InputDecoration(labelText: 'Testing Status', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _remarkCtrl,
                  decoration: const InputDecoration(labelText: 'Remark', border: OutlineInputBorder()),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Confirmations & Closing Card
            _buildSectionCard(
              title: 'Confirmations & Terms',
              icon: Icons.checklist_outlined,
              children: [
                ..._confirmationControllers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ctrl = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            decoration: InputDecoration(
                              labelText: 'Confirmation #${idx + 1}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () {
                            if (_confirmationControllers.length > 1) {
                              setState(() {
                                _confirmationControllers.removeAt(idx).dispose();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _confirmationControllers.add(TextEditingController(text: ''));
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Confirmation Point'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _closingSentenceCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Closing Declaration Sentence',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF174895)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
