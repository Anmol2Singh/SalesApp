// lib/features/attendance/models/employee_profile_model.dart

enum AttendanceRole {
  admin,
  manager,
  employee;

  static AttendanceRole fromString(String? val) {
    switch (val?.trim().toLowerCase()) {
      case 'admin':
        return AttendanceRole.admin;
      case 'manager':
        return AttendanceRole.manager;
      default:
        return AttendanceRole.employee;
    }
  }

  String get displayName {
    switch (this) {
      case AttendanceRole.admin:
        return 'Administrator';
      case AttendanceRole.manager:
        return 'Manager';
      case AttendanceRole.employee:
        return 'Employee';
    }
  }
}

class AttendanceEmployeeProfile {
  final String id;
  final String employeeCode;
  final String fullName;
  final String email;
  final String? phone;
  final String designation;
  final String? departmentId;
  final String? departmentName;
  final String? reportingManagerId;
  final AttendanceRole attendanceRole;
  final String? officeLocationId;
  final String? shiftId;
  final bool isActive;
  final DateTime joiningDate;

  const AttendanceEmployeeProfile({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    required this.email,
    this.phone,
    required this.designation,
    this.departmentId,
    this.departmentName,
    this.reportingManagerId,
    this.attendanceRole = AttendanceRole.employee,
    this.officeLocationId,
    this.shiftId,
    this.isActive = true,
    required this.joiningDate,
  });

  factory AttendanceEmployeeProfile.fromJson(Map<String, dynamic> json) {
    final profileData = json['profiles'] as Map<String, dynamic>? ?? {};
    final deptData = json['departments'] as Map<String, dynamic>? ?? {};

    return AttendanceEmployeeProfile(
      id: json['id'] as String? ?? '',
      employeeCode: json['employee_code'] as String? ?? 'EMP-0000',
      fullName: profileData['full_name'] as String? ?? json['full_name'] as String? ?? 'Employee',
      email: profileData['email'] as String? ?? json['email'] as String? ?? '',
      phone: profileData['phone'] as String? ?? json['phone'] as String?,
      designation: json['designation'] as String? ?? 'Staff Member',
      departmentId: json['department_id'] as String?,
      departmentName: deptData['name'] as String? ?? json['department_name'] as String?,
      reportingManagerId: json['reporting_manager_id'] as String?,
      attendanceRole: AttendanceRole.fromString(json['attendance_role'] as String?),
      officeLocationId: json['office_location_id'] as String?,
      shiftId: json['shift_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      joiningDate: json['joining_date'] != null
          ? DateTime.tryParse(json['joining_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
