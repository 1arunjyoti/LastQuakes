import 'package:flutter/foundation.dart';

@immutable
class SafeZone {
  final String name;
  final double latitude;
  final double longitude;

  const SafeZone({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  // Factory constructor for creating a new SafeZone instance from a map.
  factory SafeZone.fromJson(Map<String, dynamic> json) {
    return SafeZone(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  // Method for converting a SafeZone instance to a map.
  Map<String, dynamic> toJson() {
    return {'name': name, 'latitude': latitude, 'longitude': longitude};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SafeZone &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => name.hashCode ^ latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() {
    return 'SafeZone{name: $name, latitude: $latitude, longitude: $longitude}';
  }
}
