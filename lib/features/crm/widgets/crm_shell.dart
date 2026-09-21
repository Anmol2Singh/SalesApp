import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_role.dart';
import '../../auth/providers/auth_provider.dart';

import '../../../core/router/app_router.dart';

class CrmShell extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const CrmShell({super.key, required this.child, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final profile = ref.watch(currentProfileProvider);
    final isSalesOrAdmin = profile?.roles.any((r) => r.isSalesOrAdmin) ?? false;
    final isCrmStaff = profile?.roles.contains(UserRole.crmStaff) ?? false;
    final isAdmin = profile?.roles.contains(UserRole.admin) ?? false;
    final hasComplaints = profile?.roles.contains(UserRole.serviceHead) ?? false;
    final canAccessCrmDashboard = isSalesOrAdmin || isCrmStaff;
    final canAccessLeads = isSalesOrAdmin || isCrmStaff;
    final canAccessCustomers = isSalesOrAdmin; // CRM staff cannot access Customers unless they have sales/admin

    // Non-sales/non-CRM staff roles (BOQ, factory, material staff) must only access Prospects
    if (!canAccessCrmDashboard && currentRoute == '/crm/dashboard') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/crm/prospects');
      });
    }

    // CRM Staff without sales/admin cannot access Customer list or customer details
    if (!canAccessCustomers && isCrmStaff && currentRoute.startsWith('/crm/customers')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/crm/dashboard');
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }

        if (context.canPop()) {
          context.pop();
          return;
        }

        if (!canAccessCrmDashboard) {
          final role = profile?.primaryRole;
          if (role != null) {
            context.go(getRoleHome(role));
            return;
          }
          context.go(AppRoutes.login);
          return;
        }

        // Sub-screens -> CRM Dashboard
        if (currentRoute.startsWith('/crm/prospects') ||
            currentRoute.startsWith('/crm/leads') ||
            currentRoute.startsWith('/crm/customers')) {
          context.go('/crm/dashboard');
          return;
        }

        // CRM Dashboard -> Admin Dashboard (for Admin)
        if (currentRoute == '/crm/dashboard' && isAdmin) {
          context.go(AppRoutes.adminDashboard);
          return;
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            if (isWide)
              _buildDesktopCrmTabs(
                context,
                isCrmStaff: isCrmStaff,
                canAccessDashboard: canAccessCrmDashboard,
                canAccessLeads: canAccessLeads,
                canAccessCustomers: canAccessCustomers,
              ),
            Expanded(child: child),
          ],
        ),
        bottomNavigationBar: (isWide || !canAccessCrmDashboard)
            ? null
            : _buildMobileCrmBottomNav(
                context,
                isCrmStaff: isCrmStaff,
                canAccessCustomers: canAccessCustomers,
                hasComplaints: hasComplaints,
              ),
      ),
    );
  }

  Widget _buildDesktopCrmTabs(
    BuildContext context, {
    required bool isCrmStaff,
    required bool canAccessDashboard,
    required bool canAccessLeads,
    required bool canAccessCustomers,
  }) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Text('CRM Mode', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 32),
          if (canAccessDashboard)
            _DesktopTab(
              label: 'Dashboard',
              icon: Icons.dashboard,
              isSelected: currentRoute == '/crm/dashboard',
              onTap: () => context.go('/crm/dashboard'),
            ),
          _DesktopTab(
            label: 'Prospects',
            icon: Icons.person_search,
            isSelected: currentRoute.startsWith('/crm/prospects'),
            onTap: () => context.go('/crm/prospects'),
          ),
          if (canAccessLeads)
            _DesktopTab(
              label: 'Leads',
              icon: Icons.trending_up,
              isSelected: currentRoute.startsWith('/crm/leads'),
              onTap: () => context.go('/crm/leads'),
            ),
          if (isCrmStaff)
            _DesktopTab(
              label: "Today's Report",
              icon: Icons.assessment,
              isSelected: currentRoute == '/reports/activity',
              onTap: () => context.push('/reports/activity'),
            ),
          if (canAccessCustomers)
            _DesktopTab(
              label: 'Customers',
              icon: Icons.people,
              isSelected: currentRoute.startsWith('/crm/customers'),
              onTap: () => context.go('/crm/customers'),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileCrmBottomNav(
    BuildContext context, {
    required bool isCrmStaff,
    required bool canAccessCustomers,
    required bool hasComplaints,
  }) {
    final navItems = <({String route, String label, IconData icon, IconData activeIcon, bool isPush})>[
      (route: '/crm/dashboard', label: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, isPush: false),
      (route: '/crm/prospects', label: 'Prospects', icon: Icons.person_search_outlined, activeIcon: Icons.person_search, isPush: false),
      (route: '/crm/leads', label: 'Leads', icon: Icons.trending_up_outlined, activeIcon: Icons.trending_up, isPush: false),
    ];

    if (hasComplaints) {
      navItems.add((
        route: AppRoutes.complaintsDashboard,
        label: 'Complaints',
        icon: Icons.support_agent_outlined,
        activeIcon: Icons.support_agent,
        isPush: false,
      ));
    } else if (canAccessCustomers) {
      navItems.add((
        route: '/crm/customers',
        label: 'Customers',
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        isPush: false,
      ));
    }

    if (isCrmStaff && navItems.length < 5) {
      navItems.add((
        route: '/reports/activity',
        label: "Today's Report",
        icon: Icons.assessment_outlined,
        activeIcon: Icons.assessment,
        isPush: true,
      ));
    } else if (canAccessCustomers && navItems.length < 5 && !navItems.any((i) => i.route == '/crm/customers')) {
      navItems.add((
        route: '/crm/customers',
        label: 'Customers',
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        isPush: false,
      ));
    }

    int selectedIndex = 0;
    for (int i = 0; i < navItems.length; i++) {
      if (currentRoute == navItems[i].route || (navItems[i].route != '/crm/dashboard' && currentRoute.startsWith(navItems[i].route))) {
        selectedIndex = i;
        break;
      }
    }

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
        selectedIndex: selectedIndex.clamp(0, navItems.length - 1),
        onDestinationSelected: (index) {
          final item = navItems[index];
          if (item.isPush) {
            context.push(item.route);
          } else {
            context.go(item.route);
          }
        },
        destinations: navItems.map((item) => NavigationDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.activeIcon),
          label: item.label,
        )).toList(),
      ),
    );
  }
}

class _DesktopTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DesktopTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
