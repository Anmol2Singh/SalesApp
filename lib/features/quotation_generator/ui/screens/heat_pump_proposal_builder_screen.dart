// lib/features/quotation_generator/ui/screens/proposal_builder_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../data/deal_quotations_repository.dart';
import '../../data/qg_proposals_repository.dart';
import '../../models/deal_quotation_item.dart';
import '../../models/qg_proposal_draft.dart';
import '../../services/qg_item_parser.dart';
import '../../services/qg_drafts_service.dart';
import '../../services/qg_catalog_service.dart';
import '../widgets/item_resolve_dialog.dart';
import '../../services/price_calculator.dart';
import '../../models/generator_company_settings.dart';
import '../../providers/quotation_generator_providers.dart';
import '../../../../core/providers/company_provider.dart';
import 'quotation_preview_screen.dart';

class HeatPumpProposalBuilderScreen extends ConsumerStatefulWidget {
  final String quotationId;
  final DealQuotationItem? initialDealQuotation;

  const HeatPumpProposalBuilderScreen({
    super.key,
    required this.quotationId,
    this.initialDealQuotation,
  });

  @override
  ConsumerState<HeatPumpProposalBuilderScreen> createState() => _HeatPumpProposalBuilderScreenState();
}

class _HeatPumpProposalBuilderScreenState extends ConsumerState<HeatPumpProposalBuilderScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  
  DealQuotationItem? _dealQuotation;
  QgProposalDraft? _draft;
  bool _isSaving = false;
  bool _isRestoredFromDraft = false;
  bool _sourceQuotationChanged = false;

  Timer? _autoSaveDebounce;

  @override
  void initState() {
    super.initState();
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
      final supabase = ref.read(supabaseClientProvider);
      final repo = DealQuotationsRepository(supabase);

      // 1. Fetch latest deal quotation if not provided
      DealQuotationItem? dealItem = widget.initialDealQuotation;
      if (dealItem == null) {
        dealItem = await repo.getDealQuotationById(widget.quotationId);
      }

      if (dealItem == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Quotation with ID "${widget.quotationId}" could not be found.';
        });
        return;
      }

      final pName = dealItem.productName.toLowerCase();
      final isEligible = pName.contains('heat pump') ||
          pName.contains('heatpump') ||
          pName.contains('all in one') ||
          pName.contains('all-in-one') ||
          pName.contains('aio') ||
          pName.contains('pool') ||
          pName.contains('iz-') ||
          pName.contains('izyheat');
      if (!isEligible) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Quotation Generator is restricted strictly to Heat Pump products.\nSelected product "${dealItem!.productName}" is not eligible.';
        });
        return;
      }

      _dealQuotation = dealItem;

      // 2. Check for local Hive draft
      final savedDraft = await QgDraftsService.loadDraft(widget.quotationId);

      if (savedDraft != null) {
        _draft = savedDraft;
        _isRestoredFromDraft = true;

        // Check if source quotation in CRM has been updated since the draft was created
        if (dealItem.updatedAt.isAfter(savedDraft.quotationUpdatedAt)) {
          _sourceQuotationChanged = true;
        }
      } else {
        // Initial draft from source deal quotation
        final settings = ref.read(quotationSettingsProvider).valueOrNull ?? await ref.read(quotationRepositoryProvider).getSettings();
        _draft = QgProposalDraft.fromDealQuotation(dealItem, settings: settings);
        _isRestoredFromDraft = false;

        // If Module Settings didn't have specs for this model, attempt catalog match
        if (_draft!.specsCopiedFrom == null || !_draft!.specsCopiedFrom!.startsWith('Module Settings')) {
          final catalogService = QgCatalogService(supabase);
          final specMatch = await catalogService.matchSpecifications(_draft!.hpKw);
          _draft!.hpSpecs = specMatch.specs;
          _draft!.specsCopiedFrom = specMatch.specsCopiedFrom;
        }

        // Save initial draft
        await QgDraftsService.saveDraft(_draft!);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading proposal: $e';
      });
    }
  }

  bool _hasUnsavedChanges = false;

  void _markChanged() {
    if (!_hasUnsavedChanges && mounted) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  void _triggerAutoSave() {
    // Auto-save disabled per requirement: mark changes as unsaved
    _markChanged();
  }

  Future<void> _saveDraft({bool showSnackbar = true}) async {
    if (_draft == null) return;
    setState(() => _isSaving = true);
    try {
      await QgDraftsService.saveDraft(_draft!);
      _hasUnsavedChanges = false;
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Heat Pump proposal draft saved successfully'),
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

  Future<bool> _handlePopScope() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Unsaved Changes'),
          ],
        ),
        content: const Text(
          'You have unsaved changes in this proposal. Do you want to save your changes before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save & Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _saveDraft(showSnackbar: false);
      return true;
    } else if (result == 'discard') {
      return true;
    }
    return false;
  }

  Future<void> _resetToDealQuotation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Proposal Draft?'),
        content: const Text(
          'This will discard all local modifications made on this device and re-initialize the proposal directly from the deal quotation in CRM.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset to Deal Quotation'),
          ),
        ],
      ),
    );

    if (confirm == true && _dealQuotation != null) {
      await QgDraftsService.deleteDraft(widget.quotationId);
      final supabase = ref.read(supabaseClientProvider);
      final catalogService = QgCatalogService(supabase);

      final settings = ref.read(quotationSettingsProvider).valueOrNull ?? await ref.read(quotationRepositoryProvider).getSettings();
      final freshDraft = QgProposalDraft.fromDealQuotation(_dealQuotation!, settings: settings);
      if (freshDraft.specsCopiedFrom == null || !freshDraft.specsCopiedFrom!.startsWith('Module Settings')) {
        final specMatch = await catalogService.matchSpecifications(freshDraft.hpKw);
        freshDraft.hpSpecs = specMatch.specs;
        freshDraft.specsCopiedFrom = specMatch.specsCopiedFrom;
      }

      await QgDraftsService.saveDraft(freshDraft);

      setState(() {
        _draft = freshDraft;
        _isRestoredFromDraft = false;
        _sourceQuotationChanged = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proposal reset to CRM deal quotation values.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proposal Builder')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading deal quotation & specifications...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _draft == null || _dealQuotation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proposal Builder')),
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
    final isConfirmed = draft.isConfirmed;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _handlePopScope();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Proposal Builder • ${draft.quotationNumber}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                draft.customerName,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
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
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              )
            else if (_hasUnsavedChanges)
              TextButton.icon(
                icon: const Icon(Icons.save_outlined, size: 16, color: Colors.white),
                label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _saveDraft(showSnackbar: true),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done_outlined, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        _isRestoredFromDraft ? 'Draft Restored' : 'Saved',
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
        bottomNavigationBar: _buildBottomActionBar(draft, isConfirmed),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Pre-approval Banner or CRM Changed Banner
            _buildStatusBanners(draft, isConfirmed),
            const SizedBox(height: 16),

            // Section 1: Customer & Sales Block
            _buildCustomerSalesSection(draft),
            const SizedBox(height: 16),

            // Section 2: Items & Specification Mapping
            _buildItemsSection(draft),
            const SizedBox(height: 16),

            // Section 3: Supplementary Items
            _buildSupplementarySection(draft),
            const SizedBox(height: 16),

            // Section 4: Payment Terms & Totals
            _buildPaymentAndTotalsSection(draft),
            const SizedBox(height: 16),

            // Section 5: Technical Specifications
            _buildSpecificationsSection(draft),
            const SizedBox(height: 16),

            // Section 6: Image Overrides
            _buildImagesSection(draft),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanners(QgProposalDraft draft, bool isConfirmed) {
    return Column(
      children: [
        if (!isConfirmed)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withAlpha(120)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock, color: AppColors.warning, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pending Approval: Changes stay on this device',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Quotation status is "${draft.status.toUpperCase()}". PDF previews carry a "DRAFT - NOT APPROVED" watermark. Finalize will be enabled once confirmed by Admin/Sales Head.',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withAlpha(120)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_outlined, color: AppColors.success, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quotation Approved & Confirmed',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ready to generate final proposal PDF and publish to quotation repository.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (_sourceQuotationChanged)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withAlpha(120)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync_problem, color: AppColors.error, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Source quotation was updated in CRM. Tap "Reset to Deal Quotation" if you wish to synchronize new changes.',
                    style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _resetToDealQuotation,
                  child: const Text('Reset', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── SECTION 1: CUSTOMER & SALES ──────────────────────────────────────────

  Widget _buildCustomerSalesSection(QgProposalDraft draft) {
    return _CollapsibleCard(
      title: 'Customer & Sales Details',
      subtitle: '${draft.customerSalutation} ${draft.customerName} • Sales: ${draft.salesmanName}',
      icon: Icons.person_outline,
      initiallyExpanded: true,
      children: [
        Row(
          children: [
            SizedBox(
              width: 100,
              child: DropdownButtonFormField<String>(
                value: draft.customerSalutation,
                decoration: const InputDecoration(labelText: 'Salutation', border: OutlineInputBorder()),
                items: ['M/s.', 'Mr.', 'Ms.', 'Mrs.'].map((s) {
                  return DropdownMenuItem(value: s, child: Text(s));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => draft.customerSalutation = val);
                    _triggerAutoSave();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: draft.customerName,
                decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder()),
                onChanged: (val) {
                  draft.customerName = val;
                  _triggerAutoSave();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: draft.customerAddress,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Billing Address', border: OutlineInputBorder()),
          onChanged: (val) {
            draft.customerAddress = val;
            _triggerAutoSave();
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: draft.customerPhone,
                decoration: const InputDecoration(labelText: 'Customer Mobile', border: OutlineInputBorder()),
                onChanged: (val) {
                  draft.customerPhone = val;
                  _triggerAutoSave();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: draft.customerGst ?? '',
                decoration: const InputDecoration(labelText: 'GST Number (Optional)', border: OutlineInputBorder()),
                onChanged: (val) {
                  draft.customerGst = val.trim().isEmpty ? null : val.trim();
                  _triggerAutoSave();
                },
              ),
            ),
          ],
        ),
        const Divider(height: 28),
        Row(
          children: [
            SizedBox(
              width: 100,
              child: DropdownButtonFormField<String>(
                value: draft.salesmanSalutation,
                decoration: const InputDecoration(labelText: 'Salutation', border: OutlineInputBorder()),
                items: ['Mr.', 'Ms.', 'Mrs.'].map((s) {
                  return DropdownMenuItem(value: s, child: Text(s));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => draft.salesmanSalutation = val);
                    _triggerAutoSave();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: draft.salesmanName,
                decoration: const InputDecoration(labelText: 'Salesperson Name', border: OutlineInputBorder()),
                onChanged: (val) {
                  draft.salesmanName = val;
                  _triggerAutoSave();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: draft.salesmanPhone,
                decoration: const InputDecoration(labelText: 'Salesperson Mobile', border: OutlineInputBorder()),
                onChanged: (val) {
                  draft.salesmanPhone = val;
                  _triggerAutoSave();
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
                initialValue: draft.quoteDate,
                decoration: const InputDecoration(
                  labelText: 'Quote Date (dd/MM/yyyy)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                onChanged: (val) {
                  draft.quoteDate = val;
                  _triggerAutoSave();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: draft.refNumber,
                decoration: const InputDecoration(
                  labelText: 'Quotation Ref Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag, size: 18),
                ),
                onChanged: (val) {
                  draft.refNumber = val;
                  _triggerAutoSave();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── SECTION 2: ITEMS & RESOLVE ──────────────────────────────────────────

  Widget _buildItemsSection(QgProposalDraft draft) {
    return _CollapsibleCard(
      title: 'Line Items & Specification Mapping',
      subtitle: '${draft.items.length} items • Derived Model: ${draft.hpModel}',
      icon: Icons.list_alt,
      initiallyExpanded: true,
      children: [
        for (int i = 0; i < draft.items.length; i++) ...[
          _buildItemTile(draft, i),
          if (i < draft.items.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildItemTile(QgProposalDraft draft, int index) {
    final item = draft.items[index];
    final isResolved = item.status == ItemResolveStatus.resolved;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isResolved ? Colors.white : AppColors.warning.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isResolved ? AppColors.border : AppColors.warning.withAlpha(120),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.rawDescription,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isResolved ? AppColors.success.withAlpha(20) : AppColors.warning.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isResolved ? item.type.name.toUpperCase() : 'UNMAPPED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isResolved ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('Qty: ${item.qty}  •  Rate: ₹${item.rate.toStringAsFixed(2)}  •  Amount: ₹${item.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.tune, size: 14),
                label: const Text('Resolve / Edit', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  final updated = await ItemResolveDialog.show(context, item: item);
                  if (updated != null) {
                    setState(() {
                      draft.items[index] = updated;
                      _recalculateHpAndTank(draft);
                    });
                    _triggerAutoSave();
                  }
                },
              ),
            ],
          ),
          if (item.hpModel != null)
            Text(
              'Model: ${item.hpModel} (${item.hpKw} kW)',
              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          if (item.unmappedReason != null && !isResolved)
            Text(
              'Reason: ${item.unmappedReason}',
              style: const TextStyle(fontSize: 11, color: AppColors.warning),
            ),
        ],
      ),
    );
  }

  void _recalculateHpAndTank(QgProposalDraft draft) {
    int highestKw = 8;
    String derivedHpModel = 'IZ-8C';
    bool foundHp = false;

    for (final it in draft.items) {
      if (it.type == ParsedItemType.heatPump && it.hpKw != null) {
        foundHp = true;
        if (it.hpKw! > highestKw || !foundHp) {
          highestKw = it.hpKw!;
          derivedHpModel = it.hpModel ?? 'IZ-${it.hpKw}C';
        }
      }
    }

    draft.hpKw = highestKw;
    draft.hpModel = derivedHpModel;
    draft.specCategoryId = QgCatalogService.resolveCategory(hpKw: highestKw).id;

    // Check tank lines
    for (final it in draft.items) {
      if (it.type == ParsedItemType.tank) {
        draft.hasTank = true;
        if (it.tankCapacityLitres != null) draft.tankCapacityLitres = it.tankCapacityLitres!;
        if (it.tankMaterial != null) draft.tankMaterial = it.tankMaterial!;
        draft.isTankPressurized = it.isPressurized;
        break;
      }
    }
  }

  // ─── SECTION 3: SUPPLEMENTARY ITEMS ──────────────────────────────────────

  Widget _buildSupplementarySection(QgProposalDraft draft) {
    return _CollapsibleCard(
      title: 'Supplementary Terms & Charges',
      subtitle: '${draft.supplementaryItems.length} items • Subtotal: ${PriceCalculator.formatIndianCurrency(draft.supplementarySubtotal.round())}',
      icon: Icons.add_shopping_cart,
      children: [
        if (draft.supplementaryItems.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No supplementary charges attached to this deal quotation.'),
          )
        else
          for (int i = 0; i < draft.supplementaryItems.length; i++) ...[
            _buildSupplementaryRow(draft, i),
            if (i < draft.supplementaryItems.length - 1) const Divider(),
          ],
      ],
    );
  }

  Widget _buildSupplementaryRow(QgProposalDraft draft, int index) {
    final item = draft.supplementaryItems[index];
    final isIncluded = (item['type']?.toString().toLowerCase() ?? 'included') == 'included';
    final name = item['name']?.toString() ?? 'Item';
    final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
    final qty = (item['qty'] as num?)?.toInt() ?? (isIncluded ? 0 : 1);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                height: 38,
                child: SegmentedButton<String>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(value: 'Included', label: Text('Included', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: 'Extra', label: Text('Extra', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {isIncluded ? 'Included' : 'Extra'},
                  onSelectionChanged: (set) {
                    setState(() {
                      final chosen = set.first;
                      draft.supplementaryItems[index]['type'] = chosen;
                      if (chosen == 'Included') {
                        draft.supplementaryItems[index]['rate'] = 0.0;
                        if (((draft.supplementaryItems[index]['qty'] as num?)?.toInt() ?? 0) <= 0) {
                          draft.supplementaryItems[index]['qty'] = 1;
                        }
                      } else {
                        if (((draft.supplementaryItems[index]['qty'] as num?)?.toInt() ?? 0) <= 0) {
                          draft.supplementaryItems[index]['qty'] = 1;
                        }
                      }
                      _recalculateSupplementarySubtotal(draft);
                    });
                    _triggerAutoSave();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Qty field
              SizedBox(
                width: 60,
                height: 38,
                child: TextFormField(
                  key: ValueKey('supp_qty_${index}_$isIncluded'),
                  initialValue: qty > 0 ? qty.toString() : '1',
                  enabled: true,
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final newQty = int.tryParse(val) ?? 1;
                    draft.supplementaryItems[index]['qty'] = newQty;
                    _recalculateSupplementarySubtotal(draft);
                    _triggerAutoSave();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Rate field (Disabled when Included)
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextFormField(
                    key: ValueKey('supp_rate_${index}_$isIncluded'),
                    initialValue: isIncluded ? '' : (rate > 0 ? rate.toStringAsFixed(0) : ''),
                    enabled: !isIncluded,
                    decoration: InputDecoration(
                      labelText: isIncluded ? 'Rate (Incl.)' : 'Rate (₹)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final newRate = double.tryParse(val) ?? 0.0;
                      draft.supplementaryItems[index]['rate'] = newRate;
                      _recalculateSupplementarySubtotal(draft);
                      _triggerAutoSave();
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _recalculateSupplementarySubtotal(QgProposalDraft draft) {
    double sum = 0.0;
    for (final s in draft.supplementaryItems) {
      final type = s['type']?.toString().toLowerCase() ?? 'included';
      if (type == 'extra') {
        final rate = (s['rate'] as num?)?.toDouble() ?? 0.0;
        final qty = (s['qty'] as num?)?.toInt() ?? 1;
        sum += rate * qty;
      }
    }
    draft.supplementarySubtotal = sum;
  }

  // ─── SECTION 4: PAYMENT TERMS & TOTALS ───────────────────────────────────

  Widget _buildPaymentAndTotalsSection(QgProposalDraft draft) {
    final grandTotalFormatted = PriceCalculator.formatIndianCurrency(draft.grandTotal.round());
    return _CollapsibleCard(
      title: 'Payment Terms & Totals Reconciliation',
      subtitle: 'Grand Total: $grandTotalFormatted',
      icon: Icons.receipt_long,
      children: [
        TextFormField(
          initialValue: draft.paymentTermsText.replaceAllMapped(RegExp(r'(\d+)\.\d+%'), (m) => '${m[1]}%'),
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Payment Terms Sentence (Annexure III)',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) {
            draft.paymentTermsText = val;
            _triggerAutoSave();
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildTotalRow('Base Line Items Subtotal', PriceCalculator.formatIndianCurrency(draft.subtotal.round())),
              _buildTotalRow('Supplementary Charges (Extra)', PriceCalculator.formatIndianCurrency(draft.supplementarySubtotal.round())),
              const Divider(),
              _buildTotalRow('Calculated Printed Subtotal', PriceCalculator.formatIndianCurrency(draft.calculatedSubTotal.round()), isBold: true),
              _buildTotalRow('CGST (${draft.cgstRate.round()}%)', PriceCalculator.formatIndianCurrency(draft.cgstAmount.round())),
              _buildTotalRow('SGST (${draft.sgstRate.round()}%)', PriceCalculator.formatIndianCurrency(draft.sgstAmount.round())),
              if (draft.igstAmount > 0)
                _buildTotalRow('IGST (${draft.igstRate.round()}%)', PriceCalculator.formatIndianCurrency(draft.igstAmount.round())),
              const Divider(),
              _buildTotalRow('Calculated Grand Total', PriceCalculator.formatIndianCurrency(draft.calculatedGrandTotal.round()), isBold: true, color: AppColors.primary),
              _buildTotalRow('CRM Deal Grand Total', grandTotalFormatted, isBold: true),
            ],
          ),
        ),
        if (draft.hasReconciliationMismatch) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.warning.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reconciliation notice: Printed sum differs by ${PriceCalculator.formatIndianCurrency((draft.calculatedGrandTotal - draft.grandTotal).abs().round())} from CRM deal quotation.',
                    style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  // ─── SECTION 5: TECHNICAL SPECIFICATIONS ─────────────────────────────────

  Widget _buildSpecificationsSection(QgProposalDraft draft) {
    return _CollapsibleCard(
      title: 'Technical Specifications',
      subtitle: '${draft.hpModel} (${draft.hpKw} kW) • Category: ${draft.specCategoryId}',
      icon: Icons.precision_manufacturing,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: '${draft.hpKw}',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'HP kW (Integer Only)',
                  border: OutlineInputBorder(),
                  suffixText: 'kW',
                ),
                onChanged: (val) async {
                  final newKw = int.tryParse(val);
                  if (newKw != null && newKw > 0) {
                    draft.hpKw = newKw;
                    draft.hpModel = 'IZ-${newKw}C';
                    final supabase = ref.read(supabaseClientProvider);
                    final catalogService = QgCatalogService(supabase);
                    final specMatch = await catalogService.matchSpecifications(newKw);
                    setState(() {
                      draft.hpSpecs = specMatch.specs;
                      draft.specsCopiedFrom = specMatch.specsCopiedFrom;
                    });
                    _triggerAutoSave();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: draft.hpModel,
                decoration: const InputDecoration(
                  labelText: 'Model Number (Auto: IZ-{kW}C)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  draft.hpModel = val.trim();
                  _triggerAutoSave();
                },
              ),
            ),
          ],
        ),
        if (draft.specsCopiedFrom != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.warning.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Specs copied from catalog fallback: ${draft.specsCopiedFrom}. All row values are editable below.',
                    style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Heat Pump 13-Row Specification Table (Annexure II)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        for (final entry in draft.hpSpecs.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(entry.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: entry.value,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    onChanged: (newVal) {
                      draft.hpSpecs[entry.key] = newVal;
                      _triggerAutoSave();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        const Divider(height: 28),

        // Tank Specifications (if applicable)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include Hot Water Storage Tank Specification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          value: draft.hasTank,
          onChanged: (val) {
            setState(() => draft.hasTank = val);
            _triggerAutoSave();
          },
        ),
        if (draft.hasTank) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: draft.tankMaterial,
                  decoration: const InputDecoration(labelText: 'Tank Material', border: OutlineInputBorder()),
                  items: ['GI', 'MS', 'Enamel', 'SS'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        draft.tankMaterial = val;
                        draft.warrantyTankYears = val == 'Enamel' ? 15 : 5;
                      });
                      _triggerAutoSave();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: draft.tankInsulation,
                  decoration: const InputDecoration(labelText: 'Insulation', border: OutlineInputBorder()),
                  items: ['Puff', 'Rockwool', 'Custom'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => draft.tankInsulation = val);
                      _triggerAutoSave();
                    }
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
                  initialValue: '${draft.tankCapacityLitres}',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tank Capacity (L)', border: OutlineInputBorder()),
                  onChanged: (val) {
                    final lit = int.tryParse(val);
                    if (lit != null) {
                      draft.tankCapacityLitres = lit;
                      _triggerAutoSave();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pressurized (6/9 bar)', style: TextStyle(fontSize: 12)),
                  value: draft.isTankPressurized,
                  onChanged: (val) {
                    setState(() => draft.isTankPressurized = val);
                    _triggerAutoSave();
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ─── SECTION 6: IMAGES & OVERRIDES ───────────────────────────────────────

  Widget _buildImagesSection(QgProposalDraft draft) {
    return _CollapsibleCard(
      title: 'Branding & Product Images',
      subtitle: 'Cover, Stamp, Banner & Category Product Image',
      icon: Icons.photo_library_outlined,
      children: [
        _buildImageOverrideRow(
          label: 'Quotation Cover Image',
          currentPath: draft.coverImagePath ?? 'assets/images/cover_final.png',
          onReset: () {
            setState(() => draft.coverImagePath = null);
            _triggerAutoSave();
          },
        ),
        const Divider(),
        _buildImageOverrideRow(
          label: 'Company Stamp / Signature',
          currentPath: draft.stampImagePath ?? 'assets/images/stamp_final.png',
          onReset: () {
            setState(() => draft.stampImagePath = null);
            _triggerAutoSave();
          },
        ),
        const Divider(),
        _buildImageOverrideRow(
          label: 'Product Showcase Banner',
          currentPath: draft.bannerImagePath ?? 'assets/images/insiya_banner.png',
          onReset: () {
            setState(() => draft.bannerImagePath = null);
            _triggerAutoSave();
          },
        ),
      ],
    );
  }

  Widget _buildImageOverrideRow({
    required String label,
    required String currentPath,
    required VoidCallback onReset,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(currentPath, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: onReset,
            child: const Text('Reset to Default', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM ACTION BAR ───────────────────────────────────────────────────

  Widget _buildBottomActionBar(QgProposalDraft draft, bool isConfirmed) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(isConfirmed ? 'Preview PDF' : 'Preview (Draft)'),
                onPressed: () {
                  final company = ref.read(companyForProductProvider('heat_pump'));
                  final moduleSettings = ref.read(quotationSettingsProvider).valueOrNull;
                  var companySettings = GeneratorCompanySettings.fromAppCompany(company);
                  if (moduleSettings != null) {
                    companySettings = companySettings.copyWith(
                      models: moduleSettings.models.isNotEmpty ? moduleSettings.models : null,
                      allInOneModels: moduleSettings.allInOneModels.isNotEmpty ? moduleSettings.allInOneModels : null,
                      poolModels: moduleSettings.poolModels.isNotEmpty ? moduleSettings.poolModels : null,
                      defaultCoverImagePath: moduleSettings.defaultCoverImagePath,
                      defaultBannerImagePath: moduleSettings.defaultBannerImagePath,
                      stampImagePath: moduleSettings.stampImagePath,
                      domesticHpImagePath: moduleSettings.domesticHpImagePath,
                      allInOneImagePath: moduleSettings.allInOneImagePath,
                      allInOneWallImagePath: moduleSettings.allInOneWallImagePath,
                      swimmingPoolImagePath: moduleSettings.swimmingPoolImagePath,
                    );
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => QuotationPreviewScreen(
                        quotation: draft.toGeneratorQuotation(settings: companySettings),
                        settings: companySettings,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConfirmed ? AppColors.primary : Colors.grey,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Finalize Proposal'),
                onPressed: isConfirmed
                    ? () => _handleFinalize(draft)
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.warning,
                            content: Text(
                              'Approval Gating: Quotation status is "${draft.status.toUpperCase()}". Must be confirmed by Admin/Sales Head before finalizing.',
                            ),
                          ),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFinalize(QgProposalDraft draft) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalize Proposal?'),
        content: Text(
          'This will snapshot proposal details for quotation "${draft.quotationNumber}" and store the finalized proposal version into Supabase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Finalize'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final supabase = ref.read(supabaseClientProvider);
        final repo = QgProposalsRepository(supabase);

        await repo.finalizeProposal(
          quotationId: draft.quotationId,
          payload: draft.toJson(),
          pdfPath: 'proposals/${draft.quotationId}/${draft.quotationNumber.replaceAll('/', '_')}.pdf',
          refNo: draft.refNumber,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('✓ Proposal finalized and snapshot stored successfully!'),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Finalization failed: $e'),
            ),
          );
        }
      }
    }
  }
}

class _CollapsibleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _CollapsibleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withAlpha(20),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          childrenPadding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: children,
        ),
      ),
    );
  }
}
