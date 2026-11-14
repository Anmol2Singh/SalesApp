// lib/features/quotation/services/quotation_pdf_launcher.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/customer.dart';
import '../../../core/models/product.dart';
import '../../../core/models/quotation.dart';
import '../../../core/providers/company_provider.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/global_click_guard.dart';
import '../../../core/widgets/pdf_preview_screen.dart';
import '../../../core/widgets/pdf_loading_dialog.dart';
import '../../quotation_generator/templates/qg_template_registry.dart';
import '../../quotation_generator/templates/boom_barrier_template.dart';
import '../../quotation_generator/data/catalog_repository.dart';
import '../../quotation_generator/models/boom_barrier_proposal_draft.dart';
import '../../quotation_generator/models/deal_quotation_item.dart';
import '../../quotation_generator/models/generator_company_settings.dart';
import '../../quotation_generator/models/qg_product_profile.dart';
import '../../quotation_generator/models/qg_proposal_draft.dart';
import '../../quotation_generator/providers/quotation_generator_providers.dart';
import '../../quotation_generator/services/qg_boom_barrier_drafts_service.dart';
import '../../quotation_generator/services/qg_drafts_service.dart';
import '../../quotation_generator/services/qg_model_specs_resolver.dart';
import '../../quotation_generator/ui/screens/boom_barrier_preview_screen.dart';
import '../../quotation_generator/ui/screens/quotation_preview_screen.dart';

class QuotationPdfLauncher {
  /// Displays the Single-Page vs Multi-Page dialog and launches the appropriate preview.
  static Future<void> showFormatSelectionAndLaunch({
    required BuildContext context,
    required WidgetRef ref,
    required Quotation quotation,
    Customer? customer,
    Product? product,
    String? leadOrDealTitle,
    String? salesmanName,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'View Quotation PDF',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Select format to generate & preview',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.pop(ctx),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: isDark ? Colors.white54 : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Card 1: Single Page Quotation
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    if (!GlobalClickGuard.canClick()) return;
                    Navigator.pop(ctx, 'single');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: Color(0xFF0284C7),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Single-Page Quotation',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Standard 1-page commercial offer & BOQ summary',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Card 2: Multi-Page Proposal
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    if (!GlobalClickGuard.canClick()) return;
                    Navigator.pop(ctx, 'multi');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withValues(alpha: isDark ? 0.25 : 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.auto_stories_outlined,
                            color: Color(0xFF2563EB),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Multi-Page Proposal',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'FULL SPECS',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF10B981),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Complete proposal with technical specs & terms',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Cancel Button
                SizedBox(
                  height: 38,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white60 : Colors.grey.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (choice == null) return;

    GlobalClickGuard.setBusy(true);

    if (choice == 'multi') {
      final dismissLoading = PdfLoadingDialog.show(
        context,
        title: 'Preparing Multi-Page Proposal...',
        message: 'Loading specifications, equipment details & terms.\nPlease wait...',
      );

      try {
        final prodName = leadOrDealTitle?.trim() ?? product?.name.trim() ?? '';
        final lineDescs = quotation.lineItems.map((e) => e.description).join(' ');
        final combinedProduct = '$prodName $lineDescs ${quotation.productId}'.toLowerCase();

        final template = QgTemplateRegistry.findTemplateForProduct(prodName.isNotEmpty ? prodName : lineDescs);
        final isBoomBarrier = template is BoomBarrierTemplate ||
            combinedProduct.contains('boom barrier') ||
            combinedProduct.contains('barrier');

        if (isBoomBarrier) {
          final prodKey = quotation.productId.isNotEmpty ? quotation.productId : 'Boom Barrier';
          final company = ref.read(companyForProductProvider(prodKey));
          final profile = QgProductProfile.defaultBoomBarrier().withAppCompany(company).copyWith(
            logoPath: (company.logoUrl != null && !company.logoUrl!.contains('logo.png'))
                ? company.logoUrl
                : 'assets/images/boom_barrier/sefdor_logo.png',
          );

          BoomBarrierProposalDraft? bbDraft = await QgBoomBarrierDraftsService.loadDraft(quotation.id);
          if (bbDraft == null) {
            final dealItem = DealQuotationItem(
              id: quotation.id,
              quotationNumber: quotation.quotationNumber,
              status: quotation.status.displayName,
              revision: quotation.revision,
              orderDate: quotation.orderDate ?? quotation.createdAt,
              createdAt: quotation.createdAt,
              updatedAt: quotation.updatedAt,
              customerName: quotation.customerName ?? customer?.companyName ?? 'Valued Customer',
              customerPhone: quotation.customerPhone ?? customer?.phone ?? '',
              customerAddress: quotation.billingAddress ?? customer?.address ?? '',
              customerGst: quotation.customerGstin ?? customer?.gstNumber,
              salesmanName: quotation.salesman ?? salesmanName ?? 'Insiya Sales',
              salesmanPhone: '',
              subtotal: quotation.subtotal,
              supplementarySubtotal: quotation.supplementarySubtotal,
              cgstAmount: quotation.cgstAmount,
              sgstAmount: quotation.sgstAmount,
              igstAmount: (quotation.cgstAmount + quotation.sgstAmount + quotation.igstAmount) > 0
                  ? quotation.igstAmount
                  : ((quotation.grandTotal > (quotation.subtotal + quotation.supplementarySubtotal))
                      ? (quotation.grandTotal - (quotation.subtotal + quotation.supplementarySubtotal))
                      : 0.0),
              grandTotal: quotation.grandTotal,
              cgstRate: quotation.cgstRate,
              sgstRate: quotation.sgstRate,
              igstRate: quotation.igstAmount > 0
                  ? (quotation.cgstRate + quotation.sgstRate)
                  : (quotation.cgstRate + quotation.sgstRate > 0 ? (quotation.cgstRate + quotation.sgstRate) : 18.0),
              lineItems: quotation.lineItems.map((e) => e.toJson()).toList(),
              supplementaryTerms: quotation.supplementaryTerms?.map((e) => e.toJson()).toList() ?? const [],
              paymentTerms: quotation.paymentTerms ?? const [],
              termsText: quotation.termsText,
              pipelineId: quotation.pipelineId,
              productId: quotation.productId,
              productName: prodName.isNotEmpty ? prodName : 'Boom Barrier',
              productSpecs: quotation.productSpecs,
              remarks: quotation.remarks,
            );
            bbDraft = BoomBarrierProposalDraft.fromDealQuotation(dealItem, profile);
          }

          dismissLoading();
          GlobalClickGuard.setBusy(false);
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => BoomBarrierPreviewScreen(
                  draft: bbDraft!,
                  profile: profile,
                ),
              ),
            );
          }
          return;
        }

        // Multi-page Heat Pump proposal
        await CatalogRepository.loadBundledModels();
        await CatalogRepository.loadBundledPoolModels();
        await CatalogRepository.loadBundledAllInOneModels();

        final company = ref.read(companyForProductProvider(quotation.productId));
        var settings = GeneratorCompanySettings.fromAppCompany(company);
        final moduleSettings = ref.read(quotationSettingsProvider).valueOrNull;
        if (moduleSettings != null && moduleSettings.models.isNotEmpty) {
          settings = settings.copyWith(
            models: moduleSettings.models,
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
        } else {
          try {
            final repoSettings = await ref.read(quotationRepositoryProvider).getSettings();
            settings = settings.copyWith(
              models: repoSettings.models.isNotEmpty ? repoSettings.models : null,
              allInOneModels: repoSettings.allInOneModels.isNotEmpty ? repoSettings.allInOneModels : null,
              poolModels: repoSettings.poolModels.isNotEmpty ? repoSettings.poolModels : null,
              defaultCoverImagePath: repoSettings.defaultCoverImagePath,
              defaultBannerImagePath: repoSettings.defaultBannerImagePath,
              stampImagePath: repoSettings.stampImagePath,
              domesticHpImagePath: repoSettings.domesticHpImagePath,
              allInOneImagePath: repoSettings.allInOneImagePath,
              allInOneWallImagePath: repoSettings.allInOneWallImagePath,
              swimmingPoolImagePath: repoSettings.swimmingPoolImagePath,
            );
          } catch (_) {}
        }

        if (settings.models.isEmpty) {
          final bundledHp = await CatalogRepository.loadBundledModels();
          settings = settings.copyWith(models: bundledHp);
        }

        final dealItem = DealQuotationItem(
          id: quotation.id,
          quotationNumber: quotation.quotationNumber,
          status: quotation.status.displayName,
          revision: quotation.revision,
          orderDate: quotation.orderDate ?? quotation.createdAt,
          createdAt: quotation.createdAt,
          updatedAt: quotation.updatedAt,
          customerName: quotation.customerName ?? customer?.companyName ?? 'Valued Customer',
          customerPhone: quotation.customerPhone ?? customer?.phone ?? '',
          customerAddress: quotation.billingAddress ?? customer?.address ?? '',
          customerGst: quotation.customerGstin ?? customer?.gstNumber,
          salesmanName: quotation.salesman ?? salesmanName ?? 'Insiya Sales',
          salesmanPhone: '',
          subtotal: quotation.subtotal,
          supplementarySubtotal: quotation.supplementarySubtotal,
          cgstAmount: quotation.cgstAmount,
          sgstAmount: quotation.sgstAmount,
          igstAmount: (quotation.cgstAmount + quotation.sgstAmount + quotation.igstAmount) > 0
              ? quotation.igstAmount
              : ((quotation.grandTotal > (quotation.subtotal + quotation.supplementarySubtotal))
                  ? (quotation.grandTotal - (quotation.subtotal + quotation.supplementarySubtotal))
                  : 0.0),
          grandTotal: quotation.grandTotal,
          cgstRate: quotation.cgstRate,
          sgstRate: quotation.sgstRate,
          igstRate: quotation.igstAmount > 0
              ? (quotation.cgstRate + quotation.sgstRate)
              : (quotation.cgstRate + quotation.sgstRate > 0 ? (quotation.cgstRate + quotation.sgstRate) : 18.0),
          lineItems: quotation.lineItems.map((e) => e.toJson()).toList(),
          supplementaryTerms: quotation.supplementaryTerms?.map((e) => e.toJson()).toList() ?? const [],
          paymentTerms: quotation.paymentTerms ?? const [],
          termsText: quotation.termsText,
          pipelineId: quotation.pipelineId,
          productId: quotation.productId,
          productName: prodName.isNotEmpty ? prodName : 'Heat Pump',
          productSpecs: quotation.productSpecs,
          remarks: quotation.remarks,
        );

        final freshDraft = QgProposalDraft.fromDealQuotation(dealItem, settings: settings);
        QgProposalDraft? loadedDraft = await QgDraftsService.loadDraft(quotation.id);

        QgProposalDraft draft;
        if (loadedDraft == null ||
            loadedDraft.hpModel != freshDraft.hpModel ||
            loadedDraft.hpKw != freshDraft.hpKw ||
            loadedDraft.hpSpecs['Heat Pump Model'] != freshDraft.hpModel ||
            (freshDraft.hpSpecs.isNotEmpty && loadedDraft.hpSpecs.isEmpty) ||
            loadedDraft.tankMaterial != freshDraft.tankMaterial ||
            loadedDraft.tankShellThickness != freshDraft.tankShellThickness ||
            loadedDraft.tankDishThickness != freshDraft.tankDishThickness ||
            loadedDraft.tankInsulation != freshDraft.tankInsulation ||
            loadedDraft.tankCapacityLitres != freshDraft.tankCapacityLitres ||
            loadedDraft.isTankPressurized != freshDraft.isTankPressurized ||
            quotation.updatedAt.isAfter(loadedDraft.quotationUpdatedAt)) {
          draft = freshDraft;
        } else {
          draft = loadedDraft;
          draft.status = dealItem.status;
          if (freshDraft.hpSpecs.isNotEmpty &&
              (draft.hpSpecs['Heat Pump Model'] != freshDraft.hpModel ||
                  draft.hpSpecs['Rated Heating Capacity'] != freshDraft.hpSpecs['Rated Heating Capacity'])) {
            draft.hpModel = freshDraft.hpModel;
            draft.hpKw = freshDraft.hpKw;
            draft.hpSpecs = Map<String, String>.from(freshDraft.hpSpecs);
            draft.specsCopiedFrom = freshDraft.specsCopiedFrom;
          }
          draft.tankMaterial = freshDraft.tankMaterial;
          draft.tankShellThickness = freshDraft.tankShellThickness;
          draft.tankDishThickness = freshDraft.tankDishThickness;
          draft.tankInsulation = freshDraft.tankInsulation;
          draft.tankCapacityLitres = freshDraft.tankCapacityLitres;
          draft.isTankPressurized = freshDraft.isTankPressurized;
          draft.hasTank = freshDraft.hasTank;
          draft.tankSpecs = Map<String, String>.from(freshDraft.tankSpecs);
          draft.remarks = freshDraft.remarks;

          // Always synchronize latest items, supplementary items, and financial values from the quotation:
          draft.items = freshDraft.items;
          draft.supplementaryItems = freshDraft.supplementaryItems;
          draft.subtotal = freshDraft.subtotal;
          draft.supplementarySubtotal = freshDraft.supplementarySubtotal;
          draft.cgstRate = freshDraft.cgstRate;
          draft.sgstRate = freshDraft.sgstRate;
          draft.igstRate = freshDraft.igstRate;
          draft.cgstAmount = freshDraft.cgstAmount;
          draft.sgstAmount = freshDraft.sgstAmount;
          draft.igstAmount = freshDraft.igstAmount;
          draft.grandTotal = freshDraft.grandTotal;
        }

        HeatPumpType hpType = HeatPumpType.domesticCommercial;
        if (draft.specCategoryId == 'all_in_one' || draft.specCategoryId == 'wall_mounted') {
          hpType = HeatPumpType.allInOne;
        } else if (draft.specCategoryId == 'pool') {
          hpType = HeatPumpType.swimmingPool;
        }

        final resSpecs = QgModelSpecsResolver.resolve(
          modelName: draft.hpModel,
          kw: draft.hpKw.toDouble(),
          isWallMounted: draft.specCategoryId == 'wall_mounted',
          heatPumpType: hpType,
          settings: settings,
        );
        if (resSpecs.specs.isNotEmpty) {
          draft.hpSpecs = Map<String, String>.from(resSpecs.specs);
          draft.hpModel = resSpecs.modelName;
          if (resSpecs.kw > 0) draft.hpKw = resSpecs.kw.round();
          draft.specsCopiedFrom = resSpecs.specsCopiedFrom;
        }
        await QgDraftsService.saveDraft(draft);

        final genQuot = draft.toGeneratorQuotation(settings: settings);

        dismissLoading();
        GlobalClickGuard.setBusy(false);
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => QuotationPreviewScreen(
                quotation: genQuot,
                settings: settings,
              ),
            ),
          );
        }
      } catch (e) {
        dismissLoading();
        GlobalClickGuard.setBusy(false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error opening multi-page quotation: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
      return;
    }

    // choice == 'single'
    final dismissLoading = PdfLoadingDialog.show(
      context,
      title: 'Generating Quotation PDF...',
      message: 'Preparing single-page commercial offer & BOQ summary.\nPlease wait...',
    );

    try {
      final supabase = ref.read(supabaseClientProvider);

      final templateRes = await supabase
          .from('pdf_templates')
          .select('template_config')
          .eq('document_type', 'quotation')
          .eq('is_active', true)
          .maybeSingle();

      final templateConfig = (templateRes != null && templateRes['template_config'] is Map)
          ? Map<String, dynamic>.from(templateRes['template_config'] as Map)
          : <String, dynamic>{};

      final effectiveCustomer = customer ??
          Customer(
            id: quotation.pipelineId.isNotEmpty ? quotation.pipelineId : quotation.id,
            companyName: quotation.customerName ?? 'Valued Customer',
            phone: quotation.customerPhone ?? '',
            address: quotation.billingAddress ?? '',
            createdBy: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      final effectiveProduct = product ??
          Product(
            id: quotation.productId.isNotEmpty ? quotation.productId : 'prod',
            name: leadOrDealTitle?.isNotEmpty == true
                ? leadOrDealTitle!
                : (quotation.lineItems.isNotEmpty ? quotation.lineItems.first.description : 'Product'),
            category: 'Solar',
            baseSpecs: const ProductBaseSpecs(quotationFields: [], boqRequiredFields: []),
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      final pdfBytes = await PdfService.generateQuotationPdf(
        quotation: quotation,
        customer: effectiveCustomer,
        product: effectiveProduct,
        templateConfig: templateConfig,
      );

      dismissLoading();
      GlobalClickGuard.setBusy(false);

      if (context.mounted) {
        final fileName = quotation.quotationNumber.isNotEmpty
            ? '${quotation.quotationNumber.replaceAll('/', '_')}.pdf'
            : 'Quotation_${quotation.id}.pdf';

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              fileName: fileName,
            ),
          ),
        );
      }
    } catch (e) {
      dismissLoading();
      GlobalClickGuard.setBusy(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate single-page quotation: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

