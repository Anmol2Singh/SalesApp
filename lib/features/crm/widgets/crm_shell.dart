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
    final isSalesOrAdmin = profile?.primaryRole.isSalesOrAdmin ?? false;
    final isCrmStaff = profile?.primaryRole == UserRole.crmStaff;
    final isAdmin = profile?.primaryRole == UserRole.admin || profile?.roles.contains(UserRole.admin) == true;
    final canAccessCrmDashboard = isSalesOrAdmin || isCrmStaff;
    final canAccessLeads = isSalesOrAdmin || isCrmStaff;
    final canAccessCustomers = isSalesOrAdmin; // CRM staff cannot access Customers

    // Non-sales/non-CRM staff roles (BOQ, factory, material staff) must only access Prospects
    if (!canAccessCrmDashboard && currentRoute == '/crm/dashboard') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/crm/prospects');
      });
    }

    // CRM Staff cannot access Customer list or customer details
    if (isCrmStaff && currentRoute.startsWith('/crm/customers')) {
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
  }) {
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_search_outlined),
        selectedIcon: Icon(Icons.person_search),
        label: 'Prospects',
      ),
      const NavigationDestination(
        icon: Icon(Icons.trending_up_outlined),
        selectedIcon: Icon(Icons.trending_up),
        label: 'Leads',
      ),
      if (isCrmStaff)
        const NavigationDestination(
          icon: Icon(Icons.assessment_outlined),
          selectedIcon: Icon(Icons.assessment),
          label: "Today's Report",
        ),
      if (canAccessCustomers)
        const NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Customers',
        ),
    ];

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 64,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
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
        selectedIndex: _getSelectedIndex(currentRoute, canAccessCustomers, isCrmStaff: isCrmStaff),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/crm/dashboard');
              break;
            case 1:
              context.go('/crm/prospects');
              break;
            case 2:
              context.go('/crm/leads');
              break;
            case 3:
              if (isCrmStaff) {
                context.push('/reports/activity');
              } else if (canAccessCustomers) {
                context.go('/crm/customers');
              }
              break;
            case 4:
              if (isCrmStaff && canAccessCustomers) {
                context.go('/crm/customers');
              }
              break;
          }
        },
        destinations: destinations,
      ),
    );
  }

  int _getSelectedIndex(String route, bool canAccessCustomers, {bool isCrmStaff = false}) {
    if (route == '/crm/dashboard') return 0;
    if (route.startsWith('/crm/prospects')) return 1;
    if (route.startsWith('/crm/leads')) return 2;
    if (isCrmStaff && route == '/reports/activity') return 3;
    if (canAccessCustomers && route.startsWith('/crm/customers')) {
      return isCrmStaff ? 4 : 3;
    }
    return 0;
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
