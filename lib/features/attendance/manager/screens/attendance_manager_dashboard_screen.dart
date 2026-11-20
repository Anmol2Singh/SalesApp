// lib/features/attendance/manager/screens/attendance_manager_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/attendance_record_model.dart';
import '../../providers/attendance_providers.dart';

class AttendanceManagerDashboardScreen extends ConsumerStatefulWidget {
  const AttendanceManagerDashboardScreen({super.key});

  @override
  ConsumerState<AttendanceManagerDashboardScreen> createState() =>
      _AttendanceManagerDashboardScreenState();
}

class _AttendanceManagerDashboardScreenState
    extends ConsumerState<AttendanceManagerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamRecordsAsync = ref.watch(managerTeamAttendanceProvider);
    final correctionsAsync = ref.watch(pendingCorrectionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Team Attendance',
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(managerTeamAttendanceProvider);
              ref.invalidate(pendingCorrectionsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.black54,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: [
            const Tab(
              icon: Icon(Icons.group_outlined, size: 20),
              text: "Today's Team",
            ),
            Tab(
              icon: const Icon(Icons.assignment_outlined, size: 20),
              text: correctionsAsync.maybeWhen(
                data: (list) => list.isNotEmpty
                    ? 'Requests (${list.length})'
                    : 'Requests',
                orElse: () => 'Requests',
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTeamTab(teamRecordsAsync),
              _buildCorrectionsTab(correctionsAsync),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamTab(AsyncValue<List<AttendanceRecord>> teamRecordsAsync) {
    return teamRecordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text('Failed to load team data: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(managerTeamAttendanceProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (records) {
        final presentCount = records.where((r) => r.status == AttendanceRecordStatus.present).length;
        final lateCount = records.where((r) => r.status == AttendanceRecordStatus.late || r.isLate).length;
        final absentCount = records.where((r) => r.status == AttendanceRecordStatus.absent).length;
        final total = records.length;

        final filtered = records.where((r) {
          if (_selectedFilter == 'all') return true;
          if (_selectedFilter == 'present') {
            return r.status == AttendanceRecordStatus.present || r.status == AttendanceRecordStatus.late;
          }
          if (_selectedFilter == 'late') {
            return r.status == AttendanceRecordStatus.late || r.isLate;
          }
          if (_selectedFilter == 'absent') {
            return r.status == AttendanceRecordStatus.absent;
          }
          return true;
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(managerTeamAttendanceProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Total Team',
                      count: total,
                      color: AppColors.primary,
                      icon: Icons.groups,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Present',
                      count: presentCount,
                      color: const Color(0xFF10B981),
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Late',
                      count: lateCount,
                      color: const Color(0xFFF59E0B),
                      icon: Icons.access_time,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Absent',
                      count: absentCount,
                      color: const Color(0xFFEF4444),
                      icon: Icons.cancel_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All ($total)'),
                    const SizedBox(width: 8),
                    _buildFilterChip('present', 'Present (${presentCount + lateCount})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('late', 'Late ($lateCount)'),
                    const SizedBox(width: 8),
                    _buildFilterChip('absent', 'Absent ($absentCount)'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No team members match this filter.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                )
              else
                ...filtered.map((r) => _buildTeamMemberCard(r)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : Colors.black87,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = value);
      },
    );
  }

  Widget _buildMetricCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMemberCard(AttendanceRecord record) {
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.12),
            foregroundColor: statusColor,
            radius: 22,
            child: Text(
              record.status == AttendanceRecordStatus.absent ? 'A' : 'P',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(width: 14),
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
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.login, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'In: $inTime',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.logout, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Out: $outTime',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const Spacer(),
                    Text(
                      '$hoursWorked hrs',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if ((record.checkInDistanceMeters ?? 999) <= 250) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.verified, size: 13, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        'Verified at Office',
                        style: TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectionsTab(
      AsyncValue<List<Map<String, dynamic>>> correctionsAsync) {
    return correctionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Text('Error loading requests: $e'),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 54, color: Colors.green),
                SizedBox(height: 12),
                Text(
                  'No pending correction requests',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                Text(
                  'Your team attendance is fully up to date.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            final reqId = req['id'] as String;
            final empName = req['employee_name'] ?? 'Team Member';
            final date = req['attendance_date'] ?? '--';
            final reason = req['reason'] ?? 'No reason provided';
            final requestedIn = req['requested_check_in'] ?? '--';
            final requestedOut = req['requested_check_out'] ?? '--';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          empName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Date: $date',
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Requested In: $requestedIn  |  Requested Out: $requestedOut',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reason: $reason',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _reviewRequest(reqId, 'rejected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          child: const Text('Reject'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => _reviewRequest(reqId, 'approved'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _reviewRequest(String requestId, String status) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      await ref.read(attendanceRepositoryProvider).reviewCorrectionRequest(
            requestId: requestId,
            status: status,
          );
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Request $status successfully'),
          backgroundColor:
              status == 'approved' ? const Color(0xFF10B981) : Colors.redAccent,
        ),
      );
      ref.invalidate(pendingCorrectionsProvider);
      ref.invalidate(managerTeamAttendanceProvider);
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Failed to update request: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
