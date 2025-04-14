import 'dart:convert';
import 'dart:math' show pi;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:lastquake/services/api_service.dart';
import 'package:lastquake/services/location_service.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:lastquake/utils/formatting.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
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
                      ), // Different color maybe?
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
  const EarthquakeMapScreen({Key? key}) : super(key: key);

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
  bool _isLoadingLocation = false;
  final LocationService _locationService = LocationService();

  // --- NEW State Variables for Filtering ---
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

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _loadMapPreferences();

    // ADDED: Fetch initial data
    _fetchInitialData();

    // automatic location fetching
    //_fetchUserLocation();
  }

  // --- NEW: Helper to load preferences ---
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

        // --- IMPORTANT: Load fault lines if preference was true ---
        // If the preference was to show fault lines, AND they haven't been loaded yet,
        // trigger the load now.
        if (_showFaultLines && _faultLinePolylines.isEmpty) {
          _loadFaultLineData(); // Don't await here, let it load in background
        }
      });
    }
  }

  Future<void> _saveBoolPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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

      newMarkers.add(
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

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
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

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Wrap(
                //runSpacing: 16.0,
                children: <Widget>[
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Earthquakes',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),

                  // --- Minimum Magnitude Slider ---
                  Text(
                    "Minimum Magnitude: ≥ ${currentSliderValue.toStringAsFixed(1)}",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: currentSliderValue,
                    min: _magnitudeFilterOptions.first,
                    max: _magnitudeFilterOptions.last,
                    divisions:
                        (_magnitudeFilterOptions.last -
                                _magnitudeFilterOptions.first)
                            .toInt() *
                        2, // Finer steps (0.5)
                    label: "≥ ${currentSliderValue.toStringAsFixed(1)}",
                    onChanged: (double value) {
                      setSheetState(() {
                        currentSliderValue = (value * 2).round() / 2;
                      });
                    },
                    onChangeEnd: (double value) {
                      double finalValue = (value * 2).round() / 2;

                      if (_selectedMinMagnitude != finalValue) {
                        setState(() {
                          _selectedMinMagnitude = finalValue;
                        });
                        _applyFilters();
                      }
                    },
                  ),
                  // --- Time Window Filter
                  Text(
                    // Label for the time window section
                    "Time Window",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children:
                        TimeWindow.values.map((window) {
                          return ChoiceChip(
                            label: Text(timeWindowLabels[window] ?? "N/A"),
                            selected: currentTimeWindow == window,
                            selectedColor:
                                Theme.of(context).colorScheme.primaryContainer,
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
                          );
                        }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Optimized location fetching with error handling
  Future<void> _fetchUserLocation() async {
    if (!mounted) return;

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
        _showLocationSuccessSnackBar();

        // Update markers to reflect new distances
        _updateMarkers();
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
      if (magnitude >= 7.0) return Colors.red.shade700;
      if (magnitude >= 6.0) return Colors.orange.shade800;
      if (magnitude >= 5.0) return Colors.amber.shade700;
      return Colors.green.shade600;
    });
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
          maxZoom: 19, // Esri supports higher zoom
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
          _showFaultLines = true;
          _isLoadingFaultLines = false;
        });
        await _saveBoolPreference(_showFaultLinesPrefKey, true);

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
      debugPrint('Error loading fault lines: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingFaultLines = false;
        _showFaultLines = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading fault lines: $e'),
          backgroundColor: Colors.red,
        ),
      );
      await _saveBoolPreference(_showFaultLinesPrefKey, false);
    }
  }

  // --- Helper to toggle fault lines and load data if needed ---
  void _toggleFaultLines() async {
    if (_isLoadingFaultLines) return; // Prevent action while loading

    if (_showFaultLines) {
      // Just hide if already shown
      setState(() {
        _showFaultLines = false;
      });
      await _saveBoolPreference(_showFaultLinesPrefKey, false);
    } else {
      // Show: Load data if it hasn't been loaded yet
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
            onSelected: (dynamic result) async {
              final prefs = await SharedPreferences.getInstance();
              if (result is MapLayerType) {
                // Handle Map Layer Type selection
                if (result != _selectedMapType) {
                  setState(() {
                    _selectedMapType = result;
                  });
                  await prefs.setString(_mapTypePrefKey, result.name);
                }
              } else if (result == 'toggle_fault_lines') {
                // Handle Fault Line toggle
                _toggleFaultLines(); // Call helper function
              }
            },
            itemBuilder: (BuildContext context) {
              final theme = Theme.of(context);
              final textTheme = theme.textTheme;

              // Build the list of menu entries directly
              return <PopupMenuEntry<dynamic>>[
                // --- Map Types Header ---
                // Use a disabled item styled as a header
                /* PopupMenuItem<dynamic>(
                  enabled: false, // Not selectable
                  height: 20, // Reduce height for header feel
                  child: Center(
                    child: Text(
                      "Map Type",
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const PopupMenuDivider(height: 1), // Divider after header */
                // --- Map Type Options (Using CheckedPopupMenuItem) ---
                CheckedPopupMenuItem<MapLayerType>(
                  value: MapLayerType.osm,
                  checked: _selectedMapType == MapLayerType.osm,
                  child: Text("Street Map", style: textTheme.bodyMedium),
                ),
                CheckedPopupMenuItem<MapLayerType>(
                  value: MapLayerType.satellite,
                  checked: _selectedMapType == MapLayerType.satellite,
                  child: Text("Satellite", style: textTheme.bodyMedium),
                ),
                CheckedPopupMenuItem<MapLayerType>(
                  value: MapLayerType.terrain,
                  checked: _selectedMapType == MapLayerType.terrain,
                  child: Text("Terrain", style: textTheme.bodyMedium),
                ),
                CheckedPopupMenuItem<MapLayerType>(
                  value: MapLayerType.dark,
                  checked: _selectedMapType == MapLayerType.dark,
                  child: Text("Dark", style: textTheme.bodyMedium),
                ),

                // --- Divider before Features ---
                const PopupMenuDivider(),

                CheckedPopupMenuItem<String>(
                  value: 'toggle_fault_lines',
                  checked: _showFaultLines,
                  child: Text("Show Fault Lines", style: textTheme.bodyMedium),
                ),
              ];
            },
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
                      maxClusterRadius: 45, // Slightly larger radius
                      size: const Size(40, 40),
                      markers: _currentMarkers, // Use memoized markers
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
                          backgroundColor: Colors.blue.withValues(alpha: 0.9),
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
                  MarkerLayer(markers: _currentMarkers), // Use memoized markers
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
            const Center(child: CircularProgressIndicator.adaptive()),

          // Show Error Message Centered
          if (_error != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                color: Colors.red.withValues(alpha: 0.8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _fetchInitialData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                      ), // Retry button
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            ),

          // --- ADD LOCAL FILTERING INDICATOR ---
          // Show a subtle indicator below the AppBar when filtering locally
          if (_isFilteringLocally &&
              !_isLoading) // Don't show if initial loading
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          // Zoom Controls
          if (!_isLoading &&
              _error == null) // Only show controls when map is visible
            Positioned(
              right: 16,
              bottom: 90,
              child: _ZoomControls(
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
            ),
          // --- ADD COMPASS BUTTON (Top-Right) ---
          if (!_isLoading && _error == null) // Only show if map is visible
            _buildCompassButton(),
        ],
      ),
      // --- ADD FLOATING ACTION BUTTON ---
      floatingActionButton: FloatingActionButton(
        onPressed: _showFilterBottomSheet, // Method to open the bottom sheet
        tooltip: 'Filter Earthquakes',
        child: const Icon(Icons.filter_list),
      ),
      //floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
  // Inside _EarthquakeMapScreenState class:

  Widget _buildCompassButton() {
    // Tolerance: Show button if rotation is more than ~1 degree off
    final bool isRotated = _currentRotation.abs() > 1.0;
    // Convert degrees to radians for Transform.rotate
    final double rotationRadians = _currentRotation * (pi / 180.0);

    return Positioned(
      top: 16, // Adjust positioning as needed
      right: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isRotated ? 1.0 : 0.0, // Fade in/out
        child: IgnorePointer(
          // Prevent interaction when invisible
          ignoring: !isRotated,
          child: Material(
            // Provides elevation, ink splash etc.
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            shape: const CircleBorder(),
            elevation: 4.0,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: _resetRotation, // Call reset function on tap
              child: Container(
                padding: const EdgeInsets.all(8.0),
                child: Transform.rotate(
                  angle:
                      -rotationRadians, // Rotate needle opposite to map rotation
                  child: Icon(
                    Icons
                        .navigation_rounded, // Navigation arrow looks like compass needle
                    size: 24.0,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
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
    // The onPositionChanged callback will automatically update _currentRotation state
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
  static const double defaultBottomPadding = 90.0;

  const _ZoomControls({
    required this.zoomLevel,
    required this.mapController,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
              color: colorScheme.surface.withValues(alpha: 0.92),
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
                          backgroundColor: magColor.withValues(alpha: 0.8),
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
                      displayLocationTitle,
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
                    if (distanceFormatted != null) ...[
                      const Divider(height: 1, indent: 30),
                      _DetailRow(
                        icon: Icons.social_distance_outlined,
                        iconColor: colorScheme.tertiary,
                        text: "$distanceFormatted from your location",
                      ),
                    ],

                    // --- ADDED TSUNAMI ---
                    if (tsunamiCode != null) ...[
                      const Divider(height: 1, indent: 30),
                      _DetailRow(
                        icon: Icons.tsunami_rounded,
                        iconColor: tsunamiColor,
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
