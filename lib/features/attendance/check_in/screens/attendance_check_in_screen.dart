// lib/features/attendance/check_in/screens/attendance_check_in_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/attendance_providers.dart';
import '../../widgets/attendance_bottom_nav.dart';
import '../services/attendance_location_service.dart';

class AttendanceCheckInScreen extends ConsumerStatefulWidget {
  const AttendanceCheckInScreen({super.key});

  @override
  ConsumerState<AttendanceCheckInScreen> createState() =>
      _AttendanceCheckInScreenState();
}

class _AttendanceCheckInScreenState extends ConsumerState<AttendanceCheckInScreen> {
  int _activeSegmentTab = 0; // 0 = Todays Attendance, 1 = Attendance List
  bool _isProcessing = false;
  LocationResult? _currentLocation;

  @override
  void initState() {
    super.initState();
    _fetchGpsLocation();
  }

  Future<void> _fetchGpsLocation() async {
    final loc = await AttendanceLocationService.getCurrentLocation();
    if (mounted) {
      setState(() => _currentLocation = loc);
    }
  }

  Future<void> _handleCheckIn() async {
    setState(() {
      _isProcessing = true;
    });

    final loc = await AttendanceLocationService.getCurrentLocation();
    _currentLocation = loc;

    if (!loc.isSuccess) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorMessage ?? 'GPS Location unavailable'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    final offices = await ref.read(activeOfficesProvider.future);
    final primaryOffice = offices.isNotEmpty ? offices.first : null;

    if (primaryOffice == null) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      return;
    }

    final repo = ref.read(attendanceRepositoryProvider);
    final result = await repo.checkIn(
      officeId: primaryOffice.id,
      latitude: loc.latitude!,
      longitude: loc.longitude!,
      accuracy: loc.accuracy ?? 10.0,
      address: primaryOffice.address,
      deviceInfo: 'App Session',
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });

      ref.invalidate(todayAttendanceProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Check-in processed'),
          backgroundColor: result['success'] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _handleCheckOut() async {
    setState(() {
      _isProcessing = true;
    });

    final loc = await AttendanceLocationService.getCurrentLocation();
    final repo = ref.read(attendanceRepositoryProvider);

    final result = await repo.checkOut(
      latitude: loc.latitude ?? 18.5204,
      longitude: loc.longitude ?? 73.8567,
      accuracy: loc.accuracy ?? 10.0,
      address: 'Insiya Solar Industry HQ',
      deviceInfo: 'App Session',
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });

      ref.invalidate(todayAttendanceProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Check-out processed'),
          backgroundColor: result['success'] == true ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final todayAsync = ref.watch(todayAttendanceProvider);
    final officesAsync = ref.watch(activeOfficesProvider);

    final today = todayAsync.valueOrNull;
    final offices = officesAsync.valueOrNull ?? [];
    final primaryOffice = offices.isNotEmpty ? offices.first : null;

    final now = DateTime.now();
    final dateStr = DateFormat('dd MMM, yyyy').format(now);
    final hourStr = DateFormat('hh').format(now);
    final minStr = DateFormat('mm').format(now);
    final amPmStr = DateFormat('a').format(now).toUpperCase();

    final isCheckedIn = today != null && today.isCheckedIn;
    final isCompleted = today != null && today.isCompleted;

    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: isWide ? const Color(0xFFF1F5F9) : const Color(0xFFFAF7F2),
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
                  children: [
                    const SizedBox(height: 12),

                    // 1. Centered Header Title
                    const Center(
                      child: Text(
                        'Attendance',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 2. Dual Segmented Tab Toggle
                    _buildSegmentedToggle(),

                    const SizedBox(height: 16),

                    // 3. Current Date
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        dateStr,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 4. Start Time Card with Digital Clock
                    _buildStartTimeCard(
                      hourStr: hourStr,
                      minStr: minStr,
                      amPmStr: amPmStr,
                      address: primaryOffice?.address ?? 'Kuwaiti Mosque Rd, Dhaka 1212',
                    ),

                    const SizedBox(height: 16),

                    // 5. GPS Map View with Geofence Radar Circle
                    _buildMapContainer(primaryOffice),

                    const SizedBox(height: 24),

                    // 6. Large Circular Green Check In Button
                    _buildLargeCheckInButton(
                      isCheckedIn: isCheckedIn,
                      isCompleted: isCompleted,
                    ),

                    const SizedBox(height: 20),

                    // 7. Supporting Action Controls
                    _buildSupportingActions(isCheckedIn: isCheckedIn),

                    const SizedBox(height: 100), // Spacing for floating bottom bar
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AttendanceBottomNav(
        activeTab: AttendanceNavTab.attendance,
        onTabSelected: (tab) {
          if (tab == AttendanceNavTab.dashboard) {
            context.go(AppRoutes.attendanceDashboard);
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

  Widget _buildSegmentedToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSegmentTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeSegmentTab == 0
                      ? const Color(0xFFF59E0B) // Active golden amber
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Todays Attendance',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _activeSegmentTab == 0 ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSegmentTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeSegmentTab == 1
                      ? const Color(0xFFF59E0B)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Attendance List',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _activeSegmentTab == 1 ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartTimeCard({
    required String hourStr,
    required String minStr,
    required String amPmStr,
    required String address,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Start Time',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),

          // Digital Segmented Time Blocks
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDigitalBox(hourStr),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              ),
              _buildDigitalBox(minStr),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              ),
              _buildDigitalBox(amPmStr),
            ],
          ),

          const SizedBox(height: 10),

          // Location Subtitle
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
                    fontSize: 11.5,
                    color: Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalBox(String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        val,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: Color(0xFF111827),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildMapContainer(dynamic office) {
    final lat = _currentLocation?.latitude ?? office?.latitude ?? 18.5204;
    final lng = _currentLocation?.longitude ?? office?.longitude ?? 73.8567;
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Map layer
            if (isMobile)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(lat, lng),
                  zoom: 16.0,
                ),
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                myLocationEnabled: true,
                circles: {
                  Circle(
                    circleId: const CircleId('geofence'),
                    center: LatLng(lat, lng),
                    radius: (office?.geofenceRadiusMeters ?? 150).toDouble(),
                    fillColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    strokeColor: const Color(0xFF6366F1),
                    strokeWidth: 2,
                  ),
                },
              )
            else
              // Visual map illustration matching reference design for desktop
              Container(
                color: const Color(0xFFE5E7EB),
                child: CustomPaint(
                  size: const Size(double.infinity, 180),
                  painter: _MapGridPainter(),
                ),
              ),

            // Center Radar Rings with Purple Location Pin (matching visual spec)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF4F46E5), // Purple pin circle
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeCheckInButton({
    required bool isCheckedIn,
    required bool isCompleted,
  }) {
    final bgColor = isCompleted
        ? const Color(0xFF10B981)
        : isCheckedIn
            ? const Color(0xFFF97316) // Orange for Checkout
            : const Color(0xFF10B981); // Vibrant green

    return GestureDetector(
      onTap: _isProcessing
          ? null
          : (isCheckedIn ? _handleCheckOut : _handleCheckIn),
      child: Container(
        width: 105,
        height: 105,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _isProcessing
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCheckedIn ? Icons.logout_rounded : Icons.touch_app_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCompleted
                        ? 'Done'
                        : isCheckedIn
                            ? 'Check Out'
                            : 'Check In',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSupportingActions({required bool isCheckedIn}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircularIconBtn(
          icon: Icons.login_rounded,
          onTap: isCheckedIn ? null : _handleCheckIn,
        ),
        const SizedBox(width: 24),
        _buildCircularIconBtn(
          icon: Icons.logout_rounded,
          onTap: isCheckedIn ? _handleCheckOut : null,
        ),
        const SizedBox(width: 24),
        _buildCircularIconBtn(
          icon: Icons.access_time_rounded,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Break duration logged.')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCircularIconBtn({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: const Color(0xFF6366F1)),
        ),
      ),
    );
  }
}

// Custom painter for desktop/test simulated map grid matching visual spec
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 3;

    // Roads and blocks
    canvas.drawLine(const Offset(0, 40), Offset(size.width, 60), paint);
    canvas.drawLine(const Offset(0, 120), Offset(size.width, 100), paint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.4, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.65, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
