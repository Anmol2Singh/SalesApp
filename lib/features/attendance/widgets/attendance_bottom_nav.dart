// lib/features/attendance/widgets/attendance_bottom_nav.dart

import 'package:flutter/material.dart';

enum AttendanceNavTab {
  dashboard,
  attendance,
  report,
  more,
}

class AttendanceBottomNav extends StatelessWidget {
  final AttendanceNavTab activeTab;
  final ValueChanged<AttendanceNavTab> onTabSelected;

  const AttendanceBottomNav({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  tab: AttendanceNavTab.dashboard,
                  label: 'Dashboard',
                  icon: Icons.grid_view_rounded,
                ),
                _buildNavItem(
                  tab: AttendanceNavTab.attendance,
                  label: 'Attendance',
                  icon: Icons.touch_app_outlined,
                ),
                _buildNavItem(
                  tab: AttendanceNavTab.report,
                  label: 'Report',
                  icon: Icons.bar_chart_rounded,
                ),
                _buildNavItem(
                  tab: AttendanceNavTab.more,
                  label: 'Home',
                  icon: Icons.menu_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required AttendanceNavTab tab,
    required String label,
    required IconData icon,
  }) {
    final isSelected = activeTab == tab;

    if (isSelected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B), // Warm golden amber from reference
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1E1E1E)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1E1E),
              ),
            ),
          ],
        ),
      );
    }

    return IconButton(
      icon: Icon(icon, size: 22, color: Colors.grey.shade400),
      onPressed: () => onTabSelected(tab),
      splashRadius: 20,
    );
  }
}
