// lib/features/attendance/models/shift_model.dart

class EmployeeShift {
  final String id;
  final String name;
  final String startTime; // '09:00:00'
  final String endTime;   // '18:00:00'
  final int breakDurationMinutes;
  final int gracePeriodMinutes;
  final double requiredHours;
  final bool allowOvertime;
  final bool isActive;

  const EmployeeShift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.breakDurationMinutes = 60,
    this.gracePeriodMinutes = 15,
    this.requiredHours = 8.0,
    this.allowOvertime = true,
    this.isActive = true,
  });

  factory EmployeeShift.fromJson(Map<String, dynamic> json) {
    return EmployeeShift(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'General Shift',
      startTime: json['start_time'] as String? ?? '09:00:00',
      endTime: json['end_time'] as String? ?? '18:00:00',
      breakDurationMinutes: (json['break_duration_minutes'] as num?)?.toInt() ?? 60,
      gracePeriodMinutes: (json['grace_period_minutes'] as num?)?.toInt() ?? 15,
      requiredHours: (json['required_hours'] as num?)?.toDouble() ?? 8.0,
      allowOvertime: json['allow_overtime'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'start_time': startTime,
      'end_time': endTime,
      'break_duration_minutes': breakDurationMinutes,
      'grace_period_minutes': gracePeriodMinutes,
      'required_hours': requiredHours,
      'allow_overtime': allowOvertime,
      'is_active': isActive,
    };
  }
}
