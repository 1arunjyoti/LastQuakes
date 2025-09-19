import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:lastquake/screens/earthquake_details.dart';
import 'package:lastquake/services/api_service.dart';
import 'package:lastquake/services/location_service.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:lastquake/utils/formatting.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
import 'package:lastquake/widgets/components/location_button.dart';
import 'package:lastquake/widgets/components/map_layers_button.dart';
import 'package:lastquake/widgets/components/zoom_controls.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Top-level function for parsing in an isolate ---
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
                  color: Colors.red.withValues(alpha: 0.8), // Style the lines
                  strokeWidth: 1.5,
                  //isDotted: false,
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
                      color: Colors.orange.withValues(
                        alpha: 0.7,
                      ), // Different color for MultiLineString
                      strokeWidth: 1.5,
                      //isDotted: false,
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
    debugPrint('Error parsing GeoJSON: $e');
    return []; // Return empty list on error
  }
}

// Top level isolate function and data class for filtering
class FilterParameters {
  final List<Map<String, dynamic>> earthquakes;
  final double minMagnitude;
  final DateTime? cutoffTime;

  FilterParameters({
    required this.earthquakes,
    required this.minMagnitude,
    this.cutoffTime,
  });
}

List<Map<String, dynamic>> _filterEarthquakesIsolate(FilterParameters params) {
  return params.earthquakes.where((quake) {
    final properties = quake['properties'];
    if (properties == null || properties is! Map) return false;

    final magnitude = (properties['mag'] as num?)?.toDouble() ?? 0.0;
    final timeMillis = (properties['time'] as int?) ?? 0;

    bool passesMagnitude = magnitude >= params.minMagnitude;
    bool passesTime = true;
    if (params.cutoffTime != null && timeMillis > 0) {
      final quakeDateTime = DateTime.fromMillisecondsSinceEpoch(timeMillis);
      passesTime = quakeDateTime.isAfter(params.cutoffTime!);
    }

    return passesMagnitude && passesTime;
  }).toList();
}

class EarthquakeMapScreen extends StatefulWidget {
  const EarthquakeMapScreen({super.key});

  @override
  State<EarthquakeMapScreen> createState() => _EarthquakeMapScreenState();
}

class _EarthquakeMapScreenState extends State<EarthquakeMapScreen>
    with AutomaticKeepAliveClientMixin {
  // State Variables
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _allFetchedEarthquakes = []; // Store fetched data
  List<Map<String, dynamic>> _filteredEarthquakes = [];
  List<Marker> _currentMarkers = []; // Memoized markers list

  late final MapController _mapController;
  double _zoomLevel = 2.0;
  static const double _minZoom = 2.0;
  static const double _maxZoom = 18.0;
  double _currentRotation = 0.0;
  static const double _clusteringThreshold = 3.0;
  static final Map<double, Color> _markerColorCache = {};
  MapLayerType _selectedMapType = MapLayerType.osm;

  // --- State for Fault Lines ---
  bool _showFaultLines = false; // Initially hidden
  bool _isLoadingFaultLines = false;
  List<Polyline> _faultLinePolylines = []; // To store parsed polylines
  static const String _faultLineDataUrl =
      'https://raw.githubusercontent.com/fraxen/tectonicplates/master/GeoJSON/PB2002_boundaries.json';

  static const String _mapTypePrefKey =
      'map_layer_type_preference_v2'; // Use v2 for enum name storage
  static const String _showFaultLinesPrefKey = 'show_fault_lines_preference';

  Position? _userPosition;
  final LocationService _locationService = LocationService();

  // --- State Variables for Filtering ---
  double _selectedMinMagnitude = 3.0;
  bool _isFilteringLocally = false;
  static final List<double> _magnitudeFilterOptions = [
    3.0,
    4.0,
    5.0,
    6.0,
    7.0,
    8.0,
    9.0,
  ];
  // --- State for Time Window
  TimeWindow _selectedTimeWindow =
      TimeWindow.last45Days; // Default to show all fetched data

  @override
  bool get wantKeepAlive => true;

  // initialize state and load preferences
  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _loadMapPreferences();

    // Fetch initial data
    _fetchInitialData();
  }

  // --- Helper to load preferences ---
  Future<void> _loadMapPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Map Layer Type
    final String? savedMapTypeString = prefs.getString(_mapTypePrefKey);
    MapLayerType loadedMapType = MapLayerType.osm; // Default
    if (savedMapTypeString != null) {
      // Try to find the enum value matching the saved string name
      try {
        loadedMapType = MapLayerType.values.firstWhere(
          (e) => e.name == savedMapTypeString,
          // orElse: () => MapLayerType.osm // Redundant with default above
        );
      } catch (e) {
        debugPrint(
          "Error parsing saved map type '$savedMapTypeString', defaulting to osm.",
        );
        loadedMapType = MapLayerType.osm; // Fallback on error
      }
    }

    // Load Fault Line Visibility
    final bool loadedShowFaultLines =
        prefs.getBool(_showFaultLinesPrefKey) ?? false; // Default to false

    // Update state if the widget is still mounted after async operation
    if (mounted) {
      setState(() {
        _selectedMapType = loadedMapType;
        _showFaultLines = loadedShowFaultLines;

        // --- Load fault lines if preference was true ---
        // If the preference was to show fault lines, AND they haven't been loaded yet,
        // trigger the load now.
        if (_showFaultLines && _faultLinePolylines.isEmpty) {
          _loadFaultLineData(); // Don't await here, let it load in background
        }
      });
    }
  }

  // Save a boolean preference
  Future<void> _saveBoolPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // Fetch initial earthquake data
  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch data from API
      // For simplicity, fetch recent significant ones initially
      final data = await ApiService.fetchEarthquakes(
        minMagnitude: 3.0, // Default initial fetch
        days: 45,
        forceRefresh: false,
      );
      if (!mounted) return;

      _allFetchedEarthquakes = data;
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load map data: ${e.toString()}";
        _isLoading = false;
        _isFilteringLocally = false;
      });
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Apply filters using isolate for performance
  Future<void> _applyFilters() async {
    if (!mounted) return;
    setState(() {
      _isFilteringLocally = true;
    });

    // Calculate Time Cutoff
    final now = DateTime.now();
    DateTime? cutoffTime;

    switch (_selectedTimeWindow) {
      case TimeWindow.lastHour:
        cutoffTime = now.subtract(const Duration(hours: 1));
        break;
      case TimeWindow.last24Hours:
        cutoffTime = now.subtract(const Duration(days: 1));
        break;
      case TimeWindow.last7Days:
        cutoffTime = now.subtract(const Duration(days: 7));
        break;
      case TimeWindow.last45Days:
        cutoffTime = null;
        break;
    }

    // Create filter parameters for isolate
    final params = FilterParameters(
      earthquakes: _allFetchedEarthquakes,
      minMagnitude: _selectedMinMagnitude,
      cutoffTime: cutoffTime,
    );

    try {
      // Run filtering in isolate
      final filteredResults = await compute(_filterEarthquakesIsolate, params);

      if (!mounted) return;
      setState(() {
        _filteredEarthquakes = filteredResults;
        _isFilteringLocally = false;
      });

      // Update markers after filtering
      _updateMarkers();
    } catch (e) {
      debugPrint('Error during filtering: $e');
      if (!mounted) return;
      setState(() {
        _isFilteringLocally = false;
      });
    }
  }

  // Update markers based on filtered earthquakes
  void _updateMarkers() {
    if (!mounted) return;

    final List<Marker> newMarkers = [];
    if (_filteredEarthquakes.isEmpty) {
      setState(() => _currentMarkers = newMarkers);
      return;
    }

    // Create markers from filtered earthquakes
    for (final quake in _filteredEarthquakes) {
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
      final Color markerColor = _getMarkerColor(
        magnitude,
      ).withValues(alpha: 0.85);

      // Create a mutable copy of properties to add distance
      final Map<String, dynamic> mutableProperties = Map.from(properties);

      // Calculate distance if user location is available
      if (_userPosition != null) {
        final distanceKm = _locationService.calculateDistance(
          _userPosition!.latitude,
          _userPosition!.longitude,
          lat,
          lon,
        );
        mutableProperties["distance"] = distanceKm.round();
      } else {
        mutableProperties.remove("distance");
      }
      // Create the marker with GestureDetector for taps
      newMarkers.add(
        Marker(
          point: LatLng(lat, lon),
          width: markerSize,
          height: markerSize,
          child: GestureDetector(
            onTap: () => _showEarthquakeDetails(mutableProperties, quake),
            child: Tooltip(
              message:
                  'M ${magnitude.toStringAsFixed(1)}\n${mutableProperties["place"] ?? 'Unknown'}',
              preferBelow: false,
              child: Container(
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Add user location marker if available
    final userMarker = _buildUserLocationMarker();
    if (userMarker != null) {
      newMarkers.add(userMarker);
    }

    setState(() => _currentMarkers = newMarkers);
  }

  // Show modern filter bottom sheet
  void _showFilterBottomSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            double currentSliderValue = _selectedMinMagnitude;
            TimeWindow currentTimeWindow = _selectedTimeWindow;

            // Helper map for chip labels
            const timeWindowLabels = {
              TimeWindow.lastHour: "Last Hour",
              TimeWindow.last24Hours: "Last 24 Hrs",
              TimeWindow.last7Days: "Last 7 Days",
              TimeWindow.last45Days: "All (45 Days)",
            };

            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter Earthquakes',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // --- Minimum Magnitude Section ---
                    Text(
                      "Minimum Magnitude",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.waves,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "≥ ${currentSliderValue.toStringAsFixed(1)}",
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 12,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 20,
                        ),
                      ),
                      child: Slider(
                        value: currentSliderValue,
                        min: _magnitudeFilterOptions.first,
                        max: _magnitudeFilterOptions.last,
                        divisions:
                            (_magnitudeFilterOptions.last -
                                    _magnitudeFilterOptions.first)
                                .toInt() *
                            2,
                        label: "≥ ${currentSliderValue.toStringAsFixed(1)}",
                        onChanged: (double value) {
                          double newValue = (value * 2).round() / 2;
                          setSheetState(() {
                            currentSliderValue = newValue;
                          });
                          // Update parent state immediately for UI responsiveness
                          setState(() {
                            _selectedMinMagnitude = newValue;
                          });
                        },
                        onChangeEnd: (double value) {
                          // Apply filters only when user stops dragging
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- Time Window Section ---
                    Text(
                      "Time Window",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children:
                          TimeWindow.values.map((window) {
                            final isSelected = currentTimeWindow == window;
                            return FilterChip(
                              label: Text(timeWindowLabels[window] ?? "N/A"),
                              selected: isSelected,
                              onSelected: (bool selected) {
                                if (selected) {
                                  setSheetState(() {
                                    currentTimeWindow = window;
                                  });
                                  if (_selectedTimeWindow != window) {
                                    setState(() {
                                      _selectedTimeWindow = window;
                                    });
                                    _applyFilters();
                                  }
                                }
                              },
                              backgroundColor: colorScheme.surface,
                              selectedColor: colorScheme.primaryContainer,
                              checkmarkColor: colorScheme.primary,
                              side: BorderSide(
                                color:
                                    isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outline.withValues(
                                          alpha: 0.5,
                                        ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  // Memoized marker color retrieval
  Color _getMarkerColor(double magnitude) {
    return _markerColorCache.putIfAbsent(magnitude, () {
      if (magnitude >= 8.0) return Colors.red.shade900;
      if (magnitude >= 7.0) return Colors.red.shade700;
      if (magnitude >= 6.0) return Colors.orange.shade800;
      if (magnitude >= 5.0) return Colors.amber.shade700;
      return Colors.green.shade600;
    });
  }

  // Navigate to earthquake details screen
  void _navigateToEarthquakeDetails(Map<String, dynamic> quake) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EarthquakeDetailsScreen(quakeData: quake),
      ),
    );
  }

  // Dialog construction with const and reduced computation
  void _showEarthquakeDetails(
    Map<String, dynamic> quakeProperties,
    Map<String, dynamic> fullQuakeData,
  ) {
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
        return _EarthquakeDetailsDialog(
          quake: quakeProperties,
          fullQuakeData: fullQuakeData,
          onDetailsPressed: () {
            Navigator.pop(context); // Close dialog first
            _navigateToEarthquakeDetails(fullQuakeData);
          },
        );
      },
    );
  }

  // --- Helper Function to Build the Map Layer
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
          maxZoom: 19,
        );
      case MapLayerType.terrain:
        return TileLayer(
          // USGS Topo (check terms: https://www.usgs.gov/information-policies-and-notices)
          urlTemplate:
              'https://basemap.nationalmap.gov/arcgis/rest/services/USGSTopo/MapServer/tile/{z}/{y}/{x}',
          //subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.lastquake',
          maxZoom: 15, // OpenTopoMap limit
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
      case MapLayerType.osm:
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

    /* ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Loading fault line data...'),
        duration: Duration(seconds: 2),
      ),
    ); */

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
          _showFaultLines = true;
          _isLoadingFaultLines = false;
        });
        await _saveBoolPreference(_showFaultLinesPrefKey, true);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).hideCurrentSnackBar(); // Hide loading message
        }
        /* ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fault lines loaded.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        ); */
      } else {
        throw Exception(
          'Failed to load fault line data: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error loading fault lines: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingFaultLines = false;
        _showFaultLines = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading fault lines: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      await _saveBoolPreference(_showFaultLinesPrefKey, false);
    }
  }

  // --- Helper to toggle fault lines and load data if needed ---
  void _toggleFaultLines() async {
    if (_isLoadingFaultLines) return; // Prevent action while loading

    if (_showFaultLines) {
      setState(() {
        _showFaultLines = false;
      });
      await _saveBoolPreference(_showFaultLinesPrefKey, false);
    } else {
      // Load data if it hasn't been loaded yet
      if (_faultLinePolylines.isNotEmpty) {
        setState(() {
          _showFaultLines = true;
        });
        await _saveBoolPreference(_showFaultLinesPrefKey, true);
      } else {
        _loadFaultLineData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: LastQuakesAppBar(
        title: "LastQuakes Map",
        actions: const [], // Remove actions from app bar for cleaner look
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
                          20.6,
                          78.9,
                        ), // Default center (adjust as needed)
                initialZoom: _zoomLevel,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                onPositionChanged: (position, hasGesture) {
                  // --- UPDATE Rotation State ---
                  final newRotation =
                      position.rotation; // Rotation is in degrees
                  if (newRotation != _currentRotation) {
                    if (mounted) {
                      // Check if widget is still mounted
                      setState(() {
                        _currentRotation = newRotation;
                      });
                    }
                  }

                  //  zoom level update logic
                  if (hasGesture && position.zoom != _zoomLevel) {
                    if (mounted) {
                      setState(() {
                        _zoomLevel = position.zoom;
                      });
                    }
                  }
                },
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.all,
                  // --- SET Rotation Threshold
                  rotationThreshold: 0.7,
                ),
              ),
              children: [
                _buildTileLayer(),

                // --- Conditional Fault Line Layer ---
                if (_showFaultLines && _faultLinePolylines.isNotEmpty)
                  PolylineLayer(
                    polylines: _faultLinePolylines,
                    //polylineCulling: true,
                  ),

                // --- Marker Layer (Clustered or Normal) ---
                if (_zoomLevel < _clusteringThreshold)
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 45,
                      size: const Size(40, 40),
                      markers: _currentMarkers, // Use memoized markers
                      polygonOptions: const PolygonOptions(
                        borderColor: Colors.blueAccent,
                        color: Colors.black12,
                        borderStrokeWidth: 2,
                      ),

                      builder: (context, markers) {
                        return Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              markers.length.toString(),
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  MarkerLayer(markers: _currentMarkers), // Use memoized markers
                // --- Attribution Widget ---
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
                        'USGS',
                        onTap:
                            () => launchUrl(Uri.parse('https://www.usgs.gov/')),
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
            Container(
              color: colorScheme.surface.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator.adaptive(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading earthquake data...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Show Error Message Centered
          if (_error != null)
            Container(
              color: colorScheme.surface.withValues(alpha: 0.9),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connection Error',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _fetchInitialData,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // --- LOCAL FILTERING INDICATOR ---
          if (_isFilteringLocally && !_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.0),
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
              ),
            ),

          // Modern floating controls panel
          if (!_isLoading && _error == null) _buildModernControlsPanel(context),

          // --- COMPASS BUTTON (Top-Right) ---
          if (!_isLoading && _error == null) // Only show if map is visible
            _buildModernCompassButton(context),
        ],
      ),
    );
  }

  // --- Modern Compass Button Widget ---
  Widget _buildModernCompassButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isRotated = _currentRotation.abs() > 1.0;
    final double rotationRadians = _currentRotation * (math.pi / 180.0);

    return Positioned(
      top: 16,
      right: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isRotated ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !isRotated,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _resetRotation,
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  child: Transform.rotate(
                    angle: -rotationRadians,
                    child: Icon(
                      Icons.navigation_rounded,
                      size: 24.0,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Modern Controls Panel ---
  Widget _buildModernControlsPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Map layers button
          MapLayersButton(
            selectedMapType: _selectedMapType,
            showFaultLines: _showFaultLines,
            isLoadingFaultLines: _isLoadingFaultLines,
            onMapTypeChanged: (mapType) {
              setState(() {
                _selectedMapType = mapType;
              });
            },
            onFaultLinesToggled: (show) {
              _toggleFaultLines();
            },
          ),
          const SizedBox(height: 12),

          // Location button
          LocationButton(
            mapController: _mapController,
            zoomLevel: _zoomLevel,
            onLocationFound: (position) {
              setState(() {
                _userPosition = position;
              });
              _updateMarkers();
            },
            onLocationError: () {
              // Handle location error if needed
            },
          ),
          const SizedBox(height: 12),

          // Zoom controls
          ZoomControls(
            zoomLevel: _zoomLevel,
            mapController: _mapController,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
            onZoomChanged: (newZoom) {
              if (mounted && newZoom != _zoomLevel) {
                setState(() {
                  _zoomLevel = newZoom;
                });
              }
            },
          ),
          const SizedBox(height: 12),

          // Filter button (replaces FAB)
          _ModernControlButton(
            icon: Icons.tune,
            tooltip: 'Filter Earthquakes',
            onPressed: _showFilterBottomSheet,
            colorScheme: colorScheme,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  // --- Action to reset rotation ---
  void _resetRotation() {
    // Animate rotation back to 0 degrees
    _mapController.moveAndRotate(
      _mapController.camera.center, // Keep current center
      _mapController.camera.zoom, // Keep current zoom
      0.0, // Target rotation (North up)
    );
  }
}

/// Modern Control Button Widget
class _ModernControlButton extends StatelessWidget {
  final IconData? icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;
  final bool isPrimary;

  const _ModernControlButton({
    this.icon,
    required this.tooltip,
    this.onPressed,
    required this.colorScheme,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color:
              isPrimary
                  ? colorScheme.primary
                  : colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Icon(
                icon,
                size: 24,
                color:
                    isPrimary ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern Earthquake Details Dialog
class _EarthquakeDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> quake;
  final Map<String, dynamic> fullQuakeData;
  final VoidCallback onDetailsPressed;

  const _EarthquakeDetailsDialog({
    required this.quake,
    required this.fullQuakeData,
    required this.onDetailsPressed,
  });

  static Color _getMagnitudeColor(double magnitude) {
    if (magnitude >= 8.0) return Colors.red.shade900;
    if (magnitude >= 7.0) return Colors.red.shade700;
    if (magnitude >= 6.0) return Colors.orange.shade800;
    if (magnitude >= 5.0) return Colors.amber.shade700;
    return Colors.green.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Extract data safely
    final String location = quake["place"] ?? "Unknown Location";
    final double magnitude = (quake["mag"] as num?)?.toDouble() ?? 0.0;
    final int timeMillis = quake["time"] ?? 0;
    final int? tsunamiCode = quake["tsunami"] as int?;
    final int? distanceRaw = quake["distance"] as int?;
    final String displayLocationTitle = FormattingUtils.formatPlaceString(
      context,
      location,
    );

    // Pre-calculate formatted values
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timeMillis);
    final String timeFormatted = FormattingUtils.formatDateTime(
      context,
      dateTime,
    );
    String? distanceFormatted;
    if (distanceRaw != null) {
      distanceFormatted = FormattingUtils.formatDistance(
        context,
        distanceRaw.toDouble(),
      );
    }
    final Color magColor = _getMagnitudeColor(magnitude);
    final String tsunamiText = (tsunamiCode == 1) ? "Yes" : "No";
    final Color tsunamiColor =
        (tsunamiCode == 1) ? Colors.blueAccent : colorScheme.onSurfaceVariant;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(
          top: 80.0,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with gradient background
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          magColor.withValues(alpha: 0.8),
                          magColor.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Magnitude display
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.waves,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Magnitude",
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    magnitude.toStringAsFixed(1),
                                    style: textTheme.headlineMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Close Button
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Location
                        Text(
                          displayLocationTitle,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Details
                        _ModernDetailRow(
                          icon: Icons.access_time_rounded,
                          iconColor: colorScheme.primary,
                          title: "Time",
                          value: timeFormatted,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),

                        if (distanceFormatted != null) ...[
                          const SizedBox(height: 16),
                          _ModernDetailRow(
                            icon: Icons.location_on_outlined,
                            iconColor: colorScheme.secondary,
                            title: "Distance",
                            value: "$distanceFormatted from your location",
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                          ),
                        ],

                        if (tsunamiCode != null) ...[
                          const SizedBox(height: 16),
                          _ModernDetailRow(
                            icon: Icons.tsunami_rounded,
                            iconColor: tsunamiColor,
                            title: "Tsunami Warning",
                            value: tsunamiText,
                            colorScheme: colorScheme,
                            textTheme: textTheme,
                          ),
                        ],

                        // Details Button
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onDetailsPressed,
                            icon: const Icon(Icons.info_outline),
                            label: const Text("View Full Details"),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// Modern Detail Row Widget
class _ModernDetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ModernDetailRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
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
