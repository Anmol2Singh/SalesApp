// lib/features/attendance/repositories/attendance_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employee_profile_model.dart';
import '../models/office_location_model.dart';
import '../models/shift_model.dart';
import '../models/attendance_record_model.dart';
import '../models/attendance_report_model.dart';

class AttendanceRepository {
  final SupabaseClient _supabase;

  AttendanceRepository(this._supabase);

  /// Fetch full employee profile
  Future<AttendanceEmployeeProfile?> getEmployeeProfile(String userId) async {
    try {
      final res = await _supabase
          .from('employee_profiles')
          .select('''
            *,
            profiles!inner(full_name, email, phone, role),
            departments(name, code)
          ''')
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        return AttendanceEmployeeProfile.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (_) {}
    return null;
  }

  /// Fetch today's attendance record for user
  Future<AttendanceRecord?> getTodayRecord(String userId) async {
    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    try {
      final res = await _supabase
          .from('attendance_records')
          .select('''
            *,
            office_locations(name, address)
          ''')
          .eq('employee_id', userId)
          .eq('attendance_date', todayStr)
          .maybeSingle();

      if (res != null) {
        return AttendanceRecord.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (_) {}
    return null;
  }

  /// Fetch available active offices
  Future<List<OfficeLocation>> getActiveOffices() async {
    try {
      final res = await _supabase
          .from('office_locations')
          .select()
          .eq('is_active', true)
          .order('name');
      return (res as List)
          .map((e) => OfficeLocation.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Submit Authoritative Check-In via RPC
  Future<Map<String, dynamic>> checkIn({
    required String officeId,
    required double latitude,
    required double longitude,
    double accuracy = 10.0,
    String address = '',
    String deviceInfo = '',
  }) async {
    try {
      final res = await _supabase.rpc('submit_attendance_check_in', params: {
        'p_office_id': officeId,
        'p_lat': latitude,
        'p_lng': longitude,
        'p_accuracy': accuracy,
        'p_address': address,
        'p_device_info': deviceInfo,
      });

      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Submit Authoritative Check-Out via RPC
  Future<Map<String, dynamic>> checkOut({
    required double latitude,
    required double longitude,
    double accuracy = 10.0,
    String address = '',
    String deviceInfo = '',
  }) async {
    try {
      final res = await _supabase.rpc('submit_attendance_check_out', params: {
        'p_lat': latitude,
        'p_lng': longitude,
        'p_accuracy': accuracy,
        'p_address': address,
        'p_device_info': deviceInfo,
      });

      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fetch Monthly Summary Statistics (e.g. for February or January)
  Future<AttendanceSummaryStats> getMonthlyStats(String userId, int year, int month) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0);

    final startStr = "${startOfMonth.year}-${startOfMonth.month.toString().padLeft(2, '0')}-01";
    final endStr = "${endOfMonth.year}-${endOfMonth.month.toString().padLeft(2, '0')}-${endOfMonth.day.toString().padLeft(2, '0')}";

    try {
      final res = await _supabase
          .from('attendance_records')
          .select('''
            *,
            office_locations(name, address)
          ''')
          .eq('employee_id', userId)
          .gte('attendance_date', startStr)
          .lte('attendance_date', endStr)
          .order('attendance_date', ascending: true);

      final records = (res as List)
          .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      int present = 0;
      int late = 0;
      int absent = 0;
      int totalWorkingMins = 0;
      int totalOvertimeMins = 0;

      for (final r in records) {
        if (r.status == AttendanceRecordStatus.present) present++;
        if (r.status == AttendanceRecordStatus.late || r.isLate) late++;
        if (r.status == AttendanceRecordStatus.absent) absent++;
        totalWorkingMins += r.totalWorkingMinutes;
        totalOvertimeMins += r.overtimeMinutes;
      }

      // Weekly hours calculation for the current week
      final now = DateTime.now();
      final dayOfWeek = now.weekday; // 1 = Mon, 7 = Sun
      final monday = now.subtract(Duration(days: dayOfWeek - 1));
      final sunday = monday.subtract(const Duration(days: 1)); // start from Sun as in UI

      final List<DayWorkingHours> weekly = [];
      final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

      for (int i = 0; i < 7; i++) {
        final d = sunday.add(Duration(days: i));
        final match = records.where((r) =>
            r.attendanceDate.year == d.year &&
            r.attendanceDate.month == d.month &&
            r.attendanceDate.day == d.day).firstOrNull;

        final isFriOrSat = (i == 5 || i == 6); // Fri, Sat as weekend/holiday in sample or Sun/Fri
        final hours = (match != null) ? match.totalWorkingMinutes / 60.0 : 0.0;
        final isAbsent = match?.status == AttendanceRecordStatus.absent || (hours == 0 && !isFriOrSat && d.isBefore(now));

        weekly.add(DayWorkingHours(
          dayName: dayNames[i],
          hours: hours,
          isAbsent: isAbsent,
          isHoliday: isFriOrSat,
        ));
      }

      return AttendanceSummaryStats(
        presentCount: present,
        lateCount: late,
        absentCount: absent,
        totalHoursMinutes: totalWorkingMins,
        totalOvertimeMinutes: totalOvertimeMins,
        weeklyHours: weekly,
        records: records,
      );
    } catch (_) {
      return const AttendanceSummaryStats();
    }
  }

  /// Manager team attendance list
  Future<List<AttendanceRecord>> getTeamAttendance(String managerId, [DateTime? date]) async {
    final targetDate = date ?? DateTime.now();
    final dateStr = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

    try {
      final res = await _supabase
          .from('attendance_records')
          .select('''
            *,
            employee_profiles!inner(
              employee_code,
              designation,
              profiles!inner(full_name, email),
              departments(name)
            ),
            office_locations(name)
          ''')
          .eq('attendance_date', dateStr);

      return (res as List)
          .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Admin organization-wide attendance list
  Future<List<AttendanceRecord>> getOrganizationAttendance({
    DateTime? startDate,
    DateTime? endDate,
    String? departmentId,
    String? status,
  }) async {
    try {
      var query = _supabase
          .from('attendance_records')
          .select('''
            *,
            employee_profiles!inner(
              employee_code,
              designation,
              department_id,
              profiles!inner(full_name, email),
              departments(name)
            ),
            office_locations(name, address)
          ''');

      if (startDate != null) {
        final sStr = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
        query = query.gte('attendance_date', sStr);
      }
      if (endDate != null) {
        final eStr = "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
        query = query.lte('attendance_date', eStr);
      }
      if (departmentId != null && departmentId.isNotEmpty) {
        query = query.eq('employee_profiles.department_id', departmentId);
      }
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final res = await query.order('attendance_date', ascending: false);
      return (res as List)
          .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch all shifts
  Future<List<EmployeeShift>> getShifts() async {
    try {
      final res = await _supabase.from('employee_shifts').select().order('name');
      return (res as List)
          .map((e) => EmployeeShift.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch pending correction requests
  Future<List<Map<String, dynamic>>> getPendingCorrectionRequests() async {
    try {
      final res = await _supabase
          .from('attendance_correction_requests')
          .select('''
            *,
            employee_profiles(
              employee_code,
              profiles(full_name)
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (res as List).map((e) {
        final map = Map<String, dynamic>.from(e);
        final emp = map['employee_profiles'] as Map?;
        final prof = emp?['profiles'] as Map?;
        map['employee_name'] = prof?['full_name'] ?? emp?['employee_code'] ?? 'Employee';
        return map;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Review (approve / reject) correction request
  Future<void> reviewCorrectionRequest({
    required String requestId,
    required String status,
  }) async {
    await _supabase
        .from('attendance_correction_requests')
        .update({
          'status': status,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
  }
}
