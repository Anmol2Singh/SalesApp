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
import 'package:http/http.dart' as http;
import 'package:salesapp/core/widgets/pdf_preview_screen.dart';
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
  String? _bookingStatus; // null, 'requested', 'pending', 'accepted'
  int _currentImageIndex = 0;
  final PageController _imagePageController = PageController();

  @override
  void initState() {
    super.initState();
    _checkRequestStatus();
  }

  Future<void> _checkRequestStatus() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final prefs = await SharedPreferences.getInstance();
      String phone = prefs.getString('customer_session_phone') ??
          SupabaseAuthRepository.loggedInPhone ??
          supabase.auth.currentUser?.phone ??
          '';

      // First check local cache
      final raw = prefs.getString('cached_product_inquiries');
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          if (item is Map && (item['product_id'] == widget.productId || item['id'] == widget.productId)) {
            final st = (item['status'] as String? ?? '').toLowerCase();
            if (st == 'accepted' || st == 'requested' || st == 'pending') {
              if (mounted) setState(() => _bookingStatus = st);
              return;
            }
          }
        }
      }

      // Check Supabase product_inquiries
      final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');
      var query = supabase.from('product_inquiries').select('status, product_id, customer_phone');
      if (widget.productId.isNotEmpty) {
        query = query.eq('product_id', widget.productId);
      }
      final rows = await query.order('created_at', ascending: false).limit(10);
      for (final r in (rows as List)) {
        final rPhone = (r['customer_phone']?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
        if (cleanDigits.isEmpty || rPhone.isEmpty || rPhone == cleanDigits || cleanDigits.endsWith(rPhone) || rPhone.endsWith(cleanDigits)) {
          final st = (r['status'] as String? ?? '').toLowerCase();
          if (mounted) setState(() => _bookingStatus = st);
          break;
        }
      }
    } catch (_) {}
  }

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

      // 1. Try to get user profile from userProfileProvider / customer_profiles
      try {
        final profile = await ref.read(userProfileProvider.future);
        if (profile.isNotEmpty) {
          final pName = profile['name']?.toString().trim();
          final pPhone = profile['phone']?.toString().trim();
          if (pName != null && pName.isNotEmpty && pName != 'Customer' && pName != 'Valued Customer') {
            name = pName;
          }
          if (pPhone != null && pPhone.isNotEmpty) {
            phone = pPhone;
          }
        }
      } catch (_) {}

      // 2. Fallback check directly in customer_profiles table if name still generic
      if (name == 'Valued Customer' || name.isEmpty) {
        try {
          final uid = supabase.auth.currentUser?.id ?? prefs.getString('customer_session_uid');
          if (uid != null) {
            final row = await supabase.from('customer_profiles').select('full_name, phone').eq('id', uid).maybeSingle();
            if (row != null) {
              if (row['full_name'] != null && row['full_name'].toString().trim().isNotEmpty) {
                name = row['full_name'].toString().trim();
              }
              if (phone.isEmpty && row['phone'] != null && row['phone'].toString().trim().isNotEmpty) {
                phone = row['phone'].toString().trim();
              }
            }
          }
        } catch (_) {}
      }

      // 3. Fallback check by phone in customer_profiles
      if (name == 'Valued Customer' || name.isEmpty) {
        try {
          final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');
          if (cleanDigits.isNotEmpty) {
            final allProfiles = await supabase.from('customer_profiles').select('full_name, phone').limit(50);
            for (final p in (allProfiles as List? ?? [])) {
              final pDigits = (p['phone']?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
              if (pDigits.isNotEmpty && (pDigits == cleanDigits || cleanDigits.endsWith(pDigits) || pDigits.endsWith(cleanDigits))) {
                if (p['full_name'] != null && p['full_name'].toString().trim().isNotEmpty) {
                  name = p['full_name'].toString().trim();
                  break;
                }
              }
            }
          }
        } catch (_) {}
      }

      // 4. Fallback check in customers table
      if (name == 'Valued Customer' || name.isEmpty) {
        try {
          final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');
          final cust = await supabase
              .from('customers')
              .select('customer_name, phone, company_name, contact_person')
              .or('phone.eq.$phone,phone.ilike.%$cleanDigits%')
              .limit(1)
              .maybeSingle();
          if (cust != null) {
            final cName = cust['customer_name']?.toString() ?? cust['contact_person']?.toString() ?? cust['company_name']?.toString();
            if (cName != null && cName.trim().isNotEmpty) {
              name = cName.trim();
            }
            if (cust['phone'] != null && cust['phone'].toString().isNotEmpty) {
              phone = cust['phone'].toString();
            }
          }
        } catch (_) {}
      }

      // 5. Fallback check in profiles table
      if (name == 'Valued Customer' || name.isEmpty) {
        try {
          final uid = supabase.auth.currentUser?.id ?? prefs.getString('customer_session_uid');
          if (uid != null) {
            final pRow = await supabase.from('profiles').select('full_name, phone').eq('id', uid).maybeSingle();
            if (pRow != null && pRow['full_name'] != null && pRow['full_name'].toString().trim().isNotEmpty) {
              name = pRow['full_name'].toString().trim();
            }
          }
        } catch (_) {}
      }

      // Persist resolved customer name for next interactions
      if (name != 'Valued Customer' && name.isNotEmpty) {
        await prefs.setString('customer_session_name', name);
      }

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
          'status': 'requested',
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
          'status': 'requested',
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

      if (mounted) {
        setState(() {
          _bookingStatus = 'requested';
        });
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
    // 1. Resolve brochure URL if available
    String? brochureUrl;
    if (product.brochureUrls.isNotEmpty) {
      for (final b in product.brochureUrls) {
        final u = b['url']?.toString() ?? b['link']?.toString() ?? b['file_url']?.toString();
        if (u != null && u.startsWith('http')) {
          brochureUrl = u;
          break;
        }
      }
    }

    // 2. If brochure PDF is available, load and display in full PdfPreviewScreen (with download, share, and print)
    if (brochureUrl != null && brochureUrl.isNotEmpty) {
      // Show loading indicator
      ToastService.show(context, 'Loading brochure PDF...', type: ToastType.info);
      try {
        final response = await http.get(Uri.parse(brochureUrl)).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfPreviewScreen(
                pdfBytes: response.bodyBytes,
                fileName: '${product.productName.replaceAll(' ', '_')}_Brochure.pdf',
              ),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('Error fetching brochure bytes: $e');
      }

      // Fallback: if byte fetch failed or timed out, attempt to launch in browser
      try {
        final uri = Uri.parse(brochureUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }

    // 3. If no brochure is uploaded/available, show the user requested popup
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Brochure Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No PDF brochure is currently uploaded for "${product.productName}".',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Would you like to view the technical engineering specifications sheet instead?',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _showTechnicalSpecificationsSheet(context, product);
              },
              child: const Text('View Specs Sheet'),
            ),
          ],
        );
      },
    );
  }

  void _showTechnicalSpecificationsSheet(BuildContext context, Product product) {
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
                    child: const Icon(Icons.analytics_outlined, color: Color(0xFF2563EB), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Technical Specifications',
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
                'Engineering & Quality Highlights',
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
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(ctx),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: labelCol)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            val, 
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valCol),
          ),
        ),
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
                                      AppColors.primary,
                                      AppColors.accent,
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
                                    Text(
                                      'Get 24/7 priority support, free annual cleaning, parts replacement discount, and guaranteed service turnaround within 24 hours.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.9),
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
                                      AppColors.primary,
                                      AppColors.accent,
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
                                    SizedBox(height: 8),
                                    Text(
                                      'Get 24/7 priority support, free annual cleaning, parts replacement discount, and guaranteed service turnaround within 24 hours.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
          );

          final bool isRequested = _bookingStatus == 'requested' || _bookingStatus == 'pending';
          final bool isAccepted = _bookingStatus == 'accepted';

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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isPurchased && isAccepted) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Product request accepted! Our sales representative will be in touch.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (!isPurchased && isRequested) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200, width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.hourglass_top_rounded, color: Colors.blue.shade700, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Product request submitted. Awaiting approval.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Row(
                        children: [
                          if (!isPurchased) ...[
                            Expanded(
                              child: GradientButton(
                                label: _isBooking
                                    ? 'Registering...'
                                    : (isAccepted ? 'Book More' : (isRequested ? 'Requested' : 'Book Now')),
                                onTap: _isBooking ? () {} : () => _handleBookNow(context, product),
                                icon: _isBooking
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Icon(
                                        isAccepted
                                            ? Icons.add_shopping_cart
                                            : (isRequested ? Icons.check : Icons.shopping_cart_checkout),
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
