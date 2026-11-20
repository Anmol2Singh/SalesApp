// lib/features/attendance/models/attendance_record_model.dart

enum AttendanceRecordStatus {
  present,
  late,
  halfDay,
  absent,
  onLeave,
  holiday,
  weeklyOff;

  static AttendanceRecordStatus fromString(String? val) {
    switch (val?.trim().toLowerCase()) {
      case 'present':
        return AttendanceRecordStatus.present;
      case 'late':
        return AttendanceRecordStatus.late;
      case 'half_day':
        return AttendanceRecordStatus.halfDay;
      case 'absent':
        return AttendanceRecordStatus.absent;
      case 'on_leave':
        return AttendanceRecordStatus.onLeave;
      case 'holiday':
        return AttendanceRecordStatus.holiday;
      case 'weekly_off':
        return AttendanceRecordStatus.weeklyOff;
      default:
        return AttendanceRecordStatus.present;
    }
  }

  String get displayName {
    switch (this) {
      case AttendanceRecordStatus.present:
        return 'Present';
      case AttendanceRecordStatus.late:
        return 'Late';
      case AttendanceRecordStatus.halfDay:
        return 'Half Day';
      case AttendanceRecordStatus.absent:
        return 'Absent';
      case AttendanceRecordStatus.onLeave:
        return 'On Leave';
      case AttendanceRecordStatus.holiday:
        return 'Holiday';
      case AttendanceRecordStatus.weeklyOff:
        return 'Weekly Off';
    }
  }
}

class AttendanceRecord {
  final String id;
  final String employeeId;
  final DateTime attendanceDate;
  final String? shiftId;
  final String? officeLocationId;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double? checkInLat;
  final double? checkInLng;
  final double? checkOutLat;
  final double? checkOutLng;
  final double? checkInDistanceMeters;
  final double? checkOutDistanceMeters;
  final int totalWorkingMinutes;
  final int overtimeMinutes;
  final AttendanceRecordStatus status;
  final bool isLate;
  final bool isEarlyDeparture;
  final String? checkInAddress;
  final String? checkOutAddress;
  final String? notes;

  // Joined display attributes
  final String? employeeName;
  final String? employeeCode;
  final String? departmentName;
  final String? officeName;

  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.attendanceDate,
    this.shiftId,
    this.officeLocationId,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLat,
    this.checkInLng,
    this.checkOutLat,
    this.checkOutLng,
    this.checkInDistanceMeters,
    this.checkOutDistanceMeters,
    this.totalWorkingMinutes = 0,
    this.overtimeMinutes = 0,
    this.status = AttendanceRecordStatus.present,
    this.isLate = false,
    this.isEarlyDeparture = false,
    this.checkInAddress,
    this.checkOutAddress,
    this.notes,
    this.employeeName,
    this.employeeCode,
    this.departmentName,
    this.officeName,
  });

  bool get isCheckedIn => checkInTime != null && checkOutTime == null;
  bool get isCompleted => checkInTime != null && checkOutTime != null;

  String get workingHoursString {
    final h = totalWorkingMinutes ~/ 60;
    final m = totalWorkingMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} hrs';
  }

  String get overtimeHoursString {
    final h = overtimeMinutes ~/ 60;
    final m = overtimeMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} hrs';
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final empProfile = json['employee_profiles'] as Map<String, dynamic>?;
    final profile = empProfile?['profiles'] as Map<String, dynamic>?;
    final dept = empProfile?['departments'] as Map<String, dynamic>?;
    final office = json['office_locations'] as Map<String, dynamic>?;

    return AttendanceRecord(
      id: json['id'] as String? ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      attendanceDate: json['attendance_date'] != null
          ? DateTime.tryParse(json['attendance_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      shiftId: json['shift_id'] as String?,
      officeLocationId: json['office_location_id'] as String?,
      checkInTime: json['check_in_time'] != null
          ? DateTime.tryParse(json['check_in_time'].toString())
          : null,
      checkOutTime: json['check_out_time'] != null
          ? DateTime.tryParse(json['check_out_time'].toString())
          : null,
      checkInLat: (json['check_in_lat'] as num?)?.toDouble(),
      checkInLng: (json['check_in_lng'] as num?)?.toDouble(),
      checkOutLat: (json['check_out_lat'] as num?)?.toDouble(),
      checkOutLng: (json['check_out_lng'] as num?)?.toDouble(),
      checkInDistanceMeters: (json['check_in_distance_meters'] as num?)?.toDouble(),
      checkOutDistanceMeters: (json['check_out_distance_meters'] as num?)?.toDouble(),
      totalWorkingMinutes: (json['total_working_minutes'] as num?)?.toInt() ?? 0,
      overtimeMinutes: (json['overtime_minutes'] as num?)?.toInt() ?? 0,
      status: AttendanceRecordStatus.fromString(json['status'] as String?),
      isLate: json['is_late'] as bool? ?? false,
      isEarlyDeparture: json['is_early_departure'] as bool? ?? false,
      checkInAddress: json['check_in_address'] as String?,
      checkOutAddress: json['check_out_address'] as String?,
      notes: json['notes'] as String?,
      employeeName: profile?['full_name'] as String?,
      employeeCode: empProfile?['employee_code'] as String?,
      departmentName: dept?['name'] as String?,
      officeName: office?['name'] as String?,
    );
  }
}
