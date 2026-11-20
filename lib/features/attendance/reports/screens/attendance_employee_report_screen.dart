// lib/features/attendance/reports/screens/attendance_employee_report_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/attendance_providers.dart';
import '../../widgets/attendance_bottom_nav.dart';

class AttendanceEmployeeReportScreen extends ConsumerStatefulWidget {
  const AttendanceEmployeeReportScreen({super.key});

  @override
  ConsumerState<AttendanceEmployeeReportScreen> createState() =>
      _AttendanceEmployeeReportScreenState();
}

class _AttendanceEmployeeReportScreenState
    extends ConsumerState<AttendanceEmployeeReportScreen> {
  int _selectedMonth = DateTime.now().month;
  final int _selectedYear = DateTime.now().year;

  final List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final statsAsync = ref.watch(monthlyStatsProvider((
      year: _selectedYear,
      month: _selectedMonth,
    )));

    final stats = statsAsync.valueOrNull;
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: isWide ? const Color(0xFFF1F5F9) : const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: isWide,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.attendanceDashboard);
            }
          },
        ),
        title: const Text(
          'Report',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // 1. Working Hours Card with Purple Bar Chart
                    _buildWorkingHoursCard(stats),

                    const SizedBox(height: 24),

                    // 2. Total Attendance (Days) Card
                    _buildTotalAttendanceSection(stats),

                    const SizedBox(height: 100), // Spacing for bottom nav
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AttendanceBottomNav(
        activeTab: AttendanceNavTab.report,
        onTabSelected: (tab) {
          if (tab == AttendanceNavTab.dashboard) {
            context.go(AppRoutes.attendanceDashboard);
          } else if (tab == AttendanceNavTab.attendance) {
            context.go(AppRoutes.attendanceCheckIn);
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

  Widget _buildWorkingHoursCard(dynamic stats) {
    final totalHours = stats?.totalHoursFormatted ?? '38:24 hrs';
    final overtime = stats?.totalOvertimeFormatted ?? '01:20 hrs';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Working Hours',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
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

          const SizedBox(height: 14),

          // Stats row
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF6366F1), size: 16),
              const SizedBox(width: 6),
              Text(
                'Total Hours $totalHours',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: Color(0xFF6366F1), size: 16),
              const SizedBox(width: 6),
              Text(
                'Overtime $overtime',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Working Hours Custom Bar Chart
          _buildDetailedBarChart(),
        ],
      ),
    );
  }

  Widget _buildDetailedBarChart() {
    final yLabels = ['10h', '8h', '6h', '4h', '2h', '0h'];
    final xLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    // Heights fraction out of 10h max
    final fractions = [0.45, 0.80, 0.72, 0.98, 0.60, 0.70, 0.70];

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Y-axis labels
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: yLabels.map((lbl) => Text(
              lbl,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
            )).toList(),
          ),

          const SizedBox(width: 12),

          // Bars Area
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final isAbsent = (i == 0);
                final isHoliday = (i == 5 || i == 6);
                final frac = fractions[i];

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 22,
                      height: 145 * frac,
                      decoration: BoxDecoration(
                        color: isAbsent
                            ? const Color(0xFFFDE8E8) // Soft pink
                            : isHoliday
                                ? const Color(0xFFEDE9FE) // Soft lavender
                                : const Color(0xFF4F46E5), // Vibrant purple
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: (isAbsent || isHoliday)
                          ? RotatedBox(
                              quarterTurns: 3,
                              child: Text(
                                isAbsent ? 'Absent' : 'Holiday',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: isAbsent
                                      ? const Color(0xFFF43F5E)
                                      : const Color(0xFF8B5CF6),
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      xLabels[i],
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAttendanceSection(dynamic stats) {
    final present = stats?.presentCount ?? 19;
    final late = stats?.lateCount ?? 3;
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
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
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
              Container(width: 1, height: 42, color: Colors.grey.shade200),
              _buildStatMetric(late.toString(), 'Late Login', const Color(0xFFF59E0B)),
              Container(width: 1, height: 42, color: Colors.grey.shade200),
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
}
