import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lastquake/services/location_service.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:permission_handler/permission_handler.dart';

// Define min/max zoom levels for button enabling/disabling
const double _minZoom = 3.0;
const double _maxZoom = 18.0;

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialCenter;

  const MapPickerScreen({super.key, this.initialCenter});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  LatLng? _currentCenter;
  final LocationService _locationService = LocationService();
  bool _isLoadingLocation = false;
  bool _locationPermissionGranted = false;
  bool _mapReady = false; 

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialCenter;
    _currentCenter = widget.initialCenter ?? const LatLng(39.8283, -98.5795);
    // Don't call _checkPermissionAndCenter directly here

    // Schedule map initialization checks after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _mapReady = true; 
        });
        // Now it's safer to check permissions and potentially move the map
        _checkPermissionAndCenter();
      }
    });
  }

  // Check permissions and center map if needed
  Future<void> _checkPermissionAndCenter() async {
    if (!_mapReady) return;

    _locationPermissionGranted = await _checkLocationPermission();
    if (_locationPermissionGranted && widget.initialCenter == null) {
      await _centerOnUserLocation();
    }
  }

  // Check if location permission is granted
  Future<bool> _checkLocationPermission() async {
    PermissionStatus status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  // Center map on user's current location
  Future<void> _centerOnUserLocation() async {
    if (!_locationPermissionGranted) {
      debugPrint(
        "MapPicker: Location permission not granted. Cannot center on user.",
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      Position? userPos = await _locationService.getCurrentLocation();
      if (userPos != null && mounted) {
        final userLatLng = LatLng(userPos.latitude, userPos.longitude);
        setState(() {
          _currentCenter = userLatLng;
        });
        if (_mapReady) {
          _mapController.move(userLatLng, 13.0);
        }
      }
    } catch (e) {
      debugPrint("MapPicker: Error getting current location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get current location: ${e.toString()}'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  // Handle map tap to select location
  void _handleTap(TapPosition tapPosition, LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      Navigator.of(context).pop(_selectedLocation);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap on the map to select a location first.'),
        ),
      );
    }
  }

  // --- Zoom Methods ---
  void _zoomIn() {
    if (!_mapReady) return;
    final currentZoom = _mapController.camera.zoom;
    final newZoom = currentZoom + 1;
    if (newZoom <= _maxZoom) {
      _mapController.move(_mapController.camera.center, newZoom);
    }
  }

  void _zoomOut() {
    if (!_mapReady) return;
    final currentZoom = _mapController.camera.zoom;
    final newZoom = currentZoom - 1;
    if (newZoom >= _minZoom) {
      _mapController.move(_mapController.camera.center, newZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LastQuakesAppBar(title: 'Select Safe Zone Location'),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter!,
              initialZoom: _currentCenter == widget.initialCenter ? 5.0 : 13.0,
              onTap: _handleTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.lastquake',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 80,
                      height: 80,
                      child: Icon(
                        Icons.location_pin,
                        size: 50,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_isLoadingLocation)
            const Center(
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.all(Radius.circular(8)),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text("Fetching location..."),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton.extended(
              onPressed: _confirmSelection,
              label: const Text('Confirm Location'),
              icon: const Icon(Icons.check),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'centerLocationMapPicker',
              mini: true,
              onPressed:
                  _locationPermissionGranted ? _centerOnUserLocation : null,
              tooltip:
                  _locationPermissionGranted
                      ? 'Center on my location'
                      : 'Location permission needed',
              backgroundColor:
                  _locationPermissionGranted
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Colors.grey,
              child:
                  _isLoadingLocation
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Icon(
                        Icons.my_location,
                        color:
                            _locationPermissionGranted ? null : Colors.white54,
                      ),
            ),
          ),

          // --- Zoom Buttons ---
          Positioned(
            bottom: 30, 
            left: 30,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoomInMapPicker', 
                  tooltip: 'Zoom In',
                  onPressed:
                      _mapReady && (_mapController.camera.zoom < _maxZoom)
                          ? _zoomIn
                          : null,
                  backgroundColor:
                      _mapReady && (_mapController.camera.zoom < _maxZoom)
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Colors.grey,
                  child: Icon(
                    Icons.add,
                    color:
                        _mapReady && (_mapController.camera.zoom < _maxZoom)
                            ? null
                            : Colors.white54,
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoomOutMapPicker', 
                  tooltip: 'Zoom Out',
                  onPressed:
                      _mapReady && (_mapController.camera.zoom > _minZoom)
                          ? _zoomOut
                          : null,
                  backgroundColor:
                      _mapReady && (_mapController.camera.zoom > _minZoom)
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Colors.grey,
                  child: Icon(
                    Icons.remove,
                    color:
                        _mapReady && (_mapController.camera.zoom > _minZoom)
                            ? null
                            : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
