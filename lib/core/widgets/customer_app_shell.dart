import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/customer_app/core/theme/app_theme.dart';
import '../../features/customer_app/data/providers/app_providers.dart';
import '../providers/realtime_provider.dart';
import 'package:flutter/services.dart';

class CustomerAppShell extends ConsumerStatefulWidget {
  final Widget child;

  const CustomerAppShell({super.key, required this.child});

  @override
  ConsumerState<CustomerAppShell> createState() => _CustomerAppShellState();
}

class _CustomerAppShellState extends ConsumerState<CustomerAppShell> {
  int _getSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location == '/bookings') return 1;
    if (location == '/invoices') return 2;
    if (location == '/support') return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/customer/dashboard');
        break;
      case 1:
        context.go('/bookings');
        break;
      case 2:
        context.go('/invoices');
        break;
      case 3:
        context.go('/support');
        break;
    }
  }

  Widget _buildNavRail(BuildContext context, int selectedIndex, bool hasActiveComplaints) {
    Color navBgColor = const Color(0xFF1E1B4B);
    Color selectedTextColor = Colors.white;
    Color unselectedTextColor = Colors.white70;
    Color selectedBgColor = Colors.white.withOpacity(0.18);
    Color logoColor = Colors.white;
    Color logoIconBg = Colors.white.withOpacity(0.18);
    Color logoIcon = Colors.white;

    final items = [
      {'icon': Icons.home_outlined, 'selectedIcon': Icons.home, 'label': 'Home', 'route': '/customer/dashboard'},
      {'icon': Icons.assignment_outlined, 'selectedIcon': Icons.assignment, 'label': 'Complaints', 'route': '/bookings', 'hasBadge': hasActiveComplaints},
      {'icon': Icons.receipt_long_outlined, 'selectedIcon': Icons.receipt_long, 'label': 'Invoices', 'route': '/invoices'},
      {'icon': Icons.chat_bubble_outline, 'selectedIcon': Icons.chat_bubble, 'label': 'Support', 'route': '/support'},
    ];

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: navBgColor,
        border: Border(
          right: BorderSide(
            color: AppColors.borderColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo area
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: logoIconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.whatshot_rounded, color: logoIcon, size: 28),
              ),
              const SizedBox(width: 12),
              Text(
                'IZYHEAT',
                style: TextStyle(
                  color: logoColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIndex == index;
                final showBadge = item['hasBadge'] == true;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? selectedBgColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.go(item['route'] as String),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Badge(
                            isLabelVisible: showBadge,
                            backgroundColor: Colors.amberAccent,
                            smallSize: 8,
                            child: Icon(
                              isSelected ? item['selectedIcon'] as IconData : item['icon'] as IconData,
                              color: isSelected ? selectedTextColor : unselectedTextColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item['label'] as String,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: isSelected ? selectedTextColor : unselectedTextColor,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(realtimeSubscriptionProvider);
    final int selectedIndex = _getSelectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderCol = isDark ? AppColors.borderColor : const Color(0xFFE5E7EB);
    final scaffoldBg = isDark ? AppColors.bgPrimary : AppColors.bgPrimaryLight;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final requests = ref.watch(serviceRequestsProvider).value ?? [];
    final hasActiveComplaints = requests.any((r) =>
        r.status != 'completed' &&
        r.status != 'cancelled' &&
        r.status != 'closed' &&
        r.status != 'resolved');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // If not on Home tab, navigate back to Home instead of exiting
        final currentIdx = _getSelectedIndex(context);
        if (currentIdx != 0) {
          context.go('/customer/dashboard');
          return;
        }
        
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit IZYHEAT App?'),
            content: const Text('Are you sure you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: isDesktop 
            ? Row(
                children: [
                  _buildNavRail(context, selectedIndex, hasActiveComplaints),
                  VerticalDivider(thickness: 1, width: 1, color: borderCol),
                  Expanded(child: widget.child),
                ],
              )
            : Builder(
                builder: (context) {
                  final mq = MediaQuery.of(context);
                  final bottomInset = mq.viewPadding.bottom;
                  final topOfNavBar = 69.0 + (bottomInset > 0 ? bottomInset + 4 : 12);
                  return MediaQuery(
                    data: mq.copyWith(
                      padding: mq.padding.copyWith(
                        bottom: topOfNavBar + 8,
                      ),
                      viewPadding: mq.viewPadding.copyWith(
                        bottom: topOfNavBar + 8,
                      ),
                    ),
                    child: widget.child,
                  );
                },
              ),
        bottomNavigationBar: isDesktop ? null : Builder(
          builder: (context) {
            final bottomInset = MediaQuery.of(context).padding.bottom;
            final screenWidth = MediaQuery.of(context).size.width;
            final navItems = [
              {
                'icon': Icons.home_outlined,
                'activeIcon': Icons.home_rounded,
                'label': 'Home',
                'hasBadge': false,
              },
              {
                'icon': Icons.assignment_outlined,
                'activeIcon': Icons.assignment_rounded,
                'label': 'Complaints',
                'hasBadge': hasActiveComplaints,
              },
              {
                'icon': Icons.receipt_long_outlined,
                'activeIcon': Icons.receipt_long_rounded,
                'label': 'Invoices',
                'hasBadge': false,
              },
              {
                'icon': Icons.chat_bubble_outline_rounded,
                'activeIcon': Icons.chat_bubble_rounded,
                'label': 'Support',
                'hasBadge': false,
              },
            ];

            return Container(
              color: Colors.transparent,
              padding: EdgeInsets.fromLTRB(
                screenWidth > 500 ? (screenWidth - 480) / 2 : 16,
                6,
                screenWidth > 500 ? (screenWidth - 480) / 2 : 16,
                bottomInset > 0 ? bottomInset + 4 : 12,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: 69,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.78)
                          : Colors.white.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.45)
                              : const Color(0xFF1E3A5F).withValues(alpha: 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(navItems.length, (index) {
                        final item = navItems[index];
                        final isSelected = index == selectedIndex;
                        final showBadge = item['hasBadge'] == true;

                        return Expanded(
                          child: InkWell(
                            onTap: () => _onItemTapped(index, context),
                            borderRadius: BorderRadius.circular(22),
                            splashColor: AppColors.primary.withValues(alpha: 0.1),
                            highlightColor: Colors.transparent,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSelected ? 12 : 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark
                                          ? const Color(0xFF1E3A5F).withValues(alpha: 0.35)
                                          : const Color(0xFF1E3A5F).withValues(alpha: 0.1))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: isSelected
                                      ? Border.all(
                                          color: (isDark ? const Color(0xFF60A5FA) : AppColors.primary)
                                              .withValues(alpha: 0.25),
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedScale(
                                      scale: isSelected ? 1.15 : 1.0,
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeOutBack,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 220),
                                        transitionBuilder: (child, anim) => FadeTransition(
                                          opacity: anim,
                                          child: ScaleTransition(scale: anim, child: child),
                                        ),
                                        child: KeyedSubtree(
                                          key: ValueKey<bool>(isSelected),
                                          child: Badge(
                                            isLabelVisible: showBadge,
                                            backgroundColor: isDark
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFFE8A020),
                                            smallSize: 8,
                                            child: Icon(
                                              (isSelected
                                                  ? item['activeIcon']
                                                  : item['icon']) as IconData,
                                              size: 21,
                                              color: isSelected
                                                  ? (isDark ? const Color(0xFF60A5FA) : AppColors.primary)
                                                  : (isDark ? Colors.white60 : AppColors.textSecondary),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      curve: Curves.easeInOut,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: isSelected ? 10.5 : 9.5,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        letterSpacing: -0.2,
                                        color: isSelected
                                            ? (isDark ? const Color(0xFF93C5FD) : AppColors.primary)
                                            : (isDark ? Colors.white60 : AppColors.textSecondary),
                                      ),
                                      child: Text(
                                        item['label'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
