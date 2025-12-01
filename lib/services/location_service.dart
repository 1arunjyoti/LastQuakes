import 'package:geolocator/geolocator.dart';
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

    // Get current position with lower accuracy for faster retrieval
    try {
      _cachedPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10), // Limit location fetch time
        ),
      );
      _lastLocationFetchTime = DateTime.now();
      return _cachedPosition;
    } catch (e) {
      //debugPrint('Error getting location: $e');
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
