// lib/features/admin/screens/amc_management_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';

class AmcPlanItem {
  final String id;
  final String planCode;
  final String title;
  final String description;
  final int visitsPerYear;
  final double ratePerYear;
  final bool sparePartsDiscountEnabled;
  final double sparePartsDiscountPercentage;
  final String? badge;
  final String? offerText;
  final bool isActive;
  final int sortOrder;

  AmcPlanItem({
    required this.id,
    required this.planCode,
    required this.title,
    required this.description,
    required this.visitsPerYear,
    required this.ratePerYear,
    required this.sparePartsDiscountEnabled,
    required this.sparePartsDiscountPercentage,
    this.badge,
    this.offerText,
    required this.isActive,
    required this.sortOrder,
  });

  factory AmcPlanItem.fromJson(Map<String, dynamic> json) {
    return AmcPlanItem(
      id: json['id']?.toString() ?? '',
      planCode: json['plan_code']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Plan',
      description: json['description']?.toString() ?? '',
      visitsPerYear: (json['visits_per_year'] as num?)?.toInt() ?? 2,
      ratePerYear: (json['rate_per_year'] as num?)?.toDouble() ?? 4999.0,
      sparePartsDiscountEnabled: json['spare_parts_discount_enabled'] as bool? ?? true,
      sparePartsDiscountPercentage: (json['spare_parts_discount_percentage'] as num?)?.toDouble() ?? 15.0,
      badge: json['badge'] as String?,
      offerText: json['offer_text'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plan_code': planCode,
      'title': title,
      'description': description,
      'visits_per_year': visitsPerYear,
      'rate_per_year': ratePerYear,
      'spare_parts_discount_enabled': sparePartsDiscountEnabled,
      'spare_parts_discount_percentage': sparePartsDiscountPercentage,
      'badge': badge,
      'offer_text': offerText,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }
}

class AmcManagementScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const AmcManagementScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<AmcManagementScreen> createState() => _AmcManagementScreenState();
}

class _AmcManagementScreenState extends ConsumerState<AmcManagementScreen> {
  List<AmcPlanItem> _plans = [];
  bool _isLoading = true;
  String? _promoHeadline;
  String? _promoSubtext;

  @override
  void initState() {
    super.initState();
    _loadAmcPlans();
  }

  Future<void> _loadAmcPlans() async {
    setState(() => _isLoading = true);
    try {
      // 1. Try local cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cached_amc_plans');
        if (raw != null && raw.isNotEmpty) {
          final list = (jsonDecode(raw) as List)
              .map((e) => AmcPlanItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (list.isNotEmpty && mounted) {
            setState(() => _plans = list);
          }
        }
        _promoHeadline = prefs.getString('amc_promo_headline') ?? 'IZYHEAT Care Protection';
        _promoSubtext = prefs.getString('amc_promo_subtext') ?? 'Extend equipment lifespan with certified preventative servicing & priority breakdown support.';
      } catch (_) {}

      // 2. Fetch from Supabase amc_plans
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase
          .from('amc_plans')
          .select()
          .order('sort_order', ascending: true);

      if (res.isNotEmpty) {
        final loaded = (res as List)
            .map((e) => AmcPlanItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        if (mounted) {
          setState(() {
            _plans = loaded;
          });
        }

        // Cache locally
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_amc_plans', jsonEncode(loaded.map((p) => p.toJson()).toList()));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error loading AMC plans: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePlan(AmcPlanItem plan, {bool isNew = false}) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final planData = plan.toJson();
      planData['updated_at'] = DateTime.now().toIso8601String();

      await supabase.from('amc_plans').upsert(planData);

      // Refresh list
      await _loadAmcPlans();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNew ? '✅ New AMC Plan created!' : '✅ AMC Plan updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving plan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deletePlan(AmcPlanItem plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${plan.title} Plan?'),
        content: const Text('Are you sure you want to remove this AMC plan from the customer catalog?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final supabase = ref.read(supabaseClientProvider);
        await supabase.from('amc_plans').delete().eq('id', plan.id);
        await _loadAmcPlans();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AMC Plan deleted.'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting plan: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _openPlanDialog({AmcPlanItem? existingPlan}) {
    final isNew = existingPlan == null;
    final titleCtrl = TextEditingController(text: existingPlan?.title ?? '');
    final codeCtrl = TextEditingController(
        text: existingPlan?.planCode ?? 'plan_${DateTime.now().millisecondsSinceEpoch % 10000}');
    final descCtrl = TextEditingController(text: existingPlan?.description ?? '');
    final visitsCtrl = TextEditingController(text: (existingPlan?.visitsPerYear ?? 2).toString());
    final rateCtrl = TextEditingController(text: (existingPlan?.ratePerYear ?? 4999.0).toStringAsFixed(0));
    final discountCtrl = TextEditingController(text: (existingPlan?.sparePartsDiscountPercentage ?? 15.0).toStringAsFixed(0));
    final badgeCtrl = TextEditingController(text: existingPlan?.badge ?? '');
    final offerCtrl = TextEditingController(text: existingPlan?.offerText ?? '');

    bool sparePartsDiscountEnabled = existingPlan?.sparePartsDiscountEnabled ?? true;
    bool isActive = existingPlan?.isActive ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isNew ? 'Create AMC Plan' : 'Edit ${existingPlan.title} Plan',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Plan Name (e.g. Standard, Comprehensive, Premium)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: visitsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Visits / Year',
                            border: OutlineInputBorder(),
                            suffixText: 'visits',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: rateCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Rate / Year (₹)',
                            border: OutlineInputBorder(),
                            prefixText: '₹ ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Short Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Give Spare Parts Discount?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Discount applied when customer needs spare parts replacement', style: TextStyle(fontSize: 12)),
                    value: sparePartsDiscountEnabled,
                    onChanged: (val) => setModalState(() => sparePartsDiscountEnabled = val),
                  ),
                  if (sparePartsDiscountEnabled) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: discountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Discount Percentage (%)',
                        border: OutlineInputBorder(),
                        suffixText: '% OFF',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: badgeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Badge Tag (Optional)',
                            hintText: 'e.g. POPULAR, BEST VALUE',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: offerCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Special Offer / Deal',
                            hintText: 'e.g. Extra 10% off',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active for Customer Selection', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    value: isActive,
                    onChanged: (val) => setModalState(() => isActive = val),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) return;

                        final code = codeCtrl.text.trim().toLowerCase().replaceAll(' ', '_');
                        final visits = int.tryParse(visitsCtrl.text.trim()) ?? 2;
                        final rate = double.tryParse(rateCtrl.text.trim()) ?? 4999.0;
                        final discPct = double.tryParse(discountCtrl.text.trim()) ?? 15.0;
                        final id = existingPlan?.id ?? 'plan_${DateTime.now().millisecondsSinceEpoch}';

                        final updated = AmcPlanItem(
                          id: id,
                          planCode: code.isNotEmpty ? code : id,
                          title: title,
                          description: descCtrl.text.trim(),
                          visitsPerYear: visits,
                          ratePerYear: rate,
                          sparePartsDiscountEnabled: sparePartsDiscountEnabled,
                          sparePartsDiscountPercentage: discPct,
                          badge: badgeCtrl.text.trim().isNotEmpty ? badgeCtrl.text.trim().toUpperCase() : null,
                          offerText: offerCtrl.text.trim().isNotEmpty ? offerCtrl.text.trim() : null,
                          isActive: isActive,
                          sortOrder: existingPlan?.sortOrder ?? _plans.length + 1,
                        );

                        Navigator.pop(ctx);
                        _savePlan(updated, isNew: isNew);
                      },
                      child: Text(isNew ? 'Create Plan' : 'Save Changes',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPromoConfigDialog() {
    final headlineCtrl = TextEditingController(text: _promoHeadline ?? 'IZYHEAT Care Protection');
    final subtextCtrl = TextEditingController(text: _promoSubtext ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AMC Hero Banner & Offer', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: headlineCtrl,
              decoration: const InputDecoration(labelText: 'Banner Headline', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subtextCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Banner Promotional Text / Offer', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final h = headlineCtrl.text.trim();
              final s = subtextCtrl.text.trim();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('amc_promo_headline', h);
              await prefs.setString('amc_promo_subtext', s);
              setState(() {
                _promoHeadline = h;
                _promoSubtext = s;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Promotional banner updated!'), backgroundColor: AppColors.success),
              );
            },
            child: const Text('Save Banner', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadAmcPlans,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4C1D95), Color(0xFF6D28D9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6D28D9).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_user, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AMC Packages & Plan Manager',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Configure plans, annual rates, visit frequencies, and spare parts discounts available on customer "Opt for AMC" screen.',
                                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Actions Row
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Available AMC Plans (${_plans.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _openPromoConfigDialog,
                              icon: const Icon(Icons.campaign_outlined, size: 16),
                              label: const Text('Promo Banner', style: TextStyle(fontSize: 12)),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _openPlanDialog(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Plans List
                    if (_plans.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Text('No AMC plans configured yet. Click "Add Plan" to create one.'),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _plans.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final plan = _plans[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: plan.isActive
                                    ? (plan.badge != null ? AppColors.primary : Colors.grey.shade300)
                                    : Colors.grey.shade400,
                                width: plan.badge != null ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          plan.title,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        if (plan.badge != null && plan.badge!.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF06B6D4),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              plan.badge!,
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: plan.isActive ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            plan.isActive ? 'Active' : 'Inactive',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: plan.isActive ? Colors.green : Colors.grey,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          tooltip: 'Edit Plan',
                                          onPressed: () => _openPlanDialog(existingPlan: plan),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          tooltip: 'Delete Plan',
                                          onPressed: () => _deletePlan(plan),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (plan.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(plan.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Column(
                                        children: [
                                          const Text('RATE / YR', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text('₹${plan.ratePerYear.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                        ],
                                      ),
                                      Container(width: 1, height: 28, color: Colors.grey.shade300),
                                      Column(
                                        children: [
                                          const Text('VISITS / YR', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text('${plan.visitsPerYear} Visits', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      Container(width: 1, height: 28, color: Colors.grey.shade300),
                                      Column(
                                        children: [
                                          const Text('PARTS DISCOUNT', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text(
                                            plan.sparePartsDiscountEnabled
                                                ? '${plan.sparePartsDiscountPercentage.toStringAsFixed(0)}% OFF'
                                                : 'No Discount',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: plan.sparePartsDiscountEnabled ? Colors.green : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (plan.offerText != null && plan.offerText!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.local_offer_outlined, size: 14, color: Colors.orange),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Special Offer: ${plan.offerText}',
                                          style: const TextStyle(fontSize: 11.5, color: Colors.orange, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
