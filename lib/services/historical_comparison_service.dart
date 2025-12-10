import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/services/secure_http_client.dart';
import 'package:lastquakes/utils/secure_logger.dart';

/// Service for fetching and comparing historical earthquakes in a region.
/// Uses USGS FDSN API with radius-based queries.
class HistoricalComparisonService {
  static const String _boxName = 'historical_comparison_cache';
  static const Duration _cacheDuration = Duration(hours: 24);

  // Singleton instance
  static final HistoricalComparisonService _instance =
      HistoricalComparisonService._internal();
  static HistoricalComparisonService get instance => _instance;

  HistoricalComparisonService._internal();

  /// Fetch historical earthquakes similar to the given earthquake.
  ///
  /// Parameters:
  /// - [earthquake] - The earthquake to compare against
  /// - [radiusKm] - Search radius in kilometers (default: 200)
  /// - [magnitudeRange] - Magnitude tolerance (default: ±1.0), ignored if minMagnitude is set
  /// - [minMagnitude] - Absolute minimum magnitude to fetch (overrides magnitudeRange)
  /// - [yearsBack] - How many years of history to fetch (default: 20)
  Future<HistoricalComparisonResult> fetchHistoricalComparison({
    required Earthquake earthquake,
    double radiusKm = 200,
    double magnitudeRange = 1.0,
    double? minMagnitude,
    int yearsBack = 50,
  }) async {
    final cacheKey = _generateCacheKey(
      earthquake.latitude,
      earthquake.longitude,
      earthquake.magnitude,
      radiusKm,
    );

    // Check cache first
    final cachedResult = await _getCachedResult(cacheKey);
    if (cachedResult != null) {
      debugPrint('HistoricalComparison: Using cached result for $cacheKey');
      return cachedResult;
    }

    // Determine magnitude filter: use minMagnitude if provided, otherwise use range
    final double effectiveMinMag =
        minMagnitude ?? max(0, earthquake.magnitude - magnitudeRange);
    final double? effectiveMaxMag =
        minMagnitude != null ? null : earthquake.magnitude + magnitudeRange;

    // Fetch from API
    try {
      final earthquakes = await _fetchFromUsgs(
        latitude: earthquake.latitude,
        longitude: earthquake.longitude,
        radiusKm: radiusKm,
        minMagnitude: effectiveMinMag,
        maxMagnitude: effectiveMaxMag,
        yearsBack: yearsBack,
      );

      // Remove the current earthquake from results
      final historicalQuakes =
          earthquakes.where((e) => e.id != earthquake.id).toList();

      // Calculate statistics
      final result = HistoricalComparisonResult(
        currentEarthquake: earthquake,
        historicalEarthquakes: historicalQuakes,
        radiusKm: radiusKm,
        yearsSearched: yearsBack,
      );

      // Cache the result
      await _cacheResult(cacheKey, result);

      return result;
    } catch (e) {
      SecureLogger.error('HistoricalComparison: Error fetching data', e);
      rethrow;
    }
  }

  /// Fetch earthquakes from USGS API with radius-based query
  Future<List<Earthquake>> _fetchFromUsgs({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required double minMagnitude,
    double? maxMagnitude,
    required int yearsBack,
  }) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year - yearsBack, now.month, now.day);

    final queryParams = <String, String>{
      'format': 'geojson',
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'maxradiuskm': radiusKm.toString(),
      'starttime': startDate.toIso8601String().split('T')[0],
      'endtime': now.toIso8601String().split('T')[0],
      'minmagnitude': minMagnitude.toStringAsFixed(1),
      'orderby': 'magnitude', // Sort by magnitude to get strongest first
      'limit': '500',
    };

    // Only add maxmagnitude if specified
    if (maxMagnitude != null) {
      queryParams['maxmagnitude'] = maxMagnitude.toStringAsFixed(1);
    }

    final uri = Uri.https(
      'earthquake.usgs.gov',
      '/fdsnws/event/1/query',
      queryParams,
    );

    SecureLogger.api('earthquake.usgs.gov/fdsnws/event/1/query', method: 'GET');

    final response = await SecureHttpClient.instance.get(
      uri,
      timeout: const Duration(seconds: 30),
    );

    if (response.statusCode == 200) {
      return await compute(_parseUsgsResponse, response.body);
    } else if (response.statusCode == 204) {
      return []; // No earthquakes found
    } else {
      throw Exception('USGS API Error: ${response.statusCode}');
    }
  }

  /// Parse USGS GeoJSON response (runs in isolate)
  static List<Earthquake> _parseUsgsResponse(String body) {
    try {
      final data = json.decode(body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>?;

      if (features == null || features.isEmpty) {
        return [];
      }

      return features
          .map((feature) {
            try {
              return Earthquake.fromUsgs(feature as Map<String, dynamic>);
            } catch (e) {
              return null;
            }
          })
          .whereType<Earthquake>()
          .toList();
    } catch (e) {
      debugPrint('Error parsing USGS response: $e');
      return [];
    }
  }

  /// Generate cache key based on location and parameters
  String _generateCacheKey(
    double lat,
    double lon,
    double magnitude,
    double radiusKm,
  ) {
    // Round to reduce cache fragmentation
    final latRounded = (lat * 10).round() / 10;
    final lonRounded = (lon * 10).round() / 10;
    final magRounded = magnitude.round();
    return 'hist_${latRounded}_${lonRounded}_${magRounded}_$radiusKm';
  }

  /// Get cached result if valid
  Future<HistoricalComparisonResult?> _getCachedResult(String key) async {
    try {
      final box = await _getBox();
      final cached = box.get(key);

      if (cached == null) return null;

      final data = json.decode(cached) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;

      if (age > _cacheDuration.inMilliseconds) {
        await box.delete(key);
        return null;
      }

      return HistoricalComparisonResult.fromJson(data);
    } catch (e) {
      debugPrint('HistoricalComparison: Cache read error: $e');
      return null;
    }
  }

  /// Cache the result
  Future<void> _cacheResult(
    String key,
    HistoricalComparisonResult result,
  ) async {
    try {
      final box = await _getBox();
      final data = result.toJson();
      data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      await box.put(key, json.encode(data));
    } catch (e) {
      debugPrint('HistoricalComparison: Cache write error: $e');
    }
  }

  /// Get Hive box for caching
  Future<Box<String>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<String>(_boxName);
    }
    return Hive.box<String>(_boxName);
  }

  /// Clear the cache
  Future<void> clearCache() async {
    try {
      final box = await _getBox();
      await box.clear();
    } catch (e) {
      debugPrint('HistoricalComparison: Error clearing cache: $e');
    }
  }
}

/// Result of historical earthquake comparison
class HistoricalComparisonResult {
  final Earthquake currentEarthquake;
  final List<Earthquake> historicalEarthquakes;
  final double radiusKm;
  final int yearsSearched;

  HistoricalComparisonResult({
    required this.currentEarthquake,
    required this.historicalEarthquakes,
    required this.radiusKm,
    required this.yearsSearched,
  });

  /// Total count of historical earthquakes in the region
  int get totalCount => historicalEarthquakes.length;

  /// Average magnitude of historical earthquakes
  double get averageMagnitude {
    if (historicalEarthquakes.isEmpty) return 0;
    final sum = historicalEarthquakes.fold<double>(
      0,
      (prev, eq) => prev + eq.magnitude,
    );
    return sum / historicalEarthquakes.length;
  }

  /// Strongest earthquake in the region
  Earthquake? get strongest {
    if (historicalEarthquakes.isEmpty) return null;
    return historicalEarthquakes.reduce(
      (a, b) => a.magnitude > b.magnitude ? a : b,
    );
  }

  /// The most recent earthquake in history
  Earthquake? get mostRecent {
    if (historicalEarthquakes.isEmpty) return null;
    return historicalEarthquakes.first; // Already sorted by time descending
  }

  /// Ranking of current earthquake (1 = strongest in region)
  int get currentRanking {
    final sorted = [...historicalEarthquakes, currentEarthquake]
      ..sort((a, b) => b.magnitude.compareTo(a.magnitude));
    return sorted.indexWhere((e) => e.id == currentEarthquake.id) + 1;
  }

  /// Earthquakes grouped by decade
  Map<int, List<Earthquake>> get byDecade {
    final result = <int, List<Earthquake>>{};
    for (final eq in historicalEarthquakes) {
      final decade = (eq.time.year ~/ 10) * 10;
      result.putIfAbsent(decade, () => []).add(eq);
    }
    return result;
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'currentEarthquake': currentEarthquake.toJson(),
      'historicalEarthquakes':
          historicalEarthquakes.map((e) => e.toJson()).toList(),
      'radiusKm': radiusKm,
      'yearsSearched': yearsSearched,
    };
  }

  /// Create from cached JSON
  factory HistoricalComparisonResult.fromJson(Map<String, dynamic> json) {
    return HistoricalComparisonResult(
      currentEarthquake: Earthquake.fromJson(
        json['currentEarthquake'] as Map<String, dynamic>,
      ),
      historicalEarthquakes:
          (json['historicalEarthquakes'] as List<dynamic>)
              .map((e) => Earthquake.fromJson(e as Map<String, dynamic>))
              .toList(),
      radiusKm: (json['radiusKm'] as num).toDouble(),
      yearsSearched: json['yearsSearched'] as int,
    );
  }
}
