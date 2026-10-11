// lib/core/widgets/app_shell.dart
// Main navigation shell for authenticated users

import 'dart:ui';
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
  bool? _installationsExpanded;

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRoute != widget.currentRoute) {
      final isCrm = widget.currentRoute.startsWith('/crm');
      final isComplaints = widget.currentRoute.startsWith('/complaints') || 
          widget.currentRoute.startsWith('/technician') || 
          widget.currentRoute.contains('complaint') ||
          widget.currentRoute == AppRoutes.complaintsDashboard ||
          widget.currentRoute == AppRoutes.assignTechnician ||
          widget.currentRoute == AppRoutes.serviceHistory;
      final isInstallations = widget.currentRoute.startsWith('/installations') ||
          widget.currentRoute == AppRoutes.installationsDashboard ||
          widget.currentRoute == AppRoutes.installationsList ||
          widget.currentRoute == AppRoutes.bookInstallation ||
          widget.currentRoute == AppRoutes.assignInstallation ||
          widget.currentRoute == AppRoutes.installationHistory;

      _crmExpanded = isCrm;
      _complaintsExpanded = isComplaints;
      _installationsExpanded = isInstallations;
    }
  }

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
        extendBody: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;
            final showsNavBar = !isWide &&
                profile.primaryRole != UserRole.customer &&
                !widget.currentRoute.startsWith('/inventory') &&
                widget.currentRoute != AppRoutes.inventory &&
                (!widget.currentRoute.startsWith('/crm') ||
                    profile.primaryRole == UserRole.boq ||
                    profile.primaryRole == UserRole.factory ||
                    profile.primaryRole == UserRole.purchase);

            if (isWide && profile.primaryRole != UserRole.customer) {
              return Row(
                children: [
                  _buildNavRail(context, profile.roles, unreadCount, isWide),
                  Expanded(child: widget.child),
                ],
              );
            }

            // On mobile with the floating nav bar, inject extra bottom padding
            // into MediaQuery so inner Scaffold FABs and scrollable content
            // automatically clear the ~90px floating glass nav bar.
            if (showsNavBar) {
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
        widget.currentRoute.startsWith('/complaints') ||
        widget.currentRoute == AppRoutes.dailyTasks) {
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

    final hasAdmin = roles.any((r) => r == UserRole.admin);
    final hasAdminOrManager = roles.any((r) => r == UserRole.admin || r == UserRole.manager);
    final hasSales = roles.any((r) => r == UserRole.sales || r == UserRole.salesHead);
    final hasCrm = roles.any((r) => r == UserRole.crmStaff || r == UserRole.admin || r == UserRole.manager || r == UserRole.sales || r == UserRole.salesHead);
    final hasComplaints = roles.any((r) => r == UserRole.admin || r == UserRole.manager || r == UserRole.serviceHead);
    final hasInstallations = roles.any((r) => r == UserRole.admin || r == UserRole.manager || r == UserRole.serviceHead || r == UserRole.salesHead);
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

    final isInstallationsActive = widget.currentRoute.startsWith('/installations') ||
        widget.currentRoute == AppRoutes.installationsDashboard ||
        widget.currentRoute == AppRoutes.installationsList ||
        widget.currentRoute == AppRoutes.bookInstallation ||
        widget.currentRoute == AppRoutes.assignInstallation ||
        widget.currentRoute == AppRoutes.installationHistory;

    final crmExpanded = _crmExpanded ?? isCrmActive;
    final complaintsExpanded = _complaintsExpanded ?? isComplaintsActive;
    final installationsExpanded = _installationsExpanded ?? isInstallationsActive;

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
                else if (isBoq || isFactory || isPurchase)
                  _buildNavItemTile(
                    route: AppRoutes.boqDashboard,
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

                // 5. Daily Tasks Completed (Available for all roles)
                _buildNavItemTile(
                  route: AppRoutes.dailyTasks,
                  label: 'Daily Tasks',
                  icon: const Icon(Icons.fact_check_outlined),
                  selectedIcon: const Icon(Icons.fact_check),
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
                        final next = !crmExpanded;
                        _crmExpanded = next;
                        if (next) {
                          _complaintsExpanded = false;
                          _installationsExpanded = false;
                        }
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
                        final next = !complaintsExpanded;
                        _complaintsExpanded = next;
                        if (next) {
                          _crmExpanded = false;
                          _installationsExpanded = false;
                        }
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

                // 5.5 Cascaded Installations Section
                if (hasInstallations) ...[
                  _buildGroupHeader(
                    label: 'Installations',
                    icon: isInstallationsActive ? Icons.build_circle : Icons.build_circle_outlined,
                    isExpanded: installationsExpanded,
                    isActive: isInstallationsActive,
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                    onTap: () {
                      setState(() {
                        final next = !installationsExpanded;
                        _installationsExpanded = next;
                        if (next) {
                          _crmExpanded = false;
                          _complaintsExpanded = false;
                        }
                      });
                    },
                  ),
                  if (installationsExpanded) ...[
                    _buildChildTile(
                      label: 'Dashboard',
                      route: AppRoutes.installationsDashboard,
                      icon: const Icon(Icons.dashboard_outlined),
                      selectedTextColor: selectedTextColor,
                      unselectedTextColor: unselectedTextColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildChildTile(
                      label: 'Installations',
                      route: AppRoutes.installationsList,
                      icon: const Icon(Icons.assignment_outlined),
                      selectedTextColor: selectedTextColor,
                      unselectedTextColor: unselectedTextColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildChildTile(
                      label: 'Assign',
                      route: AppRoutes.assignInstallation,
                      icon: const Icon(Icons.assignment_ind_outlined),
                      selectedTextColor: selectedTextColor,
                      unselectedTextColor: unselectedTextColor,
                      selectedBgColor: selectedBgColor,
                    ),
                    _buildChildTile(
                      label: 'History',
                      route: AppRoutes.installationHistory,
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

                // 8. Quotations Hub (Strictly Admin only)
                if (hasAdmin)
                  _buildNavItemTile(
                    route: AppRoutes.heatPumpQuotationHub,
                    label: 'Quotations',
                    icon: const Icon(Icons.request_quote_outlined),
                    selectedIcon: const Icon(Icons.request_quote),
                    selectedTextColor: selectedTextColor,
                    unselectedTextColor: unselectedTextColor,
                    selectedBgColor: selectedBgColor,
                  ),

                // 9. Search PDF
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;

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
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 69,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.78)
                  : Colors.white.withValues(alpha: 0.82),
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
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = index == currentIndex;

                return Expanded(
                  child: InkWell(
                    onTap: () => context.go(item.route),
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
                                  child: IconTheme(
                                    data: IconThemeData(
                                      size: 21,
                                      color: isSelected
                                          ? (isDark ? const Color(0xFF60A5FA) : AppColors.primary)
                                          : (isDark ? Colors.white60 : AppColors.textSecondary),
                                    ),
                                    child: isSelected ? item.selectedIcon : item.icon,
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
                                item.label,
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
    final bool isComplaintsRoute = widget.currentRoute.startsWith('/complaints') ||
        widget.currentRoute.startsWith('/technician') ||
        widget.currentRoute == AppRoutes.complaintsDashboard ||
        widget.currentRoute == AppRoutes.assignTechnician ||
        widget.currentRoute == AppRoutes.serviceHistory;

    final bool isInstallationsRoute = widget.currentRoute.startsWith('/installations') ||
        widget.currentRoute == AppRoutes.installationsDashboard ||
        widget.currentRoute == AppRoutes.installationsList ||
        widget.currentRoute == AppRoutes.bookInstallation ||
        widget.currentRoute == AppRoutes.assignInstallation ||
        widget.currentRoute == AppRoutes.installationHistory;

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
    final bool hasInstallations = roles.any((r) => r == UserRole.admin || r == UserRole.manager || r == UserRole.serviceHead || r == UserRole.salesHead);
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
      } else if (isBoq || isFactory || isPurchase) {
        addItem(const _NavItem(route: AppRoutes.boqDashboard, label: 'Operations', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
      } else {
        addItem(const _NavItem(route: '/complaints/technicians', label: 'Technicians', icon: Icon(Icons.engineering_outlined), selectedIcon: Icon(Icons.engineering)));
      }
      addItem(const _NavItem(route: AppRoutes.serviceHistory, label: 'History', icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history)));
      return uniqueItems.values.toList();
    }

    // 1.5 Installations routes
    if (!isWide && hasInstallations && isInstallationsRoute) {
      addItem(const _NavItem(route: AppRoutes.installationsDashboard, label: 'Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
      addItem(const _NavItem(route: AppRoutes.installationsList, label: 'Installations', icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment)));
      addItem(const _NavItem(route: AppRoutes.assignInstallation, label: 'Assign', icon: Icon(Icons.assignment_ind_outlined), selectedIcon: Icon(Icons.assignment_ind)));
      addItem(const _NavItem(route: AppRoutes.installationHistory, label: 'History', icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history)));
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
      } else if (isBoq || isFactory || isPurchase) {
        addItem(const _NavItem(route: AppRoutes.boqDashboard, label: 'Operations', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
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
      if (isBoq || isFactory || isPurchase) {
        addItem(const _NavItem(route: AppRoutes.boqDashboard, label: 'Operations', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
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

    // 7. Operations (BOQ/Factory/Purchase)
    if (isBoq || isFactory || isPurchase) {
      addItem(const _NavItem(route: AppRoutes.boqDashboard, label: 'Dashboard', icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard)));
      addItem(const _NavItem(route: AppRoutes.pipelines, label: 'Deals', icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work)));
      addItem(const _NavItem(route: '/crm/prospects', label: 'Prospects', icon: Icon(Icons.person_search_outlined), selectedIcon: Icon(Icons.person_search)));
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
