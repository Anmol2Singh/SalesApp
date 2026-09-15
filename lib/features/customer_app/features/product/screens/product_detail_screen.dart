import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:salesapp/core/providers/supabase_provider.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/data/models/data_models.dart';
import 'package:salesapp/features/customer_app/data/providers/app_providers.dart';
import 'package:salesapp/features/customer_app/data/repositories/app_repositories.dart';
import 'package:salesapp/features/customer_app/shared/widgets/glass_card.dart';
import 'package:salesapp/features/customer_app/shared/widgets/gradient_button.dart';
import 'package:salesapp/features/customer_app/shared/widgets/image_with_fallback.dart';
import 'package:salesapp/features/customer_app/shared/widgets/status_chip.dart';
import 'package:salesapp/features/customer_app/shared/widgets/toast_service.dart';
import 'package:salesapp/features/customer_app/features/service_request/screens/service_booking_flow.dart';
import 'product_booking_confirmed_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  bool _isRenewing = false;
  bool _isBooking = false;
  int _currentImageIndex = 0;
  final PageController _imagePageController = PageController();

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  void _openBookingFlow(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ServiceBookingFlow(preselectedProductId: widget.productId),
    );
  }

  Future<void> _handleBookNow(BuildContext context, Product product) async {
    if (_isBooking) return;
    setState(() => _isBooking = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final prefs = await SharedPreferences.getInstance();

      // Resolve customer phone and name
      String phone = prefs.getString('customer_session_phone') ??
          SupabaseAuthRepository.loggedInPhone ??
          supabase.auth.currentUser?.phone ??
          '';
      String name = prefs.getString('customer_session_name') ?? 'Valued Customer';

      try {
        final cust = await supabase
            .from('customers')
            .select('customer_name, phone, company_name')
            .or('phone.eq.$phone,phone.ilike.%${phone.replaceAll(RegExp(r'\D'), '')}%')
            .limit(1)
            .maybeSingle();
        if (cust != null) {
          if (cust['customer_name'] != null && cust['customer_name'].toString().isNotEmpty) {
            name = cust['customer_name'].toString();
          }
          if (cust['phone'] != null && cust['phone'].toString().isNotEmpty) {
            phone = cust['phone'].toString();
          }
        }
      } catch (_) {}

      if (phone.isEmpty) phone = '+91 9876543210';

      final inquiryId = 'INQ-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 9000) + 1000}';

      // 1. Save to local SharedPreferences cache
      try {
        final raw = prefs.getString('cached_product_inquiries');
        List<dynamic> list = [];
        if (raw != null && raw.isNotEmpty) {
          list = jsonDecode(raw) as List;
        }
        final newEntry = {
          'id': inquiryId,
          'customer_name': name,
          'customer_phone': phone,
          'product_id': product.productId,
          'product_name': product.productName,
          'model_number': product.modelNumber,
          'category': product.category,
          'created_at': DateTime.now().toIso8601String(),
          'status': 'pending',
        };
        list.insert(0, newEntry);
        await prefs.setString('cached_product_inquiries', jsonEncode(list));
      } catch (_) {}

      // 2. Insert into product_inquiries table in Supabase
      try {
        await supabase.from('product_inquiries').insert({
          'inquiry_id': inquiryId,
          'customer_name': name,
          'customer_phone': phone,
          'product_id': product.productId,
          'product_name': product.productName,
          'model_number': product.modelNumber,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Direct product_inquiries insert error (non-fatal): $e');
      }

      // 3. Insert into crm_leads so CRM and Admin immediately see it
      try {
        await supabase.from('crm_leads').insert({
          'name': name,
          'phone': phone,
          'source': 'Customer Product Interest',
          'requirement': 'Respected customer has shown interest in following product: ${product.productName} (${product.modelNumber})',
          'notes': 'Booked via Customer Portal ($inquiryId)',
          'status': 'new',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('CRM lead insert error (non-fatal): $e');
      }

      // 4. Send notification to Admins & Sales team
      try {
        final staffResponse = await supabase.from('profiles').select('id, role, roles');
        for (final s in (staffResponse as List? ?? [])) {
          final role = (s['role'] as String? ?? '').toLowerCase();
          final rolesList = (s['roles'] is List) ? (s['roles'] as List).map((e) => e.toString().toLowerCase()).toList() : [];
          if (role == 'admin' || role == 'manager' || role == 'sales' || role == 'sales_head' ||
              rolesList.contains('admin') || rolesList.contains('sales_head')) {
            if (s['id'] != null) {
              await supabase.from('notifications').insert({
                'user_id': s['id'],
                'title': 'New Customer Product Interest 🛒',
                'body': 'Respected customer $name ($phone) has shown interest in following product: ${product.productName} (${product.modelNumber}). Our sales will contact them shortly.',
                'type': 'product_interest',
                'created_at': DateTime.now().toIso8601String(),
              });
            }
          }
        }
      } catch (_) {}

      // 5. Navigate to Animated Booking Confirmed Page!
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => ProductBookingConfirmedScreen(
              product: product,
              inquiryId: inquiryId,
              customerName: name,
              customerPhone: phone,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ToastService.show(context, 'Error registering interest: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _viewBrochure(BuildContext context, Product product) async {
    // If has direct brochure URL
    String? brochureUrl;
    if (product.brochureUrls.isNotEmpty) {
      final first = product.brochureUrls.first;
      brochureUrl = first['url']?.toString() ?? first['link']?.toString() ?? first['file_url']?.toString();
    }

    if (brochureUrl != null && brochureUrl.startsWith('http')) {
      try {
        final uri = Uri.parse(brochureUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }

    // Otherwise show rich Product Technical Brochure Sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textCol = isDark ? Colors.white : AppColors.textPrimaryLight;
        final subCol = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

        return Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF2563EB), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Brochure',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textCol,
                          ),
                        ),
                        Text(
                          '${product.productName} • Model: ${product.modelNumber}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: subCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                'Key Specifications & Engineering Highlights',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    _buildSpecRow('Category', product.category.toUpperCase(), textCol, subCol),
                    const SizedBox(height: 6),
                    _buildSpecRow('Model Series', product.modelNumber, textCol, subCol),
                    const SizedBox(height: 6),
                    _buildSpecRow('Warranty Coverage', '5 Years Manufacturer Warranty', const Color(0xFF16A34A), subCol),
                    const SizedBox(height: 6),
                    _buildSpecRow('AMC Compatibility', 'Eligible for IZYHEAT Care (2-4 visits/yr)', const Color(0xFF2563EB), subCol),
                    const SizedBox(height: 6),
                    _buildSpecRow('Standard Delivery', '2-5 Business Days with Certified Installation', textCol, subCol),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Download Official Spec Sheet (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ToastService.show(context, 'Downloading ${product.productName} Brochure...', type: ToastType.info);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecRow(String label, String val, Color valCol, Color labelCol) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: labelCol)),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valCol)),
      ],
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

          final List<String> displayImages = [];
          if (product.imageUrls.isNotEmpty) {
            displayImages.addAll(product.imageUrls);
          } else if (imageUrl.isNotEmpty) {
            displayImages.add(imageUrl);
          }

          // If unpurchased catalog item has only 1 image, add showcase perspectives so customer can slide
          if (!isPurchased && displayImages.length <= 1) {
            if (product.category.toLowerCase().contains('heat_pump')) {
              displayImages.add('https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop');
              displayImages.add('https://images.unsplash.com/photo-1581092335397-9583fe92d232?w=800&auto=format&fit=crop');
            } else if (product.category.toLowerCase().contains('boiler')) {
              displayImages.add('https://images.unsplash.com/photo-1513694203232-719a280e022f?w=800&auto=format&fit=crop');
              displayImages.add('https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=800&auto=format&fit=crop');
            } else {
              displayImages.add('https://images.unsplash.com/photo-1509391365360-2e959784a276?w=800&auto=format&fit=crop');
              displayImages.add('https://images.unsplash.com/photo-1545259742-b4fd8fea67e4?w=800&auto=format&fit=crop');
            }
          }

          final Widget imageSection = Stack(
            children: [
              Hero(
                tag: 'product_image_${product.productId}',
                child: SizedBox(
                  height: 270,
                  width: double.infinity,
                  child: displayImages.length > 1
                      ? PageView.builder(
                          controller: _imagePageController,
                          itemCount: displayImages.length,
                          onPageChanged: (idx) {
                            setState(() => _currentImageIndex = idx);
                          },
                          itemBuilder: (ctx, i) {
                            return ImageWithFallback(
                              imageUrl: displayImages[i],
                              fit: BoxFit.cover,
                            );
                          },
                        )
                      : ImageWithFallback(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              // Blur & Darken Overlay on Image
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.35)),
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
              // Sliding Dots Indicator when multiple images available
              if (displayImages.length > 1)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      displayImages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentImageIndex == i ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _currentImageIndex == i
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
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
                            label: _isBooking ? 'Registering...' : 'Book Now',
                            onTap: _isBooking ? () {} : () => _handleBookNow(context, product),
                            icon: _isBooking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(
                                    Icons.shopping_cart_checkout,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Dedicated Brochure Button in place of mobile phone / chat icon
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppColors.bgSecondary : Colors.white,
                            foregroundColor: const Color(0xFF2563EB),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                          label: const Text(
                            'Brochure',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          onPressed: () => _viewBrochure(context, product),
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
                        // Secondary Support Button for purchased products
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
