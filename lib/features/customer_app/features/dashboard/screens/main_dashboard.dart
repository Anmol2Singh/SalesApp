import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:salesapp/core/router/app_router.dart';
import 'package:salesapp/features/auth/providers/auth_provider.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/data/models/data_models.dart';
import 'package:salesapp/features/customer_app/data/repositories/app_repositories.dart';
import 'package:salesapp/features/customer_app/data/providers/app_providers.dart';
import 'package:salesapp/features/customer_app/shared/widgets/glass_card.dart';
import 'package:salesapp/features/customer_app/features/dashboard/widgets/product_card.dart';

class ActivityEvent {
  final String title;
  final String subtitle;
  final DateTime date;
  final IconData icon;
  final Color iconColor;
  final String status;

  ActivityEvent({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.icon,
    required this.iconColor,
    required this.status,
  });
}

final customerActivityProvider = FutureProvider<List<ActivityEvent>>((ref) async {
  try {
    final logs = await ref.watch(activityLogsProvider.future);
    return logs.map((log) {
      final eventType = log['event_type'] as String? ?? 'general';
      final title = log['title'] as String? ?? 'Update';
      final body = log['body'] as String? ?? '';
      final createdAtStr = log['created_at'] as String;
      final date = DateTime.tryParse(createdAtStr) ?? DateTime.now();

      IconData icon = Icons.info_outline;
      Color iconColor = AppColors.primary;
      String status = 'INFO';

      if (eventType.contains('booking')) {
        icon = Icons.event_available;
        iconColor = AppColors.warning;
        status = 'BOOKED';
      } else if (eventType.contains('invoice')) {
        icon = Icons.receipt_long;
        iconColor = AppColors.success;
        status = 'PAID';
      } else if (eventType.contains('amc')) {
        icon = Icons.verified_user;
        iconColor = AppColors.accent;
        status = 'AMC';
      } else if (eventType.contains('ticket')) {
        icon = Icons.support_agent;
        iconColor = AppColors.danger;
        status = 'SUPPORT';
      }

      return ActivityEvent(
        title: title,
        subtitle: body,
        date: date,
        icon: icon,
        iconColor: iconColor,
        status: status,
      );
    }).toList();
  } catch (e) {
    return [];
  }
});

class MainDashboard extends ConsumerWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final advProductsAsync = ref.watch(advertisementProductsProvider);
    final profileAsync = ref.watch(userProfileProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.bgPrimary : AppColors.bgPrimaryLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
            expandedHeight: 185,
            pinned: true,
            backgroundColor: const Color(0xFF1E1B4B),
            clipBehavior: Clip.antiAlias,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: ref.watch(notificationsViewedProvider)
                    ? const Icon(Icons.notifications_outlined, color: Colors.white)
                    : const Badge(
                        smallSize: 8,
                        backgroundColor: Colors.amberAccent,
                        child: Icon(Icons.notifications_outlined, color: Colors.white),
                      ),
                tooltip: 'Alerts & Notifications',
                onPressed: () => _showNotificationsSheet(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Logout',
                onPressed: () => _showLogoutDialog(context, ref),
              ),
              const SizedBox(width: 8),
            ],
            title: const Text(
              'IZYHEAT Portal',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Deep indigo → violet gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1E1B4B),
                          Color(0xFF4C1D95),
                          Color(0xFF6D28D9),
                        ],
                      ),
                    ),
                  ),
                  // Radial glow top-right
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Radial glow bottom-left
                  Positioned(
                    bottom: -20,
                    left: -40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF06B6D4).withOpacity(0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.push('/profile'),
                              child: profileAsync.when(
                                data: (profile) {
                                  final name = profile['name'] ?? 'Customer';
                                  final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : 'C';
                                  return Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 2,
                                      ),
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        firstLetter,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                loading: () => Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                error: (_, __) => Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  child: const Icon(Icons.person, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Good ${_getGreeting()}',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.6),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  profileAsync.when(
                                    data: (profile) => Text(
                                      profile['name'] ?? 'Customer',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    loading: () => const Text('Loading...', style: TextStyle(color: Colors.white)),
                                    error: (_, __) => const Text('Customer 👋', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Mini stat pills row
                        Row(
                          children: [
                            _buildHeaderStat(
                              'Today',
                              DateFormat('dd MMM').format(DateTime.now()),
                              Icons.calendar_today_outlined,
                            ),
                            const SizedBox(width: 12),
                            _buildHeaderStat(
                              'Portal',
                              'CUSTOMER',
                              Icons.person_pin_outlined,
                            ),
                            const SizedBox(width: 12),
                            _buildHeaderStat(
                              'Status',
                              'ONLINE',
                              Icons.circle,
                              iconColor: const Color(0xFF10B981),
                              iconSize: 10,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // [A] STATUS SUMMARY STRIP
                productsAsync.when(
                  data: (products) {
                    final activeCount = products.length;
                    final amcCount = products
                        .where((p) => p.amcStatus == 'active')
                        .length;

                    return _buildStatusStrip(
                      context,
                      activeCount,
                      amcCount,
                    );
                  },
                  loading: () => _buildStatusStrip(context, 0, 0),
                  error: (_, __) => _buildStatusStrip(context, 0, 0),
                ),

                const SizedBox(height: 24),

                // [B] MY PURCHASED PRODUCTS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'My Products',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        productsAsync.maybeWhen(
                          data: (prods) => prods.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${prods.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                          orElse: () {
                            final cached = SupabaseCustomerRepository.cachedProducts;
                            if (cached != null && cached.isNotEmpty) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${cached.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: 'Refresh products',
                      onPressed: () => ref.refresh(productsProvider),
                      color: subtitleColor,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                productsAsync.when(
                  data: (products) => _buildProductsList(context, ref, products, textColor, subtitleColor, isDark),
                  loading: () {
                    final cached = SupabaseCustomerRepository.cachedProducts ?? productsAsync.valueOrNull;
                    if (cached != null && cached.isNotEmpty) {
                      return _buildProductsList(context, ref, cached, textColor, subtitleColor, isDark);
                    }
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    );
                  },
                  error: (e, _) {
                    final cached = SupabaseCustomerRepository.cachedProducts;
                    if (cached != null && cached.isNotEmpty) {
                      return _buildProductsList(context, ref, cached, textColor, subtitleColor, isDark);
                    }
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text('Error loading products: $e', style: TextStyle(color: textColor)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // [D] QUICK ACTIONS
                _buildQuickActionCard(
                  context,
                  'Opt for AMC',
                  'Secure your products with scheduled maintenance',
                  Icons.verified_user,
                  AppColors.accent,
                  () => context.push('/amc_avail'),
                ),

            const SizedBox(height: 28),

            // [C2] ALSO AVAILABLE (ADVERTISEMENT)
            Text(
              'Also Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Explore other high-performance heating solutions from our catalog',
              style: TextStyle(
                fontSize: 12,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 12),
            advProductsAsync.when(
              data: (advProducts) {
                if (advProducts.isEmpty) {
                  return const SizedBox.shrink();
                }
                return SizedBox(
                  height: 280,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.none,
                    itemCount: advProducts.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      return AdvProductCard(product: advProducts[index]);
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text('Error loading advertisement products: $e', style: TextStyle(color: textColor)),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // [D] RECENT ACTIVITY STRIP
            Text(
              'Recent Activity',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ref.watch(customerActivityProvider).when(
              data: (events) {
                if (events.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No recent activity found.',
                        style: TextStyle(color: subtitleColor, fontSize: 13),
                      ),
                    ),
                  );
                }
                final recent = events.take(4).toList();
                return Column(
                  children: List.generate(recent.length, (index) {
                    return _TimelineEventTile(
                      event: recent[index],
                      isFirst: index == 0,
                      isLast: index == recent.length - 1,
                    );
                  }),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Error loading activity: $e', style: const TextStyle(color: AppColors.danger)),
                ),
              ),
            ),
                const SizedBox(height: 80), // extra padding for bottom bar
              ])),
            ),
          ],
        ),
        ),
        ),
      );
    }

    void _showNotificationsSheet(BuildContext context, WidgetRef ref) {
      ref.read(notificationsViewedProvider.notifier).state = true;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final invoices = ref.read(invoicesProvider).value ?? [];
      final requests = ref.read(serviceRequestsProvider).value ?? [];
      final advProducts = ref.read(advertisementProductsProvider).value ?? [];
      final products = ref.read(productsProvider).value ?? [];

      final List<Map<String, dynamic>> notifications = [];

      // 1. Invoices
      for (final inv in invoices.take(3)) {
        notifications.add({
          'icon': Icons.receipt_long,
          'color': Colors.teal,
          'title': 'Invoice Received',
          'subtitle': 'Invoice #${inv.invoiceId.length > 8 ? inv.invoiceId.substring(0, 8) : inv.invoiceId} for ₹${inv.amount.toStringAsFixed(0)} (${inv.status.toUpperCase()})',
          'route': '/invoices',
        });
      }

      // 2. Complaints
      for (final req in requests.take(3)) {
        notifications.add({
          'icon': Icons.assignment_outlined,
          'color': const Color(0xFF6D28D9),
          'title': 'Complaint Update',
          'subtitle': 'Ticket ${req.problemCode}: ${req.status.toUpperCase()} (${req.productId})',
          'route': '/bookings',
        });
      }

      // 3. New Product Launches
      for (final adv in advProducts.take(2)) {
        notifications.add({
          'icon': Icons.new_releases_outlined,
          'color': Colors.deepOrange,
          'title': 'New Product Introduced',
          'subtitle': '${adv.productName} is now available in catalog. Tap to explore.',
          'route': '/product/${adv.productId}',
        });
      }

      // 4. AMC Approved
      for (final p in products.where((p) => p.amcStatus == 'active').take(2)) {
        notifications.add({
          'icon': Icons.verified_user,
          'color': Colors.green,
          'title': 'AMC Contract Active',
          'subtitle': 'Annual maintenance is active for ${p.productName}. Free service visits included.',
          'route': '/profile',
        });
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: isDark ? AppColors.bgSecondary : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Alerts & Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                if (notifications.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No new alerts or notifications at this time.')),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final n = notifications[idx];
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          tileColor: isDark ? Colors.white10 : Colors.grey.shade50,
                          leading: CircleAvatar(
                            backgroundColor: (n['color'] as Color).withOpacity(0.15),
                            child: Icon(n['icon'] as IconData, color: n['color'] as Color, size: 20),
                          ),
                          title: Text(n['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(n['subtitle'] as String, style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () {
                            Navigator.pop(ctx);
                            final route = n['route'] as String;
                            context.push(route);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    String _getGreeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Morning';
      if (hour < 17) return 'Afternoon';
      return 'Evening';
    }

    static Widget _buildHeaderStat(
      String label,
      String value,
      IconData icon, {
      Color iconColor = Colors.white,
      double iconSize = 14,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: iconSize),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

  Widget _buildStatusStrip(
    BuildContext context,
    int activeCount,
    int amcCount,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Active Systems',
            activeCount.toString(),
            Icons.dns_outlined,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            context,
            'Active AMC Contracts',
            amcCount.toString(),
            Icons.verified_user_outlined,
            AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      borderRadius: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: subtitleColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out of your customer portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(
    BuildContext context,
    WidgetRef ref,
    List<Product> products,
    Color textColor,
    Color subtitleColor,
    bool isDark,
  ) {
    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 40, color: subtitleColor),
            const SizedBox(height: 10),
            Text(
              'No products registered yet',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Purchased products linked to your account will appear here.',
              style: TextStyle(fontSize: 12, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.refresh(productsProvider),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Check for Updates', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < products.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          HeroProductCard(product: products[i]),
        ],
      ],
    );
  }
}

class _TimelineEventTile extends StatelessWidget {
  final ActivityEvent event;
  final bool isFirst;
  final bool isLast;

  const _TimelineEventTile({
    required this.event,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vertical timeline connector & dot
        Column(
          children: [
            Container(
              width: 2,
              height: 12,
              color: isFirst ? Colors.transparent : (isDark ? AppColors.borderColor : AppColors.borderColorLight),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: event.iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: event.iconColor.withOpacity(0.3), width: 1.5),
              ),
              child: Icon(event.icon, color: event.iconColor, size: 16),
            ),
            Container(
              width: 2,
              height: 32,
              color: isLast ? Colors.transparent : (isDark ? AppColors.borderColor : AppColors.borderColorLight),
            ),
          ],
        ),
        const SizedBox(width: 16),
        // Timeline content card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              borderRadius: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: event.iconColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.status,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: event.iconColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(event.date),
                    style: TextStyle(
                      fontSize: 10,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

