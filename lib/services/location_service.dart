import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:lastquake/utils/secure_logger.dart';
import 'package:meta/meta.dart';

class LocationService {
  // Singleton pattern for location service
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _cachedPosition;
  DateTime? _lastLocationFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 10);

  Future<Position?> getCurrentLocation({bool forceRefresh = false}) async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      //debugPrint('Location services are disabled.');
      return null;
    }

    // Check if cached location is still valid and not forcing refresh
    if (!forceRefresh &&
        _cachedPosition != null &&
        _lastLocationFetchTime != null &&
        DateTime.now().difference(_lastLocationFetchTime!) < _cacheDuration) {
      return _cachedPosition;
    }

    // Handle permissions with early returns
    LocationPermission permission = await _checkAndRequestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    // OPTIMIZATION: Check last known position first
    // This is much faster than waiting for a fresh GPS fix
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        // If last known location is recent (e.g., within 1 hour), use it
        // Note: Geolocator doesn't provide timestamp for lastKnownPosition on all platforms easily,
        // but if it's available, it's usually "recent enough" for earthquake proximity.
        // For stricter freshness, we'd need to check the timestamp if available in Position object.
        // Position object has a timestamp.
        final now = DateTime.now();
        // timestamp is non-nullable in newer geolocator versions
        if (now.difference(lastKnown.timestamp) < const Duration(hours: 1)) {
          SecureLogger.info("Using fresh last known position");
          _cachedPosition = lastKnown;
          _lastLocationFetchTime = now;
          return lastKnown;
        }
      }
    } catch (e) {
      SecureLogger.error("Failed to get last known position", e);
    }

    // Get current position with lower accuracy for faster retrieval
    try {
      _cachedPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10), // Reduced from 20s to 10s
        ),
      );
      _lastLocationFetchTime = DateTime.now();
      return _cachedPosition;
    } on TimeoutException catch (e) {
      SecureLogger.warning(
        'Location fetch timed out, attempting fallback/retry',
      );

      // 1. Try last known position as fallback (even if slightly old)
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          SecureLogger.info("Using last known position after timeout");
          _cachedPosition = lastKnown;
          return lastKnown;
        }
      } catch (e2) {
        SecureLogger.error('Error getting last known location', e2);
      }

      // 2. Retry with lower accuracy if no last known position
      try {
        SecureLogger.info("Retrying with lower accuracy");
        _cachedPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
        _lastLocationFetchTime = DateTime.now();
        return _cachedPosition;
      } catch (e3) {
        SecureLogger.error('Retry failed', e3);
      }

      return null;
    } catch (e) {
      SecureLogger.error('Error getting location', e);

      // Fallback to last known position
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          SecureLogger.info("Using last known position as fallback");
          _cachedPosition = lastKnown;
          // Don't update _lastLocationFetchTime so we try fresh next time
          return lastKnown;
        }
      } catch (e2) {
        SecureLogger.error('Error getting last known location', e2);
      }

      return null;
    }
  }

  Future<LocationPermission> _checkAndRequestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  // Calculate distance between two coordinates
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
          startLatitude,
          startLongitude,
          endLatitude,
          endLongitude,
        ) /
        1000; // Convert to kilometers
  }

  @visibleForTesting
  void clearCache() {
    _cachedPosition = null;
    _lastLocationFetchTime = null;
  }
}
