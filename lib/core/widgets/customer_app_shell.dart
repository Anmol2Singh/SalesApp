import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/customer_app/core/theme/app_theme.dart';
import '../../features/customer_app/data/providers/app_providers.dart';
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
    Color navBgColor = AppColors.primary;
    Color selectedTextColor = Colors.white;
    Color unselectedTextColor = Colors.white70;
    Color selectedBgColor = Colors.white.withOpacity(0.2);
    Color logoColor = Colors.white;
    Color logoIconBg = Colors.white.withOpacity(0.2);
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
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? selectedBgColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    leading: Badge(
                      isLabelVisible: showBadge,
                      backgroundColor: Colors.amberAccent,
                      smallSize: 8,
                      child: IconTheme(
                        data: IconThemeData(
                          color: isSelected ? selectedTextColor : unselectedTextColor,
                          size: 20,
                        ),
                        child: Icon(
                          isSelected ? item['selectedIcon'] as IconData : item['icon'] as IconData,
                        ),
                      ),
                    ),
                    title: Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: isSelected ? selectedTextColor : unselectedTextColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => context.go(item['route'] as String),
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
    final int selectedIndex = _getSelectedIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final navBg = isDark ? AppColors.bgSecondary : Colors.white;
    final borderCol = isDark ? AppColors.borderColor : const Color(0xFFE5E7EB);
    final selectedCol = isDark ? AppColors.accent : AppColors.primary;
    final unselectedCol = isDark ? AppColors.textSecondary : const Color(0xFF9CA3AF);
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
            : widget.child,
        bottomNavigationBar: isDesktop ? null : Container(
          decoration: BoxDecoration(
            color: navBg,
            border: Border(
              top: BorderSide(color: borderCol, width: 1),
            ),
            boxShadow: isDark ? [] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: selectedIndex,
            onTap: (index) => _onItemTapped(index, context),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: selectedCol,
            unselectedItemColor: unselectedCol,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home, color: selectedCol),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: hasActiveComplaints,
                  backgroundColor: AppColors.accent,
                  smallSize: 8,
                  child: const Icon(Icons.assignment_outlined),
                ),
                activeIcon: Badge(
                  isLabelVisible: hasActiveComplaints,
                  backgroundColor: AppColors.accent,
                  smallSize: 8,
                  child: Icon(Icons.assignment, color: selectedCol),
                ),
                label: 'Complaints',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long, color: selectedCol),
                label: 'Invoices',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble, color: selectedCol),
                label: 'Support',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
