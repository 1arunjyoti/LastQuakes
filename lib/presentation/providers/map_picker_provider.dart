import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lastquake/services/location_service.dart';

class MapPickerProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();

  LatLng? _selectedLocation;
  LatLng? get selectedLocation => _selectedLocation;

  LatLng _currentCenter = const LatLng(
    39.8283,
    -98.5795,
  ); // Default to US center
  LatLng get currentCenter => _currentCenter;

  bool _isLoadingLocation = false;
  bool get isLoadingLocation => _isLoadingLocation;

  bool _locationPermissionGranted = false;
  bool get locationPermissionGranted => _locationPermissionGranted;

  bool _mapReady = false;
  bool get mapReady => _mapReady;

  String? _error;
  String? get error => _error;

  // Initialize with optional initial center
  void initialize(LatLng? initialCenter) {
    if (initialCenter != null) {
      _selectedLocation = initialCenter;
      _currentCenter = initialCenter;
    }
    // Reset other states
    _isLoadingLocation = false;
    _error = null;
    _mapReady = false;
    // Don't reset permission granted as it might be persistent or checked elsewhere
    // But we should re-check it on init
    _checkLocationPermission();
  }

  void setMapReady(bool ready) {
    _mapReady = ready;
    notifyListeners();
  }

  Future<void> checkPermissionAndCenter() async {
    await _checkLocationPermission();
    if (_locationPermissionGranted && _selectedLocation == null) {
      // Only auto-center if no location is already selected/passed
      await centerOnUserLocation();
    }
  }

  Future<void> _checkLocationPermission() async {
    PermissionStatus status = await Permission.locationWhenInUse.status;
    _locationPermissionGranted = status.isGranted;
    notifyListeners();
  }

  Future<void> centerOnUserLocation() async {
    if (!_locationPermissionGranted) {
      _error = "Location permission not granted.";
      notifyListeners();
      return;
    }

    _isLoadingLocation = true;
    _error = null;
    notifyListeners();

    try {
      Position? userPos = await _locationService.getCurrentLocation();
      if (userPos != null) {
        _currentCenter = LatLng(userPos.latitude, userPos.longitude);
        // If we are centering on user, we might want to update the map controller in UI
        // The UI will listen to _currentCenter changes, but for map movement,
        // the UI usually needs to trigger the controller.
        // We can expose a stream or callback, or just let the UI handle the move
        // when it sees the center change if it wants to follow.
        // However, standard provider pattern usually just updates state.
      } else {
        _error = "Could not get current location.";
      }
    } catch (e) {
      _error = "Error getting location: $e";
    } finally {
      _isLoadingLocation = false;
      notifyListeners();
    }
  }

  void selectLocation(LatLng location) {
    _selectedLocation = location;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
