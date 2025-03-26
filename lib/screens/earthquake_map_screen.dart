import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lastquake/services/location_service.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui';

class EarthquakeMapScreen extends StatefulWidget {
  final List<Map<String, dynamic>> earthquakes;

  const EarthquakeMapScreen({Key? key, required this.earthquakes})
    : super(key: key);

  @override
  State<EarthquakeMapScreen> createState() => _EarthquakeMapScreenState();
}

class _EarthquakeMapScreenState extends State<EarthquakeMapScreen>
    with AutomaticKeepAliveClientMixin {
  late final MapController _mapController;
  double _zoomLevel = 2.0;
  static const double _minZoom = 2.0;
  static const double _maxZoom = 18.0;

  // Zoom level threshold for disabling clustering
  static const double _clusteringThreshold = 3.0;

  // Memoize marker color to avoid repeated calculations
  static Map<double, Color> _markerColorCache = {};

  Position? _userPosition;
  bool _isLoadingLocation = false;
  final LocationService _locationService = LocationService();

  // Memoize markers to avoid unnecessary recalculation
  late final List<Marker> _cachedMarkers;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _cachedMarkers = _buildMarkers(); // Pre-compute markers once
    // automatic location fetching
    //_fetchUserLocation();
  }

  // Optimized location fetching with error handling
  Future<void> _fetchUserLocation() async {
    if (!mounted) return;

    // Check if location services are enabled first
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _showLocationServicesDisabledDialog();
        return;
      }
    }

    setState(() => _isLoadingLocation = true);

    try {
      final position = await _locationService.getCurrentLocation(
        forceRefresh: true,
      );
      if (!mounted) return;

      setState(() {
        _userPosition = position;
        _isLoadingLocation = false;
      });

      if (position != null) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _zoomLevel,
        );
      } else {
        // No position retrieved
        _showLocationErrorDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _showLocationErrorDialog();
      }
    }
  }

  void _showLocationServicesDisabledDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text(
              'Please enable location services on your device to use this feature. '
              'Go to your device settings and turn on location services.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Geolocator.openLocationSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  void _showLocationErrorDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Location Error'),
            content: const Text(
              'Unable to fetch your location. Please check your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // Add a marker for user's current location
  // Cached user location marker
  Marker? _buildUserLocationMarker() {
    if (_userPosition == null) return null;

    return Marker(
      point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
      width: 40,
      height: 40,
      child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
    );
  }

  /// Memoized marker color retrieval
  Color _getMarkerColor(double magnitude) {
    return _markerColorCache.putIfAbsent(magnitude, () {
      if (magnitude >= 8.0) return Colors.red.shade900;
      if (magnitude >= 7.0) return Colors.red;
      if (magnitude >= 6.0) return Colors.orange;
      if (magnitude >= 5.0) return Colors.amber;
      return Colors.green;
    });
  }

  // Optimized marker building with memoization and clustering support
  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];

    for (final quake in widget.earthquakes) {
      // Defensive null and type checking
      final properties = quake["properties"];
      final geometry = quake["geometry"];

      if (properties == null || geometry == null) continue;

      final coordinates = geometry["coordinates"];
      if (coordinates is! List || coordinates.length < 2) continue;

      final double longitude = coordinates[0].toDouble();
      final double latitude = coordinates[1].toDouble();
      final double magnitude = (properties["mag"] as num?)?.toDouble() ?? 0.0;

      // Calculate distance if user location is available
      if (_userPosition != null) {
        final distance = _locationService.calculateDistance(
          _userPosition!.latitude,
          _userPosition!.longitude,
          latitude,
          longitude,
        );
        properties["distance"] = distance.round();
      }

      markers.add(
        Marker(
          point: LatLng(latitude, longitude),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _showEarthquakeDetails(properties),
            child: Icon(
              Icons.location_on,
              color: _getMarkerColor(magnitude),
              size: 10 + (magnitude * 1.5),
            ),
          ),
        ),
      );
    }

    // Add user location marker if available
    final userMarker = _buildUserLocationMarker();
    if (userMarker != null) {
      markers.add(userMarker);
    }

    return markers;
  }

  /// Optimized dialog construction with const and reduced computation
  void _showEarthquakeDetails(Map<String, dynamic> quake) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
      pageBuilder: (context, _, __) {
        return _EarthquakeDetailsDialog(quake: quake);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final markers = _buildMarkers(); // Pre-compute markers

    return Scaffold(
      appBar: LastQuakesAppBar(
        title: "LastQuakes Map",
        actions: [
          IconButton(
            icon:
                _isLoadingLocation
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.location_searching),
            onPressed: _fetchUserLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _userPosition != null
                      ? LatLng(
                        _userPosition!.latitude,
                        _userPosition!.longitude,
                      )
                      : LatLng(20.0, 78.9), // Center of India
              initialZoom: _zoomLevel,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
                maxZoom: _maxZoom,
              ),
              //MarkerLayer(markers: markers),
              // Use MarkerClusterLayer directly
              // Replace MarkerLayer with MarkerClusterLayer
              if (_zoomLevel < _clusteringThreshold)
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    maxClusterRadius: 40,
                    size: const Size(40, 40),
                    markers: markers,
                    polygonOptions: const PolygonOptions(
                      borderColor: Colors.blueAccent,
                      color: Colors.blue,
                      borderStrokeWidth: 3,
                    ),
                    builder: (context, markers) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.blue.withValues(alpha: .8),
                        ),
                        child: Center(
                          child: Text(
                            markers.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                MarkerLayer(markers: markers),
            ],
          ),
          _ZoomControls(
            zoomLevel: _zoomLevel,
            mapController: _mapController,
            onZoomChanged: (newZoom) {
              setState(() => _zoomLevel = newZoom);
            },
          ),
        ],
      ),
    );
  }
}

/// Extracted zoom controls widget for better separation of concerns
class _ZoomControls extends StatelessWidget {
  final double zoomLevel;
  final MapController mapController;
  final ValueChanged<double> onZoomChanged;

  const _ZoomControls({
    required this.zoomLevel,
    required this.mapController,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Column(
        children: [
          _ZoomButton(
            icon: Icons.add,
            isEnabled: zoomLevel <= 18.0,
            onPressed: () {
              final newZoom = (zoomLevel + 1).clamp(1.0, 18.0);
              mapController.move(mapController.camera.center, newZoom);
              onZoomChanged(newZoom);
            },
          ),
          const SizedBox(height: 8),
          _ZoomButton(
            icon: Icons.remove,
            isEnabled: zoomLevel >= 1.0,
            onPressed: () {
              final newZoom = (zoomLevel - 1).clamp(1.0, 18.0);
              mapController.move(mapController.camera.center, newZoom);
              onZoomChanged(newZoom);
            },
          ),
        ],
      ),
    );
  }
}

/// Simplified zoom button widget
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final bool isEnabled;
  final VoidCallback onPressed;

  const _ZoomButton({
    required this.icon,
    required this.isEnabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: icon.toString(), // Unique hero tag
      mini: true,
      backgroundColor: isEnabled ? Colors.white : Colors.grey.shade300,
      onPressed: isEnabled ? onPressed : null,
      child: Icon(icon, color: isEnabled ? Colors.black : Colors.grey),
    );
  }
}

/// Extracted details dialog for cleaner code
class _EarthquakeDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> quake;

  const _EarthquakeDetailsDialog({required this.quake});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(top: 50),
          padding: const EdgeInsets.all(16),
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close Button
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.black54),
                    ),
                  ),

                  // Earthquake Location
                  Text(
                    quake["place"] ?? "Unknown Location",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Magnitude
                  _DetailRow(
                    icon: Icons.bar_chart,
                    iconColor: Colors.deepOrange,
                    text: "Magnitude: ${quake["mag"] ?? "N/A"}",
                  ),
                  const SizedBox(height: 6),

                  // Time
                  _DetailRow(
                    icon: Icons.access_time,
                    iconColor: Colors.blueAccent,
                    text:
                        "Time: ${DateTime.fromMillisecondsSinceEpoch(quake["time"])}",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper widget for details row
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
      ],
    );
  }
}
