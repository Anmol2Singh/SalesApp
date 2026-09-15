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
    final isAdmin = profile?.primaryRole == UserRole.admin || profile?.roles.contains(UserRole.admin) == true;

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
            if (isWide) _buildDesktopCrmTabs(context, isSalesOrAdmin),
            Expanded(child: child),
          ],
        ),
        bottomNavigationBar: isWide ? null : _buildMobileCrmBottomNav(context, isSalesOrAdmin),
      ),
    );
  }

  Widget _buildDesktopCrmTabs(BuildContext context, bool isSalesOrAdmin) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Text('CRM Mode', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 32),
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
          if (isSalesOrAdmin) ...[
            _DesktopTab(
              label: 'Leads',
              icon: Icons.trending_up,
              isSelected: currentRoute.startsWith('/crm/leads'),
              onTap: () => context.go('/crm/leads'),
            ),
            _DesktopTab(
              label: 'Customers',
              icon: Icons.people,
              isSelected: currentRoute.startsWith('/crm/customers'),
              onTap: () => context.go('/crm/customers'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileCrmBottomNav(BuildContext context, bool isSalesOrAdmin) {
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
        selectedIndex: _getSelectedIndex(currentRoute, isSalesOrAdmin),
        onDestinationSelected: (index) {
          if (!isSalesOrAdmin) {
            switch (index) {
              case 0:
                context.go('/crm/dashboard');
                break;
              case 1:
                context.go('/crm/prospects');
                break;
            }
            return;
          }

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
              context.go('/crm/customers');
              break;
          }
        },
        destinations: [
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
          if (isSalesOrAdmin) ...[
            const NavigationDestination(
              icon: Icon(Icons.trending_up_outlined),
              selectedIcon: Icon(Icons.trending_up),
              label: 'Leads',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Customers',
            ),
          ],
        ],
      ),
    );
  }

  int _getSelectedIndex(String route, bool isSalesOrAdmin) {
    if (!isSalesOrAdmin) {
      if (route.startsWith('/crm/prospects')) return 1;
      return 0;
    }
    if (route == '/crm/dashboard') return 0;
    if (route.startsWith('/crm/prospects')) return 1;
    if (route.startsWith('/crm/leads')) return 2;
    if (route.startsWith('/crm/customers')) return 3;
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
