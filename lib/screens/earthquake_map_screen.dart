import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lastquake/services/api_service.dart';
import 'package:lastquake/services/location_service.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui';

import 'package:url_launcher/url_launcher.dart';

// --- Top-level function for parsing in an isolate ---
// IMPORTANT: This function must be top-level or static
List<Polyline> _parseGeoJsonFaultLines(String geoJsonString) {
  try {
    final decodedJson = json.decode(geoJsonString);
    final List<Polyline> polylines = [];

    // Assuming GeoJSON format is a FeatureCollection
    if (decodedJson is Map && decodedJson.containsKey('features')) {
      final features = decodedJson['features'] as List;

      for (final feature in features) {
        if (feature is Map && feature.containsKey('geometry')) {
          final geometry = feature['geometry'] as Map;
          final type = geometry['type'];
          final coordinates = geometry['coordinates'] as List;

          if (type == 'LineString') {
            // Coordinates for LineString: [[lon, lat], [lon, lat], ...]
            final points =
                coordinates
                    .map<LatLng?>((coord) {
                      if (coord is List &&
                          coord.length >= 2 &&
                          coord[0] is num &&
                          coord[1] is num) {
                        // IMPORTANT: GeoJSON is usually [longitude, latitude]
                        return LatLng(coord[1].toDouble(), coord[0].toDouble());
                      }
                      return null;
                    })
                    .whereType<LatLng>() // Filter out any nulls from bad coords
                    .toList();

            if (points.isNotEmpty) {
              polylines.add(
                Polyline(
                  points: points,
                  color: Colors.red.withOpacity(0.8), // Style the lines
                  strokeWidth: 1.5,
                  isDotted: false,
                ),
              );
            }
          } else if (type == 'MultiLineString') {
            // Coordinates for MultiLineString: [[[lon, lat], ...], [[lon, lat], ...]]
            for (final line in coordinates) {
              if (line is List) {
                final points =
                    line
                        .map<LatLng?>((coord) {
                          if (coord is List &&
                              coord.length >= 2 &&
                              coord[0] is num &&
                              coord[1] is num) {
                            return LatLng(
                              coord[1].toDouble(),
                              coord[0].toDouble(),
                            );
                          }
                          return null;
                        })
                        .whereType<LatLng>()
                        .toList();

                if (points.isNotEmpty) {
                  polylines.add(
                    Polyline(
                      points: points,
                      color: Colors.orange.withOpacity(
                        0.7,
                      ), // Different color maybe?
                      strokeWidth: 1.5,
                      isDotted: false,
                    ),
                  );
                }
              }
            }
          }
        }
      }
    }
    return polylines;
  } catch (e) {
    print('Error parsing GeoJSON: $e');
    return []; // Return empty list on error
  }
}

class EarthquakeMapScreen extends StatefulWidget {
  const EarthquakeMapScreen({Key? key}) : super(key: key);

  @override
  State<EarthquakeMapScreen> createState() => _EarthquakeMapScreenState();
}

class _EarthquakeMapScreenState extends State<EarthquakeMapScreen>
    with AutomaticKeepAliveClientMixin {
  // State Variables
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _earthquakeData = []; // Store fetched data

  late final MapController _mapController;
  double _zoomLevel = 2.0;
  static const double _minZoom = 2.0;
  static const double _maxZoom = 18.0;
  static const double _clusteringThreshold = 3.0;
  static final Map<double, Color> _markerColorCache = {};
  MapLayerType _selectedMapType = MapLayerType.osm;

  // --- State for Fault Lines ---
  bool _showFaultLines = false; // Initially hidden
  bool _isLoadingFaultLines = false;
  List<Polyline> _faultLinePolylines = []; // To store parsed polylines
  static const String _faultLineDataUrl =
      'https://raw.githubusercontent.com/fraxen/tectonicplates/master/GeoJSON/PB2002_boundaries.json';

  Position? _userPosition;
  bool _isLoadingLocation = false;
  final LocationService _locationService = LocationService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // ADDED: Fetch initial data
    _fetchInitialData();

    // automatic location fetching
    //_fetchUserLocation();
  }

  // ADDED: Fetch initial earthquake data
  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch data (consider if filters are needed here, maybe default magnitude?)
      // For simplicity, fetch recent significant ones initially
      final data = await ApiService.fetchEarthquakes(
        minMagnitude: 3.0, // Default initial fetch, maybe adjustable later
        days: 45,
        forceRefresh: false,
      );
      if (!mounted) return;
      setState(() {
        _earthquakeData = data;
        _isLoading = false;
        // Optionally, trigger marker rebuild if needed immediately,
        // but _buildMarkersInternal will use _earthquakeData anyway.
      });
      // Optionally fetch location now
      // await _fetchUserLocation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load map data: ${e.toString()}";
        _isLoading = false;
      });
    }
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

      if (position != null) {
        setState(() {
          _userPosition = position;
          _isLoadingLocation = false;
        });

        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _zoomLevel,
        );
        _showLocationSuccessSnackBar(); // Added notification
      } else {
        setState(() => _isLoadingLocation = false);
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

  // ADDED: Snackbar for success
  void _showLocationSuccessSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location updated'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
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
      child: const Icon(Icons.location_on, color: Colors.blue, size: 30),
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

  // MODIFIED: Marker building now uses internal _earthquakeData state
  List<Marker> _buildMarkersInternal() {
    final List<Marker> markers = [];
    if (_earthquakeData.isEmpty) return markers; // Return early if no data

    // Use the internal state _earthquakeData
    for (final quake in _earthquakeData) {
      final properties = quake["properties"];
      final geometry = quake["geometry"];

      if (properties == null || geometry == null) continue;

      final coordinates = geometry["coordinates"];
      if (coordinates is! List || coordinates.length < 2) continue;

      final double? lon =
          (coordinates[0] is num) ? coordinates[0].toDouble() : null;
      final double? lat =
          (coordinates[1] is num) ? coordinates[1].toDouble() : null;

      if (lat == null || lon == null) continue;

      final double magnitude = (properties["mag"] as num?)?.toDouble() ?? 0.0;
      final double markerSize = 2 + (magnitude * 4.0).clamp(0, 30);

      // Create a mutable copy of properties to add distance
      final Map<String, dynamic> mutableProperties = Map.from(properties);

      // Calculate distance if user location is available
      if (_userPosition != null) {
        final distance = _locationService.calculateDistance(
          _userPosition!.latitude,
          _userPosition!.longitude,
          lat,
          lon,
        );
        mutableProperties["distance"] = distance.round(); // Add to the copy
      } else {
        mutableProperties.remove("distance");
      }

      markers.add(
        Marker(
          point: LatLng(lat, lon),
          width: markerSize,
          height: markerSize,
          child: GestureDetector(
            onTap: () => _showEarthquakeDetails(mutableProperties),
            child: Tooltip(
              message:
                  'M ${magnitude.toStringAsFixed(1)}\n${mutableProperties["place"] ?? 'Unknown'}',
              preferBelow: false,
              child: Icon(
                Icons.circle,
                color: _getMarkerColor(magnitude).withValues(alpha: 0.8),
                size: markerSize,
              ),
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

  // --- Helper Function to Build the Correct Tile Layer ---
  TileLayer _buildTileLayer() {
    switch (_selectedMapType) {
      case MapLayerType.satellite:
        return TileLayer(
          // Esri World Imagery (check terms: https://www.esri.com/en-us/legal/terms/full-master-agreement)
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          // Note: Esri uses TMS tiling scheme (y-coordinate inverted)
          // FlutterMap usually handles standard {z}/{x}/{y} automatically.
          // If tiles look wrong, you might need `tms: true`, but often not required.
          userAgentPackageName:
              'com.example.lastquake', // Replace with your package name
          maxZoom: 19, // Esri supports higher zoom
        );
      case MapLayerType.terrain:
        return TileLayer(
          // OpenTopoMap (requires attribution: https://opentopomap.org/about)
          urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.lastquake',
          maxZoom: 17, // OpenTopoMap limit
        );
      case MapLayerType.dark:
        return TileLayer(
          // CartoDB Dark Matter (requires attribution: https://carto.com/legal/)
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          // {r} is for retina tiles, FlutterMap handles this automatically based on device pixel ratio
          userAgentPackageName: 'com.example.lastquake',
          maxZoom: 20,
        );
      case MapLayerType.osm: // Default case
      default:
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.lastquake',
          maxZoom: 19, // Standard OSM limit
        );
    }
  }

  // --- Function to Load Fault Line Data ---
  Future<void> _loadFaultLineData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingFaultLines = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Loading fault line data...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final response = await http
          .get(Uri.parse(_faultLineDataUrl))
          .timeout(const Duration(seconds: 20)); // Add timeout

      if (response.statusCode == 200) {
        // Parse the data in a separate isolate using compute
        final List<Polyline> parsedPolylines = await compute(
          _parseGeoJsonFaultLines,
          response.body, // Pass the raw JSON string
        );

        if (!mounted) return; // Check again after async gap

        setState(() {
          _faultLinePolylines = parsedPolylines;
          _showFaultLines = true; // Show the layer now that it's loaded
          _isLoadingFaultLines = false;
        });
        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar(); // Hide loading message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fault lines loaded.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(
          'Failed to load fault line data: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error loading fault lines: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingFaultLines = false;
        _showFaultLines = false; // Ensure it's hidden if loading failed
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading fault lines: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- Helper to toggle fault lines and load data if needed ---
  void _toggleFaultLines() {
    if (_isLoadingFaultLines) return; // Prevent action while loading

    if (_showFaultLines) {
      // Just hide if already shown
      setState(() {
        _showFaultLines = false;
      });
    } else {
      // Show: Load data if it hasn't been loaded yet
      if (_faultLinePolylines.isEmpty) {
        _loadFaultLineData(); // Will set _showFaultLines = true on success
      } else {
        // Data already loaded, just make visible
        setState(() {
          _showFaultLines = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Build markers dynamically based on current state
    final List<Marker> currentMarkers = _buildMarkersInternal();

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
                    : const Icon(Icons.my_location),
            onPressed: _isLoadingLocation ? null : _fetchUserLocation,
            tooltip: 'Find my location',
          ),
          // --- Map Layer Selection Button ---
          PopupMenuButton<dynamic>(
            icon: const Icon(Icons.layers_outlined),
            tooltip: "Map Layers and Features",
            onSelected: (dynamic result) {
              if (result is MapLayerType) {
                // Handle Map Layer Type selection
                if (result != _selectedMapType) {
                  setState(() {
                    _selectedMapType = result;
                  });
                }
              } else if (result == 'toggle_fault_lines') {
                // Handle Fault Line toggle
                _toggleFaultLines(); // Call helper function
              }
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<dynamic>>[
                  const PopupMenuDivider(height: 1), // Divider
                  const PopupMenuItem<dynamic>(
                    enabled: false, // Not selectable, just a header
                    child: Text(
                      "Base Layers",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const PopupMenuItem<MapLayerType>(
                    value: MapLayerType.osm,
                    child: Text('Street Map'),
                  ),
                  const PopupMenuItem<MapLayerType>(
                    value: MapLayerType.satellite,
                    child: Text('Satellite'),
                  ),
                  const PopupMenuItem<MapLayerType>(
                    value: MapLayerType.terrain,
                    child: Text('Terrain'),
                  ),
                  const PopupMenuItem<MapLayerType>(
                    value: MapLayerType.dark,
                    child: Text('Dark Mode'),
                  ),
                  const PopupMenuDivider(height: 1), // Divider
                  // Fault Line Toggle Item (value is String, assignable to dynamic)
                  CheckedPopupMenuItem<String>(
                    // Keep String type for the value itself
                    value: 'toggle_fault_lines',
                    checked: _showFaultLines,
                    child: const Text('Show Fault Lines'), // Add const
                  ),
                ],
            // Optional: Change color based on theme
            // color: theme.colorScheme.surface,
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: Stack(
        children: [
          // Show map content only when not loading and no error
          if (!_isLoading && _error == null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    _userPosition != null
                        ? LatLng(
                          _userPosition!.latitude,
                          _userPosition!.longitude,
                        )
                        : const LatLng(
                          20.0,
                          0.0,
                        ), // Default center (adjust as needed)
                initialZoom: _zoomLevel,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture &&
                      position.zoom != null &&
                      position.zoom != _zoomLevel) {
                    if (mounted) {
                      setState(() {
                        _zoomLevel = position.zoom!;
                      });
                    }
                  }
                },
              ),
              children: [
                _buildTileLayer(),

                // --- Conditional Fault Line Layer ---
                if (_showFaultLines && _faultLinePolylines.isNotEmpty)
                  PolylineLayer(
                    polylines: _faultLinePolylines,
                    polylineCulling: true,
                  ),

                // --- Marker Layer (Clustered or Normal) ---
                // Use currentMarkers built dynamically
                if (_zoomLevel < _clusteringThreshold)
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 45, // Slightly larger radius
                      size: const Size(40, 40),
                      markers: currentMarkers, // Use dynamically built markers
                      polygonOptions: const PolygonOptions(
                        borderColor: Colors.blueAccent,
                        color: Colors.black12, // Less intrusive polygon color
                        borderStrokeWidth: 2,
                      ),
                      builder: (context, markers) {
                        return FloatingActionButton(
                          // Use FAB for better look
                          heroTag: null, // Avoid hero tag conflicts
                          mini: true,
                          backgroundColor: Colors.blue.withOpacity(0.9),
                          onPressed: null, // Not clickable itself
                          child: Text(
                            markers.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  MarkerLayer(
                    markers: currentMarkers,
                  ), // Use dynamically built markers
                RichAttributionWidget(
                  showFlutterMapAttribution: false,
                  attributions: [
                    // Conditionally add attribution based on selected layer
                    if (_selectedMapType == MapLayerType.osm)
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap:
                            () => launchUrl(
                              Uri.parse('https://openstreetmap.org/copyright'),
                            ),
                      ),
                    if (_selectedMapType == MapLayerType.satellite)
                      TextSourceAttribution(
                        'Tiles Esri',
                        onTap:
                            () => launchUrl(Uri.parse('https://www.esri.com/')),
                      ),
                    if (_selectedMapType == MapLayerType.terrain)
                      TextSourceAttribution(
                        'OpenTopoMap (CC-BY-SA)',
                        onTap:
                            () => launchUrl(
                              Uri.parse('https://opentopomap.org/'),
                            ),
                      ),
                    if (_selectedMapType == MapLayerType.dark) ...[
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap:
                            () => launchUrl(
                              Uri.parse('https://openstreetmap.org/copyright'),
                            ),
                      ),
                      TextSourceAttribution(
                        'CARTO',
                        onTap:
                            () => launchUrl(
                              Uri.parse('https://carto.com/attributions'),
                            ),
                      ),
                    ],
                  ],
                  alignment: AttributionAlignment.bottomLeft,
                ),
              ],
            ),

          // Show Loading Indicator Centered
          if (_isLoading)
            const Center(child: CircularProgressIndicator.adaptive()),

          // Show Error Message Centered
          if (_error != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                color: Colors.red.withOpacity(0.8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _fetchInitialData, // Retry button
                      child: const Text("Retry"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Zoom Controls (Positioned on top)
          if (!_isLoading &&
              _error == null) // Only show controls when map is visible
            _ZoomControls(
              zoomLevel: _zoomLevel,
              mapController: _mapController,
              onZoomChanged: (newZoom) {
                if (mounted && newZoom != _zoomLevel) {
                  setState(() {
                    _zoomLevel = newZoom;
                  });
                }
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

  // Define min/max zoom constants locally or pass them
  static const double _minZoom = 2.0;
  static const double _maxZoom = 18.0;

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
            isEnabled: zoomLevel <= _maxZoom,
            onPressed: () {
              final newZoom = (zoomLevel + 1).clamp(_minZoom, _maxZoom);
              mapController.move(mapController.camera.center, newZoom);
              onZoomChanged(newZoom);
            },
          ),
          const SizedBox(height: 8),
          _ZoomButton(
            icon: Icons.remove,
            isEnabled: zoomLevel >= _minZoom,
            onPressed: () {
              final newZoom = (zoomLevel - 1).clamp(_minZoom, _maxZoom);
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
      heroTag: icon.toString(),
      mini: true,
      backgroundColor: isEnabled ? Colors.white : Colors.grey.shade300,
      onPressed: isEnabled ? onPressed : null,
      child: Icon(icon, color: isEnabled ? Colors.black : Colors.grey),
    );
  }
}

/// Extracted details dialog for cleaner code - Modernized Look
class _EarthquakeDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> quake; // Receives the properties map

  const _EarthquakeDetailsDialog({Key? key, required this.quake})
    : super(key: key);

  // Static helper to determine color based on magnitude
  static Color _getMagnitudeColor(double magnitude) {
    // Keep consistent with the map screen's logic
    if (magnitude >= 8.0) return Colors.red.shade900;
    if (magnitude >= 7.0) return Colors.red.shade700;
    if (magnitude >= 6.0) return Colors.orange.shade800;
    if (magnitude >= 5.0) return Colors.amber.shade700;
    return Colors.green.shade600;
  }

  // Helper for date formatting
  static String _formatTimestamp(int timestampMillis) {
    if (timestampMillis <= 0) return "N/A";
    try {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
      // Example format: Jan 5, 2024, 1:30 PM
      return DateFormat('MMM d, yyyy, h:mm a').format(dateTime);
    } catch (e) {
      return "Invalid Date";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract theme data for consistent styling
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Extract data safely
    final String location = quake["place"] ?? "Unknown Location";
    final double magnitude = (quake["mag"] as num?)?.toDouble() ?? 0.0;
    final int timeMillis = quake["time"] ?? 0;
    final int? tsunamiCode = quake["tsunami"] as int?; // Tsunami code (0 or 1)

    // Pre-calculate formatted values
    final String timeFormatted = _formatTimestamp(timeMillis);
    final int? distance = quake["distance"] as int?; // May be null
    final Color magColor = _getMagnitudeColor(magnitude);
    final String tsunamiText = (tsunamiCode == 1) ? "Yes" : "No";
    final Color tsunamiColor =
        (tsunamiCode == 1) ? Colors.blueAccent : colorScheme.onSurfaceVariant;

    return Align(
      alignment: Alignment.topCenter, // Keep alignment
      child: Padding(
        // Add padding around the dialog to avoid touching screen edges
        padding: const EdgeInsets.only(
          top: 60.0,
          left: 15,
          right: 15,
          bottom: 20,
        ),
        child: Material(
          // Material provides elevation and ink effects container
          color: Colors.transparent, // Dialog container handles color
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 400,
            ), // Max width for larger screens
            decoration: BoxDecoration(
              // Use a semi-transparent surface color from the theme
              color: colorScheme.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(16), // Slightly larger radius
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            // Clip the backdrop filter effect to the rounded corners
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //Header Row (Close Button & Magnitude Chip)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Magnitude Chip (more prominent)
                        Chip(
                          backgroundColor: magColor.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          label: Text(
                            "M ${magnitude.toStringAsFixed(1)}",
                            style: textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Close Button
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(15),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close_rounded,
                              size: 24,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // --- Location Title ---
                    Text(
                      location,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Divider(height: 1),
                    // --- Details Section ---
                    _DetailRow(
                      icon: Icons.schedule,
                      iconColor: colorScheme.secondary,
                      text: timeFormatted,
                    ),
                    if (distance != null) ...[
                      const Divider(height: 1, indent: 30),
                      _DetailRow(
                        icon: Icons.social_distance_outlined,
                        iconColor: colorScheme.tertiary,
                        text: "$distance km from your location",
                      ),
                    ],

                    // --- ADDED TSUNAMI ---
                    if (tsunamiCode != null) ...[
                      // Check if tsunami info exists
                      const Divider(height: 1, indent: 30),
                      _DetailRow(
                        icon: Icons.tsunami_rounded, // Tsunami icon
                        iconColor: tsunamiColor, // Color indicates status
                        text: "Tsunami Warning: $tsunamiText",
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Refined Helper widget for details row
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _DetailRow({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum MapLayerType {
  osm, // OpenStreetMap Standard
  satellite, // Satellite Imagery
  terrain, // Topographic/Terrain Map
  dark, // Dark Mode Map
}
