import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:lastquake/domain/usecases/get_earthquakes_usecase.dart';
import 'package:lastquake/models/earthquake.dart';
import 'package:lastquake/services/earthquake_cache_service.dart';
import 'package:lastquake/services/location_service.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Isolate Logic for List Filtering ---
Map<String, dynamic> _filterListEarthquakesIsolate(Map<String, dynamic> args) {
  final List<Earthquake> inputList = args['list'];
  final double minMagnitude = args['minMagnitude'];
  final String countryFilter = args['countryFilter'];

  final Set<String> uniqueCountries = {};
  final List<Earthquake> filteredList = [];

  for (final quake in inputList) {
    final String country =
        quake.place.contains(", ") ? quake.place.split(", ").last.trim() : "";
    if (country.isNotEmpty) {
      uniqueCountries.add(country);
    }

    final bool passesMagnitude = quake.magnitude >= minMagnitude;
    final bool passesCountry =
        countryFilter == "All" || country == countryFilter;

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

// --- Isolate Logic for Fault Lines ---
List<Polyline> _parseGeoJsonFaultLinesIsolate(String geoJsonString) {
  try {
    if (geoJsonString.length > 100 * 1024 * 1024) return [];

    final decodedJson = json.decode(geoJsonString);
    if (decodedJson is! Map || !decodedJson.containsKey('features')) return [];

    final features = decodedJson['features'];
    if (features is! List) return [];

    final List<Polyline> polylines = [];
    const int maxPolylines = 1000;
    const int maxPointsPerLine = 500;

    const Color lineStringColor = Color(0xCCFF0000);
    const Color multiLineStringColor = Color(0xB3FF9800);

    int processedCount = 0;
    for (final feature in features) {
      if (processedCount >= maxPolylines) break;
      if (feature is! Map || !feature.containsKey('geometry')) continue;

      final geometry = feature['geometry'];
      if (geometry is! Map) continue;

      final type = geometry['type'];
      final coordinates = geometry['coordinates'];
      if (coordinates is! List) continue;

      try {
        if (type == 'LineString') {
          final points = _parseLineStringCoordinates(
            coordinates,
            maxPointsPerLine,
          );
          if (points.isNotEmpty) {
            polylines.add(
              Polyline(
                points: points,
                color: lineStringColor,
                strokeWidth: 1.5,
              ),
            );
            processedCount++;
          }
        } else if (type == 'MultiLineString') {
          for (final line in coordinates) {
            if (processedCount >= maxPolylines) break;
            if (line is! List) continue;
            final points = _parseLineStringCoordinates(line, maxPointsPerLine);
            if (points.isNotEmpty) {
              polylines.add(
                Polyline(
                  points: points,
                  color: multiLineStringColor,
                  strokeWidth: 1.5,
                ),
              );
              processedCount++;
            }
          }
        }
      } catch (e) {
        continue;
      }
    }
    return polylines;
  } catch (e) {
    return [];
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
  final LocationService _locationService = LocationService();

  // --- Shared State ---
  List<Earthquake> _allEarthquakes = [];
  bool _isLoading = false;
  String? _error;

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
  Position? _userPosition;
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
  MapLayerType _mapLayerType = MapLayerType.osm;
  bool _showFaultLines = false;
  List<Polyline> _faultLines = [];
  bool _isLoadingFaultLines = false;

  // Preferences Keys
  static const String _mapTypePrefKey = 'map_layer_type_preference_v2';
  static const String _showFaultLinesPrefKey = 'show_fault_lines_preference';
  static const String _faultLineDataUrl =
      'https://raw.githubusercontent.com/fraxen/tectonicplates/master/GeoJSON/PB2002_boundaries.json';

  // --- Getters ---

  // Shared
  bool get isLoading => _isLoading;
  String? get error => _error;

  // List Getters
  List<Earthquake> get listEarthquakes => _listFilteredEarthquakes;
  List<String> get countryList => _countryList;
  bool get isListFiltering => _isListFiltering;
  String get listSelectedCountry => _listSelectedCountry;
  double get listSelectedMagnitude => _listSelectedMagnitude;
  bool get listIsLoadingMore => _listIsLoadingMore;
  bool get listHasMoreData => _listHasMoreData;
  bool get isLoadingLocation => _isLoadingLocation;
  Position? get userPosition => _userPosition;
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
  bool get showFaultLines => _showFaultLines;
  List<Polyline> get faultLines => _faultLines;
  bool get isLoadingFaultLines => _isLoadingFaultLines;

  EarthquakeProvider({required this.getEarthquakesUseCase});

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
    if (_showFaultLines) {
      _loadFaultLines();
    }
  }

  Future<void> loadData({bool forceRefresh = false}) async {
    if (_allEarthquakes.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    _error = null;

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

      // Apply filters for both views
      await Future.wait([_applyListFilters(), _applyMapFilters()]);

      _distanceCache.clear();
      if (_userPosition != null) {
        await _preCalculateDistances();
      }
    } catch (e) {
      _error = "Failed to load earthquakes: ${e.toString()}";
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

      await Future.wait([_applyListFilters(), _applyMapFilters()]);
      _distanceCache.clear();
      if (_userPosition != null) {
        await _preCalculateDistances();
      }
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

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _locationError =
          'Location services are disabled. Please enable GPS to see nearby distances.';
      notifyListeners();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
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
        await _preCalculateDistances();
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

    for (final quake in _listFilteredEarthquakes) {
      if (_distanceCache.containsKey(quake.id)) continue;

      final computedDistance = _locationService.calculateDistance(
        userLat,
        userLon,
        quake.latitude,
        quake.longitude,
      );

      _distanceCache[quake.id] = computedDistance;

      // Implement cache size limit to prevent memory bloat
      if (_distanceCache.length > _maxCacheSize) {
        // Remove oldest entries (FIFO)
        final keysToRemove = _distanceCache.keys.take(100).toList();
        for (final key in keysToRemove) {
          _distanceCache.remove(key);
        }
      }
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

  Future<void> toggleFaultLines(bool show) async {
    if (_showFaultLines == show) return;
    _showFaultLines = show;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showFaultLinesPrefKey, show);

    if (show && _faultLines.isEmpty) {
      _loadFaultLines();
    }
  }

  Future<void> _loadFaultLines() async {
    if (_isLoadingFaultLines || _faultLines.isNotEmpty) return;

    _isLoadingFaultLines = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(_faultLineDataUrl));
      if (response.statusCode == 200) {
        _faultLines = await compute(
          _parseGeoJsonFaultLinesIsolate,
          response.body,
        );
      }
    } catch (e) {
      debugPrint("Error loading fault lines: $e");
    } finally {
      _isLoadingFaultLines = false;
      notifyListeners();
    }
  }
}
