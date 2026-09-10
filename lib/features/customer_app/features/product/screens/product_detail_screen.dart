import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../store/screens/request_product_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/data/models/data_models.dart';
import 'package:salesapp/features/customer_app/data/providers/app_providers.dart';
import 'package:salesapp/features/customer_app/shared/widgets/glass_card.dart';
import 'package:salesapp/features/customer_app/shared/widgets/gradient_button.dart';
import 'package:salesapp/features/customer_app/shared/widgets/image_with_fallback.dart';
import 'package:salesapp/features/customer_app/shared/widgets/status_chip.dart';
import 'package:salesapp/features/customer_app/shared/widgets/toast_service.dart';
import 'package:salesapp/features/customer_app/features/service_request/screens/service_booking_flow.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  bool _isRenewing = false;

  void _openBookingFlow(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ServiceBookingFlow(preselectedProductId: widget.productId),
    );
  }

  Future<void> _renewAmc(Product product) async {
    setState(() => _isRenewing = true);
    try {
      await ref.read(customerRepositoryProvider).renewAmc(product.productId);
      ref.invalidate(productsProvider); // Refresh list
      if (mounted) {
        ToastService.show(
          context,
          'AMC Contract Renewed Successfully!',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(context, e.toString(), type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isRenewing = false);
      }
    }
  }

  Future<void> _requestAmc(Product product) async {
    setState(() => _isRenewing = true);
    try {
      final isCatalogProduct = product.productId.startsWith('adv_') || !product.productId.startsWith('req_') && product.serialNumber == product.productId;
      await ref.read(customerRepositoryProvider).requestAmcService(
        productId: product.productId,
        pipelineId: isCatalogProduct ? null : product.productId,
      );
      if (mounted) {
        ToastService.show(
          context,
          '✓ AMC Service request submitted successfully! We will contact you soon.',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(context, e.toString(), type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isRenewing = false);
      }
    }
  }  @override
  Widget build(BuildContext context) {
    final purchasedAsync = ref.watch(productsProvider);
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgPrimary : AppColors.bgPrimaryLight,
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return const Center(child: Text('Product not found'));
          }
          final isPurchased = purchasedAsync.value?.any((p) => p.productId == product.productId) ?? false;

          // Beautiful network URLs based on category if assets don't load
          String getCategoryImageUrl(String category) {
            switch (category.toLowerCase()) {
              case 'boiler':
                return 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=800&auto=format&fit=crop';
              case 'heat_pump':
                return 'https://images.unsplash.com/photo-1621905252507-b354bc25edac?w=800&auto=format&fit=crop';
              case 'thermostat':
                return 'https://images.unsplash.com/photo-1545259742-b4fd8fea67e4?w=800&auto=format&fit=crop';
              default:
                return 'https://images.unsplash.com/photo-1605647540924-852290f6b0d5?w=800&auto=format&fit=crop';
            }
          }

          final imageUrl = product.imageUrl.startsWith('assets/')
              ? getCategoryImageUrl(product.category)
              : product.imageUrl;

          final isAmcExpired = product.amcStatus == 'expired';
          final isWarrantyExpired = product.warrantyExpiryDate.isBefore(
            DateTime.now(),
          );

          final Widget imageSection = Stack(
            children: [
              Hero(
                            tag: 'product_image_${product.productId}',
                            child: SizedBox(
                              height: 260,
                              width: double.infinity,
                              child: ImageWithFallback(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // Blur & Darken Overlay on Image
                          Positioned.fill(
                            child: Container(color: Colors.black.withOpacity(0.45)),
                          ),
                          // Back arrow overlaid
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 10,
                            left: 16,
                            child: ClipOval(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: Container(
                                  color: Colors.black.withOpacity(0.3),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () => context.pop(),
                                  ),
                                ),
                              ),
                            ),
                          ),
            ],
          );

          final Widget detailsSection = Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Identity Block
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.productName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayLarge
                                            ?.copyWith(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isPurchased
                                            ? 'Model: ${product.modelNumber} • S/N: ${product.serialNumber}'
                                            : 'Model: ${product.modelNumber}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(product.category),
                                    color: AppColors.accent,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Details Grid (2-column layout)
                            Text(
                              'Specifications & Coverages',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 1.6,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              children: [
                                if (isPurchased) ...[
                                  _buildGridCard(
                                    'Purchased Date',
                                    DateFormat('dd MMM yyyy').format(product.purchasedDate),
                                  ),
                                  _buildGridCard(
                                    'Seller / Dealer',
                                    product.sellerName,
                                  ),
                                ] else ...[
                                  _buildGridCard(
                                    'Availability',
                                    'In Stock',
                                  ),
                                  _buildGridCard(
                                    'Manufacturer',
                                    'IZYHEAT Solar',
                                  ),
                                ],
                                _buildGridCard(
                                  'Warranty Status',
                                  isPurchased ? (isWarrantyExpired ? 'Expired' : 'Active') : '1 Year Standard',
                                  chip: StatusChip(
                                    label: isPurchased ? (isWarrantyExpired ? 'Expired' : 'Active ✓') : 'Standard ✓',
                                    status: isPurchased ? (isWarrantyExpired ? 'danger' : 'success') : 'success',
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  ),
                                ),
                                if (isPurchased) ...[
                                  _buildGridCard(
                                    'Warranty Start',
                                    DateFormat('dd MMM yyyy').format(product.warrantyStartDate ?? product.purchasedDate),
                                  ),
                                  _buildGridCard(
                                    'Warranty End',
                                    DateFormat('dd MMM yyyy').format(product.warrantyExpiryDate),
                                  ),
                                ],
                                if (isPurchased)
                                  _buildGridCard(
                                    'AMC Contract',
                                    product.amcStatus.toUpperCase(),
                                    chip: StatusChip(
                                      label: product.amcStatus.toUpperCase(),
                                      status: product.amcStatus == 'active'
                                          ? 'success'
                                          : (product.amcStatus == 'expired' ? 'danger' : 'info'),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    ),
                                  )
                                else
                                  _buildGridCard(
                                    'AMC Support',
                                    'Available',
                                    chip: const StatusChip(
                                      label: 'AVAILABLE',
                                      status: 'success',
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    ),
                                  ),
                                _buildGridCard(
                                  isPurchased ? 'Amount Paid' : 'Base Price',
                                  'INR ${product.amountPaid.toStringAsFixed(2)}',
                                ),
                                if (isPurchased && product.amcExpiryDate != null)
                                  _buildGridCard(
                                    'AMC Expires',
                                    DateFormat('dd MMM yyyy').format(product.amcExpiryDate!),
                                  ),
                                if (isPurchased && product.amcStatus != 'none') ...[
                                  _buildGridCard(
                                    'AMC Visits Included',
                                    '${product.numberOfVisitsIncluded} Visits',
                                  ),
                                  _buildGridCard(
                                    'AMC Visits Done',
                                    '${product.numberOfVisitsCompleted} Visits',
                                  ),
                                  _buildGridCard(
                                    'AMC Visits Remaining',
                                    '${(product.numberOfVisitsIncluded - product.numberOfVisitsCompleted).clamp(0, 999)} Visits',
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 24),

                            if (isPurchased) ...[
                              const SizedBox(height: 24),

                              // Address
                              Text(
                                'Installation Location',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              GlassCard(
                                padding: const EdgeInsets.all(16),
                                borderRadius: 16,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        product.installationAddress != null && product.installationAddress!.isNotEmpty
                                            ? product.installationAddress!
                                            : 'Address recorded during order / installation',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (isPurchased && (product.amcVisits.isNotEmpty || product.amcStatus == 'active')) ...[
                                const SizedBox(height: 24),
                                Text(
                                  'Scheduled AMC Visits',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                if (product.amcVisits.isEmpty)
                                  GlassCard(
                                    padding: const EdgeInsets.all(16),
                                    borderRadius: 16,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.event_available, color: AppColors.accent),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            '${product.numberOfVisitsIncluded} annual visits included under active AMC contract. Dates will be scheduled by our service coordinator.',
                                            style: TextStyle(
                                              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ...product.amcVisits.map((visit) {
                                    final vNum = visit['visit_number'] ?? 1;
                                    final status = (visit['status'] as String? ?? 'scheduled').toUpperCase();
                                    final schedStr = visit['scheduled_date'] as String?;
                                    final compStr = visit['completed_date'] as String?;
                                    final date = (compStr != null ? DateTime.tryParse(compStr) : null) ??
                                        (schedStr != null ? DateTime.tryParse(schedStr) : null);
                                    final isCompleted = status == 'COMPLETED';

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: GlassCard(
                                        padding: const EdgeInsets.all(14),
                                        borderRadius: 14,
                                        child: Row(
                                          children: [
                                            Icon(
                                              isCompleted ? Icons.check_circle : Icons.calendar_today,
                                              color: isCompleted ? AppColors.success : AppColors.accent,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'AMC Visit #$vNum',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13.5,
                                                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                                    ),
                                                  ),
                                                  if (date != null)
                                                    Text(
                                                      '${isCompleted ? "Completed on" : "Scheduled for"} ${DateFormat("dd MMM yyyy").format(date)}',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: (isCompleted ? AppColors.success : AppColors.accent).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                status,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isCompleted ? AppColors.success : AppColors.accent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],

                              const SizedBox(height: 24),

                              // AMC Renewal Banner
                              if (isAmcExpired)
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.warning.withOpacity(0.1),
                                        AppColors.danger.withOpacity(0.1),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.warning.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            color: AppColors.warning,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'AMC Contract Expired',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  color: AppColors.warning,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Your Annual Maintenance Contract has expired. Renew today to secure priority bookings, free breakdown repair calls, and preventative upkeep.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      GradientButton(
                                        label: 'Renew AMC Now',
                                        isLoading: _isRenewing,
                                        onTap: () => _renewAmc(product),
                                      ),
                                    ],
                                  ),
                                ),
                            ] else if (isPurchased && product.amcStatus == 'none') ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withOpacity(0.1),
                                      AppColors.accent.withOpacity(0.1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          color: AppColors.accent,
                                          size: 24,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Annual Maintenance Program',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Get 24/7 priority support, free annual cleaning, parts replacement discount, and guaranteed service turnaround within 24 hours.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    GradientButton(
                                      label: 'Avail AMC Now',
                                      isLoading: _isRenewing,
                                      onTap: () => _renewAmc(product), // Avail AMC uses same method as renew for now
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (!isPurchased) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withOpacity(0.1),
                                      AppColors.accent.withOpacity(0.1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          color: AppColors.accent,
                                          size: 24,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Annual Maintenance Program',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Get 24/7 priority support, free annual cleaning, parts replacement discount, and guaranteed service turnaround within 24 hours.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
          );

          final Widget actionButtons = Container(
            padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.bgSecondary : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.borderColor : AppColors.borderColorLight,
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      if (!isPurchased) ...[
                        Expanded(
                          child: GradientButton(
                            label: 'Book Now',
                            onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) => RequestBottomSheet(product: product),
                                );
                              },
                            icon: const Icon(
                              Icons.shopping_cart_checkout,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (product.brochureUrls.isNotEmpty) ...[
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark ? AppColors.borderColor : AppColors.borderColorLight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.picture_as_pdf_outlined,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                              onPressed: () {
                                ToastService.show(context, 'Opening Brochure: ${product.brochureUrls.first['title'] ?? 'Brochure'}');
                                // open logic would go here via url_launcher ideally
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? AppColors.borderColor : AppColors.borderColorLight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.collections_outlined,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                            onPressed: () {
                              ToastService.show(context, 'More images coming soon');
                            },
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: GradientButton(
                            label: 'Request Service',
                            onTap: () => _openBookingFlow(context),
                            icon: const Icon(
                              Icons.handyman_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      // Secondary button
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? AppColors.borderColor : AppColors.borderColorLight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                          onPressed: () {
                            context.go('/support');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: imageSection,
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: detailsSection,
                            ),
                          ),
                          actionButtons,
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          imageSection,
                          detailsSection,
                        ],
                      ),
                    ),
                  ),
                  actionButtons,
                ],
              );
            },
          );
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'boiler':
        return Icons.water_drop_outlined;
      case 'heat_pump':
        return Icons.heat_pump_outlined;
      case 'thermostat':
        return Icons.thermostat_outlined;
      default:
        return Icons.device_unknown_outlined;
    }
  }

  Widget _buildGridCard(String label, String value, {Widget? chip}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 4),
          if (chip != null)
            chip
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
