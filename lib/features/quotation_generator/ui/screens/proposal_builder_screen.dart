// lib/features/quotation_generator/ui/screens/proposal_builder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/providers/company_provider.dart';
import '../../data/deal_quotations_repository.dart';
import '../../data/qg_product_profiles_repository.dart';
import '../../models/deal_quotation_item.dart';
import '../../models/qg_product_profile.dart';
import '../../templates/qg_product_template.dart';
import '../../templates/qg_template_registry.dart';

/// Top-level dispatcher for Quotation Generator proposal builders.
/// Resolves the deal's product type via QgTemplateRegistry and routes to the
/// appropriate product template builder (Heat Pump or Boom Barrier).
class ProposalBuilderScreen extends ConsumerStatefulWidget {
  final String quotationId;
  final DealQuotationItem? initialDealQuotation;

  const ProposalBuilderScreen({
    super.key,
    required this.quotationId,
    this.initialDealQuotation,
  });

  @override
  ConsumerState<ProposalBuilderScreen> createState() => _ProposalBuilderScreenState();
}

class _ProposalBuilderScreenState extends ConsumerState<ProposalBuilderScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  DealQuotationItem? _dealQuotation;
  QgProductTemplate? _resolvedTemplate;
  QgProductProfile? _resolvedProfile;

  @override
  void initState() {
    super.initState();
    _resolveQuotationAndTemplate();
  }

  Future<void> _resolveQuotationAndTemplate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch latest deal quotation if not provided
      DealQuotationItem? dealItem = widget.initialDealQuotation;
      if (dealItem == null) {
        final supabase = ref.read(supabaseClientProvider);
        final repo = DealQuotationsRepository(supabase);
        dealItem = await repo.getDealQuotationById(widget.quotationId);
      }

      if (dealItem == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Quotation with ID "${widget.quotationId}" could not be found.';
          });
        }
        return;
      }

      // 2. Resolve template via QgTemplateRegistry
      final template = QgTemplateRegistry.findTemplateForProduct(dealItem.productName);
      if (template == null) {
        if (mounted) {
          setState(() {
            _dealQuotation = dealItem;
            _isLoading = false;
            _errorMessage =
                'No quotation template is currently configured for product "${dealItem!.productName}".\n\n'
                'Currently supported products: Heat Pump, Boom Barrier.';
          });
        }
        return;
      }

      // 3. Resolve product profile
      QgProductProfile profile;
      if (template.key == 'heat_pump_proposal') {
        profile = QgProductProfile.virtualHeatPump();
      } else {
        try {
          final supabase = ref.read(supabaseClientProvider);
          final profilesRepo = QgProductProfilesRepository(supabase);
          final fetched = await profilesRepo.getProfileByKey('boom_barrier');
          profile = fetched ?? QgProductProfile.defaultBoomBarrier();
        } catch (_) {
          profile = QgProductProfile.defaultBoomBarrier();
        }
      }

      // 4. Resolve company configured for this product/deal and override profile
      try {
        final assignedCompany = ref.read(companyForProductProvider(dealItem.productId));
        profile = profile.withAppCompany(assignedCompany);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _dealQuotation = dealItem;
          _resolvedTemplate = template;
          _resolvedProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load quotation: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Proposal...'),
          elevation: 0.5,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Resolving quotation product template...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _resolvedTemplate == null || _dealQuotation == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quotation Generator'),
          elevation: 0.5,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.error),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Unable to initialize proposal builder.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Deals'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Delegate to the resolved template's builder body
    return _resolvedTemplate!.buildBuilderBody(
      context,
      quotationId: widget.quotationId,
      dealOption: _dealQuotation!,
      profile: _resolvedProfile ?? QgProductProfile.defaultBoomBarrier(),
    );
  }
}
