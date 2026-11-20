// lib/features/attendance/check_in/services/attendance_location_service.dart

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final bool isSuccess;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final bool isMocked;
  final String? errorMessage;

  const LocationResult({
    required this.isSuccess,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.isMocked = false,
    this.errorMessage,
  });
}

class AttendanceLocationService {
  static Future<LocationResult> getCurrentLocation() async {
    // Desktop platform guard: Windows does not provide mobile GPS services natively
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return const LocationResult(
        isSuccess: true,
        latitude: 18.5204, // HQ default
        longitude: 73.8567,
        accuracy: 10.0,
        errorMessage: 'Desktop Platform: Using HQ Authorized Location',
      );
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          isSuccess: false,
          errorMessage: 'Location services are disabled on your device. Please enable GPS.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            isSuccess: false,
            errorMessage: 'Location permission denied. Please allow location access to mark attendance.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          isSuccess: false,
          errorMessage: 'Location permission permanently denied. Please enable location in system settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return LocationResult(
        isSuccess: true,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        isMocked: position.isMocked,
      );
    } catch (e) {
      return LocationResult(
        isSuccess: false,
        errorMessage: 'Failed to acquire GPS location: $e',
      );
    }
  }
}
