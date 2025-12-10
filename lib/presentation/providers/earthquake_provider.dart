import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:lastquakes/domain/usecases/get_earthquakes_usecase.dart';
import 'package:lastquakes/models/data_source_status.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/services/earthquake_cache_service.dart';
import 'package:lastquakes/services/home_widget_service.dart';
import 'package:lastquakes/services/location_service.dart';
import 'package:lastquakes/services/multi_source_api_service.dart';
import 'package:lastquakes/utils/enums.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Converts a string to title case (first letter of each word capitalized).
String _toTitleCase(String text) {
  if (text.isEmpty) return text;
  return text
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

// --- Isolate Logic for List Filtering ---
Map<String, dynamic> _filterListEarthquakesIsolate(Map<String, dynamic> args) {
  final List<Earthquake> inputList = args['list'];
  final double minMagnitude = args['minMagnitude'];
  final String countryFilter = args['countryFilter'];

  final Set<String> uniqueCountries = {};
  final List<Earthquake> filteredList = [];

  for (final quake in inputList) {
    final String rawCountry =
        quake.place.contains(", ") ? quake.place.split(", ").last.trim() : "";
    // Normalize to title case to prevent duplicates from case differences
    // (e.g., "Greece" from USGS vs "GREECE" from EMSC)
    final String country = _toTitleCase(rawCountry);
    if (country.isNotEmpty) {
      uniqueCountries.add(country);
    }

    final bool passesMagnitude = quake.magnitude >= minMagnitude;
    // Compare normalized country for filtering
    final String normalizedFilter = _toTitleCase(countryFilter);
    final bool passesCountry =
        countryFilter == "All" || country == normalizedFilter;

    if (passesMagnitude && passesCountry) {
      filteredList.add(quake);
    }
  }

  // Sort by time
  filteredList.sort((a, b) => b.time.compareTo(a.time));

  return {
    'filteredList': filteredList,
    'uniqueCountries': uniqueCountries.toList()..sort(),
  };
}

// --- Isolate Logic for Map Filtering ---
class MapFilterParameters {
  final List<Earthquake> earthquakes;
  final double minMagnitude;
  final DateTime? cutoffTime;

  const MapFilterParameters({
    required this.earthquakes,
    required this.minMagnitude,
    this.cutoffTime,
  });
}

List<Earthquake> _filterMapEarthquakesIsolate(MapFilterParameters params) {
  try {
    final List<Earthquake> filtered = [];
    final cutoffMillis = params.cutoffTime?.millisecondsSinceEpoch;

    for (final quake in params.earthquakes) {
      if (quake.magnitude < params.minMagnitude) continue;

      if (cutoffMillis != null) {
        if (quake.time.millisecondsSinceEpoch <= cutoffMillis) continue;
      }

      // Basic validation
      if (quake.latitude >= -90 &&
          quake.latitude <= 90 &&
          quake.longitude >= -180 &&
          quake.longitude <= 180) {
        filtered.add(quake);
      }
    }
    return filtered;
  } catch (e) {
    debugPrint('Error in map filter isolate: $e');
    return [];
  }
}

// --- Fault Line Data Class ---
class FaultLineLabel {
  final LatLng position;
  final String plateA;
  final String plateB;
  final String boundaryType;
  final double angle; // Rotation angle in radians to follow the line

  const FaultLineLabel({
    required this.position,
    required this.plateA,
    required this.plateB,
    required this.boundaryType,
    required this.angle,
  });

  String get displayName => '$plateA - $plateB';
}

class FaultLineData {
  final List<Polyline> polylines;
  final List<FaultLineLabel> labels;

  const FaultLineData({required this.polylines, required this.labels});

  static const empty = FaultLineData(polylines: [], labels: []);
}

// Plate code to full name mapping
const Map<String, String> _plateNames = {
  'AF': 'African',
  'AN': 'Antarctic',
  'AP': 'Altiplano',
  'AR': 'Arabian',
  'AS': 'Aegean Sea',
  'AT': 'Anatolia',
  'AU': 'Australian',
  'BH': 'Birds Head',
  'BR': 'Balmoral Reef',
  'BS': 'Banda Sea',
  'BU': 'Burma',
  'CA': 'Caribbean',
  'CL': 'Caroline',
  'CO': 'Cocos',
  'CR': 'Conway Reef',
  'EA': 'Easter',
  'EU': 'Eurasian',
  'FT': 'Futuna',
  'GP': 'Galapagos',
  'IN': 'Indian',
  'JF': 'Juan de Fuca',
  'JZ': 'Juan Fernandez',
  'KE': 'Kermadec',
  'MA': 'Mariana',
  'MN': 'Manus',
  'MO': 'Maoke',
  'MS': 'Molucca Sea',
  'NA': 'North American',
  'NB': 'North Bismarck',
  'ND': 'North Andes',
  'NH': 'New Hebrides',
  'NI': 'Niuafo\'ou',
  'NZ': 'Nazca',
  'OK': 'Okhotsk',
  'ON': 'Okinawa',
  'PA': 'Pacific',
  'PM': 'Panama',
  'PS': 'Philippine Sea',
  'RI': 'Rivera',
  'SA': 'South American',
  'SB': 'South Bismarck',
  'SC': 'Scotia',
  'SL': 'Shetland',
  'SO': 'Somali',
  'SS': 'Solomon Sea',
  'SU': 'Sunda',
  'SW': 'Sandwich',
  'TI': 'Timor',
  'TO': 'Tonga',
  'WL': 'Woodlark',
  'YA': 'Yangtze',
};

String _getPlateName(String code) {
  return _plateNames[code] ?? code;
}

// --- Isolate Logic for Fault Lines ---
FaultLineData _parseGeoJsonFaultLinesIsolate(String geoJsonString) {
  try {
    if (geoJsonString.length > 100 * 1024 * 1024) return FaultLineData.empty;

    final decodedJson = json.decode(geoJsonString);
    if (decodedJson is! Map || !decodedJson.containsKey('features')) {
      return FaultLineData.empty;
    }

    final features = decodedJson['features'];
    if (features is! List) return FaultLineData.empty;

    final List<Polyline> polylines = [];
    final Map<String, FaultLineLabel> uniqueLabels = {};
    const int maxPolylines = 1000;
    const int maxPointsPerLine = 500;

    // Colors for different boundary types
    const Color subductionColor = Color(0xFFE53935);
    const Color spreadingColor = Color(0xFF43A047);

    int processedCount = 0;
    for (final feature in features) {
      if (processedCount >= maxPolylines) break;
      if (feature is! Map || !feature.containsKey('geometry')) continue;

      final geometry = feature['geometry'];
      if (geometry is! Map) continue;

      final type = geometry['type'];
      final coordinates = geometry['coordinates'];
      if (coordinates is! List) continue;

      // Extract properties
      final properties = feature['properties'];
      Color lineColor = spreadingColor;
      String plateA = '';
      String plateB = '';
      String boundaryType = 'spreading';

      if (properties is Map) {
        plateA = properties['PlateA']?.toString() ?? '';
        plateB = properties['PlateB']?.toString() ?? '';
        final typeStr = properties['Type']?.toString() ?? '';
        final name = properties['Name']?.toString() ?? '';

        if (typeStr.toLowerCase().contains('subduction')) {
          lineColor = subductionColor;
          boundaryType = 'subduction';
        } else if (name.contains('\\\\') || name.contains('\\/')) {
          lineColor = subductionColor;
          boundaryType = 'subduction';
        }
      }

      try {
        if (type == 'LineString') {
          final points = _parseLineStringCoordinates(
            coordinates,
            maxPointsPerLine,
          );
          if (points.isNotEmpty) {
            polylines.add(
              Polyline(points: points, color: lineColor, strokeWidth: 2.0),
            );
            processedCount++;

            // Create label at midpoint (only one per unique plate pair)
            if (plateA.isNotEmpty && plateB.isNotEmpty) {
              final labelKey = '${plateA}_$plateB';
              if (!uniqueLabels.containsKey(labelKey)) {
                final midIndex = points.length ~/ 2;
                // Calculate angle from adjacent points
                double angle = 0.0;
                if (points.length >= 2) {
                  final prevIdx = midIndex > 0 ? midIndex - 1 : 0;
                  final nextIdx =
                      midIndex < points.length - 1 ? midIndex + 1 : midIndex;
                  final dx =
                      points[nextIdx].longitude - points[prevIdx].longitude;
                  final dy =
                      points[nextIdx].latitude - points[prevIdx].latitude;
                  angle = math.atan2(dy, dx);
                  // Flip if text would be upside down
                  if (angle > math.pi / 2 || angle < -math.pi / 2) {
                    angle += math.pi;
                  }
                }
                uniqueLabels[labelKey] = FaultLineLabel(
                  position: points[midIndex],
                  plateA: _getPlateName(plateA),
                  plateB: _getPlateName(plateB),
                  boundaryType: boundaryType,
                  angle: angle,
                );
              }
            }
          }
        } else if (type == 'MultiLineString') {
          for (final line in coordinates) {
            if (processedCount >= maxPolylines) break;
            if (line is! List) continue;
            final points = _parseLineStringCoordinates(line, maxPointsPerLine);
            if (points.isNotEmpty) {
              polylines.add(
                Polyline(points: points, color: lineColor, strokeWidth: 2.0),
              );
              processedCount++;

              // Create label at midpoint (only one per unique plate pair)
              if (plateA.isNotEmpty && plateB.isNotEmpty) {
                final labelKey = '${plateA}_$plateB';
                if (!uniqueLabels.containsKey(labelKey)) {
                  final midIndex = points.length ~/ 2;
                  // Calculate angle from adjacent points
                  double angle = 0.0;
                  if (points.length >= 2) {
                    final prevIdx = midIndex > 0 ? midIndex - 1 : 0;
                    final nextIdx =
                        midIndex < points.length - 1 ? midIndex + 1 : midIndex;
                    final dx =
                        points[nextIdx].longitude - points[prevIdx].longitude;
                    final dy =
                        points[nextIdx].latitude - points[prevIdx].latitude;
                    angle = math.atan2(dy, dx);
                    // Flip if text would be upside down
                    if (angle > math.pi / 2 || angle < -math.pi / 2) {
                      angle += math.pi;
                    }
                  }
                  uniqueLabels[labelKey] = FaultLineLabel(
                    position: points[midIndex],
                    plateA: _getPlateName(plateA),
                    plateB: _getPlateName(plateB),
                    boundaryType: boundaryType,
                    angle: angle,
                  );
                }
              }
            }
          }
        }
      } catch (e) {
        continue;
      }
    }
    return FaultLineData(
      polylines: polylines,
      labels: uniqueLabels.values.toList(),
    );
  } catch (e) {
    return FaultLineData.empty;
  }
}

List<LatLng> _parseLineStringCoordinates(List coordinates, int maxPoints) {
  final List<LatLng> points = [];
  for (int i = 0; i < coordinates.length && i < maxPoints; i++) {
    final coord = coordinates[i];
    if (coord is! List || coord.length < 2) continue;
    final lon = coord[0];
    final lat = coord[1];
    if (lon is! num || lat is! num) continue;

    final latDouble = lat.toDouble();
    final lonDouble = lon.toDouble();

    if (latDouble < -90 ||
        latDouble > 90 ||
        lonDouble < -180 ||
        lonDouble > 180) {
      continue;
    }
    points.add(LatLng(latDouble, lonDouble));
  }
  return points;
}

class EarthquakeProvider extends ChangeNotifier {
  final GetEarthquakesUseCase getEarthquakesUseCase;
  final MultiSourceApiService? apiService;
  final LocationService _locationService = LocationService();

  // --- Shared State ---
  List<Earthquake> _allEarthquakes = [];
  bool _isLoading = false;
  String? _error;
  Map<DataSource, DataSourceStatus> _sourceStatuses = {};

  // --- List View State ---
  List<Earthquake> _listFilteredEarthquakes = [];
  List<String> _countryList = ["All"];
  bool _isListFiltering = false;

  // List Filters
  String _listSelectedCountry = "All";
  double _listSelectedMagnitude = 3.0;

  // List Pagination
  static const int _itemsPerPage = 20;
  int _listCurrentPage = 1;
  bool _listIsLoadingMore = false;
  bool _listHasMoreData = true;

  // List Location
  Location? _userPosition;
  bool _isLoadingLocation = false;
  final Map<String, double> _distanceCache = {};
  static const int _maxCacheSize = 500; // Prevent unbounded memory growth
  String? _locationError;

  // --- Map View State ---
  List<Earthquake> _mapFilteredEarthquakes = [];
  bool _isMapFiltering = false;

  // Map Filters
  double _mapMinMagnitude = 3.0;
  TimeWindow _mapTimeWindow = TimeWindow.last24Hours;

  // Map Settings
  MapLayerType _mapLayerType = MapLayerType.terrain;
  MapViewMode _mapViewMode = MapViewMode.flat;
  bool _showFaultLines = false;
  bool _showHeatmap = false;
  bool _showPlateLabels =
      true; // Show plate labels when fault lines are visible
  List<Polyline> _faultLines = [];
  List<FaultLineLabel> _faultLineLabels = [];
  bool _isLoadingFaultLines = false;

  // Preferences Keys
  static const String _mapTypePrefKey = 'map_layer_type_preference_v2';
  static const String _showFaultLinesPrefKey = 'show_fault_lines_preference';
  static const String _showPlateLabelsPrefKey = 'show_plate_labels_preference';
  static const String _faultLineDataUrl =
      'https://raw.githubusercontent.com/fraxen/tectonicplates/master/GeoJSON/PB2002_boundaries.json';
  static const String _faultLinesCacheKey = 'fault_lines_geojson_cache_v1';
  static const String _faultLinesCacheTimestampKey =
      'fault_lines_geojson_cache_ts_v1';
  static const Duration _faultLinesCacheTtl = Duration(days: 7);

  // --- Getters ---

  // Shared
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<DataSource, DataSourceStatus> get sourceStatuses => _sourceStatuses;

  // List Getters
  List<Earthquake> get listEarthquakes => _listFilteredEarthquakes;
  List<String> get countryList => _countryList;
  bool get isListFiltering => _isListFiltering;
  String get listSelectedCountry => _listSelectedCountry;
  double get listSelectedMagnitude => _listSelectedMagnitude;
  bool get listIsLoadingMore => _listIsLoadingMore;
  bool get listHasMoreData => _listHasMoreData;
  bool get isLoadingLocation => _isLoadingLocation;
  Location? get userPosition => _userPosition;
  String? get locationError => _locationError;

  List<Earthquake> get listVisibleEarthquakes {
    final count = (_listCurrentPage * _itemsPerPage);
    if (count > _listFilteredEarthquakes.length) {
      return _listFilteredEarthquakes;
    }
    return _listFilteredEarthquakes.sublist(0, count);
  }

  // Map Getters
  List<Earthquake> get mapEarthquakes => _mapFilteredEarthquakes;
  bool get isMapFiltering => _isMapFiltering;
  double get mapMinMagnitude => _mapMinMagnitude;
  TimeWindow get mapTimeWindow => _mapTimeWindow;
  MapLayerType get mapLayerType => _mapLayerType;
  MapViewMode get mapViewMode => _mapViewMode;
  bool get showFaultLines => _showFaultLines;
  bool get showHeatmap => _showHeatmap;
  bool get showPlateLabels => _showPlateLabels;
  List<Polyline> get faultLines => _faultLines;
  List<FaultLineLabel> get faultLineLabels => _faultLineLabels;
  bool get isLoadingFaultLines => _isLoadingFaultLines;

  EarthquakeProvider({
    required this.getEarthquakesUseCase,
    this.apiService,
  });

  Future<void> init() async {
    await _loadPreferences();
    // DON'T load data here - let screens trigger it when needed
    // This significantly improves app startup time
  }

  /// Ensure data is loaded - call this from screens
  Future<void> ensureDataLoaded() async {
    if (_allEarthquakes.isEmpty && !_isLoading) {
      await loadData();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Map Type
    final typeStr = prefs.getString(_mapTypePrefKey);
    if (typeStr != null) {
      try {
        _mapLayerType = MapLayerType.values.firstWhere(
          (e) => e.name == typeStr,
        );
      } catch (_) {}
    }

    // Fault Lines
    _showFaultLines = prefs.getBool(_showFaultLinesPrefKey) ?? false;

    // Plate Labels (defaults to true when fault lines are visible)
    _showPlateLabels = prefs.getBool(_showPlateLabelsPrefKey) ?? true;

    if (_showFaultLines) {
      _loadFaultLines();
    }
  }

  /// Update home screen widget with current earthquake data (Android only).
  /// This is non-blocking and debounced by the HomeWidgetService.
  void _updateHomeWidget() {
    if (!kIsWeb && Platform.isAndroid && _allEarthquakes.isNotEmpty) {
      HomeWidgetService().updateWidgetData(_allEarthquakes);
    }
  }

  Future<void> loadData({bool forceRefresh = false}) async {
    if (_allEarthquakes.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    _error = null;
    final stopwatch = Stopwatch()..start();

    try {
      // Try to load from cache first for instant display
      if (!forceRefresh && _allEarthquakes.isEmpty) {
        final cachedData = await EarthquakeCacheService.getCachedData();
        if (cachedData != null && cachedData.isNotEmpty) {
          _allEarthquakes = cachedData;
          await Future.wait([_applyListFilters(), _applyMapFilters()]);
          _distanceCache.clear();
          if (_userPosition != null) {
            await _preCalculateDistances();
          }
          _isLoading = false;
          notifyListeners();

          // Fetch fresh data in background
          _fetchFreshDataInBackground();
          return;
        }
      }

      // Fetch from network
      _allEarthquakes = await getEarthquakesUseCase(
        minMagnitude: 3.0,
        days: 45,
        forceRefresh: forceRefresh,
      ).timeout(const Duration(seconds: 30));

      // Cache the data for next time
      EarthquakeCacheService.cacheData(_allEarthquakes);
      
      // Update source statuses
      if (apiService != null) {
        _sourceStatuses = apiService!.getSourceStatuses();
      }

      // Apply filters for both views
      await Future.wait([_applyListFilters(), _applyMapFilters()]);

      _distanceCache.clear();
      if (_userPosition != null) {
        await _preCalculateDistances();
      }

      stopwatch.stop();

      // Update home screen widget (Android only, non-blocking)
      _updateHomeWidget();
    } catch (e) {
      _error = "Failed to load earthquakes: ${e.toString()}";
      stopwatch.stop();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch fresh data in background after loading from cache
  Future<void> _fetchFreshDataInBackground() async {
    try {
      final freshData = await getEarthquakesUseCase(
        minMagnitude: 3.0,
        days: 45,
        forceRefresh: true,
      ).timeout(const Duration(seconds: 30));

      // Update cache and data
      _allEarthquakes = freshData;
      EarthquakeCacheService.cacheData(_allEarthquakes);
      
      // Update source statuses
      if (apiService != null) {
        _sourceStatuses = apiService!.getSourceStatuses();
      }

      await Future.wait([_applyListFilters(), _applyMapFilters()]);
      _distanceCache.clear();
      if (_userPosition != null) {
        await _preCalculateDistances();
      }

      // Update home screen widget (Android only, non-blocking)
      _updateHomeWidget();

      notifyListeners();
    } catch (e) {
      debugPrint('Background refresh failed: $e');
    }
  }

  // --- List Logic ---

  Future<void> _applyListFilters() async {
    _isListFiltering = true;
    notifyListeners();

    try {
      final result = await compute(_filterListEarthquakesIsolate, {
        'list': _allEarthquakes,
        'minMagnitude': _listSelectedMagnitude,
        'countryFilter': _listSelectedCountry,
      });

      _listFilteredEarthquakes = result['filteredList'] as List<Earthquake>;
      _countryList = ["All"] + (result['uniqueCountries'] as List<String>);

      _listCurrentPage = 1;
      _listHasMoreData = _listFilteredEarthquakes.length > _itemsPerPage;

      await _preCalculateDistances();
    } catch (e) {
      debugPrint("Error applying list filters: $e");
    } finally {
      _isListFiltering = false;
      notifyListeners();
    }
  }

  void setListCountryFilter(String country) {
    if (_listSelectedCountry == country) return;
    _listSelectedCountry = country;
    _applyListFilters();
  }

  void setListMagnitudeFilter(double magnitude) {
    if (_listSelectedMagnitude == magnitude) return;
    _listSelectedMagnitude = magnitude;
    _applyListFilters();
  }

  void loadMoreList() {
    if (_listIsLoadingMore || !_listHasMoreData) return;

    _listIsLoadingMore = true;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 100), () {
      _listCurrentPage++;
      _listHasMoreData =
          (_listCurrentPage * _itemsPerPage) < _listFilteredEarthquakes.length;
      _listIsLoadingMore = false;
      notifyListeners();
    });
  }

  Future<void> fetchUserLocation({bool forceRefresh = true}) async {
    if (_isLoadingLocation) return;

    _locationError = null;

    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _locationError =
          'Location services are disabled. Please enable GPS to see nearby distances.';
      notifyListeners();
      return;
    }

    PermissionStatus permission = await _locationService.checkPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _locationService.requestPermission();
    }

    if (permission == PermissionStatus.denied ||
        permission == PermissionStatus.permanentlyDenied) {
      _locationError =
          'Location permission is required. Grant access from system settings.';
      notifyListeners();
      return;
    }

    _isLoadingLocation = true;
    notifyListeners();

    try {
      final position = await _locationService.getCurrentLocation(
        forceRefresh: forceRefresh,
      );

      if (position != null) {
        _userPosition = position;
        _distanceCache.clear();
        
        // If list is empty, ensure data is loaded first
        if (_listFilteredEarthquakes.isEmpty && _allEarthquakes.isNotEmpty) {
          await _applyListFilters();
        } else {
          await _preCalculateDistances();
        }
      } else {
        _locationError = 'Unable to determine your location. Please try again.';
      }
    } catch (e) {
      debugPrint('Error fetching location: $e');
      _locationError = 'Error fetching location. Please try again.';
    } finally {
      _isLoadingLocation = false;
      notifyListeners();
    }
  }

  void clearLocationError() {
    if (_locationError != null) {
      _locationError = null;
      notifyListeners();
    }
  }

  Future<void> _preCalculateDistances() async {
    if (_userPosition == null) return;

    final userLat = _userPosition!.latitude;
    final userLon = _userPosition!.longitude;
    
    // Calculate distances for all filtered earthquakes
    for (final quake in _listFilteredEarthquakes) {
      if (_distanceCache.containsKey(quake.id)) continue;

      final computedDistance = _locationService.calculateDistance(
        userLat,
        userLon,
        quake.latitude,
        quake.longitude,
      );

      _distanceCache[quake.id] = computedDistance;
    }
    
    // After calculating all distances, trim cache if needed
    // Keep the first _maxCacheSize entries (these are the most recent/visible earthquakes)
    if (_distanceCache.length > _maxCacheSize) {
      final keysToKeep = _listFilteredEarthquakes
          .take(_maxCacheSize)
          .map((e) => e.id)
          .toSet();
      
      _distanceCache.removeWhere((key, value) => !keysToKeep.contains(key));
    }
  }

  double? getDistanceForQuake(String quakeId) {
    return _distanceCache[quakeId];
  }

  // --- Map Logic ---

  Future<void> _applyMapFilters() async {
    _isMapFiltering = true;
    notifyListeners();

    try {
      DateTime? cutoffTime;
      final now = DateTime.now();
      switch (_mapTimeWindow) {
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

      final params = MapFilterParameters(
        earthquakes: _allEarthquakes,
        minMagnitude: _mapMinMagnitude,
        cutoffTime: cutoffTime,
      );

      _mapFilteredEarthquakes = await compute(
        _filterMapEarthquakesIsolate,
        params,
      );
    } catch (e) {
      debugPrint("Map Filter error: $e");
    } finally {
      _isMapFiltering = false;
      notifyListeners();
    }
  }

  void setMapFilters({double? minMagnitude, TimeWindow? timeWindow}) {
    if (minMagnitude != null) _mapMinMagnitude = minMagnitude;
    if (timeWindow != null) _mapTimeWindow = timeWindow;
    _applyMapFilters();
  }

  Future<void> setMapLayerType(MapLayerType type) async {
    if (_mapLayerType == type) return;
    _mapLayerType = type;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mapTypePrefKey, type.name);
  }

  void toggleMapViewMode() {
    _mapViewMode =
        _mapViewMode == MapViewMode.flat ? MapViewMode.globe : MapViewMode.flat;
    notifyListeners();
  }

  void toggleHeatmap(bool show) {
    if (_showHeatmap == show) return;
    _showHeatmap = show;
    notifyListeners();
  }

  Future<void> togglePlateLabels(bool show) async {
    if (_showPlateLabels == show) return;
    _showPlateLabels = show;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showPlateLabelsPrefKey, show);
  }

  Future<void> toggleFaultLines(bool show) async {
    if (_showFaultLines == show) return;
    _showFaultLines = show;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showFaultLinesPrefKey, show);

    if (show) {
      _loadFaultLines();
    }
  }

  bool _isFaultLineCacheFresh(int? timestamp) {
    if (timestamp == null) return false;
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(cacheTime) <= _faultLinesCacheTtl;
  }

  Future<void> _loadFaultLines({bool forceRefresh = false}) async {
    if (_isLoadingFaultLines) return;

    final prefs = await SharedPreferences.getInstance();
    final cacheTimestamp = prefs.getInt(_faultLinesCacheTimestampKey);
    final cacheFresh = _isFaultLineCacheFresh(cacheTimestamp);

    if (_faultLines.isNotEmpty && cacheFresh && !forceRefresh) {
      return;
    }

    _isLoadingFaultLines = true;
    notifyListeners();

    try {
      final cachedData = prefs.getString(_faultLinesCacheKey);
      final bool hasCacheData = cachedData != null;

      if (_faultLines.isEmpty && cachedData != null) {
        final cachedResult = await compute(
          _parseGeoJsonFaultLinesIsolate,
          cachedData,
        );
        if (cachedResult.polylines.isNotEmpty) {
          _faultLines = cachedResult.polylines;
          _faultLineLabels = cachedResult.labels;
          notifyListeners();
        }
      }

      final bool shouldFetchRemote =
          forceRefresh || !cacheFresh || !hasCacheData;

      if (shouldFetchRemote) {
        final response = await http.get(Uri.parse(_faultLineDataUrl));
        if (response.statusCode == 200) {
          final parsedResult = await compute(
            _parseGeoJsonFaultLinesIsolate,
            response.body,
          );
          if (parsedResult.polylines.isNotEmpty) {
            _faultLines = parsedResult.polylines;
            _faultLineLabels = parsedResult.labels;
            final nowMillis = DateTime.now().millisecondsSinceEpoch;
            await prefs.setString(_faultLinesCacheKey, response.body);
            await prefs.setInt(_faultLinesCacheTimestampKey, nowMillis);
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading fault lines: $e");
    } finally {
      _isLoadingFaultLines = false;
      notifyListeners();
    }
  }
}
