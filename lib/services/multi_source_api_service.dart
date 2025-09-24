import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:lastquake/models/earthquake.dart';
import 'package:lastquake/services/secure_http_client.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:lastquake/utils/secure_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// Optimized multi-source API service with performance and memory optimizations
class MultiSourceApiService {
  static const String _cacheTimestampKey = 'multi_source_cache_timestamp';
  static const String _cacheFilename = 'multi_source_cache.json';
  static const String _selectedSourcesKey = 'selected_data_sources';

  // Performance constants
  static const int _maxCacheSize = 50 * 1024 * 1024; // 50MB max cache size
  static const int _cacheValidityHours = 1;
  static const int _maxEarthquakesPerSource = 10000; // Prevent memory issues
  static const double _duplicateDistanceThreshold = 50.0; // km
  static const int _duplicateTimeThreshold = 600000; // 10 minutes in ms
  static const int _chunkSize = 1000; // Process data in chunks

  // Cache for expensive operations
  static final Map<String, Set<DataSource>> _sourceCache = {};
  static SharedPreferences? _prefsCache;
  static final Map<String, List<Earthquake>> _memoryCache = {};

  /// Get cached SharedPreferences instance
  static Future<SharedPreferences> _getPrefs() async {
    return _prefsCache ??= await SharedPreferences.getInstance();
  }

  /// Get selected data sources from preferences with caching
  static Future<Set<DataSource>> getSelectedSources() async {
    const cacheKey = 'selected_sources';
    if (_sourceCache.containsKey(cacheKey)) {
      return _sourceCache[cacheKey]!;
    }

    try {
      final prefs = await _getPrefs();
      final sourceNames = prefs.getStringList(_selectedSourcesKey) ?? ['usgs'];

      final sources =
          sourceNames
              .map(
                (name) => DataSource.values.cast<DataSource?>().firstWhere(
                  (e) => e?.name == name,
                  orElse: () => null,
                ),
              )
              .whereType<DataSource>()
              .toSet();

      if (sources.isEmpty) sources.add(DataSource.usgs);

      _sourceCache[cacheKey] = sources;
      return sources;
    } catch (e) {
      SecureLogger.error("Error loading selected sources", e);
      return {DataSource.usgs};
    }
  }

  /// Save selected data sources to preferences
  static Future<void> setSelectedSources(Set<DataSource> sources) async {
    try {
      final prefs = await _getPrefs();
      final sourcesToSave = sources.isEmpty ? {DataSource.usgs} : sources;
      await prefs.setStringList(
        _selectedSourcesKey,
        sourcesToSave.map((e) => e.name).toList(),
      );

      _sourceCache.clear();
      _memoryCache.clear(); // Clear memory cache when sources change
    } catch (e) {
      SecureLogger.error("Error saving selected sources", e);
      rethrow;
    }
  }

  /// Get all available data sources
  static Set<DataSource> getAvailableSources() {
    return DataSource.values.toSet();
  }

  /// Check if multiple sources are selected
  static Future<bool> hasMultipleSources() async {
    try {
      final sources = await getSelectedSources();
      return sources.length > 1;
    } catch (e) {
      SecureLogger.error("Error checking multiple sources", e);
      return false;
    }
  }

  /// Get cache file path for specific sources
  static Future<File> _getCacheFile(Set<DataSource> sources) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final sourceKey = sources.map((s) => s.name).toList()..sort();
      final filename = 'multi_source_cache_${sourceKey.join('_')}.json';
      return File('${directory.path}/$filename');
    } catch (e) {
      SecureLogger.error("Error getting cache file path", e);
      rethrow;
    }
  }

  /// Get cache timestamp key for specific sources
  static String _getCacheTimestampKey(Set<DataSource> sources) {
    final sourceKey = sources.map((s) => s.name).toList()..sort();
    return 'multi_source_cache_timestamp_${sourceKey.join('_')}';
  }

  /// Check if cache is valid and within size limits
  static Future<bool> _isCacheValid(File cacheFile, int timestamp) async {
    try {
      if (!await cacheFile.exists()) return false;

      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final cacheAge = currentTime - timestamp;

      if (cacheAge > _cacheValidityHours * 3600000) return false;

      final fileSize = await cacheFile.length();
      if (fileSize > _maxCacheSize) {
        SecureLogger.warning("Cache file too large: $fileSize bytes");
        return false;
      }

      return true;
    } catch (e) {
      SecureLogger.error("Error validating cache", e);
      return false;
    }
  }

  /// Fetch earthquakes from USGS with optimizations
  static Future<List<Earthquake>> _fetchFromUsgs({
    double minMagnitude = 3.0,
    int days = 45,
  }) async {
    try {
      final DateTime now = DateTime.now();
      final DateTime startDate = now.subtract(Duration(days: days));

      final Uri url =
          Uri.https("earthquake.usgs.gov", "/fdsnws/event/1/query", {
            "format": "geojson",
            "orderby": "time",
            "starttime": startDate.toIso8601String(),
            "endtime": now.toIso8601String(),
            "minmagnitude": minMagnitude.toString(),
            "limit": _maxEarthquakesPerSource.toString(),
          });

      final response = await SecureHttpClient.instance.get(
        url,
        timeout: const Duration(seconds: 30),
      );

      SecureLogger.api(
        "earthquake.usgs.gov/fdsnws/event/1/query",
        statusCode: response.statusCode,
        method: "GET",
      );

      if (response.statusCode == 200) {
        return await _parseUsgsResponse(response.body, minMagnitude);
      } else if (response.statusCode == 204) {
        return [];
      } else {
        throw HttpException("USGS API Error: ${response.statusCode}");
      }
    } catch (e) {
      SecureLogger.error("Error fetching USGS data", e);
      rethrow;
    }
  }

  /// Parse USGS response efficiently
  static Future<List<Earthquake>> _parseUsgsResponse(
    String responseBody,
    double minMagnitude,
  ) async {
    try {
      final data = json.decode(responseBody);
      if (data["features"] == null) return [];

      final features = data["features"] as List;
      if (features.isEmpty) return [];

      final List<Earthquake> allEarthquakes = [];

      for (int i = 0; i < features.length; i += _chunkSize) {
        final end =
            (i + _chunkSize < features.length)
                ? i + _chunkSize
                : features.length;
        final chunk = features.sublist(i, end);

        final earthquakes =
            chunk
                .whereType<Map<String, dynamic>>()
                .map((quake) {
                  try {
                    final earthquake = Earthquake.fromUsgs(quake);
                    return earthquake.magnitude >= minMagnitude
                        ? earthquake
                        : null;
                  } catch (e) {
                    if (allEarthquakes.length < 5) {
                      SecureLogger.error(
                        "Error parsing USGS earthquake data",
                        e,
                      );
                    }
                    return null;
                  }
                })
                .whereType<Earthquake>()
                .toList();

        allEarthquakes.addAll(earthquakes);
      }

      return allEarthquakes;
    } catch (e) {
      SecureLogger.error("Error parsing USGS response", e);
      return [];
    }
  }

  /// Fetch earthquakes from EMSC with optimizations
  static Future<List<Earthquake>> _fetchFromEmsc({
    double minMagnitude = 3.0,
    int days = 45,
  }) async {
    try {
      final DateTime now = DateTime.now();
      final DateTime startDate = now.subtract(Duration(days: days));

      final Uri url =
          Uri.https("www.seismicportal.eu", "/fdsnws/event/1/query", {
            "format": "json",
            "orderby": "time-desc",
            "starttime": startDate.toIso8601String().split('T')[0],
            "endtime": now.toIso8601String().split('T')[0],
            "minmagnitude": minMagnitude.toString(),
            "limit": _maxEarthquakesPerSource.toString(),
          });

      final response = await SecureHttpClient.instance.get(
        url,
        timeout: const Duration(seconds: 30),
      );

      SecureLogger.api(
        "www.seismicportal.eu/fdsnws/event/1/query",
        statusCode: response.statusCode,
        method: "GET",
      );

      if (response.statusCode == 200) {
        return await _parseEmscResponse(response.body, minMagnitude);
      } else if (response.statusCode == 204) {
        return [];
      } else {
        throw HttpException("EMSC API Error: ${response.statusCode}");
      }
    } catch (e) {
      SecureLogger.error("Error fetching EMSC data", e);
      rethrow;
    }
  }

  /// Parse EMSC response efficiently
  static Future<List<Earthquake>> _parseEmscResponse(
    String responseBody,
    double minMagnitude,
  ) async {
    try {
      final data = json.decode(responseBody);

      if (data is! Map || data["features"] == null) {
        SecureLogger.error(
          "Unexpected EMSC response format",
          "Keys: ${data is Map ? data.keys.toList() : 'Not a map'}",
        );
        return [];
      }

      final earthquakeList = data["features"] as List;
      if (earthquakeList.isEmpty) return [];

      final List<Earthquake> allEarthquakes = [];
      int parseErrorCount = 0;

      for (int i = 0; i < earthquakeList.length; i += _chunkSize) {
        final end =
            (i + _chunkSize < earthquakeList.length)
                ? i + _chunkSize
                : earthquakeList.length;
        final chunk = earthquakeList.sublist(i, end);

        final earthquakes =
            chunk
                .whereType<Map<String, dynamic>>()
                .map((quake) {
                  try {
                    final earthquakeData =
                        quake['properties'] as Map<String, dynamic>?;
                    if (earthquakeData == null) return null;

                    final earthquake = Earthquake.fromEmsc(earthquakeData);
                    return earthquake.magnitude >= minMagnitude
                        ? earthquake
                        : null;
                  } catch (e) {
                    parseErrorCount++;
                    if (parseErrorCount <= 5) {
                      SecureLogger.error(
                        "Error parsing EMSC earthquake data",
                        e,
                      );
                    }
                    return null;
                  }
                })
                .whereType<Earthquake>()
                .toList();

        allEarthquakes.addAll(earthquakes);
      }

      if (parseErrorCount > 0) {
        SecureLogger.info(
          "EMSC parsing: ${allEarthquakes.length} earthquakes ($parseErrorCount errors)",
        );
      }

      return allEarthquakes;
    } catch (e) {
      SecureLogger.error("Error parsing EMSC response", e);
      return [];
    }
  }

  /// Optimized duplicate removal using spatial indexing
  static List<Earthquake> _removeDuplicatesOptimized(
    List<Earthquake> earthquakes,
  ) {
    if (earthquakes.length <= 1) return earthquakes;

    // Sort by time for better performance
    earthquakes.sort((a, b) => b.time.compareTo(a.time));

    final List<Earthquake> unique = [];

    for (final earthquake in earthquakes) {
      bool isDuplicate = false;

      // Only check recent earthquakes for duplicates (optimization)
      final recentUnique =
          unique
              .where(
                (e) =>
                    (earthquake.time.millisecondsSinceEpoch -
                            e.time.millisecondsSinceEpoch)
                        .abs() <
                    _duplicateTimeThreshold * 2,
              )
              .toList();

      for (final existing in recentUnique) {
        final distance = _calculateDistanceFast(
          earthquake.latitude,
          earthquake.longitude,
          existing.latitude,
          existing.longitude,
        );

        final timeDiff =
            (earthquake.time.millisecondsSinceEpoch -
                    existing.time.millisecondsSinceEpoch)
                .abs();

        if (distance < _duplicateDistanceThreshold &&
            timeDiff < _duplicateTimeThreshold) {
          isDuplicate = true;

          // Replace if current is better
          if (earthquake.magnitude > existing.magnitude ||
              (earthquake.magnitude == existing.magnitude &&
                  earthquake.time.isAfter(existing.time)) ||
              (earthquake.magnitude == existing.magnitude &&
                  earthquake.time == existing.time &&
                  earthquake.source == 'USGS' &&
                  existing.source == 'EMSC')) {
            final index = unique.indexOf(existing);
            if (index >= 0) unique[index] = earthquake;
          }
          break;
        }
      }

      if (!isDuplicate) {
        unique.add(earthquake);
      }
    }

    return unique;
  }

  /// Fast distance calculation using approximation for better performance
  static double _calculateDistanceFast(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Use approximation for better performance in duplicate detection
    const double earthRadius = 6371.0;
    final double dLat = (lat2 - lat1) * (pi / 180);
    final double dLon = (lon2 - lon1) * (pi / 180);

    // Simplified calculation for performance
    final double a =
        dLat * dLat + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * dLon * dLon;
    return earthRadius * sqrt(a);
  }

  /// Main fetch method with comprehensive optimizations
  static Future<List<Earthquake>> fetchEarthquakes({
    double minMagnitude = 3.0,
    int days = 45,
    bool forceRefresh = false,
    Set<DataSource>? sources,
  }) async {
    try {
      final selectedSources = sources ?? await getSelectedSources();

      if (selectedSources.isEmpty) {
        selectedSources.add(DataSource.usgs);
      }

      // Check memory cache first
      final cacheKey =
          '${selectedSources.map((s) => s.name).join('_')}_${minMagnitude}_$days';
      if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
        final cached = _memoryCache[cacheKey]!;
        if (cached.isNotEmpty) {
          SecureLogger.info(
            "Returning ${cached.length} earthquakes from memory cache",
          );
          return cached;
        }
      }

      final prefs = await _getPrefs();
      final cacheFile = await _getCacheFile(selectedSources);
      final cacheTimestampKey = _getCacheTimestampKey(selectedSources);

      // Check disk cache
      if (!forceRefresh) {
        final cachedTimestamp = prefs.getInt(cacheTimestampKey);
        if (cachedTimestamp != null &&
            await _isCacheValid(cacheFile, cachedTimestamp)) {
          try {
            final String cachedData = await cacheFile.readAsString();
            final List<dynamic> decoded = json.decode(cachedData);
            final earthquakes =
                decoded.map((e) => Earthquake.fromJson(e)).toList();

            // Store in memory cache
            _memoryCache[cacheKey] = earthquakes;
            SecureLogger.info(
              "Returning ${earthquakes.length} earthquakes from disk cache",
            );
            return earthquakes;
          } catch (e) {
            SecureLogger.error("Error reading cache", e);
          }
        }
      }

      // Fetch from APIs concurrently for better performance
      final List<Future<List<Earthquake>>> futures = [];
      final List<String> errors = [];

      for (final source in selectedSources) {
        switch (source) {
          case DataSource.usgs:
            futures.add(_fetchFromUsgs(minMagnitude: minMagnitude, days: days));
            break;
          case DataSource.emsc:
            futures.add(_fetchFromEmsc(minMagnitude: minMagnitude, days: days));
            break;
        }
      }

      // Wait for all API calls to complete
      final results = await Future.wait(futures, eagerError: false);
      List<Earthquake> allEarthquakes = [];

      for (int i = 0; i < results.length; i++) {
        try {
          allEarthquakes.addAll(results[i]);
          final sourceName = selectedSources.elementAt(i).name.toUpperCase();
          SecureLogger.info("$sourceName: ${results[i].length} earthquakes");
        } catch (e) {
          final sourceName = selectedSources.elementAt(i).name.toUpperCase();
          errors.add("$sourceName: $e");
          SecureLogger.error(
            "Error from ${selectedSources.elementAt(i).name}",
            e,
          );
        }
      }

      // Remove duplicates only if multiple sources
      if (selectedSources.length > 1 && allEarthquakes.isNotEmpty) {
        final beforeCount = allEarthquakes.length;
        allEarthquakes = _removeDuplicatesOptimized(allEarthquakes);
        SecureLogger.info(
          "Removed ${beforeCount - allEarthquakes.length} duplicates",
        );
      }

      // Sort by time (most recent first)
      allEarthquakes.sort((a, b) => b.time.compareTo(a.time));

      SecureLogger.info("Final result: ${allEarthquakes.length} earthquakes");

      // Cache results
      if (allEarthquakes.isNotEmpty) {
        try {
          // Memory cache
          _memoryCache[cacheKey] = allEarthquakes;

          // Disk cache
          final encodedData = json.encode(
            allEarthquakes.map((e) => e.toJson()).toList(),
          );
          await cacheFile.writeAsString(encodedData);
          await prefs.setInt(
            cacheTimestampKey,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (e) {
          SecureLogger.error("Error caching data", e);
        }
      }

      // Handle errors
      if (errors.isNotEmpty) {
        if (allEarthquakes.isEmpty) {
          throw Exception("All sources failed: ${errors.join(', ')}");
        } else {
          SecureLogger.error(
            "Some sources failed but data available from others",
            "Failed sources: ${errors.join(', ')}",
          );
        }
      }

      return allEarthquakes;
    } catch (e) {
      SecureLogger.error("Error in fetchEarthquakes", e);
      rethrow;
    }
  }

  /// Clear all caches
  static Future<void> clearCache() async {
    try {
      _memoryCache.clear();
      _sourceCache.clear();

      final prefs = await _getPrefs();
      final directory = await getApplicationDocumentsDirectory();

      // Clear all cache timestamps
      final allKeys =
          prefs
              .getKeys()
              .where((key) => key.startsWith('multi_source_cache_timestamp_'))
              .toList();

      for (final key in allKeys) {
        await prefs.remove(key);
      }

      // Remove old cache file
      final oldCacheFile = File('${directory.path}/$_cacheFilename');
      if (await oldCacheFile.exists()) {
        await oldCacheFile.delete();
      }
      await prefs.remove(_cacheTimestampKey);

      // Remove all source-specific cache files
      final files = directory.listSync().where(
        (file) =>
            file.path.contains('multi_source_cache_') &&
            file.path.endsWith('.json'),
      );

      for (final file in files) {
        try {
          await file.delete();
        } catch (e) {
          SecureLogger.error("Error deleting cache file: ${file.path}", e);
        }
      }

      SecureLogger.info("All caches cleared successfully");
    } catch (e) {
      SecureLogger.error("Error clearing cache", e);
    }
  }
}
