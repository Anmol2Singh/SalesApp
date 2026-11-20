// lib/features/attendance/models/attendance_report_model.dart

import 'attendance_record_model.dart';

class DayWorkingHours {
  final String dayName; // 'Sun', 'Mon', etc.
  final double hours;
  final bool isAbsent;
  final bool isHoliday;

  const DayWorkingHours({
    required this.dayName,
    required this.hours,
    this.isAbsent = false,
    this.isHoliday = false,
  });
}

class AttendanceSummaryStats {
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int totalHoursMinutes;
  final int totalOvertimeMinutes;
  final List<DayWorkingHours> weeklyHours;
  final List<AttendanceRecord> records;

  const AttendanceSummaryStats({
    this.presentCount = 0,
    this.lateCount = 0,
    this.absentCount = 0,
    this.totalHoursMinutes = 0,
    this.totalOvertimeMinutes = 0,
    this.weeklyHours = const [],
    this.records = const [],
  });

  String get totalHoursFormatted {
    final h = totalHoursMinutes ~/ 60;
    final m = totalHoursMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} hrs';
  }

  String get totalOvertimeFormatted {
    final h = totalOvertimeMinutes ~/ 60;
    final m = totalOvertimeMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} hrs';
  }
}
