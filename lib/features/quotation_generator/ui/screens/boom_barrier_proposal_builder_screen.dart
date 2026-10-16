// lib/features/quotation_generator/ui/screens/boom_barrier_proposal_builder_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/deal_quotations_repository.dart';
import '../../models/boom_barrier_at_actual_line.dart';
import '../../models/boom_barrier_line_item.dart';
import '../../models/boom_barrier_proposal_draft.dart';
import '../../models/deal_quotation_item.dart';
import '../../models/qg_product_profile.dart';
import '../../services/boom_barrier_math.dart';
import '../../services/qg_boom_barrier_drafts_service.dart';
import '../widgets/image_picker_tile.dart';
import 'boom_barrier_preview_screen.dart';

class BoomBarrierProposalBuilderScreen extends ConsumerStatefulWidget {
  final String quotationId;
  final DealQuotationItem? initialDealQuotation;
  final QgProductProfile? initialProfile;

  const BoomBarrierProposalBuilderScreen({
    super.key,
    required this.quotationId,
    this.initialDealQuotation,
    this.initialProfile,
  });

  @override
  ConsumerState<BoomBarrierProposalBuilderScreen> createState() =>
      _BoomBarrierProposalBuilderScreenState();
}

class _BoomBarrierProposalBuilderScreenState
    extends ConsumerState<BoomBarrierProposalBuilderScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  DealQuotationItem? _dealQuotation;
  late QgProductProfile _profile;
  BoomBarrierProposalDraft? _draft;

  bool _isSaving = false;
  bool _isRestoredFromDraft = false;
  Timer? _autoSaveDebounce;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile ?? QgProductProfile.defaultBoomBarrier();
    _loadQuotationAndDraft();
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadQuotationAndDraft() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      DealQuotationItem? dealItem = widget.initialDealQuotation;
      if (dealItem == null) {
        final supabase = ref.read(supabaseClientProvider);
        final repo = DealQuotationsRepository(supabase);
        dealItem = await repo.getDealQuotationById(widget.quotationId);
      }

      if (dealItem == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Quotation with ID "${widget.quotationId}" could not be found.';
        });
        return;
      }

      _dealQuotation = dealItem;

      // Check for local Hive draft
      final savedDraft =
          await QgBoomBarrierDraftsService.loadDraft(widget.quotationId);
      if (savedDraft != null) {
        _draft = savedDraft;
        _isRestoredFromDraft = true;
      } else {
        _draft = BoomBarrierProposalDraft.fromDealQuotation(dealItem, _profile);
        _isRestoredFromDraft = false;
      }

      _recalculateTotals(save: false);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load quotation: $e';
      });
    }
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 1000), () {
      _saveDraft(showSnackbar: false);
    });
  }

  Future<void> _saveDraft({bool showSnackbar = true}) async {
    if (_draft == null) return;
    setState(() => _isSaving = true);
    try {
      await QgBoomBarrierDraftsService.saveDraft(_draft!);
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Boom Barrier proposal draft saved successfully'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _recalculateTotals({bool save = true}) {
    if (_draft == null) return;
    final calc = BoomBarrierMath.calculate(
      items: _draft!.items,
      gstPercent: _draft!.gstPercent,
    );
    _draft!.subtotal = calc.subtotal;
    _draft!.gstAmount = calc.gstAmount;
    _draft!.grandTotal = calc.grandTotal;

    if (save) {
      _scheduleAutoSave();
    }
  }

  void _resetToDealQuotation() {
    if (_dealQuotation == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Proposal?'),
        content: const Text(
          'This will discard local draft edits and re-populate from CRM deal items.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _draft = BoomBarrierProposalDraft.fromDealQuotation(
                  _dealQuotation!,
                  _profile,
                );
                _isRestoredFromDraft = false;
                _recalculateTotals(save: true);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Proposal reset to CRM deal items')),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openPdfPreview() {
    if (_draft == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => BoomBarrierPreviewScreen(
          draft: _draft!,
          profile: _profile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Boom Barrier Proposal Builder'),
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading Boom Barrier deal & template data...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _draft == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Proposal Builder'),
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(_errorMessage ?? 'Proposal not available', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadQuotationAndDraft,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final draft = _draft!;
    final isConfirmed = draft.status.toLowerCase() == 'confirmed';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  draft.quotationNumber,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isConfirmed ? Colors.green.shade700 : Colors.amber.shade800,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isConfirmed ? 'CONFIRMED' : 'DRAFT',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              draft.customerName,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Row(
                  children: [
                    const Icon(Icons.cloud_done_outlined, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      _isRestoredFromDraft ? 'Draft Restored' : 'Auto-saved',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: 'Reset to Deal Quotation',
            icon: const Icon(Icons.restore),
            onPressed: _resetToDealQuotation,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner for Draft pre-approval watermark
          if (!isConfirmed) _buildWatermarkBanner(),

          // Section 1: Customer Details
          _buildCustomerSection(draft),
          const SizedBox(height: 16),

          // Section 2: Model & Scope Configuration
          _buildConfigurationSection(draft),
          const SizedBox(height: 16),

          // Section 3: Technical Specifications (Model & LPR)
          _buildSpecsEditorSection(draft),
          const SizedBox(height: 16),

          // Section 4: Option 1 Price Table
          _buildLineItemsSection(draft),
          const SizedBox(height: 16),

          // Section 5: At-Actual Lines
          _buildAtActualSection(draft),
          const SizedBox(height: 16),

          // Section 6: Commercial Financial Totals
          _buildFinancialSummaryCard(draft),
          const SizedBox(height: 16),

          // Section 7: Site Readiness Notes & Commercial Terms
          _buildNotesAndTermsSection(draft),
          const SizedBox(height: 16),

          // Section 8: Images & Branding Overrides (Cover, Stamp, Product Gallery)
          _buildImagesSection(draft),
          const SizedBox(height: 16),

          // Section 9: Acceptance Letter & Bank Information
          _buildAcceptanceAndBankSection(draft),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildWatermarkBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade900, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pre-Approval Proposal (Draft)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'This quotation is not yet confirmed. The 5-page PDF preview will display a "DRAFT - NOT APPROVED" watermark across all pages.',
                  style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(BoomBarrierProposalDraft draft) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, color: Color(0xFF1E3A5F)),
                const SizedBox(width: 8),
                const Text(
                  'Customer & Sales Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            TextFormField(
              initialValue: draft.customerName,
              decoration: const InputDecoration(
                labelText: 'Customer / Company Name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) {
                draft.customerName = val;
                _scheduleAutoSave();
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.customerAddress,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Customer Address',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) {
                draft.customerAddress = val;
                _scheduleAutoSave();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: draft.customerPhone,
                    decoration: const InputDecoration(
                      labelText: 'Customer Mobile',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      draft.customerPhone = val;
                      _scheduleAutoSave();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: draft.quoteDate,
                    decoration: const InputDecoration(
                      labelText: 'Quote Date (DD/MM/YYYY)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      draft.quoteDate = val;
                      _scheduleAutoSave();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: draft.salesmanName,
                    decoration: const InputDecoration(
                      labelText: 'Salesperson Name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      draft.salesmanName = val;
                      _scheduleAutoSave();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: draft.salesmanPhone,
                    decoration: const InputDecoration(
                      labelText: 'Salesperson Phone',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      draft.salesmanPhone = val;
                      _scheduleAutoSave();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationSection(BoomBarrierProposalDraft draft) {
    final standardModels = ['IZ-2001', 'IZ-2026', 'IZ-2004'];
    final modelOptions = {...standardModels, draft.primaryModelNo}.toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.settings_outlined, color: Color(0xFF1E3A5F)),
                    SizedBox(width: 8),
                    Text(
                      'Boom Barrier Proposal Builder',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add New Model', style: TextStyle(fontSize: 12)),
                  onPressed: () => _showAddNewModelDialog(draft),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: modelOptions.contains(draft.primaryModelNo)
                        ? draft.primaryModelNo
                        : modelOptions.first,
                    decoration: const InputDecoration(
                      labelText: 'Primary Barrier Model',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: modelOptions.map((m) {
                      String label = m;
                      if (m == 'IZ-2001') label = 'IZ-2001 (High Speed)';
                      if (m == 'IZ-2026') label = 'IZ-2026 (Commercial)';
                      if (m == 'IZ-2004') label = 'IZ-2004 (Heavy Duty)';
                      return DropdownMenuItem(value: m, child: Text(label));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          draft.primaryModelNo = val;
                          draft.barrierSpecs = BoomBarrierProposalDraft.defaultSpecsForModel(val);
                          draft.subjectText =
                              'Quotation for Supply & Installation of Boom Barrier for Entry Gate Model No- $val';
                          _scheduleAutoSave();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: draft.optionTitle,
                    decoration: const InputDecoration(
                      labelText: 'Option Title',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      draft.optionTitle = val;
                      _scheduleAutoSave();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('subject_${draft.primaryModelNo}'),
              initialValue: draft.subjectText,
              decoration: const InputDecoration(
                labelText: 'Subject Line',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) {
                draft.subjectText = val;
                _scheduleAutoSave();
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Include NPRS / LPR Technical Specifications Table',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Displays the 9-row Number Plate Recognition Camera specs on Page 3',
                style: TextStyle(fontSize: 12),
              ),
              value: draft.includeLprSpecs,
              activeColor: const Color(0xFF1E3A5F),
              onChanged: (val) {
                setState(() {
                  draft.includeLprSpecs = val;
                  _scheduleAutoSave();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNewModelDialog(BoomBarrierProposalDraft draft) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Boom Barrier Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the model name/code (e.g. IZ-2030, IZ-Pro). The specifications table will be initialized and can be customized.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Model Name / Number',
                hintText: 'e.g. IZ-2030',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newModel = ctrl.text.trim();
              if (newModel.isNotEmpty) {
                setState(() {
                  draft.primaryModelNo = newModel;
                  draft.subjectText =
                      'Quotation for Supply & Installation of Boom Barrier for Entry Gate Model No- $newModel';
                  draft.barrierSpecs =
                      BoomBarrierProposalDraft.defaultSpecsForModel(newModel);
                  _scheduleAutoSave();
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add Model'),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsEditorSection(BoomBarrierProposalDraft draft) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.list_alt, color: Color(0xFF1E3A5F)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Technical Specifications: Model ${draft.primaryModelNo}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset Defaults', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    setState(() {
                      draft.barrierSpecs =
                          BoomBarrierProposalDraft.defaultSpecsForModel(draft.primaryModelNo);
                      _scheduleAutoSave();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reset specs to default for ${draft.primaryModelNo}')),
                    );
                  },
                ),
              ],
            ),
            const Text(
              'These specifications are printed on Page 3 of the quotation PDF.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Divider(height: 20),
            ...draft.barrierSpecs.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        key: ValueKey('spec_label_${draft.primaryModelNo}_$i'),
                        initialValue: row['label']?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Specification',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          draft.barrierSpecs[i]['label'] = val;
                          _scheduleAutoSave();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        key: ValueKey('spec_value_${draft.primaryModelNo}_$i'),
                        initialValue: row['value']?.toString() ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Value',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          draft.barrierSpecs[i]['value'] = val;
                          _scheduleAutoSave();
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: row['visible'] == false ? 'Hidden in quote' : 'Visible in quote',
                      child: Checkbox(
                        value: row['visible'] != false,
                        onChanged: (v) {
                          setState(() {
                            draft.barrierSpecs[i]['visible'] = v ?? true;
                            _scheduleAutoSave();
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      onPressed: () {
                        setState(() {
                          draft.barrierSpecs.removeAt(i);
                          _scheduleAutoSave();
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Specification Row'),
              onPressed: () {
                setState(() {
                  draft.barrierSpecs.add({
                    'label': 'New Parameter',
                    'value': '',
                    'visible': true,
                  });
                  _scheduleAutoSave();
                });
              },
            ),

            if (draft.includeLprSpecs) ...[
              const SizedBox(height: 24),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.camera_alt_outlined, color: Color(0xFF1E3A5F)),
                      SizedBox(width: 8),
                      Text(
                        'NPRS / LPR Camera Technical Specifications',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset LPR Defaults', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        draft.lprSpecs = BoomBarrierProposalDraft.defaultLprSpecs();
                        _scheduleAutoSave();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reset LPR specs to default')),
                      );
                    },
                  ),
                ],
              ),
              const Text(
                'Rendered in the second specification column on Page 3.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ...draft.lprSpecs.asMap().entries.map((entry) {
                final i = entry.key;
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          key: ValueKey('lpr_label_$i'),
                          initialValue: row['label']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'LPR Specification',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            draft.lprSpecs[i]['label'] = val;
                            _scheduleAutoSave();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          key: ValueKey('lpr_value_$i'),
                          initialValue: row['value']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Value',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            draft.lprSpecs[i]['value'] = val;
                            _scheduleAutoSave();
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: row['visible'] == false ? 'Hidden in quote' : 'Visible in quote',
                        child: Checkbox(
                          value: row['visible'] != false,
                          onChanged: (v) {
                            setState(() {
                              draft.lprSpecs[i]['visible'] = v ?? true;
                              _scheduleAutoSave();
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                        onPressed: () {
                          setState(() {
                            draft.lprSpecs.removeAt(i);
                            _scheduleAutoSave();
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add LPR Specification Row'),
                onPressed: () {
                  setState(() {
                    draft.lprSpecs.add({
                      'label': 'New Parameter',
                      'value': '',
                      'visible': true,
                    });
                    _scheduleAutoSave();
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagesSection(BoomBarrierProposalDraft draft) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.image_outlined, color: Color(0xFF1E3A5F)),
                SizedBox(width: 8),
                Text(
                  'Images & Branding Customization',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Text(
              'Upload custom cover artwork, company stamp, or showcase product images for this quotation.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Divider(height: 20),
            ImagePickerTile(
              title: 'Cover Page Artwork (Page 1)',
              subtitle: 'Full-bleed front cover image on Page 1 of the quotation',
              currentPath: draft.coverImagePath,
              defaultAssetPath: 'assets/images/boom_barrier/cover_artwork.png',
              onImageChanged: (path) {
                setState(() {
                  draft.coverImagePath = path;
                  _scheduleAutoSave();
                });
              },
              onResetToDefault: () {
                setState(() {
                  draft.coverImagePath = 'assets/images/boom_barrier/cover_artwork.png';
                  _scheduleAutoSave();
                });
              },
            ),
            const SizedBox(height: 16),
            ImagePickerTile(
              title: 'Official Company Stamp (Page 5)',
              subtitle: 'Rendered alongside signature block on Page 5 Acceptance Letter',
              currentPath: draft.stampPath,
              defaultAssetPath: 'assets/images/company_stamp.png',
              onImageChanged: (path) {
                setState(() {
                  draft.stampPath = path;
                  _scheduleAutoSave();
                });
              },
              onResetToDefault: () {
                setState(() {
                  draft.stampPath = null;
                  _scheduleAutoSave();
                });
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Product Showcase Gallery (Page 4 Images)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
            ),
            const SizedBox(height: 10),
            ImagePickerTile(
              title: 'IZ-2001 Model Image',
              subtitle: 'Showcase card 1 on Page 4 gallery',
              currentPath: draft.galleryIz2001Path,
              defaultAssetPath: 'assets/images/boom_barrier/product_iz_2001.png',
              onImageChanged: (path) {
                setState(() {
                  draft.galleryIz2001Path = path;
                  _scheduleAutoSave();
                });
              },
              onResetToDefault: () {
                setState(() {
                  draft.galleryIz2001Path = null;
                  _scheduleAutoSave();
                });
              },
            ),
            const SizedBox(height: 12),
            ImagePickerTile(
              title: 'IZ-2026 Model Image',
              subtitle: 'Showcase card 2 on Page 4 gallery',
              currentPath: draft.galleryIz2026Path,
              defaultAssetPath: 'assets/images/boom_barrier/product_iz_2026.png',
              onImageChanged: (path) {
                setState(() {
                  draft.galleryIz2026Path = path;
                  _scheduleAutoSave();
                });
              },
              onResetToDefault: () {
                setState(() {
                  draft.galleryIz2026Path = null;
                  _scheduleAutoSave();
                });
              },
            ),
            const SizedBox(height: 12),
            ImagePickerTile(
              title: 'IZ-2004 Model Image',
              subtitle: 'Showcase card 3 on Page 4 gallery',
              currentPath: draft.galleryIz2004Path,
              defaultAssetPath: 'assets/images/boom_barrier/product_iz_2004.png',
              onImageChanged: (path) {
                setState(() {
                  draft.galleryIz2004Path = path;
                  _scheduleAutoSave();
                });
              },
              onResetToDefault: () {
                setState(() {
                  draft.galleryIz2004Path = null;
                  _scheduleAutoSave();
                });
              },
            ),
            const SizedBox(height: 12),
            ImagePickerTile(
              title: 'NPRS / LPR Camera Image',
              subtitle: 'Showcase card 4 on Page 4 gallery',
              currentPath: draft.galleryNprsPath,
              defaultAssetPath: 'assets/images/boom_barrier/product_nprs.png',
              onImageChanged: (path) {
                setState(() {
                  draft.galleryNprsPath = path;
                  _scheduleAutoSave();
                });
              },
              onResetToDefault: () {
                setState(() {
                  draft.galleryNprsPath = null;
                  _scheduleAutoSave();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemsSection(BoomBarrierProposalDraft draft) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_chart_outlined, color: Color(0xFF1E3A5F)),
                    const SizedBox(width: 8),
                    const Text(
                      'Quotation Line Items (Option 1)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Item'),
                  onPressed: () => _addNewLineItem(draft),
                ),
              ],
            ),
            const Divider(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: draft.items.length,
              separatorBuilder: (ctx, i) => const Divider(height: 24),
              itemBuilder: (ctx, index) {
                final item = draft.items[index];
                return _buildLineItemRow(draft, item, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemRow(
    BoomBarrierProposalDraft draft,
    BoomBarrierLineItem item,
    int index,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${item.srNo}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: item.description,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Item Description',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    draft.items[index] = item.copyWith(description: val);
                    _scheduleAutoSave();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Delete Item',
                onPressed: () {
                  setState(() {
                    draft.items.removeAt(index);
                    // Re-index srNo
                    for (int i = 0; i < draft.items.length; i++) {
                      draft.items[i] = draft.items[i].copyWith(srNo: i + 1);
                    }
                    _recalculateTotals();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Bullet points / inclusions
          if (item.inclusions.isNotEmpty) ...[
            const Text(
              'Included Specifications / Bullets:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 4),
            ...item.inclusions.asMap().entries.map((entry) {
              final bIndex = entry.key;
              final bullet = entry.value;
              return Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        bullet,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          final updated = List<String>.from(item.inclusions)..removeAt(bIndex);
                          draft.items[index] = item.copyWith(inclusions: updated);
                          _scheduleAutoSave();
                        });
                      },
                      child: const Icon(Icons.close, size: 14, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Bullet Point', style: TextStyle(fontSize: 11)),
              onPressed: () => _addBulletPoint(draft, index, item),
            ),
            const SizedBox(height: 8),
          ],

          // Numbers row: Qty, Rate, Discount, Price or Extra
          Row(
            children: [
              // Extra Checkbox
              Checkbox(
                value: item.isExtra,
                onChanged: (val) {
                  setState(() {
                    draft.items[index] = item.copyWith(
                      isExtra: val ?? false,
                      isIncluded: false,
                    );
                    _recalculateTotals();
                  });
                },
              ),
              const Text('Extra', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 8),

              // Included Checkbox
              Checkbox(
                value: item.isIncluded,
                onChanged: (val) {
                  setState(() {
                    draft.items[index] = item.copyWith(
                      isIncluded: val ?? false,
                      isExtra: false,
                    );
                    _recalculateTotals();
                  });
                },
              ),
              const Text('Included', style: TextStyle(fontSize: 12)),
              const Spacer(),

              if (!item.isExtra && !item.isIncluded) ...[
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    initialValue: item.qty.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      final q = int.tryParse(val) ?? 1;
                      final newPrice = (q * item.rate) - item.discount;
                      draft.items[index] = item.copyWith(qty: q, price: newPrice);
                      setState(() => _recalculateTotals());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: item.rate.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rate (₹)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      final r = double.tryParse(val) ?? 0.0;
                      final newPrice = (item.qty * r) - item.discount;
                      draft.items[index] = item.copyWith(rate: r, price: newPrice);
                      setState(() => _recalculateTotals());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Total: ₹${item.price.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ] else ...[
                Text(
                  item.isExtra ? 'Status: Extra' : 'Status: Included',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: item.isExtra ? Colors.orange.shade800 : Colors.teal,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _addBulletPoint(BoomBarrierProposalDraft draft, int itemIndex, BoomBarrierLineItem item) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Inclusion Bullet'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. 2 Nos of Wireless Remote Controller',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  final list = List<String>.from(item.inclusions)..add(controller.text.trim());
                  draft.items[itemIndex] = item.copyWith(inclusions: list);
                  _scheduleAutoSave();
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addNewLineItem(BoomBarrierProposalDraft draft) {
    final descController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final rateController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Quotation Line Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: rateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rate (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final desc = descController.text.trim();
              if (desc.isNotEmpty) {
                final qty = int.tryParse(qtyController.text) ?? 1;
                final rate = double.tryParse(rateController.text) ?? 0.0;
                setState(() {
                  draft.items.add(
                    BoomBarrierLineItem(
                      srNo: draft.items.length + 1,
                      description: desc,
                      qty: qty,
                      rate: rate,
                      price: qty * rate,
                    ),
                  );
                  _recalculateTotals();
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  Widget _buildAtActualSection(BoomBarrierProposalDraft draft) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cable, color: Color(0xFF1E3A5F)),
                    SizedBox(width: 8),
                    Text(
                      'At-Actual Rate Lines',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Row'),
                  onPressed: () {
                    setState(() {
                      draft.atActualCharges.add(
                        BoomBarrierAtActualLine(
                          srNo: draft.atActualCharges.length + 1,
                          description: 'Wiring charges CAT6 + 3 core Power cable',
                          qty: '1 mtr',
                          rate: '150.00',
                          total: 'At Actual',
                        ),
                      );
                      _scheduleAutoSave();
                    });
                  },
                ),
              ],
            ),
            const Text(
              'Rates billed on actual measurement upon project completion.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Divider(height: 16),
            ...draft.atActualCharges.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        initialValue: row.description,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          draft.atActualCharges[i] = row.copyWith(description: val);
                          _scheduleAutoSave();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        initialValue: row.qty,
                        decoration: const InputDecoration(
                          labelText: 'Qty',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          draft.atActualCharges[i] = row.copyWith(qty: val);
                          _scheduleAutoSave();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        initialValue: row.rate,
                        decoration: const InputDecoration(
                          labelText: 'Rate',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          draft.atActualCharges[i] = row.copyWith(rate: val);
                          _scheduleAutoSave();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () {
                        setState(() {
                          draft.atActualCharges.removeAt(i);
                          _scheduleAutoSave();
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummaryCard(BoomBarrierProposalDraft draft) {
    final subtotalText = BoomBarrierMath.formatIndianCurrencyWithSymbol(draft.subtotal);
    final gstText = BoomBarrierMath.formatIndianCurrencyWithSymbol(draft.gstAmount);
    final grandTotalText = BoomBarrierMath.formatIndianCurrencyWithSymbol(draft.grandTotal);
    final wordsText = BoomBarrierMath.numberToIndianWords(draft.grandTotal);

    return Card(
      elevation: 2,
      color: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Commercial Financial Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal (Option 1):', style: TextStyle(fontSize: 14)),
                Text(
                  subtotalText,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GST @ ${draft.gstPercent.toStringAsFixed(0)}%:',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  gstText,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                Text(
                  grandTotalText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(
                'Amount in Words: $wordsText',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesAndTermsSection(BoomBarrierProposalDraft draft) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, color: Color(0xFF1E3A5F)),
                const SizedBox(width: 8),
                const Text(
                  'Notes, Terms & Payment Conditions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            TextFormField(
              initialValue: draft.paymentSentence,
              decoration: const InputDecoration(
                labelText: 'Payment Terms Sentence (for Option 1 & Acceptance)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) {
                draft.paymentSentence = val;
                _scheduleAutoSave();
              },
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: Text(
                'Site Readiness Notes (${draft.notes.length} points)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              children: draft.notes.asMap().entries.map((entry) {
                final i = entry.key;
                final note = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: TextFormField(
                    initialValue: note,
                    decoration: InputDecoration(
                      labelText: 'Note ${i + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      draft.notes[i] = val;
                      _scheduleAutoSave();
                    },
                  ),
                );
              }).toList(),
            ),
            ExpansionTile(
              title: Text(
                'Commercial Terms & Conditions (${draft.terms.length} points)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              children: draft.terms.asMap().entries.map((entry) {
                final i = entry.key;
                final term = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: TextFormField(
                    initialValue: term,
                    decoration: InputDecoration(
                      labelText: 'Term ${i + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      draft.terms[i] = val;
                      _scheduleAutoSave();
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptanceAndBankSection(BoomBarrierProposalDraft draft) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_outlined, color: Color(0xFF1E3A5F)),
                const SizedBox(width: 8),
                const Text(
                  'Acceptance Letter & Bank Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            TextFormField(
              initialValue: draft.acceptanceP1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Acceptance Confirmation Paragraph',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                draft.acceptanceP1 = val;
                _scheduleAutoSave();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: draft.bankName,
                    decoration: const InputDecoration(
                      labelText: 'Bank Name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      draft.bankName = val;
                      _scheduleAutoSave();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: draft.bankAccountNumber,
                    decoration: const InputDecoration(
                      labelText: 'Account Number',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      draft.bankAccountNumber = val;
                      _scheduleAutoSave();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: draft.bankBranch,
                    decoration: const InputDecoration(
                      labelText: 'Bank Branch',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      draft.bankBranch = val;
                      _scheduleAutoSave();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: draft.bankIfsc,
                    decoration: const InputDecoration(
                      labelText: 'IFSC Code',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      draft.bankIfsc = val;
                      _scheduleAutoSave();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Draft'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF1E3A5F)),
                  foregroundColor: const Color(0xFF1E3A5F),
                ),
                onPressed: () => _saveDraft(showSnackbar: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text(
                  'Preview 5-Page PDF',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _openPdfPreview,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
