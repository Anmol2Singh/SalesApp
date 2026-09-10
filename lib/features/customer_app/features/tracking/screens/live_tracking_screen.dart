import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:salesapp/features/customer_app/core/theme/app_theme.dart';
import 'package:salesapp/features/customer_app/data/models/data_models.dart';
import 'package:salesapp/features/customer_app/data/providers/app_providers.dart';
import 'package:salesapp/features/customer_app/shared/widgets/eta_badge.dart';
import 'package:salesapp/features/customer_app/shared/widgets/glass_card.dart';
import 'package:salesapp/features/customer_app/shared/widgets/toast_service.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Coordinates
  final LatLng _customerLocation = const LatLng(28.5921, 77.0463);
  LatLng _techLocation = const LatLng(28.6045, 77.0315);
  int _etaMinutes = 14;

  @override
  Widget build(BuildContext context) {
    final serviceRequestsAsync = ref.watch(serviceRequestsProvider);
    final techLocationAsync = ref.watch(
      activeTechnicianLocationProvider('tech_1'),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgPrimary : AppColors.bgPrimaryLight,
      body: serviceRequestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return _buildNoBookingsPlaceholder(context, isDark);
          }

          final hasActiveRequest = requests.any((r) => r.status != 'completed' && r.status != 'cancelled');
          if (!hasActiveRequest) {
            return _buildNoActiveTrackingPlaceholder(context, isDark);
          }

          return techLocationAsync.when(
            data: (tech) {
              final lat =
                  tech.currentLocation['latitude'] ?? _techLocation.latitude;
              final lng =
                  tech.currentLocation['longitude'] ?? _techLocation.longitude;
              final newTechPos = LatLng(lat, lng);

              // Update state and animate camera
              _techLocation = newTechPos;
              _updateEta(newTechPos);
              _updateMarkers(newTechPos);

              if (_mapController != null) {
                _mapController!.animateCamera(CameraUpdate.newLatLng(newTechPos));
              }

              return Stack(
                children: [
                  // 1. Map layer
                  _buildMap(newTechPos),

                  // 2. Back button overlay
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 16,
                    child: CircleAvatar(
                      backgroundColor: AppColors.bgSecondary.withOpacity(0.8),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => context.pop(),
                      ),
                    ),
                  ),

                  // 3. Floating live indicator top right
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'LIVE RADAR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Bottom Info Sheet
                  _buildBottomInfoSheet(tech),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildMap(LatLng techPos) {
    // Check if Google Map is config/available. If not, fallback to our beautiful Radar Visualizer!
    // Since Google Maps requires a native manifest key to not crash, we wrap in an error boundary or check
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: techPos, zoom: 14.5),
      myLocationButtonEnabled: false,
      mapType: MapType.normal,
      markers: _markers,
      polylines: _polylines,
      onMapCreated: (controller) {
        _mapController = controller;
        _updateMarkers(techPos);
      },
    );
  }

  void _updateMarkers(LatLng techPos) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: _customerLocation,
          infoWindow: const InfoWindow(title: 'Your Home'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('technician'),
          position: techPos,
          infoWindow: const InfoWindow(title: 'Technician Marcus'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        ),
      );

      // Dash Polyline
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [techPos, _customerLocation],
          color: AppColors.accent,
          width: 4,
          patterns: [PatternItem.dash(15), PatternItem.gap(10)],
        ),
      );
    });
  }

  void _updateEta(LatLng techPos) {
    // Simple distance-based ETA calculation
    double distance = _calculateDistance(
      techPos.latitude,
      techPos.longitude,
      _customerLocation.latitude,
      _customerLocation.longitude,
    );
    // Let's assume average speed is 30 km/h, convert distance to minutes
    // Adding minor padding
    int calcMinutes = (distance * 4).round() + 2;
    _etaMinutes = calcMinutes > 0 ? calcMinutes : 1;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Simple Euclidean distance multiplier for local demo
    double dx = lat1 - lat2;
    double dy = lon1 - lon2;
    return 100 * (dx * dx + dy * dy);
  }

  Widget _buildBottomInfoSheet(Technician tech) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Technician info block
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: NetworkImage(tech.avatarUrl),
                  backgroundColor: AppColors.accent.withOpacity(0.2),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tech.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${tech.rating} • ${tech.vehicleInfo}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Glowing pulsing ETA badge
                ETABadge(etaMinutes: _etaMinutes),
              ],
            ),

            const Divider(color: AppColors.borderColor, height: 24),

            // Status text
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'En Route to Your Home (Valve Leak Repair)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action button row
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderColor),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.phone,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Call Marcus',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _callNumber(tech.phone),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.message_outlined,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      label: const Text(
                        'Message',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        // Open support chat
                        context.go('/support');
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _callNumber(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ToastService.show(
        context,
        'Could not launch dialer.',
        type: ToastType.error,
      );
    }
  }

  Widget _buildNoBookingsPlaceholder(BuildContext context, bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_outlined,
                color: AppColors.primary,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Bookings Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You need to have a registered service request to track your technician in real-time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: subtitleColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: const Text('Book a Service', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                context.go('/bookings');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoActiveTrackingPlaceholder(BuildContext context, bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.map_outlined,
                color: AppColors.accent,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Service Call',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'There is no technician currently en route to your location. Tracking is enabled only when a service call status becomes active.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: subtitleColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.history_toggle_off, color: Colors.white),
              label: const Text('View Bookings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                context.go('/bookings');
              },
            ),
          ],
        ),
      ),
    );
  }
}
