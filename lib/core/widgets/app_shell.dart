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

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({super.key, required this.child, required this.currentRoute});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool? _crmExpanded;
  bool? _complaintsExpanded;

  @override
  Widget build(BuildContext context) {
    ref.watch(realtimeSubscriptionProvider);
    final profile = ref.watch(currentProfileProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;

    if (profile == null) return widget.child;

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

        final home = getRoleHome(profile.primaryRole);
        if (widget.currentRoute != home) {
          context.go(home);
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
                  Expanded(child: widget.child),
                ],
              );
            }
            return widget.child;
          },
        ),
        bottomNavigationBar: MediaQuery.of(context).size.width < 800 &&
                profile.primaryRole != UserRole.customer &&
                !widget.currentRoute.startsWith('/inventory') &&
                widget.currentRoute != AppRoutes.inventory &&
                (!widget.currentRoute.startsWith('/crm') ||
                    profile.primaryRole == UserRole.boq ||
                    profile.primaryRole == UserRole.factory ||
                    profile.primaryRole == UserRole.purchase)
            ? _buildNavBar(context, profile.roles, unreadCount, false)
            : null,
      ),
    );
  }

  Widget _buildNavRail(BuildContext context, List<UserRole> roles, int unreadCount, bool isWide) {
    // Determine nav rail colors based on current route
    Color navBgColor = Theme.of(context).scaffoldBackgroundColor;
    Color selectedTextColor = AppColors.primary;
    Color unselectedTextColor = AppColors.textSecondary;
    Color selectedBgColor = AppColors.primary.withOpacity(0.1);
    Color logoColor = AppColors.textPrimary;
    Color logoIconBg = AppColors.primary.withOpacity(0.1);
    Color logoIcon = AppColors.primary;

    if (widget.currentRoute == AppRoutes.adminDashboard || 
        widget.currentRoute == AppRoutes.salesDashboard || 
        widget.currentRoute.startsWith('/pipelines') || 
        widget.currentRoute.startsWith('/customers') ||
        widget.currentRoute.startsWith('/factory') || 
        widget.currentRoute.startsWith('/purchase') || 
        widget.currentRoute.startsWith('/amc') ||
        widget.currentRoute.startsWith('/complaints')) {
      navBgColor = const Color(0xFF1E1B4B);
      selectedTextColor = Colors.white;
      unselectedTextColor = Colors.white70;
      selectedBgColor = Colors.white.withOpacity(0.2);
      logoColor = Colors.white;
      logoIconBg = Colors.white.withOpacity(0.2);
      logoIcon = Colors.white;
    } else if (widget.currentRoute.startsWith('/crm') || 
               widget.currentRoute.startsWith('/admin') || 
               widget.currentRoute.startsWith('/inventory') ||
               widget.currentRoute.startsWith('/notifications')) {
      navBgColor = AppColors.primary;
      selectedTextColor = Colors.white;
      unselectedTextColor = Colors.white70;
      selectedBgColor = Colors.white.withOpacity(0.2);
      logoColor = Colors.white;
      logoIconBg = Colors.white.withOpacity(0.2);
      logoIcon = Colors.white;
    }

    final hasAdminOrManager = roles.any((r) => r == UserRole.admin || r == UserRole.manager);
    final hasSales = roles.any((r) => r == UserRole.sales || r == UserRole.salesHead);
    final hasCrm = roles.any((r) => r == UserRole.crmStaff || r == UserRole.admin || r == UserRole.manager || r == UserRole.sales || r == UserRole.salesHead);
    final hasComplaints = roles.any((r) => r == UserRole.admin || r == UserRole.manager || r == UserRole.serviceHead);
    final isTechnician = roles.any((r) => r == UserRole.technician);
    final isBoq = roles.any((r) => r == UserRole.boq);
    final isFactory = roles.any((r) => r == UserRole.factory);
    final isPurchase = roles.any((r) => r == UserRole.purchase);

    // Expansion status
    final isCrmActive = widget.currentRoute.startsWith('/crm');
    final isComplaintsActive = widget.currentRoute.startsWith('/complaints') || 
        widget.currentRoute.startsWith('/technician') || 
        widget.currentRoute.contains('complaint') ||
        widget.currentRoute == AppRoutes.complaintsDashboard ||
        widget.currentRoute == AppRoutes.assignTechnician ||
        widget.currentRoute == AppRoutes.serviceHistory;

    final crmExpanded = _crmExpanded ?? isCrmActive;
    final complaintsExpanded = _complaintsExpanded ?? isComplaintsActive;

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
          const SizedBox(height: 36),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 1. Primary Dashboard Item
                if (hasAdminOrManager)
                  _buildNavItemTile(
                    route: AppRoutes.adminDashboard,
                    label: 'Dashboard',
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(Icons.dashboard),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  )
                else if (hasSales)
                  _buildNavItemTile(
                    route: AppRoutes.salesDashboard,
                    label: 'Dashboard',
                    icon: const Icon(Icons.bar_chart_outlined),
                    selectedIcon: const Icon(Icons.bar_chart),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  )
                else if (isTechnician)
                  _buildNavItemTile(
                    route: AppRoutes.technicianDashboard,
                    label: 'Home',
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  )
                else if (isBoq)
                  _buildNavItemTile(
                    route: AppRoutes.boqDashboard,
                    label: 'Dashboard',
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(Icons.dashboard),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  )
                else if (isFactory)
                  _buildNavItemTile(
                    route: AppRoutes.factoryQueue,
                    label: 'Dashboard',
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(Icons.dashboard),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  )
                else if (isPurchase)
                  _buildNavItemTile(
                    route: AppRoutes.purchaseQueue,
                    label: 'Dashboard',
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(Icons.dashboard),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  )
                else if (hasComplaints)
                  _buildNavItemTile(
                    route: AppRoutes.complaintsDashboard,
                    label: 'Dashboard',
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(Icons.dashboard),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  )
                else if (hasCrm)
                  _buildNavItemTile(
                    route: '/crm/dashboard',
                    label: 'Dashboard',
                    icon: const Icon(Icons.dashboard_outlined),
                    selectedIcon: const Icon(Icons.dashboard),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  ),

                // Factory Queue (when not already primary dashboard)
                if (isFactory && (hasAdminOrManager || hasSales || hasComplaints || hasCrm || isBoq))
                  _buildNavItemTile(
                    route: AppRoutes.factoryQueue,
                    label: 'Factory Queue',
                    icon: const Icon(Icons.precision_manufacturing_outlined),
                    selectedIcon: const Icon(Icons.precision_manufacturing),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  ),

                // Purchase Queue (when not already primary dashboard)
                if (isPurchase && (hasAdminOrManager || hasSales || hasComplaints || hasCrm || isBoq || isFactory))
                  _buildNavItemTile(
                    route: AppRoutes.purchaseQueue,
                    label: 'Purchase Queue',
                    icon: const Icon(Icons.shopping_cart_outlined),
                    selectedIcon: const Icon(Icons.shopping_cart),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  ),

                // BOQ Dashboard (when not already primary dashboard)
                if (isBoq && (hasAdminOrManager || hasSales || hasComplaints || hasCrm))
                  _buildNavItemTile(
                    route: AppRoutes.boqDashboard,
                    label: 'BOQ',
                    icon: const Icon(Icons.calculate_outlined),
                    selectedIcon: const Icon(Icons.calculate),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  ),

                // 2. Customers (Independent, above Deals)
                if (hasAdminOrManager || hasSales || isBoq)
                  _buildNavItemTile(
                    route: AppRoutes.customers,
                    label: 'Customers',
                    icon: const Icon(Icons.business_outlined),
                    selectedIcon: const Icon(Icons.business),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  ),

                // 3. Deals / Pipelines
                if (hasAdminOrManager || hasSales || isBoq)
                  _buildNavItemTile(
                    route: AppRoutes.pipelines,
                    label: 'Deals',
                    icon: const Icon(Icons.handshake_outlined),
                    selectedIcon: const Icon(Icons.handshake),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  ),

                // 4. Alerts / Notifications
                _buildNavItemTile(
                  route: AppRoutes.notifications,
                  label: 'Alerts',
                  icon: const Icon(Icons.notifications_outlined),
                  selectedIcon: const Icon(Icons.notifications),
                  selectedTextColor: selectedTextColor,
                  unselectedTextColor: unselectedTextColor,
                  selectedBgColor: selectedBgColor,
                ),

                // 5. Cascaded CRM Section
                if (hasCrm) ...[
                  _buildGroupHeader(
                    label: 'CRM',
                    icon: isCrmActive ? Icons.people_alt : Icons.people_alt_outlined,
                    isExpanded: crmExpanded,
                    isActive: isCrmActive,
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                    onTap: () {
                      setState(() {
                        _crmExpanded = !crmExpanded;
                      });
                    },
                  ),
                  if (crmExpanded) ...[
                    _buildChildTile(
                      label: 'Dashboard',
                      route: '/crm/dashboard',
                      icon: const Icon(Icons.dashboard_outlined),
                      selectedTextColor: selectedTextColor,
                      unselectedTextColor: unselectedTextColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildChildTile(
                      label: 'Prospects',
                      route: '/crm/prospects',
                      icon: const Icon(Icons.person_search_outlined),
                      selectedTextColor: selectedTextColor,
                      unselectedTextColor: unselectedTextColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildChildTile(
                      label: 'Leads',
                      route: '/crm/leads',
                      icon: const Icon(Icons.trending_up_outlined),
                      selectedTextColor: selectedTextColor,
                      unselectedTextColor: unselectedTextColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    if (hasAdminOrManager || hasSales)
                      _buildChildTile(
                        label: 'Customers',
                        route: '/crm/customers',
                        icon: const Icon(Icons.people_outline),
                        selectedTextColor: selectedTextColor,
                        unselectedTextColor: unselectedTextColor,
                        selectedBgColor: selectedBgColor,
                      ),
                  ],
                ],

                // 5. Cascaded Complaints Section
                if (hasComplaints) ...[
                  _buildGroupHeader(
                    label: 'Complaints',
                    icon: isComplaintsActive ? Icons.support_agent : Icons.support_agent_outlined,
                    isExpanded: complaintsExpanded,
                    isActive: isComplaintsActive,
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                    onTap: () {
                      setState(() {
                        _complaintsExpanded = !complaintsExpanded;
                      });
                    },
                  ),
                  if (complaintsExpanded) ...[
                    _buildChildTile(
                      label: 'Dashboard',
                      route: AppRoutes.complaintsDashboard,
                      icon: const Icon(Icons.dashboard_outlined),
                      selectedTextColor: selectedTextColor,
                      unselectedTextColor: unselectedTextColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildChildTile(
                      label: 'Complaints',
                      route: AppRoutes.complaintsList,
                      icon: const Icon(Icons.assignment_outlined),
                      selectedTextColor: selectedTextColor,
                      unselectedTextColor: unselectedTextColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildChildTile(
                      label: 'Assign',
                      route: AppRoutes.assignTechnician,
                      icon: const Icon(Icons.assignment_ind_outlined),
                      selectedTextColor: selectedTextColor,
                      unselectedTextColor: unselectedTextColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildChildTile(
                      label: 'Technicians',
                      route: '/complaints/technicians',
                      icon: const Icon(Icons.engineering_outlined),
                      selectedTextColor: selectedTextColor,
                      unselectedTextColor: unselectedTextColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildChildTile(
                      label: 'History',
                      route: AppRoutes.serviceHistory,
                      icon: const Icon(Icons.history_outlined),
                      selectedTextColor: selectedTextColor,
                      unselectedTextColor: unselectedTextColor,
                      selectedBgColor: selectedBgColor,
                    ),
                  ],
                ],

                // 6. Technician Specific items (if technician role only)
                if (isTechnician && !hasComplaints) ...[
                  _buildNavItemTile(
                    route: AppRoutes.technicianTasks,
                    label: 'My Tasks',
                    icon: const Icon(Icons.assignment_outlined),
                    selectedIcon: const Icon(Icons.assignment),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  ),
                  _buildNavItemTile(
                    route: AppRoutes.serviceHistory,
                    label: 'History',
                    icon: const Icon(Icons.history_outlined),
                    selectedIcon: const Icon(Icons.history),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  ),
                ],

                // 7. Inventory
                if (hasAdminOrManager)
                  _buildNavItemTile(
                    route: AppRoutes.inventory,
                    label: 'Inventory',
                    icon: const Icon(Icons.inventory_2_outlined),
                    selectedIcon: const Icon(Icons.inventory_2),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  ),

                // 8. Search PDF
                if (hasAdminOrManager || hasSales)
                  _buildNavItemTile(
                    route: AppRoutes.searchPdf,
                    label: 'Search PDF',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    selectedIcon: const Icon(Icons.picture_as_pdf),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  ),
              ],
            ),
          ),

          // Admin item pinned at the bottom
          if (hasAdminOrManager)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildNavItemTile(
                route: AppRoutes.userManagement,
                label: 'Admin',
                icon: const Icon(Icons.admin_panel_settings_outlined),
                selectedIcon: const Icon(Icons.admin_panel_settings),
                selectedTextColor: selectedTextColor,
                unselectedTextColor: unselectedTextColor,
                selectedBgColor: selectedBgColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItemTile({
    required String route,
    required String label,
    required Widget icon,
    required Widget selectedIcon,
    required Color selectedTextColor,
    required Color unselectedTextColor,
    required Color selectedBgColor,
  }) {
    final isSelected = widget.currentRoute == route || (route != '/' && widget.currentRoute.startsWith(route));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
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
          child: isSelected ? selectedIcon : icon,
        ),
        title: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(
            fontFamily: 'Inter',
            color: isSelected ? selectedTextColor : unselectedTextColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
          child: Text(label),
        ),
        onTap: () => context.go(route),
      ),
    );
  }

  Widget _buildGroupHeader({
    required String label,
    required IconData icon,
    required bool isExpanded,
    required bool isActive,
    required Color selectedTextColor,
    required Color unselectedTextColor,
    required Color selectedBgColor,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? selectedBgColor.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          icon,
          size: 20,
          color: isActive ? selectedTextColor : unselectedTextColor,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            color: isActive ? selectedTextColor : unselectedTextColor,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: AnimatedRotation(
          turns: isExpanded ? 0.5 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: (isActive ? selectedTextColor : unselectedTextColor).withOpacity(0.7),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildChildTile({
    required String label,
    required String route,
    required Widget icon,
    required Color selectedTextColor,
    required Color unselectedTextColor,
    required Color selectedBgColor,
  }) {
    final isSelected = widget.currentRoute == route;
    return Padding(
      padding: const EdgeInsets.only(left: 32, right: 16, top: 1, bottom: 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.white.withOpacity(0.15)) : null,
        ),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: IconTheme(
            data: IconThemeData(
              color: isSelected ? selectedTextColor : unselectedTextColor.withOpacity(0.8),
              size: 16,
            ),
            child: icon,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              color: isSelected ? selectedTextColor : unselectedTextColor.withOpacity(0.85),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          onTap: () => context.go(route),
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, List<UserRole> roles, int unreadCount, bool isWide) {
    final items = _getNavItems(roles, isWide);
    final currentIndex = _getCurrentIndex(items);

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
            color: AppColors.textSecondary,
          );
        }),
      ),
      child: NavigationBar(
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
      ),
    );
  }

  int _getCurrentIndex(List<_NavItem> items) {
    int bestIndex = 0;
    int maxMatchLength = -1;
    for (int i = 0; i < items.length; i++) {
      if (widget.currentRoute == items[i].route) {
        return i;
      }
      if (widget.currentRoute.startsWith(items[i].route) && items[i].route.length > maxMatchLength) {
        maxMatchLength = items[i].route.length;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  List<_NavItem> _getNavItems(List<UserRole> roles, bool isWide) {
    final bool isComplaintsRoute = widget.currentRoute.contains('complaint') ||
        widget.currentRoute.contains('technician') ||
        widget.currentRoute.contains('history') ||
        widget.currentRoute.contains('service') ||
        widget.currentRoute == AppRoutes.complaintsDashboard ||
        widget.currentRoute == AppRoutes.assignTechnician ||
        widget.currentRoute == AppRoutes.serviceHistory;

    final Map<String, _NavItem> uniqueItems = {};

    void addItem(_NavItem item) {
      if (!uniqueItems.containsKey(item.route)) {
        uniqueItems[item.route] = item;
      }
    }

    final bool hasAdminOrManager = roles.any((r) => r == UserRole.admin || r == UserRole.manager);
    final bool hasSales = roles.any((r) => r == UserRole.sales || r == UserRole.salesHead);
    final bool hasCrm = roles.any((r) => r == UserRole.crmStaff);
    final bool hasComplaints = roles.any((r) => r == UserRole.serviceHead);
    final bool isBoq = roles.any((r) => r == UserRole.boq);
    final bool isFactory = roles.any((r) => r == UserRole.factory);
    final bool isPurchase = roles.any((r) => r == UserRole.purchase);
    final bool isTechnician = roles.any((r) => r == UserRole.technician);

    // 1. Complaints routes
    if (!isWide && (hasAdminOrManager || hasComplaints) && isComplaintsRoute) {
      addItem(const _NavItem(route: AppRoutes.complaintsDashboard, label: 'Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
      addItem(const _NavItem(route: AppRoutes.complaintsList, label: 'Complaints', icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment)));
      addItem(const _NavItem(route: AppRoutes.assignTechnician, label: 'Assign', icon: Icon(Icons.assignment_ind_outlined), selectedIcon: Icon(Icons.assignment_ind)));
      
      if (hasCrm) {
        addItem(const _NavItem(route: '/crm/dashboard', label: 'CRM', icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt)));
      } else if (hasSales) {
        addItem(const _NavItem(route: AppRoutes.salesDashboard, label: 'Sales', icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart)));
      } else if (isFactory) {
        addItem(const _NavItem(route: AppRoutes.factoryQueue, label: 'Factory', icon: Icon(Icons.precision_manufacturing_outlined), selectedIcon: Icon(Icons.precision_manufacturing)));
      } else if (isPurchase) {
        addItem(const _NavItem(route: AppRoutes.purchaseQueue, label: 'Purchase', icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart)));
      } else if (isBoq) {
        addItem(const _NavItem(route: AppRoutes.boqDashboard, label: 'BOQ', icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate)));
      } else {
        addItem(const _NavItem(route: '/complaints/technicians', label: 'Technicians', icon: Icon(Icons.engineering_outlined), selectedIcon: Icon(Icons.engineering)));
      }
      addItem(const _NavItem(route: AppRoutes.serviceHistory, label: 'History', icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history)));
      return uniqueItems.values.toList();
    }

    // 2. Admin / Manager
    if (hasAdminOrManager) {
      addItem(const _NavItem(route: AppRoutes.adminDashboard, label: 'Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
      addItem(const _NavItem(route: AppRoutes.customers, label: 'Customers', icon: Icon(Icons.business_outlined), selectedIcon: Icon(Icons.business)));
      addItem(const _NavItem(route: AppRoutes.pipelines, label: 'Deals', icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake)));
      addItem(const _NavItem(route: AppRoutes.notifications, label: 'Alerts', icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications)));
      addItem(const _NavItem(route: AppRoutes.userManagement, label: 'Admin', icon: Icon(Icons.admin_panel_settings_outlined), selectedIcon: Icon(Icons.admin_panel_settings)));
      return uniqueItems.values.toList();
    }

    // 3. Sales / SalesHead
    if (hasSales) {
      addItem(const _NavItem(route: AppRoutes.salesDashboard, label: 'Dashboard', icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart)));
      addItem(const _NavItem(route: AppRoutes.customers, label: 'Customers', icon: Icon(Icons.business_outlined), selectedIcon: Icon(Icons.business)));
      addItem(const _NavItem(route: AppRoutes.pipelines, label: 'Deals', icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake)));
      addItem(const _NavItem(route: AppRoutes.notifications, label: 'Alerts', icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications)));
      if (hasComplaints) {
        addItem(const _NavItem(route: AppRoutes.complaintsDashboard, label: 'Complaints', icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent)));
      } else {
        addItem(const _NavItem(route: '/crm/dashboard', label: 'CRM', icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt)));
      }
      return uniqueItems.values.toList();
    }

    // 4. CRM Staff
    if (hasCrm) {
      addItem(const _NavItem(route: '/crm/dashboard', label: 'CRM Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
      addItem(const _NavItem(route: '/crm/prospects', label: 'Prospects', icon: Icon(Icons.person_search_outlined), selectedIcon: Icon(Icons.person_search)));
      addItem(const _NavItem(route: '/crm/leads', label: 'Leads', icon: Icon(Icons.trending_up_outlined), selectedIcon: Icon(Icons.trending_up)));
      if (hasComplaints) {
        addItem(const _NavItem(route: AppRoutes.complaintsDashboard, label: 'Complaints', icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent)));
      } else if (isFactory) {
        addItem(const _NavItem(route: AppRoutes.factoryQueue, label: 'Factory', icon: Icon(Icons.precision_manufacturing_outlined), selectedIcon: Icon(Icons.precision_manufacturing)));
      } else if (isPurchase) {
        addItem(const _NavItem(route: AppRoutes.purchaseQueue, label: 'Purchase', icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart)));
      } else if (isBoq) {
        addItem(const _NavItem(route: AppRoutes.boqDashboard, label: 'BOQ', icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate)));
      } else {
        addItem(const _NavItem(route: '/reports/activity', label: "Today's Report", icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment)));
      }
      addItem(const _NavItem(route: AppRoutes.notifications, label: 'Alerts', icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications)));
      return uniqueItems.values.toList();
    }

    // 5. Service Head (when not on complaints route)
    if (hasComplaints) {
      addItem(const _NavItem(route: AppRoutes.complaintsDashboard, label: 'Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
      addItem(const _NavItem(route: AppRoutes.complaintsList, label: 'Complaints', icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment)));
      addItem(const _NavItem(route: AppRoutes.assignTechnician, label: 'Assign', icon: Icon(Icons.assignment_ind_outlined), selectedIcon: Icon(Icons.assignment_ind)));
      if (isFactory) {
        addItem(const _NavItem(route: AppRoutes.factoryQueue, label: 'Factory', icon: Icon(Icons.precision_manufacturing_outlined), selectedIcon: Icon(Icons.precision_manufacturing)));
      } else if (isPurchase) {
        addItem(const _NavItem(route: AppRoutes.purchaseQueue, label: 'Purchase', icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart)));
      } else if (isBoq) {
        addItem(const _NavItem(route: AppRoutes.boqDashboard, label: 'BOQ', icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate)));
      } else {
        addItem(const _NavItem(route: '/complaints/technicians', label: 'Technicians', icon: Icon(Icons.engineering_outlined), selectedIcon: Icon(Icons.engineering)));
      }
      addItem(const _NavItem(route: AppRoutes.serviceHistory, label: 'History', icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history)));
      return uniqueItems.values.toList();
    }

    // 6. Technician
    if (isTechnician) {
      addItem(const _NavItem(route: AppRoutes.technicianDashboard, label: 'Home', icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home)));
      addItem(const _NavItem(route: AppRoutes.technicianTasks, label: 'My Tasks', icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment)));
      addItem(const _NavItem(route: AppRoutes.serviceHistory, label: 'History', icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history)));
      return uniqueItems.values.toList();
    }

    // 7. BOQ
    if (isBoq) {
      addItem(const _NavItem(route: AppRoutes.boqDashboard, label: 'Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
      addItem(const _NavItem(route: AppRoutes.pipelines, label: 'Deals', icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work)));
      addItem(const _NavItem(route: '/crm/prospects', label: 'Prospects', icon: Icon(Icons.person_search_outlined), selectedIcon: Icon(Icons.person_search)));
      if (isFactory) {
        addItem(const _NavItem(route: AppRoutes.factoryQueue, label: 'Factory', icon: Icon(Icons.precision_manufacturing_outlined), selectedIcon: Icon(Icons.precision_manufacturing)));
      } else if (isPurchase) {
        addItem(const _NavItem(route: AppRoutes.purchaseQueue, label: 'Purchase', icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart)));
      } else {
        addItem(const _NavItem(route: AppRoutes.notifications, label: 'Alerts', icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications)));
      }
      addItem(const _NavItem(route: AppRoutes.notifications, label: 'Alerts', icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications)));
      return uniqueItems.values.take(5).toList();
    }

    // 8. Factory
    if (isFactory) {
      addItem(const _NavItem(route: AppRoutes.factoryQueue, label: 'Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
      if (isPurchase) {
        addItem(const _NavItem(route: AppRoutes.purchaseQueue, label: 'Purchase', icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart)));
      }
      addItem(const _NavItem(route: '/crm/prospects', label: 'Prospects', icon: Icon(Icons.person_search_outlined), selectedIcon: Icon(Icons.person_search)));
      addItem(const _NavItem(route: AppRoutes.pipelines, label: 'Deals', icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work)));
      addItem(const _NavItem(route: AppRoutes.notifications, label: 'Alerts', icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications)));
      return uniqueItems.values.take(5).toList();
    }

    // 9. Purchase
    if (isPurchase) {
      addItem(const _NavItem(route: AppRoutes.purchaseQueue, label: 'Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
      addItem(const _NavItem(route: '/crm/prospects', label: 'Prospects', icon: Icon(Icons.person_search_outlined), selectedIcon: Icon(Icons.person_search)));
      addItem(const _NavItem(route: AppRoutes.pipelines, label: 'Deals', icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work)));
      addItem(const _NavItem(route: AppRoutes.notifications, label: 'Alerts', icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications)));
      return uniqueItems.values.take(5).toList();
    }

    return uniqueItems.values.take(5).toList();
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
