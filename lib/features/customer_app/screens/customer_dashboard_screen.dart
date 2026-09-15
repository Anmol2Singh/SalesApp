// lib/features/customer_app/screens/customer_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/router/app_router.dart';
import 'package:salesapp/features/customer_app/data/repositories/app_repositories.dart';

final customerPurchasedProductsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  String? phone = user.phone;
  String? email = user.email;

  if (phone == null || phone.isEmpty) {
    phone = SupabaseAuthRepository.loggedInPhone;
  }

  if ((phone == null || phone.isEmpty) && (email == null || email.isEmpty)) {
    return [];
  }

  String? customerId;
  if (phone != null && phone.isNotEmpty) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    try {
      final customersRes = await supabase.from('customers').select('id, phone');
      for (final row in customersRes as List) {
        final rowPhone = (row['phone'] as String?)?.replaceAll(RegExp(r'\D'), '') ?? '';
        if (rowPhone.isNotEmpty && (rowPhone == cleanPhone || cleanPhone.endsWith(rowPhone) || rowPhone.endsWith(cleanPhone))) {
          customerId = row['id'] as String;
          break;
        }
      }
    } catch (_) {}
  }

  if (customerId == null && email != null && email.isNotEmpty) {
    try {
      final customersRes = await supabase.from('customers').select('id').eq('email', email).limit(1).maybeSingle();
      if (customersRes != null) {
        customerId = customersRes['id'] as String;
      }
    } catch (_) {}
  }

  if (customerId == null) return [];

  final response = await supabase
      .from('sales_pipelines')
      .select('*, products(*), boqs(*), amc_contracts(*)')
      .eq('customer_id', customerId)
      .or('status.eq.completed,current_step.eq.completed')
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response as List);
});

final productLaunchesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('product_launches')
      .select()
      .eq('is_active', true)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response as List);
});

class CustomerDashboardScreen extends ConsumerWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final purchasesAsync = ref.watch(customerPurchasedProductsProvider);
    final launchesAsync = ref.watch(productLaunchesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(profile?.fullName ?? 'My Customer Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customerPurchasedProductsProvider);
          ref.invalidate(productLaunchesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome back,', style: TextStyle(fontFamily: 'Inter', color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    profile?.fullName ?? 'Valued Customer',
                    style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text('Phone: ${profile?.phone ?? "Logged in"}', style: const TextStyle(fontFamily: 'Inter', color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Purchased Products Section
            const Text('My Purchased Products', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 10),

            purchasesAsync.when(
              data: (deals) {
                if (deals.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('No active purchases linked yet.', style: TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary))),
                  );
                }

                return Column(
                  children: deals.map((deal) {
                    final productData = deal['products'] as Map<String, dynamic>? ?? {};
                    final productName = productData['name'] as String? ?? 'Solar Installation';
                    final category = productData['category'] as String? ?? 'Equipment';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.solar_power, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(productName, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700)),
                                    Text(category, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _renewAmc(context, ref, deal['id'] as String),
                                icon: const Icon(Icons.autorenew, size: 16),
                                label: const Text('Renew AMC'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => context.push('/warranty/${deal['id']}'),
                                icon: const Icon(Icons.card_membership, size: 16),
                                label: const Text('Warranty Card'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(child: Text('Error loading purchases: $e')),
            ),

            const SizedBox(height: 24),

            // Marketing: New Product Launches Showcase
            const Text('New Product Launches & Innovations', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 10),

            launchesAsync.when(
              data: (launches) {
                if (launches.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                    child: const Text('Stay tuned for upcoming IZYHEAT product launches!', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textSecondary)),
                  );
                }

                return SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: launches.length,
                    itemBuilder: (ctx, idx) {
                      final item = launches[idx];
                      final title = item['title'] as String? ?? 'New Product';
                      final desc = item['description'] as String? ?? '';
                      final imgUrl = item['image_url'] as String?;

                      return Container(
                        width: 240,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imgUrl != null && imgUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(imgUrl, height: 90, width: double.infinity, fit: BoxFit.cover),
                              )
                            else
                              Container(
                                height: 90,
                                decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
                                child: const Center(child: Icon(Icons.new_releases_outlined, size: 36, color: AppColors.primary)),
                              ),
                            const SizedBox(height: 8),
                            Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(desc, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renewAmc(BuildContext context, WidgetRef ref, String pipelineId) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('notifications').insert({
        'user_id': supabase.auth.currentUser!.id,
        'title': 'Customer AMC Renewal Request',
        'body': 'A customer requested AMC renewal for deal #$pipelineId.',
        'type': 'amc_renewal_request',
        'related_pipeline_id': pipelineId,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ AMC Renewal Request submitted! Our team will contact you shortly.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}
