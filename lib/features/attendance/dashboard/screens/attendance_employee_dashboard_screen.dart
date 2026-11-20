// lib/features/attendance/dashboard/screens/attendance_employee_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/user_role.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/employee_profile_model.dart';
import '../../providers/attendance_providers.dart';
import '../../widgets/attendance_bottom_nav.dart';

class AttendanceEmployeeDashboardScreen extends ConsumerStatefulWidget {
  const AttendanceEmployeeDashboardScreen({super.key});

  @override
  ConsumerState<AttendanceEmployeeDashboardScreen> createState() =>
      _AttendanceEmployeeDashboardScreenState();
}

class _AttendanceEmployeeDashboardScreenState
    extends ConsumerState<AttendanceEmployeeDashboardScreen> {
  int _selectedMonth = DateTime.now().month;
  final int _selectedYear = DateTime.now().year;

  final List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final empProfileAsync = ref.watch(currentEmployeeProfileProvider);
    final todayAsync = ref.watch(todayAttendanceProvider);
    final statsAsync = ref.watch(monthlyStatsProvider((
      year: _selectedYear,
      month: _selectedMonth,
    )));

    final emp = empProfileAsync.valueOrNull;
    final today = todayAsync.valueOrNull;
    final stats = statsAsync.valueOrNull;

    final name = emp?.fullName ?? profile?.fullName ?? 'Employee';
    final designation = emp?.designation ?? 'Technical Specialist';
    final now = DateTime.now();
    final dateStr = DateFormat('dd MMM, yyyy').format(now);

    final roles = profile?.roles ?? [];
    final isAdmin = (emp?.attendanceRole == AttendanceRole.admin) ||
        roles.contains(UserRole.admin);
    final isManager = (emp?.attendanceRole == AttendanceRole.manager) ||
        roles.contains(UserRole.manager) ||
        roles.contains(UserRole.salesHead);

    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: isWide ? const Color(0xFFF1F5F9) : const Color(0xFFF9F6F0),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9F6F0),
              boxShadow: isWide
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Warm Brown Header with Working Time Card
                    _buildTopHeaderWithCard(
                      name: name,
                      designation: designation,
                      dateStr: dateStr,
                      todayRecord: today,
                      isAdmin: isAdmin,
                      isManager: isManager,
                    ),

                    // Admin Quick Management Banner (only for Admins)
                    if (isAdmin) ...[
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildAdminAccessBanner(),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 2. Total Attendance (Days) Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildTotalAttendanceSection(stats),
                    ),

                    const SizedBox(height: 20),

                    // 3. Working Hours Section with Chart
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildWorkingHoursSection(stats),
                    ),

                    const SizedBox(height: 100), // Spacing for floating bottom bar
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AttendanceBottomNav(
        activeTab: AttendanceNavTab.dashboard,
        onTabSelected: (tab) {
          if (tab == AttendanceNavTab.attendance) {
            context.go(AppRoutes.attendanceCheckIn);
          } else if (tab == AttendanceNavTab.report) {
            context.go(AppRoutes.attendanceReports);
          } else if (tab == AttendanceNavTab.more) {
            final homeRoute = profile != null
                ? getRoleHome(profile.primaryRole)
                : AppRoutes.unifiedDashboard;
            if (context.canPop()) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
            context.go(homeRoute);
          }
        },
      ),
    );
  }

  Widget _buildAdminAccessBanner() {
    return InkWell(
      onTap: () => context.push(AppRoutes.attendanceAdmin),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organization Attendance Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Company roster, office geofence & shift settings',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Console',
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF1E3A8A), size: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeaderWithCard({
    required String name,
    required String designation,
    required String dateStr,
    dynamic todayRecord,
    bool isAdmin = false,
    bool isManager = false,
  }) {
    final now = DateTime.now();
    final hourStr = DateFormat('hh').format(now);
    final minStr = DateFormat('mm').format(now);
    final amPmStr = DateFormat('a').format(now).toUpperCase();

    final isCheckedIn = todayRecord != null && todayRecord.isCheckedIn;
    final isCompleted = todayRecord != null && todayRecord.isCompleted;
    final address = todayRecord?.checkInAddress ??
        todayRecord?.officeName ??
        'Insiya Solar Industry - Pune HQ';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Brown Header Background
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 80),
          decoration: const BoxDecoration(
            color: Color(0xFF4A2E18), // Deep warm brown
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(36),
              bottomRight: Radius.circular(36),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFD4A373),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'E',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E1B4B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ] else if (isManager) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'MANAGER',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          designation,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFD4A373), // Warm golden
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    InkWell(
                      onTap: () => context.push(AppRoutes.attendanceAdmin),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Admin View',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (isManager)
                    InkWell(
                      onTap: () => context.push(AppRoutes.attendanceManager),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.groups_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Team',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Notification bell
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Title and Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Todays Attendance",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFD4A373),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Working Time White Floating Card
        Container(
          margin: const EdgeInsets.only(top: 155, left: 20, right: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                isCheckedIn ? 'Working Time' : 'Attendance Status',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 12),

              // Segmented Digital Clock Box
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTimeBlock(hourStr),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  ),
                  _buildTimeBlock(minStr),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  ),
                  _buildTimeBlock(amPmStr),
                ],
              ),

              const SizedBox(height: 12),

              // Location Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      address,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Action Button (Checkout if checked-in, Check-in if not)
              SizedBox(
                width: 170,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/attendance/check-in');
                  },
                  icon: Icon(
                    isCompleted
                        ? Icons.done_all_rounded
                        : isCheckedIn
                            ? Icons.logout_rounded
                            : Icons.touch_app_rounded,
                    size: 18,
                  ),
                  label: Text(
                    isCompleted
                        ? 'Completed'
                        : isCheckedIn
                            ? 'Checkout'
                            : 'Check In',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCompleted
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF97316), // Orange
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeBlock(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFF111827),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildTotalAttendanceSection(dynamic stats) {
    final present = stats?.presentCount ?? 8;
    final late = stats?.lateCount ?? 2;
    final absent = stats?.absentCount ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Total Attendance (Days)",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            // Month dropdown pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                  items: List.generate(12, (i) {
                    return DropdownMenuItem(
                      value: i + 1,
                      child: Text(
                        _monthNames[i],
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMonth = val);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatMetric(present.toString(), 'Present', const Color(0xFF10B981)),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _buildStatMetric(late.toString(), 'Late', const Color(0xFFF59E0B)),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _buildStatMetric(absent.toString(), 'Absent', const Color(0xFFF43F5E)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatMetric(String count, String label, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkingHoursSection(dynamic stats) {
    final totalHours = stats?.totalHoursFormatted ?? '38:24 hrs';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Working Hours",
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: const [
                  Text(
                    '5 Jan - 12 Jan',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF6366F1), size: 16),
                  const SizedBox(width: 6),
                  Text('Total Hours $totalHours', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: Color(0xFF6366F1), size: 16),
                  const SizedBox(width: 6),
                  Text('Total Hours $totalHours', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                ],
              ),
              const SizedBox(height: 16),

              // Weekly bars mini-preview
              _buildMiniWeeklyBars(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniWeeklyBars() {
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final heights = [0.2, 0.75, 0.7, 0.95, 0.6, 0.4, 0.4];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final isHoliday = (i == 5 || i == 6);
        final isAbsent = (i == 0);
        return Column(
          children: [
            Container(
              width: 14,
              height: 70 * heights[i],
              decoration: BoxDecoration(
                color: isAbsent
                    ? const Color(0xFFFDE8E8)
                    : isHoliday
                        ? const Color(0xFFEDE9FE)
                        : const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              days[i],
              style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.grey),
            ),
          ],
        );
      }),
    );
  }
}
