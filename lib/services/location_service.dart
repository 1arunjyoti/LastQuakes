import 'dart:async';
import 'dart:math' show sin, cos, sqrt, atan2, pi;

import 'package:fl_location/fl_location.dart';
import 'package:lastquakes/utils/secure_logger.dart';
import 'package:meta/meta.dart';

class LocationService {
  // Singleton pattern for location service
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Location? _cachedLocation;
  DateTime? _lastLocationFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 10);

  Future<Location?> getCurrentLocation({bool forceRefresh = false}) async {
    // Check if location services are enabled
    bool serviceEnabled = await FlLocation.isLocationServicesEnabled;
    if (!serviceEnabled) {
      return null;
    }

    // Check if cached location is still valid and not forcing refresh
    if (!forceRefresh &&
        _cachedLocation != null &&
        _lastLocationFetchTime != null &&
        DateTime.now().difference(_lastLocationFetchTime!) < _cacheDuration) {
      return _cachedLocation;
    }

    // Handle permissions with early returns
    LocationPermission permission = await _checkAndRequestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    // Get current location
    try {
      _cachedLocation = await FlLocation.getLocation(
        accuracy: LocationAccuracy.balanced,
        timeLimit: const Duration(seconds: 10),
      );
      _lastLocationFetchTime = DateTime.now();
      return _cachedLocation;
    } on TimeoutException {
      SecureLogger.warning(
        'Location fetch timed out, attempting retry with lower accuracy',
      );

      // Retry with lower accuracy
      try {
        SecureLogger.info("Retrying with lower accuracy");
        _cachedLocation = await FlLocation.getLocation(
          accuracy: LocationAccuracy.powerSave,
          timeLimit: const Duration(seconds: 5),
        );
        _lastLocationFetchTime = DateTime.now();
        return _cachedLocation;
      } catch (e) {
        SecureLogger.error('Retry failed', e);
      }

      // Return cached location if available
      if (_cachedLocation != null) {
        SecureLogger.info("Using cached location after timeout");
        return _cachedLocation;
      }

      return null;
    } catch (e) {
      SecureLogger.error('Error getting location', e);

      // Return cached location as fallback
      if (_cachedLocation != null) {
        SecureLogger.info("Using cached location as fallback");
        return _cachedLocation;
      }

      return null;
    }
  }

  Future<LocationPermission> _checkAndRequestPermission() async {
    LocationPermission permission = await FlLocation.checkLocationPermission();

    if (permission == LocationPermission.denied) {
      permission = await FlLocation.requestLocationPermission();
    }

    return permission;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await FlLocation.isLocationServicesEnabled;
  }

  /// Check current permission status
  Future<LocationPermission> checkPermission() async {
    return await FlLocation.checkLocationPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await FlLocation.requestLocationPermission();
  }

  // Calculate distance between two coordinates using Haversine formula
  // Returns distance in kilometers
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
