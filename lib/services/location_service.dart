import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;

import 'package:flutter/services.dart';
import 'package:lastquakes/utils/secure_logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:meta/meta.dart';

/// Custom Location class to replace fl_location dependency
class Location {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double speed;
  final double heading;
  final DateTime timestamp;

  Location({
    required this.latitude,
    required this.longitude,
    this.accuracy = 0.0,
    this.altitude = 0.0,
    this.speed = 0.0,
    this.heading = 0.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Location.fromJson(Map<dynamic, dynamic> json) {
    return Location(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
      timestamp:
          json['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                (json['timestamp'] as num).toInt(),
              )
              : null,
    );
  }

  @override
  String toString() {
    return 'Location(latitude: $latitude, longitude: $longitude)';
  }
}

class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static const MethodChannel _channel = MethodChannel(
    'app.lastquakes.foss/location',
  );

  Location? _cachedLocation;
  DateTime? _lastLocationFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 10);

  Future<Location?> getCurrentLocation({bool forceRefresh = false}) async {
    // Check if cached location is valid
    if (!forceRefresh &&
        _cachedLocation != null &&
        _lastLocationFetchTime != null &&
        DateTime.now().difference(_lastLocationFetchTime!) < _cacheDuration) {
      return _cachedLocation;
    }

    // Check permission using permission_handler (standard Android permission)
    final status = await Permission.location.status;
    if (!status.isGranted) {
      return null;
    }

    try {
      // Invoke native method
      final result = await _channel.invokeMethod('getCurrentLocation');

      if (result != null) {
        final location = Location.fromJson(result);
        _cachedLocation = location;
        _lastLocationFetchTime = DateTime.now();
        return location;
      }
    } on PlatformException catch (e) {
      SecureLogger.error('Error fetching native location', e);
    } catch (e) {
      SecureLogger.error('Unknown location error', e);
    }

    return null;
  }

  Future<bool> isLocationServiceEnabled() async {
    final status = await Permission.location.serviceStatus;
    return status.isEnabled;
  }

  Future<PermissionStatus> checkPermission() async {
    return await Permission.location.status;
  }

  Future<PermissionStatus> requestPermission() async {
    return await Permission.location.request();
  }

  // Calculate distance between two coordinates using Haversine formula
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _toRadians(endLatitude - startLatitude);
    final double dLon = _toRadians(endLongitude - startLongitude);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(startLatitude)) *
            cos(_toRadians(endLatitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  @visibleForTesting
  void clearCache() {
    _cachedLocation = null;
    _lastLocationFetchTime = null;
  }
}
