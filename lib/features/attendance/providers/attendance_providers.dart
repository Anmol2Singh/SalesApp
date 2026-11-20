// lib/features/attendance/providers/attendance_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/attendance_repository.dart';
import '../models/employee_profile_model.dart';
import '../models/office_location_model.dart';
import '../models/shift_model.dart';
import '../models/attendance_record_model.dart';
import '../models/attendance_report_model.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AttendanceRepository(supabase);
});

final currentEmployeeProfileProvider = FutureProvider<AttendanceEmployeeProfile?>((ref) async {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return null;
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getEmployeeProfile(authUser.id);
});

final todayAttendanceProvider = FutureProvider<AttendanceRecord?>((ref) async {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return null;
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getTodayRecord(authUser.id);
});

final activeOfficesProvider = FutureProvider<List<OfficeLocation>>((ref) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getActiveOffices();
});

final officeLocationsProvider = FutureProvider<List<OfficeLocation>>((ref) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getActiveOffices();
});

final shiftsProvider = FutureProvider<List<EmployeeShift>>((ref) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getShifts();
});

final todayAttendanceRecordsProvider = FutureProvider<List<AttendanceRecord>>((ref) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  final now = DateTime.now();
  return repo.getOrganizationAttendance(startDate: now, endDate: now);
});

final managerTeamAttendanceProvider = FutureProvider<List<AttendanceRecord>>((ref) async {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return [];
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getTeamAttendance(authUser.id);
});

final pendingCorrectionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getPendingCorrectionRequests();
});

final monthlyStatsProvider = FutureProvider.family<AttendanceSummaryStats, ({int year, int month})>((ref, arg) async {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return const AttendanceSummaryStats();
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getMonthlyStats(authUser.id, arg.year, arg.month);
});

final teamAttendanceProvider = FutureProvider.family<List<AttendanceRecord>, DateTime?>((ref, date) async {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return [];
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getTeamAttendance(authUser.id, date);
});
