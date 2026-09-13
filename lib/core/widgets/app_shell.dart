// lib/core/widgets/app_shell.dart
// Main navigation shell for authenticated users

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/user_role.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/notifications/providers/notifications_provider.dart';
import '../router/app_router.dart';
import '../providers/realtime_provider.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({super.key, required this.child, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(realtimeSubscriptionProvider);
    final profile = ref.watch(currentProfileProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;

    if (profile == null) return child;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        if (context.canPop()) {
          context.pop();
          return;
        }
        
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit IZYHEAT?'),
            content: const Text("You'll be signed out of nothing — just closing the app."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;
            if (isWide && profile.primaryRole != UserRole.customer) {
              return Row(
                children: [
                  _buildNavRail(context, profile.roles, unreadCount, isWide),
                  Expanded(child: child),
                ],
              );
            }
            return child;
          },
        ),
        bottomNavigationBar: MediaQuery.of(context).size.width < 800 && profile.primaryRole != UserRole.customer && !currentRoute.startsWith('/crm')
            ? _buildNavBar(context, profile.roles, unreadCount, false)
            : null,
      ),
    );
  }

  
  Widget _buildNavRail(BuildContext context, List<UserRole> roles, int unreadCount, bool isWide) {
    final items = _getNavItems(roles, isWide);
    if (items.isEmpty) return const SizedBox.shrink();
    
    final currentIndex = _getCurrentIndex(items);

    // Determine nav rail colors based on current route
    Color navBgColor = Theme.of(context).scaffoldBackgroundColor;
    Color selectedTextColor = AppColors.primary;
    Color unselectedTextColor = AppColors.textSecondary;
    Color selectedBgColor = AppColors.primary.withOpacity(0.1);
    Color logoColor = AppColors.textPrimary;
    Color logoIconBg = AppColors.primary.withOpacity(0.1);
    Color logoIcon = AppColors.primary;

    if (currentRoute == AppRoutes.adminDashboard || 
        currentRoute == AppRoutes.salesDashboard || 
        currentRoute.startsWith('/pipelines') || 
        currentRoute.startsWith('/factory') || 
        currentRoute.startsWith('/purchase') || 
        currentRoute.startsWith('/amc') ||
        currentRoute.startsWith('/complaints')) {
      navBgColor = const Color(0xFF1E1B4B);
      selectedTextColor = Colors.white;
      unselectedTextColor = Colors.white70;
      selectedBgColor = Colors.white.withOpacity(0.2);
      logoColor = Colors.white;
      logoIconBg = Colors.white.withOpacity(0.2);
      logoIcon = Colors.white;
    } else if (currentRoute.startsWith('/customers') || 
               currentRoute.startsWith('/admin') || 
               currentRoute.startsWith('/inventory') ||
               currentRoute.startsWith('/notifications')) {
      navBgColor = AppColors.primary;
      selectedTextColor = Colors.white;
      unselectedTextColor = Colors.white70;
      selectedBgColor = Colors.white.withOpacity(0.2);
      logoColor = Colors.white;
      logoIconBg = Colors.white.withOpacity(0.2);
      logoIcon = Colors.white;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 250,
      decoration: BoxDecoration(
        color: navBgColor,
        border: Border(
          right: BorderSide(
            color: AppColors.border.withOpacity(0.2),
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: logoIconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.whatshot_rounded, color: logoIcon, size: 28),
              ),
              const SizedBox(width: 12),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  color: logoColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
                child: const Text('IZYHEAT'),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = currentIndex == index;
                
                // Skip admin item here, we'll put it at the bottom
                if (item.label == 'Admin') return const SizedBox.shrink();

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? selectedBgColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    leading: IconTheme(
                      data: IconThemeData(
                        color: isSelected ? selectedTextColor : unselectedTextColor,
                        size: 20,
                      ),
                      child: isSelected ? item.selectedIcon : item.icon,
                    ),
                    title: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: isSelected ? selectedTextColor : unselectedTextColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      ),
                      child: Text(item.label),
                    ),
                    onTap: () => context.go(item.route),
                  ),
                );
              },
            ),
          ),
          // Admin item at the bottom
          if (items.any((i) => i.label == 'Admin')) ...[
            Builder(
              builder: (context) {
                final adminItem = items.firstWhere((i) => i.label == 'Admin');
                final adminIndex = items.indexOf(adminItem);
                final isSelected = currentIndex == adminIndex;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? selectedBgColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      leading: IconTheme(
                        data: IconThemeData(
                          color: isSelected ? selectedTextColor : unselectedTextColor,
                          size: 20,
                        ),
                        child: isSelected ? adminItem.selectedIcon : adminItem.icon,
                      ),
                      title: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: isSelected ? selectedTextColor : unselectedTextColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                        child: Text(adminItem.label),
                      ),
                      onTap: () => context.go(adminItem.route),
                    ),
                  ),
                );
              }
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildNavBar(BuildContext context, List<UserRole> roles, int unreadCount, bool isWide) {
    final items = _getNavItems(roles, isWide);
    final currentIndex = _getCurrentIndex(items);

    return NavigationBar(
      selectedIndex: currentIndex.clamp(0, items.length - 1),
      onDestinationSelected: (index) {
        context.go(items[index].route);
      },
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySurface,
      destinations: items.map((item) {
        return NavigationDestination(
          icon: item.icon,
          selectedIcon: item.selectedIcon,
          label: item.label,
        );
      }).toList(),
    );
  }

  int _getCurrentIndex(List<_NavItem> items) {
    int bestIndex = 0;
    int maxMatchLength = -1;
    for (int i = 0; i < items.length; i++) {
      if (currentRoute == items[i].route) {
        return i;
      }
      if (currentRoute.startsWith(items[i].route) && items[i].route.length > maxMatchLength) {
        maxMatchLength = items[i].route.length;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  List<_NavItem> _getNavItems(List<UserRole> roles, bool isWide) {
    final bool isComplaintsRoute = currentRoute.contains('complaint') ||
        currentRoute.contains('technician') ||
        currentRoute.contains('history') ||
        currentRoute.contains('service') ||
        currentRoute == AppRoutes.complaintsDashboard ||
        currentRoute == AppRoutes.assignTechnician ||
        currentRoute == AppRoutes.serviceHistory;

    final Map<String, _NavItem> uniqueItems = {};

    void addItem(_NavItem item) {
      if (!uniqueItems.containsKey(item.route)) {
        uniqueItems[item.route] = item;
      }
    }

    // On mobile, we MUST split the nav items to avoid bottom bar overflow (max 5 items)
    bool hasAdminOrManagerOrServiceHead = roles.any((r) => r == UserRole.admin || r == UserRole.manager || r == UserRole.serviceHead);
    if (!isWide && hasAdminOrManagerOrServiceHead && isComplaintsRoute) {
      addItem(const _NavItem(route: AppRoutes.complaintsDashboard, label: 'Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
      addItem(const _NavItem(route: AppRoutes.complaintsList, label: 'Complaints', icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment)));
      addItem(const _NavItem(route: AppRoutes.assignTechnician, label: 'Assign', icon: Icon(Icons.assignment_ind_outlined), selectedIcon: Icon(Icons.assignment_ind)));
      addItem(const _NavItem(route: '/complaints/technicians', label: 'Technicians', icon: Icon(Icons.engineering_outlined), selectedIcon: Icon(Icons.engineering)));
      addItem(const _NavItem(route: AppRoutes.serviceHistory, label: 'History', icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history)));
      return uniqueItems.values.toList();
    }
    
    for (final role in roles) {
      switch (role) {
        case UserRole.admin:
        case UserRole.manager:
          addItem(const _NavItem(route: AppRoutes.adminDashboard, label: 'Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
          addItem(const _NavItem(route: AppRoutes.customers, label: 'Customers', icon: Icon(Icons.business_outlined), selectedIcon: Icon(Icons.business)));
          addItem(const _NavItem(route: AppRoutes.pipelines, label: 'Deals', icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake)));
          addItem(const _NavItem(route: AppRoutes.notifications, label: 'Alerts', icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications)));
          addItem(const _NavItem(route: AppRoutes.userManagement, label: 'Admin', icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings)));
          if (isWide) {
            addItem(const _NavItem(route: '/crm/dashboard', label: 'CRM', icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt)));
            addItem(const _NavItem(route: AppRoutes.complaintsDashboard, label: 'Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
            addItem(const _NavItem(route: AppRoutes.complaintsList, label: 'Complaints', icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment)));
            addItem(const _NavItem(route: AppRoutes.assignTechnician, label: 'Assign', icon: Icon(Icons.assignment_ind_outlined), selectedIcon: Icon(Icons.assignment_ind)));
            addItem(const _NavItem(route: '/complaints/technicians', label: 'Technicians', icon: Icon(Icons.engineering_outlined), selectedIcon: Icon(Icons.engineering)));
            addItem(const _NavItem(route: AppRoutes.serviceHistory, label: 'History', icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history)));
            addItem(const _NavItem(route: AppRoutes.inventory, label: 'Inventory', icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2)));
          }
          break;
        case UserRole.sales:
        case UserRole.salesHead:
          addItem(const _NavItem(route: AppRoutes.salesDashboard, label: 'Dashboard', icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart)));
          addItem(const _NavItem(route: AppRoutes.customers, label: 'Customers', icon: Icon(Icons.business_outlined), selectedIcon: Icon(Icons.business)));
          addItem(const _NavItem(route: AppRoutes.pipelines, label: 'Deals', icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake)));
          addItem(const _NavItem(route: AppRoutes.notifications, label: 'Alerts', icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications)));
          addItem(const _NavItem(route: '/crm/dashboard', label: 'CRM', icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt)));
          break;
        case UserRole.crmStaff:
          addItem(const _NavItem(route: '/crm/dashboard', label: 'CRM', icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt)));
          break;
        case UserRole.serviceHead:
          addItem(const _NavItem(route: AppRoutes.complaintsDashboard, label: 'Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
          addItem(const _NavItem(route: AppRoutes.complaintsList, label: 'Complaints', icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment)));
          addItem(const _NavItem(route: AppRoutes.assignTechnician, label: 'Assign', icon: Icon(Icons.assignment_ind_outlined), selectedIcon: Icon(Icons.assignment_ind)));
          addItem(const _NavItem(route: '/complaints/technicians', label: 'Technicians', icon: Icon(Icons.engineering_outlined), selectedIcon: Icon(Icons.engineering)));
          addItem(const _NavItem(route: AppRoutes.serviceHistory, label: 'History', icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history)));
          break;
        case UserRole.technician:
          addItem(const _NavItem(route: AppRoutes.technicianDashboard, label: 'My Tasks', icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build)));
          addItem(const _NavItem(route: AppRoutes.serviceHistory, label: 'History', icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history)));
          break;
        case UserRole.factory:
        case UserRole.purchase:
        case UserRole.boq:
          addItem(const _NavItem(route: AppRoutes.salesDashboard, label: 'Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
          addItem(const _NavItem(route: AppRoutes.pipelines, label: 'Deals', icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake)));
          addItem(const _NavItem(route: AppRoutes.notifications, label: 'Alerts', icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications)));
          break;
        case UserRole.customer:
          break;
      }
    }
    
    return uniqueItems.values.toList();
  }
}

class _NavItem {
  final String route;
  final String label;
  final Widget icon;
  final Widget selectedIcon;

  const _NavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
