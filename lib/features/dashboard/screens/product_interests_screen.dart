import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../crm/providers/crm_providers.dart';

class ProductInterestItem {
  final String id;
  final String customerName;
  final String customerPhone;
  final String productName;
  final String modelNumber;
  final DateTime createdAt;
  final String status;

  ProductInterestItem({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.productName,
    required this.modelNumber,
    required this.createdAt,
    required this.status,
  });
}

class ProductInterestsScreen extends ConsumerStatefulWidget {
  const ProductInterestsScreen({super.key});

  @override
  ConsumerState<ProductInterestsScreen> createState() => _ProductInterestsScreenState();
}

class _ProductInterestsScreenState extends ConsumerState<ProductInterestsScreen> {
  List<ProductInterestItem> _interests = [];
  bool _isLoading = true;
  bool _isCreatingDeal = false;

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  Future<void> _loadInterests() async {
    setState(() => _isLoading = true);
    final List<ProductInterestItem> loaded = [];

    try {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cached_product_inquiries');
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List;
          for (final item in list) {
            if (item is Map) {
              loaded.add(ProductInterestItem(
                id: item['id']?.toString() ?? '',
                customerName: item['customer_name']?.toString() ?? 'Valued Customer',
                customerPhone: item['customer_phone']?.toString() ?? '',
                productName: item['product_name']?.toString() ?? 'Solar System',
                modelNumber: item['model_number']?.toString() ?? '',
                createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now(),
                status: item['status']?.toString() ?? 'pending',
              ));
            }
          }
        }
      } catch (_) {}

      try {
        final supabase = ref.read(supabaseClientProvider);
        final res = await supabase
            .from('product_inquiries')
            .select()
            .order('created_at', ascending: false);

        for (final item in (res as List? ?? [])) {
          final id = item['inquiry_id']?.toString() ?? item['id']?.toString() ?? '';
          if (!loaded.any((e) => e.id == id && id.isNotEmpty)) {
            loaded.add(ProductInterestItem(
              id: id,
              customerName: item['customer_name']?.toString() ?? 'Valued Customer',
              customerPhone: item['customer_phone']?.toString() ?? '',
              productName: item['product_name']?.toString() ?? 'Solar System',
              modelNumber: item['model_number']?.toString() ?? '',
              createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now(),
              status: item['status']?.toString() ?? 'pending',
            ));
          }
        }
      } catch (_) {}

      try {
        final supabase = ref.read(supabaseClientProvider);
        final res = await supabase
            .from('crm_leads')
            .select()
            .eq('source', 'Customer Product Interest')
            .order('created_at', ascending: false);

        for (final item in (res as List? ?? [])) {
          final id = item['id']?.toString() ?? '';
          final req = item['requirement']?.toString() ?? '';
          String prodName = 'Solar Equipment';
          if (req.contains('product:')) {
            prodName = req.split('product:').last.trim();
          } else if (req.contains('buying')) {
            prodName = req.split('buying').last.trim();
          }

          if (!loaded.any((e) => e.id == id && id.isNotEmpty)) {
            loaded.add(ProductInterestItem(
              id: id,
              customerName: item['name']?.toString() ?? 'Customer',
              customerPhone: item['phone']?.toString() ?? '',
              productName: prodName,
              modelNumber: '',
              createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now(),
              status: item['status']?.toString() ?? 'new',
            ));
          }
        }
      } catch (_) {}

      // Filter out any cancelled requests completely
      loaded.removeWhere((e) => e.status.toLowerCase() == 'cancelled');

      loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _interests = loaded;
          _isLoading = false;
        });
      }
    }
  }

  void _launchCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }

  void _launchWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$clean');
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _cancelRequest(ProductInterestItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: Text('Are you sure you want to cancel the interest request for "${item.productName}" from ${item.customerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 1. Remove completely from local cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cached_product_inquiries');
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List;
          list.removeWhere((e) => e is Map && (e['id'] == item.id || e['inquiry_id'] == item.id));
          await prefs.setString('cached_product_inquiries', jsonEncode(list));
        }
      } catch (_) {}

      // 2. Delete / update from Supabase product_inquiries
      final supabase = ref.read(supabaseClientProvider);
      try {
        await supabase
            .from('product_inquiries')
            .delete()
            .or('inquiry_id.eq.${item.id},id.eq.${item.id}');
      } catch (_) {
        try {
          await supabase
              .from('product_inquiries')
              .update({'status': 'cancelled'})
              .or('inquiry_id.eq.${item.id},id.eq.${item.id}');
        } catch (_) {}
      }

      // 3. Delete / cancel from Supabase crm_leads if applicable
      try {
        await supabase
            .from('crm_leads')
            .delete()
            .eq('id', item.id);
      } catch (_) {
        try {
          await supabase
              .from('crm_leads')
              .update({'status': 'cancelled'})
              .eq('id', item.id);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _interests.removeWhere((e) => e.id == item.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled successfully'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _acceptRequest(ProductInterestItem item) async {
    try {
      // 1. Update in SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cached_product_inquiries');
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List;
          for (final entry in list) {
            if (entry is Map && (entry['id'] == item.id || entry['inquiry_id'] == item.id)) {
              entry['status'] = 'accepted';
            }
          }
          await prefs.setString('cached_product_inquiries', jsonEncode(list));
        }
      } catch (_) {}

      // 2. Update status in Supabase product_inquiries
      final supabase = ref.read(supabaseClientProvider);
      try {
        await supabase
            .from('product_inquiries')
            .update({'status': 'accepted'})
            .or('inquiry_id.eq.${item.id},id.eq.${item.id}');
      } catch (_) {}

      // 3. Update status in Supabase crm_leads if applicable
      try {
        await supabase
            .from('crm_leads')
            .update({'status': 'contacted'})
            .eq('id', item.id);
      } catch (_) {}

      if (mounted) {
        setState(() {
          for (int i = 0; i < _interests.length; i++) {
            if (_interests[i].id == item.id) {
              _interests[i] = ProductInterestItem(
                id: item.id,
                customerName: item.customerName,
                customerPhone: item.customerPhone,
                productName: item.productName,
                modelNumber: item.modelNumber,
                status: 'accepted',
                createdAt: item.createdAt,
              );
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Product request accepted successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting request: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createDeal(ProductInterestItem item) async {
    setState(() => _isCreatingDeal = true);
    try {
      await ref.read(leadsProvider.notifier).addDirectLead(
        prospectName: item.customerName,
        contactPhone: item.customerPhone,
        productName: item.productName,
        estimatedValue: 0.0,
        notes: 'Deal created from Product Interest request. Product: ${item.productName} ${item.modelNumber}',
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Deal created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating deal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingDeal = false);
      }
    }
  }

  void _showInterestMenu(ProductInterestItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;

            return Container(
              padding: const EdgeInsets.all(24),
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_outline, color: Color(0xFF2563EB), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.customerName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              item.customerPhone,
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Product of Interest', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(item.productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if (item.modelNumber.isNotEmpty)
                          Text('Model: ${item.modelNumber}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: const Color(0xFF16A34A),
                            side: const BorderSide(color: Color(0xFF16A34A)),
                          ),
                          onPressed: () => _launchWhatsApp(item.customerPhone),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFF2563EB)),
                          ),
                          onPressed: () => _launchCall(item.customerPhone),
                          icon: const Icon(Icons.phone_outlined),
                          label: const Text('Call', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (item.status != 'accepted') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _acceptRequest(item);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Accept Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isCreatingDeal ? null : () => _createDeal(item),
                      icon: _isCreatingDeal
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.handshake_outlined),
                      label: Text(_isCreatingDeal ? 'Creating Deal...' : 'Create Deal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _cancelRequest(item);
                      },
                      icon: Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 18),
                      label: Text('Cancel Request', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasItems = _interests.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.background,
      appBar: AppBar(
        title: const Text('All Product Interests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInterests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !hasItems
              ? const Center(child: Text('No product interests found.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _interests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _interests[index];
                    return InkWell(
                      onTap: () => _showInterestMenu(item),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shopping_cart_outlined,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.customerName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.productName,
                                    style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt),
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: item.status == 'accepted' ? Colors.green.shade50 : Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: item.status == 'accepted' ? Colors.green.shade300 : Colors.amber.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          item.status.toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: item.status == 'accepted' ? Colors.green.shade800 : Colors.amber.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
