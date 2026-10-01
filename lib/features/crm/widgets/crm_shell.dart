import 'dart:ui';
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
        extendBody: true,
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
            Expanded(
              child: Builder(
                builder: (context) {
                  if (!isWide && canAccessCrmDashboard) {
                    final mq = MediaQuery.of(context);
                    final bottomInset = mq.viewPadding.bottom;
                    final topOfNavBar = 69.0 + (bottomInset > 0 ? bottomInset + 4 : 12);
                    return MediaQuery(
                      data: mq.copyWith(
                        viewPadding: mq.viewPadding.copyWith(
                          bottom: topOfNavBar + 4,
                        ),
                      ),
                      child: child,
                    );
                  }
                  return child;
                },
              ),
            ),
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
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected = index == selectedIndex;

                return Expanded(
                  child: InkWell(
                    onTap: () {
                      if (item.isPush) {
                        context.push(item.route);
                      } else {
                        context.go(item.route);
                      }
                    },
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
                                    child: Icon(isSelected ? item.activeIcon : item.icon),
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
