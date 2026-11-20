// lib/features/attendance/admin/screens/attendance_admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/office_location_model.dart';
import '../../models/shift_model.dart';
import '../../models/attendance_record_model.dart';
import '../../models/employee_profile_model.dart';
import '../../providers/attendance_providers.dart';
import '../../reports/services/attendance_pdf_report_service.dart';

class AttendanceAdminDashboardScreen extends ConsumerStatefulWidget {
  const AttendanceAdminDashboardScreen({super.key});

  @override
  ConsumerState<AttendanceAdminDashboardScreen> createState() =>
      _AttendanceAdminDashboardScreenState();
}

class _AttendanceAdminDashboardScreenState
    extends ConsumerState<AttendanceAdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final officesAsync = ref.watch(officeLocationsProvider);
    final shiftsAsync = ref.watch(shiftsProvider);
    final todayRecordsAsync = ref.watch(todayAttendanceRecordsProvider);
    final currentEmployeeAsync = ref.watch(currentEmployeeProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Attendance Administration',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.fingerprint, size: 18),
            label: const Text('My Punch In'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            onPressed: () => context.push(AppRoutes.attendanceDashboard),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export Report',
            onPressed: () => _exportAttendanceReport(currentEmployeeAsync.value),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(officeLocationsProvider);
              ref.invalidate(shiftsProvider);
              ref.invalidate(todayAttendanceRecordsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.black54,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.badge_outlined, size: 20), text: "Today's Roster"),
            Tab(icon: Icon(Icons.location_city_outlined, size: 20), text: 'Offices & Geofence'),
            Tab(icon: Icon(Icons.schedule_outlined, size: 20), text: 'Shifts'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRosterTab(todayRecordsAsync),
              _buildOfficesTab(officesAsync),
              _buildShiftsTab(shiftsAsync),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRosterTab(AsyncValue<List<AttendanceRecord>> todayRecordsAsync) {
    return todayRecordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text('Failed to load roster: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(todayAttendanceRecordsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (records) {
        final presentCount = records.where((r) => r.status == AttendanceRecordStatus.present).length;
        final lateCount = records.where((r) => r.status == AttendanceRecordStatus.late || r.isLate).length;
        final totalEnrolled = records.length;
        final attendanceRate = totalEnrolled > 0
            ? (((presentCount + lateCount) / totalEnrolled) * 100).toStringAsFixed(1)
            : '0.0';

        final filtered = records.where((r) {
          if (_searchQuery.isEmpty) return true;
          return (r.employeeName ?? r.employeeId).toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.status.name.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todayAttendanceRecordsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Top KPI cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Staff Enrolled',
                      value: '$totalEnrolled',
                      color: AppColors.primary,
                      icon: Icons.people_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Attendance Rate',
                      value: '$attendanceRate%',
                      color: const Color(0xFF10B981),
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Late Check-ins',
                      value: '$lateCount',
                      color: const Color(0xFFF59E0B),
                      icon: Icons.access_time,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by employee or status...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              ),
              const SizedBox(height: 16),

              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No attendance records found.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                )
              else
                ...filtered.map((r) => _buildRosterCard(r)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRosterCard(AttendanceRecord record) {
    Color statusColor;
    String statusText;
    switch (record.status) {
      case AttendanceRecordStatus.present:
        statusColor = const Color(0xFF10B981);
        statusText = 'Present';
        break;
      case AttendanceRecordStatus.late:
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Late';
        break;
      case AttendanceRecordStatus.absent:
        statusColor = const Color(0xFFEF4444);
        statusText = 'Absent';
        break;
      case AttendanceRecordStatus.halfDay:
        statusColor = const Color(0xFF8B5CF6);
        statusText = 'Half Day';
        break;
      default:
        statusColor = Colors.grey;
        statusText = record.status.name.toUpperCase();
    }

    final inTime = record.checkInTime != null
        ? DateFormat('hh:mm a').format(record.checkInTime!)
        : '--';
    final outTime = record.checkOutTime != null
        ? DateFormat('hh:mm a').format(record.checkOutTime!)
        : '--';
    final hoursWorked = (record.totalWorkingMinutes / 60.0).toStringAsFixed(1);
    final displayName = record.employeeName ?? record.employeeCode ?? record.employeeId.substring(0, 8);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.12),
            foregroundColor: statusColor,
            radius: 20,
            child: Text(
              record.status == AttendanceRecordStatus.absent ? 'A' : 'P',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'In: $inTime | Out: $outTime ($hoursWorked hrs)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficesTab(AsyncValue<List<OfficeLocation>> officesAsync) {
    return officesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading offices: $e')),
      data: (offices) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Configured Geofences',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${offices.length} Active',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...offices.map((office) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.business, color: Color(0xFF1E3A8A)),
                              const SizedBox(width: 8),
                              Text(
                                office.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: office.isActive
                                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              office.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: office.isActive ? const Color(0xFF10B981) : Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (office.address.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          office.address,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.radar, size: 14, color: Colors.blueAccent),
                          const SizedBox(width: 4),
                          Text(
                            'Radius: ${office.geofenceRadiusMeters} meters',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            'GPS: ${office.latitude.toStringAsFixed(4)}, ${office.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildShiftsTab(AsyncValue<List<EmployeeShift>> shiftsAsync) {
    return shiftsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading shifts: $e')),
      data: (shifts) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Configured Working Shifts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...shifts.map((shift) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            shift.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${shift.requiredHours.toStringAsFixed(1)}h Shift',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${shift.startTime} - ${shift.endTime}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Text(
                            'Grace: ${shift.gracePeriodMinutes} mins',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _exportAttendanceReport(AttendanceEmployeeProfile? profile) async {
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee profile is loading, please wait...')),
      );
      return;
    }

    final records = ref.read(todayAttendanceRecordsProvider).value ?? [];
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    await AttendancePdfReportService.generateAndPreviewPdf(
      context,
      employee: profile,
      records: records,
      periodStart: startOfMonth,
      periodEnd: now,
      organizationTitle: 'INSIYA SOLAR INDUSTRY',
    );
  }
}
