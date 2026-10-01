import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/user_role.dart';
import '../router/app_router.dart';
import '../../features/auth/providers/auth_provider.dart';

class DashboardSwitcherButton extends ConsumerWidget {
  final Color iconColor;
  final double iconSize;

  const DashboardSwitcherButton({
    super.key,
    this.iconColor = Colors.white,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) return const SizedBox.shrink();

    final uniqueRoles = profile.roles.toSet();

    final hasAdmin = uniqueRoles.contains(UserRole.admin) || uniqueRoles.contains(UserRole.manager);
    final hasSales = uniqueRoles.contains(UserRole.sales) || uniqueRoles.contains(UserRole.salesHead);
    final hasService = uniqueRoles.contains(UserRole.serviceHead);
    final hasCrm = uniqueRoles.contains(UserRole.crmStaff);
    final hasTechnician = uniqueRoles.contains(UserRole.technician);
    final hasOperations = uniqueRoles.contains(UserRole.boq) ||
        uniqueRoles.contains(UserRole.factory) ||
        uniqueRoles.contains(UserRole.purchase);

    int distinctDashboards = 0;
    if (hasAdmin) distinctDashboards++;
    if (hasSales) distinctDashboards++;
    if (hasService) distinctDashboards++;
    if (hasCrm) distinctDashboards++;
    if (hasTechnician) distinctDashboards++;
    if (hasOperations) distinctDashboards++;

    if (distinctDashboards <= 1) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: Icon(Icons.apps_rounded, color: iconColor, size: iconSize),
      tooltip: 'Switch Dashboard',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: const Color(0xFF1E293B),
      elevation: 6,
      onSelected: (route) {
        context.go(route);
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];

        items.add(
          const PopupMenuItem<String>(
            enabled: false,
            height: 36,
            child: Text(
              'SWITCH DASHBOARD',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: Colors.white54,
              ),
            ),
          ),
        );

        if (hasAdmin) {
          items.add(
            const PopupMenuItem<String>(
              value: AppRoutes.adminDashboard,
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF38BDF8), size: 18),
                  SizedBox(width: 10),
                  Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }

        if (hasService) {
          items.add(
            const PopupMenuItem<String>(
              value: AppRoutes.complaintsDashboard,
              child: Row(
                children: [
                  Icon(Icons.support_agent_outlined, color: Color(0xFFC084FC), size: 18),
                  SizedBox(width: 10),
                  Text('Complaints Dashboard', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
          items.add(
            const PopupMenuItem<String>(
              value: AppRoutes.installationsDashboard,
              child: Row(
                children: [
                  Icon(Icons.build_circle_outlined, color: Color(0xFF38BDF8), size: 18),
                  SizedBox(width: 10),
                  Text('Installation Dashboard', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }

        if (hasCrm) {
          items.add(
            const PopupMenuItem<String>(
              value: '/crm/dashboard',
              child: Row(
                children: [
                  Icon(Icons.people_alt_outlined, color: Color(0xFF34D399), size: 18),
                  SizedBox(width: 10),
                  Text('CRM Dashboard', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }

        if (hasSales) {
          items.add(
            const PopupMenuItem<String>(
              value: AppRoutes.salesDashboard,
              child: Row(
                children: [
                  Icon(Icons.bar_chart_outlined, color: Color(0xFFFBBF24), size: 18),
                  SizedBox(width: 10),
                  Text('Sales Dashboard', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }

        if (hasOperations) {
          items.add(
            const PopupMenuItem<String>(
              value: AppRoutes.boqDashboard,
              child: Row(
                children: [
                  Icon(Icons.precision_manufacturing_outlined, color: Color(0xFFF59E0B), size: 18),
                  SizedBox(width: 10),
                  Text('Operations Dashboard', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }

        if (hasTechnician) {
          items.add(
            const PopupMenuItem<String>(
              value: AppRoutes.technicianDashboard,
              child: Row(
                children: [
                  Icon(Icons.home_outlined, color: Color(0xFF4ADE80), size: 18),
                  SizedBox(width: 10),
                  Text('Technician Home', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }

        items.add(
          const PopupMenuDivider(height: 1),
        );
        items.add(
          const PopupMenuItem<String>(
            value: AppRoutes.dailyTasks,
            child: Row(
              children: [
                Icon(Icons.fact_check_outlined, color: Color(0xFF34D399), size: 18),
                SizedBox(width: 10),
                Text('Daily Tasks Completed', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );

        return items;
      },
    );
  }
}
