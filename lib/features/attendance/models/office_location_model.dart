// lib/features/attendance/models/office_location_model.dart

class OfficeLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int geofenceRadiusMeters;
  final bool isActive;
  final DateTime createdAt;

  const OfficeLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.geofenceRadiusMeters = 150,
    this.isActive = true,
    required this.createdAt,
  });

  factory OfficeLocation.fromJson(Map<String, dynamic> json) {
    return OfficeLocation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Head Office',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      geofenceRadiusMeters: (json['geofence_radius_meters'] as num?)?.toInt() ?? 150,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'geofence_radius_meters': geofenceRadiusMeters,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
