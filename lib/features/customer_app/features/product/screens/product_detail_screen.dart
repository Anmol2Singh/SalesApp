import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:salesapp/features/customer_app/shared/widgets/toast_service.dart';
import 'package:salesapp/features/customer_app/features/service_request/screens/service_booking_flow.dart';
import 'package:http/http.dart' as http;
import 'package:salesapp/core/widgets/pdf_preview_screen.dart';
import 'package:salesapp/core/utils/currency_helper.dart';
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
  final PageController _imagePageController = PageController(initialPage: 5000);

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
          if (item is Map &&
              (item['product_id'] == widget.productId ||
                  item['id'] == widget.productId)) {
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
      var query = supabase
          .from('product_inquiries')
          .select('status, product_id, customer_phone');
      if (widget.productId.isNotEmpty) {
        query = query.eq('product_id', widget.productId);
      }
      final rows = await query.order('created_at', ascending: false).limit(10);
      for (final r in (rows as List)) {
        final rPhone = (r['customer_phone']?.toString() ?? '')
            .replaceAll(RegExp(r'\D'), '');
        if (cleanDigits.isEmpty ||
            rPhone.isEmpty ||
            rPhone == cleanDigits ||
            cleanDigits.endsWith(rPhone) ||
            rPhone.endsWith(cleanDigits)) {
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

  void _openFullScreenImageViewer(
      BuildContext context, List<String> images, int initialIndex) {
    if (images.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.92),
        pageBuilder: (ctx, anim, secAnim) {
          int pageIdx = initialIndex;
          final pageController = PageController(initialPage: initialIndex);

          return StatefulBuilder(
            builder: (context, setViewerState) {
              return Scaffold(
                backgroundColor: Colors.black.withOpacity(0.92),
                body: SafeArea(
                  child: Stack(
                    children: [
                      // Interactive Zoomable PageView
                      PageView.builder(
                        controller: pageController,
                        itemCount: images.length,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (i) => setViewerState(() => pageIdx = i),
                        itemBuilder: (context, i) {
                          return Center(
                            child: InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 4.0,
                              child: ImageWithFallback(
                                imageUrl: images[i],
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          );
                        },
                      ),

                      // Top Bar
                      Positioned(
                        top: 10,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                '${pageIdx + 1} / ${images.length}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ClipOval(
                              child: Material(
                                color: Colors.black.withOpacity(0.6),
                                child: IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      color: Colors.white, size: 24),
                                  onPressed: () => Navigator.of(ctx).pop(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Left/Right Navigation Chevrons
                      if (images.length > 1) ...[
                        if (pageIdx > 0)
                          Positioned(
                            left: 16,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.chevron_left_rounded,
                                    size: 36),
                                onPressed: () {
                                  pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            ),
                          ),
                        if (pageIdx < images.length - 1)
                          Positioned(
                            right: 16,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.chevron_right_rounded,
                                    size: 36),
                                onPressed: () {
                                  pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCapacitySelectionSheet(BuildContext context, Product product) {
    // 1. Resolve available capacities
    List<String> capacities = List<String>.from(product.capacities);

    // Fallback based on category / product name if capacities not yet defined
    if (capacities.isEmpty) {
      final name = product.productName.toLowerCase();
      final cat = product.category.toLowerCase();
      if (name.contains('heat pump') || cat.contains('heat_pump')) {
        capacities = ['4KW', '8KW', '10KW', '12KW', '18KW', '58KW'];
      } else if (name.contains('boom barrier') || cat.contains('barrier')) {
        capacities = ['IZ-2001', 'IZ-2026'];
      } else if (name.contains('water heater') ||
          name.contains('swh') ||
          cat.contains('boiler')) {
        capacities = [
          '100 LPD',
          '150 LPD',
          '200 LPD',
          '250 LPD',
          '300 LPD',
          '500 LPD'
        ];
      } else {
        capacities = ['Standard Sizing', 'Commercial / High Capacity'];
      }
    }

    String selectedCap = capacities.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
            final textCol = isDark ? Colors.white : AppColors.textPrimaryLight;
            final subCol =
                isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
            final borderCol = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.4),
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
                            color: const Color(0xFFF59E0B).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.straighten_rounded,
                              color: Color(0xFFD97706), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Capacity / Size',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: textCol,
                                ),
                              ),
                              Text(
                                product.productName,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Choose from available capacities for this product. Our engineering and sales team will contact you with sizing recommendations and proposal.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: subCol,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: capacities.map((cap) {
                        final isSel = selectedCap == cap;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setSheetState(() => selectedCap = cap);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? const Color(0xFF1E1B4B)
                                  : (isDark
                                      ? Colors.white.withOpacity(0.04)
                                      : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    isSel ? const Color(0xFFF59E0B) : borderCol,
                                width: isSel ? 2 : 1,
                              ),
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF1E1B4B)
                                            .withOpacity(0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSel
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 18,
                                  color:
                                      isSel ? const Color(0xFFF59E0B) : subCol,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cap,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: isSel
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSel ? Colors.white : textCol,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        label: 'Confirm & Book ($selectedCap)',
                        isLoading: _isBooking,
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleBookNow(product,
                              selectedCapacity: selectedCap);
                        },
                        icon: const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleBookNow(Product product,
      {String? selectedCapacity}) async {
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
      String name =
          prefs.getString('customer_session_name') ?? 'Valued Customer';

      // 1. Try to get user profile from userProfileProvider / customer_profiles
      try {
        final profile = await ref.read(userProfileProvider.future);
        if (profile.isNotEmpty) {
          final pName = profile['name']?.toString().trim();
          final pPhone = profile['phone']?.toString().trim();
          if (pName != null &&
              pName.isNotEmpty &&
              pName != 'Customer' &&
              pName != 'Valued Customer') {
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
          final uid = supabase.auth.currentUser?.id ??
              prefs.getString('customer_session_uid');
          if (uid != null) {
            final row = await supabase
                .from('customer_profiles')
                .select('full_name, phone')
                .eq('id', uid)
                .maybeSingle();
            if (row != null) {
              if (row['full_name'] != null &&
                  row['full_name'].toString().trim().isNotEmpty) {
                name = row['full_name'].toString().trim();
              }
              if (phone.isEmpty &&
                  row['phone'] != null &&
                  row['phone'].toString().trim().isNotEmpty) {
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
            final allProfiles = await supabase
                .from('customer_profiles')
                .select('full_name, phone')
                .limit(50);
            for (final p in (allProfiles as List? ?? [])) {
              final pDigits =
                  (p['phone']?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
              if (pDigits.isNotEmpty &&
                  (pDigits == cleanDigits ||
                      cleanDigits.endsWith(pDigits) ||
                      pDigits.endsWith(cleanDigits))) {
                if (p['full_name'] != null &&
                    p['full_name'].toString().trim().isNotEmpty) {
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
            final cName = cust['customer_name']?.toString() ??
                cust['contact_person']?.toString() ??
                cust['company_name']?.toString();
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
          final uid = supabase.auth.currentUser?.id ??
              prefs.getString('customer_session_uid');
          if (uid != null) {
            final pRow = await supabase
                .from('profiles')
                .select('full_name, phone')
                .eq('id', uid)
                .maybeSingle();
            if (pRow != null &&
                pRow['full_name'] != null &&
                pRow['full_name'].toString().trim().isNotEmpty) {
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

      final inquiryId =
          'INQ-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 9000) + 1000}';
      final modelWithCap =
          (selectedCapacity != null && selectedCapacity.isNotEmpty)
              ? '$selectedCapacity • ${product.modelNumber}'
              : product.modelNumber;

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
          'model_number': modelWithCap,
          'category': product.category,
          'selected_capacity': selectedCapacity,
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
          'model_number': modelWithCap,
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
          'requirement':
              'Respected customer has shown interest in following product: ${product.productName} ($modelWithCap)',
          'notes':
              'Booked via Customer Portal ($inquiryId)${selectedCapacity != null ? " - Capacity: $selectedCapacity" : ""}',
          'status': 'new',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('CRM lead insert error (non-fatal): $e');
      }

      // 4. Send notification to Admins & Sales team
      try {
        final staffResponse =
            await supabase.from('profiles').select('id, role, roles');
        for (final s in (staffResponse as List? ?? [])) {
          final role = (s['role'] as String? ?? '').toLowerCase();
          final rolesList = (s['roles'] is List)
              ? (s['roles'] as List)
                  .map((e) => e.toString().toLowerCase())
                  .toList()
              : [];
          if (role == 'admin' ||
              role == 'manager' ||
              role == 'sales' ||
              role == 'sales_head' ||
              rolesList.contains('admin') ||
              rolesList.contains('sales_head')) {
            if (s['id'] != null) {
              await supabase.from('notifications').insert({
                'user_id': s['id'],
                'title': 'New Customer Product Interest 🛒',
                'body':
                    'Respected customer $name ($phone) has shown interest in following product: ${product.productName} (${selectedCapacity != null ? "Capacity: $selectedCapacity, " : ""}Model: ${product.modelNumber}). Our sales will contact them shortly.',
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
      if (mounted) {
        ToastService.show(context, 'Error registering interest: $e',
            type: ToastType.error);
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
        final u = b['url']?.toString() ??
            b['link']?.toString() ??
            b['file_url']?.toString();
        if (u != null && u.startsWith('http')) {
          brochureUrl = u;
          break;
        }
      }
    }

    // 2. If brochure PDF is available, load and display in full PdfPreviewScreen (with download, share, and print)
    if (brochureUrl != null && brochureUrl.isNotEmpty) {
      // Show loading indicator
      ToastService.show(context, 'Loading brochure PDF...',
          type: ToastType.info);
      try {
        final response = await http
            .get(Uri.parse(brochureUrl))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200 &&
            response.bodyBytes.isNotEmpty &&
            context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfPreviewScreen(
                pdfBytes: response.bodyBytes,
                fileName:
                    '${product.productName.replaceAll(' ', '_')}_Brochure.pdf',
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: Colors.amber, size: 24),
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
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.textSecondaryLight,
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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

  void _showTechnicalSpecificationsSheet(
      BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textCol = isDark ? Colors.white : AppColors.textPrimaryLight;
        final subCol =
            isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

        return Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
                    child: const Icon(Icons.analytics_outlined,
                        color: Color(0xFF2563EB), size: 26),
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
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    _buildSpecRow('Category', product.category.toUpperCase(),
                        textCol, subCol),
                    const SizedBox(height: 6),
                    _buildSpecRow(
                        'Model Series', product.modelNumber, textCol, subCol),
                    const SizedBox(height: 6),
                    _buildSpecRow(
                        'Warranty Coverage',
                        '5 Years Manufacturer Warranty',
                        const Color(0xFF16A34A),
                        subCol),
                    const SizedBox(height: 6),
                    _buildSpecRow(
                        'AMC Compatibility',
                        'Eligible for IZYHEAT Care (2-4 visits/yr)',
                        const Color(0xFF2563EB),
                        subCol),
                    const SizedBox(height: 6),
                    _buildSpecRow(
                        'Standard Delivery',
                        '2-5 Business Days with Certified Installation',
                        textCol,
                        subCol),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Dismiss',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: valCol),
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
      final isCatalogProduct = product.productId.startsWith('adv_') ||
          !product.productId.startsWith('req_') &&
              product.serialNumber == product.productId;
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
  }

  @override
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
          final isPurchased = purchasedAsync.value
                  ?.any((p) => p.productId == product.productId) ??
              false;

          final isAmcExpired = product.amcStatus == 'expired';
          final isWarrantyExpired = product.warrantyExpiryDate.isBefore(
            DateTime.now(),
          );

          final List<String> displayImages = [];
          for (final u in product.imageUrls) {
            final clean = u.trim();
            if (clean.isNotEmpty && !displayImages.contains(clean)) {
              displayImages.add(clean);
            }
          }
          final singleClean = product.imageUrl.trim();
          if (singleClean.isNotEmpty && !displayImages.contains(singleClean)) {
            displayImages.insert(0, singleClean);
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
                          physics: const BouncingScrollPhysics(),
                          controller: _imagePageController,
                          itemCount: 10000,
                          onPageChanged: (idx) {
                            setState(() => _currentImageIndex =
                                idx % displayImages.length);
                          },
                          itemBuilder: (ctx, i) {
                            final realIdx = i % displayImages.length;
                            return InkWell(
                              onTap: () => _openFullScreenImageViewer(
                                  context, displayImages, realIdx),
                              child: ImageWithFallback(
                                imageUrl: displayImages[realIdx],
                                category: product.category,
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        )
                      : InkWell(
                          onTap: displayImages.isNotEmpty
                              ? () => _openFullScreenImageViewer(
                                  context, displayImages, 0)
                              : null,
                          child: ImageWithFallback(
                            imageUrl: displayImages.isNotEmpty
                                ? displayImages.first
                                : '',
                            category: product.category,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              // Blur & Darken Overlay on Image
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                        Colors.black.withOpacity(0.55),
                      ],
                    ),
                  ),
                ),
              ),
              // Fullscreen tap hint
              Positioned(
                bottom: 14,
                right: 16,
                child: InkWell(
                  onTap: () => _openFullScreenImageViewer(
                      context, displayImages, _currentImageIndex),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded,
                            color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'View Full',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Category badge on top-right of image
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B4B).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getCategoryIcon(product.category),
                          color: AppColors.accent, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        product.category.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Back arrow overlaid
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      color: Colors.black.withOpacity(0.35),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
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
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              displayImages.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                width: _currentImageIndex == i ? 22 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _currentImageIndex == i
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: _currentImageIndex == i
                                      ? [
                                          BoxShadow(
                                            color:
                                                Colors.white.withOpacity(0.5),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.productName,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Model: ${product.modelNumber}',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              if (isPurchased)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF10B981)
                                          .withOpacity(0.25),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 13,
                                        color: Color(0xFF059669),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Installed & Active',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Technical Specs',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 22),
                      onPressed: () =>
                          _showTechnicalSpecificationsSheet(context, product),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Protection Highlights (Warranty & AMC)
                Row(
                  children: [
                    // Warranty Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isWarrantyExpired
                                ? [
                                    const Color(0xFFFEF2F2),
                                    const Color(0xFFFEE2E2)
                                  ]
                                : [
                                    const Color(0xFFECFDF5),
                                    const Color(0xFFD1FAE5)
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isWarrantyExpired
                                ? const Color(0xFFFECACA)
                                : const Color(0xFFA7F3D0),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.verified_user_rounded,
                                  size: 18,
                                  color: isWarrantyExpired
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF059669),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Warranty',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isWarrantyExpired
                                          ? const Color(0xFF991B1B)
                                          : const Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isWarrantyExpired
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isPurchased
                                        ? (isWarrantyExpired
                                            ? 'EXPIRED'
                                            : 'ACTIVE')
                                        : 'STANDARD',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isPurchased
                                  ? (isWarrantyExpired
                                      ? 'Expired on ${DateFormat('dd MMM yyyy').format(product.warrantyExpiryDate)}'
                                      : 'Valid till ${DateFormat('dd MMM yyyy').format(product.warrantyExpiryDate)}')
                                  : '1 Year Manufacturer Warranty',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isWarrantyExpired
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // AMC Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: product.amcStatus == 'active'
                                ? [
                                    const Color(0xFFEFF6FF),
                                    const Color(0xFFDBEAFE)
                                  ]
                                : (product.amcStatus == 'expired'
                                    ? [
                                        const Color(0xFFFFFBEB),
                                        const Color(0xFFFEF3C7)
                                      ]
                                    : [
                                        const Color(0xFFF8FAFC),
                                        const Color(0xFFF1F5F9)
                                      ]),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: product.amcStatus == 'active'
                                ? const Color(0xFF93C5FD)
                                : (product.amcStatus == 'expired'
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFFE2E8F0)),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.health_and_safety_rounded,
                                  size: 18,
                                  color: product.amcStatus == 'active'
                                      ? const Color(0xFF2563EB)
                                      : (product.amcStatus == 'expired'
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    product.amcStatus == 'active'
                                        ? 'AMC Availed'
                                        : 'AMC Plan',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: product.amcStatus == 'active'
                                          ? const Color(0xFF1E40AF)
                                          : (product.amcStatus == 'expired'
                                              ? const Color(0xFF92400E)
                                              : const Color(0xFF334155)),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: product.amcStatus == 'active'
                                        ? const Color(0xFF2563EB)
                                        : (product.amcStatus == 'expired'
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFF94A3B8)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    product.amcStatus == 'active'
                                        ? 'AVAILED ✓'
                                        : product.amcStatus.toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.amcStatus == 'active'
                                  ? (product.amcExpiryDate != null
                                      ? '1 Year Duration • Valid till ${DateFormat('dd MMM yyyy').format(product.amcExpiryDate!)}'
                                      : '1 Year Duration • Active Protection')
                                  : (product.amcStatus == 'expired'
                                      ? 'Contract Expired'
                                      : 'Not Subscribed'),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: product.amcStatus == 'active'
                                    ? const Color(0xFF1D4ED8)
                                    : (product.amcStatus == 'expired'
                                        ? const Color(0xFFB45309)
                                        : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // Specifications & Details Section
                Text(
                  'Specifications & Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                ),
                const SizedBox(height: 10),
                GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  borderRadius: 16,
                  child: Column(
                    children: [
                      if (isPurchased) ...[
                        if (product.modelNumber.isNotEmpty &&
                            product.modelNumber != 'HVAC' &&
                            product.modelNumber != 'COMMERCIAL') ...[
                          _buildSpecTile(
                            icon: Icons.precision_manufacturing_outlined,
                            label: 'Purchased Equipment / Model',
                            value: product.modelNumber,
                            iconColor: const Color(0xFF6366F1),
                          ),
                          const Divider(height: 16),
                        ],
                        _buildSpecTile(
                          icon: Icons.calendar_today_outlined,
                          label: 'Purchased Date',
                          value: DateFormat('dd MMM yyyy')
                              .format(product.purchasedDate),
                          iconColor: const Color(0xFF3B82F6),
                        ),
                        const Divider(height: 16),
                        _buildSpecTile(
                          icon: Icons.storefront_outlined,
                          label: 'Seller / Dealer',
                          value: product.sellerName.isNotEmpty
                              ? product.sellerName
                              : 'IZYHEAT Industry',
                          iconColor: const Color(0xFF10B981),
                        ),
                        const Divider(height: 16),
                        _buildSpecTile(
                          icon: Icons.shield_outlined,
                          label: 'Warranty Coverage Window',
                          value:
                              '${DateFormat('dd MMM yyyy').format(product.warrantyStartDate ?? product.purchasedDate)}  –  ${DateFormat('dd MMM yyyy').format(product.warrantyExpiryDate)}',
                          iconColor: const Color(0xFF8B5CF6),
                        ),
                        const Divider(height: 16),
                        _buildSpecTile(
                          icon: Icons.receipt_long_outlined,
                          label: 'Order / Amount Paid',
                          value: formatIndianCurrency(product.amountPaid,
                              includeDecimals: true),
                          iconColor: const Color(0xFFF59E0B),
                        ),
                      ] else ...[
                        _buildSpecTile(
                          icon: Icons.inventory_2_outlined,
                          label: 'Availability Status',
                          value: 'In Stock & Ready for Dispatch',
                          iconColor: const Color(0xFF10B981),
                        ),
                        const Divider(height: 16),
                        _buildSpecTile(
                          icon: Icons.factory_outlined,
                          label: 'Manufacturer',
                          value: 'IZYHEAT Solar Industry',
                          iconColor: const Color(0xFF3B82F6),
                        ),
                        const Divider(height: 16),
                        _buildSpecTile(
                          icon: Icons.currency_rupee,
                          label: 'Base Pricing',
                          value: formatIndianCurrency(product.amountPaid,
                              includeDecimals: true),
                          iconColor: const Color(0xFFF59E0B),
                        ),
                      ],
                      if (isPurchased &&
                          product.installationAddress != null &&
                          product.installationAddress!.isNotEmpty) ...[
                        const Divider(height: 16),
                        _buildSpecTile(
                          icon: Icons.location_on_outlined,
                          label: 'Installation Location',
                          value: product.installationAddress!
                              .replaceAll(RegExp(r'[ \t]+'), ' ')
                              .replaceAll(RegExp(r'\n\s*\n'), '\n')
                              .trim(),
                          iconColor: const Color(0xFFEF4444),
                        ),
                      ],
                      if (isPurchased && product.amcStatus != 'none') ...[
                        const Divider(height: 16),
                        _buildSpecTile(
                          icon: Icons.fact_check_outlined,
                          label: 'AMC Visits Track',
                          value:
                              '${product.numberOfVisitsIncluded} Included  •  ${product.numberOfVisitsCompleted} Completed  •  ${(product.numberOfVisitsIncluded - product.numberOfVisitsCompleted).clamp(0, 999)} Remaining',
                          iconColor: const Color(0xFF06B6D4),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Included Equipment & Quotation Items Purchased
                () {
                  final effectivePurchasedItems =
                      List<String>.from(product.includedItems);
                  if (effectivePurchasedItems.isEmpty &&
                      product.modelNumber.isNotEmpty &&
                      product.modelNumber != 'HVAC' &&
                      product.modelNumber != 'COMMERCIAL') {
                    effectivePurchasedItems.add(product.modelNumber);
                  }

                  if (effectivePurchasedItems.isEmpty)
                    return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.checklist_rtl_rounded,
                              color: Color(0xFF6D28D9), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Quotation Items / Components Purchased',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimaryLight,
                                ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${effectivePurchasedItems.length} items',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        borderRadius: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Equipment and accessories supplied with this installation (as listed in quotation & sales records):',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...effectivePurchasedItems.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.04)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white10
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6D28D9)
                                              .withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_circle_rounded,
                                          size: 16,
                                          color: Color(0xFF6D28D9),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  );
                }(),

                if (isPurchased &&
                    (product.amcVisits.isNotEmpty ||
                        product.amcStatus == 'active')) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Scheduled AMC Visits',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (product.amcVisits.isEmpty)
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 16,
                      child: Row(
                        children: [
                          const Icon(Icons.event_available,
                              color: AppColors.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${product.numberOfVisitsIncluded} annual visits included under active AMC contract. Dates will be scheduled by our service coordinator.',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textPrimary
                                    : AppColors.textPrimaryLight,
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
                      final status = (visit['status'] as String? ?? 'scheduled')
                          .toUpperCase();
                      final schedStr = visit['scheduled_date'] as String?;
                      final compStr = visit['completed_date'] as String?;
                      final date = (compStr != null
                              ? DateTime.tryParse(compStr)
                              : null) ??
                          (schedStr != null
                              ? DateTime.tryParse(schedStr)
                              : null);
                      final isCompleted = status == 'COMPLETED';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          borderRadius: 14,
                          child: Row(
                            children: [
                              Icon(
                                isCompleted
                                    ? Icons.check_circle
                                    : Icons.calendar_today,
                                color: isCompleted
                                    ? AppColors.success
                                    : AppColors.accent,
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
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.textPrimaryLight,
                                      ),
                                    ),
                                    if (date != null)
                                      Text(
                                        '${isCompleted ? "Completed on" : "Scheduled for"} ${DateFormat("dd MMM yyyy").format(date)}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark
                                              ? AppColors.textSecondary
                                              : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isCompleted
                                          ? AppColors.success
                                          : AppColors.accent)
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted
                                        ? AppColors.success
                                        : AppColors.accent,
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
                if (isPurchased && isAmcExpired) ...[
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
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
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF0F172A),
                          Color(0xFF1E1B4B),
                          Color(0xFF312E81),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.4),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E1B4B).withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                color: Color(0xFFF59E0B),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Annual Maintenance Program',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Certified Protection & Upkeep Plans',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0xFFFBBF24),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Get 24/7 priority support, free periodic cleaning visits, discounts on spare parts, and guaranteed turnaround within 24 hours.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            height: 1.4,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildAmcFeaturePill(Icons.check_circle_rounded,
                                'Free Service Visits'),
                            _buildAmcFeaturePill(
                                Icons.discount_rounded, 'Parts Discount'),
                            _buildAmcFeaturePill(
                                Icons.speed_rounded, 'Priority SLA'),
                          ],
                        ),
                        const SizedBox(height: 18),
                        InkWell(
                          onTap: () {
                            context.push(
                                '/amc_avail?productId=' + product.productId);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFF59E0B).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.workspace_premium_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Avail AMC Protection Now',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isPurchased && product.amcStatus == 'active') ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF10B981)
                              .withOpacity(isDark ? 0.25 : 0.12),
                          const Color(0xFF047857)
                              .withOpacity(isDark ? 0.3 : 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.verified_user,
                                      color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AMC Availed • ${product.amcPlanTitle ?? 'Standard'} Plan',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                    Text(
                                      product.amcExpiryDate != null
                                          ? '1 Year Duration (Valid till ${DateFormat('dd MMM yyyy').format(product.amcExpiryDate!)})'
                                          : '1 Year Duration (Active Protection)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${product.numberOfVisitsIncluded > 0 ? product.numberOfVisitsIncluded : 2} Visits/Yr',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your system is fully protected with priority support, discounted spare parts, and certified technician maintenance checkups.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  context.push(
                                    '/amc_avail?productId=${product.productId}&mode=extend',
                                  );
                                },
                                icon:
                                    const Icon(Icons.update_rounded, size: 16),
                                label: const Text(
                                  'Extend Year',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF047857),
                                  side: const BorderSide(
                                      color: Color(0xFF10B981), width: 1.5),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  context.push(
                                    '/amc_avail?productId=${product.productId}&mode=upgrade',
                                  );
                                },
                                icon:
                                    const Icon(Icons.upgrade_rounded, size: 16),
                                label: const Text(
                                  'Upgrade Plan',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
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

          final bool isRequested =
              _bookingStatus == 'requested' || _bookingStatus == 'pending';
          final bool isAccepted = _bookingStatus == 'accepted';

          final Widget actionButtons = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bgSecondary : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? AppColors.borderColor
                      : AppColors.borderColorLight,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.green.shade300, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.green.shade700, size: 20),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.blue.shade200, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded,
                              color: Colors.blue.shade700, size: 18),
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
                                : (isAccepted
                                    ? 'Book More'
                                    : (isRequested ? 'Requested' : 'Book Now')),
                            onTap: _isBooking
                                ? () {}
                                : () => _showCapacitySelectionSheet(
                                    context, product),
                            icon: _isBooking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : Icon(
                                    isAccepted
                                        ? Icons.add_shopping_cart
                                        : (isRequested
                                            ? Icons.check
                                            : Icons.shopping_cart_checkout),
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Dedicated Brochure Button in place of mobile phone / chat icon
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark ? AppColors.bgSecondary : Colors.white,
                            foregroundColor: const Color(0xFF2563EB),
                            elevation: 0,
                            side: const BorderSide(
                                color: Color(0xFF2563EB), width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_outlined,
                              size: 20),
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
                              color: isDark
                                  ? AppColors.borderColor
                                  : AppColors.borderColorLight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight,
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
                        child: _buildDesktopImageGallery(
                            context, displayImages, product),
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

  Widget _buildDesktopImageGallery(
      BuildContext context, List<String> displayImages, Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderCol = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb / Back Navigation Bar
          Row(
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor:
                      isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 10),
              Text(
                'Product Details',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  product.productName,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Vertical Column of multiple product images (top, beneath it, beneath it)
          if (displayImages.isEmpty)
            Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderCol, width: 1.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ImageWithFallback(
                  imageUrl: '',
                  category: product.category,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            ...displayImages.asMap().entries.map((entry) {
              final idx = entry.key;
              final url = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderCol, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      InkWell(
                        onTap: () => _openFullScreenImageViewer(
                            context, displayImages, idx),
                        child: ImageWithFallback(
                          imageUrl: url,
                          category: product.category,
                          fit: BoxFit.cover,
                          height: 260,
                          width: double.infinity,
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fullscreen_rounded,
                                  color: Colors.white, size: 15),
                              const SizedBox(width: 4),
                              Text(
                                'View Full (${idx + 1}/${displayImages.length})',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
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
    final subtitleColor =
        isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

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

  Widget _buildAmcFeaturePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFFBBF24)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecTile({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
    Color? valueColor,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor =
        isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor ?? AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? textColor,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
