import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lastquake/models/earthquake.dart';
import 'package:lastquake/services/secure_http_client.dart';
import 'package:lastquake/services/sources/earthquake_data_source.dart';
import 'package:lastquake/services/sources/emsc_data_source.dart';
import 'package:lastquake/services/sources/usgs_data_source.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:lastquake/utils/secure_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optimized multi-source API service with performance and memory optimizations
class MultiSourceApiService {
  static const String _cacheTimestampKey = 'multi_source_cache_timestamp';
  static const String _cacheFilename = 'multi_source_cache.json';
  static const String _selectedSourcesKey = 'selected_data_sources';

  // Performance constants
  // Performance and Configuration constants
  static const int _maxCacheSize = 50 * 1024 * 1024; // 50MB max cache size
  static const int _cacheValidityHours = 1;
  static const int _staleCacheValidityHours =
      24; // Allow up to 24h old data if network fails

  final SharedPreferences _prefs;
  final Directory _cacheDir;
  final Map<DataSource, EarthquakeDataSource> _sources;

  // Cache for expensive operations
  final Map<String, List<Earthquake>> _memoryCache = {};

  MultiSourceApiService({
    required SharedPreferences prefs,
    required SecureHttpClient client,
    required Directory cacheDir,
    Map<DataSource, EarthquakeDataSource>? sources,
  }) : _prefs = prefs,
       _cacheDir = cacheDir,
       _sources =
           sources ??
           {
             DataSource.usgs: UsgsDataSource(client, prefs),
             DataSource.emsc: EmscDataSource(client, prefs),
           };

  /// Factory to create instance with default dependencies
  static Future<MultiSourceApiService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final client = SecureHttpClient.instance;
    final cacheDir = await getApplicationDocumentsDirectory();
    return MultiSourceApiService(
      prefs: prefs,
      client: client,
      cacheDir: cacheDir,
    );
  }

  /// Get selected data sources from preferences
  Set<DataSource> getSelectedSources() {
    try {
      final sourceNames = _prefs.getStringList(_selectedSourcesKey) ?? ['usgs'];

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
      return sources;
    } catch (e) {
      SecureLogger.error("Error loading selected sources", e);
      return {DataSource.usgs};
    }
  }

  /// Save selected data sources to preferences
  Future<void> setSelectedSources(Set<DataSource> sources) async {
    try {
      final sourcesToSave = sources.isEmpty ? {DataSource.usgs} : sources;
      await _prefs.setStringList(
        _selectedSourcesKey,
        sourcesToSave.map((e) => e.name).toList(),
      );
      _memoryCache.clear(); // Clear memory cache when sources change
    } catch (e) {
      SecureLogger.error("Error saving selected sources", e);
      rethrow;
    }
  }

  /// Get all available data sources
  Set<DataSource> getAvailableSources() {
    return DataSource.values.toSet();
  }

  /// Check if multiple sources are selected
  bool hasMultipleSources() {
    try {
      final sources = getSelectedSources();
      return sources.length > 1;
    } catch (e) {
      SecureLogger.error("Error checking multiple sources", e);
      return false;
    }
  }

  /// Get cache file path for specific sources
  File _getCacheFile(Set<DataSource> sources) {
    try {
      final sourceKey = sources.map((s) => s.name).toList()..sort();
      final filename = 'multi_source_cache_${sourceKey.join('_')}.json';
      return File('${_cacheDir.path}/$filename');
    } catch (e) {
      SecureLogger.error("Error getting cache file path", e);
      rethrow;
    }
  }

  /// Get cache timestamp key for specific sources
  String _getCacheTimestampKey(Set<DataSource> sources) {
    final sourceKey = sources.map((s) => s.name).toList()..sort();
    return 'multi_source_cache_timestamp_${sourceKey.join('_')}';
  }

  /// Check if cache is valid and within size limits
  Future<bool> _isCacheValid(
    File cacheFile,
    int timestamp, {
    bool allowStale = false,
  }) async {
    try {
      if (!await cacheFile.exists()) return false;

      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final cacheAge = currentTime - timestamp;
      final validityWindow =
          (allowStale ? _staleCacheValidityHours : _cacheValidityHours) *
          3600000;

      if (cacheAge > validityWindow) return false;

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

  /// Main fetch method with comprehensive optimizations
  Future<List<Earthquake>> fetchEarthquakes({
    double minMagnitude = 3.0,
    int days = 45,
    bool forceRefresh = false,
    Set<DataSource>? sources,
  }) async {
    try {
      final selectedSources = sources ?? getSelectedSources();

      if (selectedSources.isEmpty) {
        selectedSources.add(DataSource.usgs);
      }

      final List<DataSource> sourcesList =
          selectedSources.toList()..sort((a, b) => a.index.compareTo(b.index));
      final String sourcesKey = sourcesList.map((s) => s.name).join('_');

      // Check memory cache first
      final cacheKey = '${sourcesKey}_${minMagnitude}_$days';
      if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
        final cached = _memoryCache[cacheKey]!;
        if (cached.isNotEmpty) {
          SecureLogger.info(
            "Returning ${cached.length} earthquakes from memory cache",
          );
          return cached;
        }
      }

      final cacheFile = _getCacheFile(selectedSources);
      final cacheTimestampKey = _getCacheTimestampKey(selectedSources);

      // Check disk cache
      if (!forceRefresh) {
        final cachedTimestamp = _prefs.getInt(cacheTimestampKey);
        if (cachedTimestamp != null &&
            await _isCacheValid(cacheFile, cachedTimestamp)) {
          try {
            final String cachedData = await cacheFile.readAsString();
            // Use compute for JSON parsing
            final earthquakes = await compute(
              _parseEarthquakesJson,
              cachedData,
            );

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
      final List<String> errors = [];

      if (sourcesList.isEmpty) {
        return [];
      }

      final stopwatch = Stopwatch()..start();
      final results = await Future.wait(
        sourcesList.map((source) async {
          try {
            final dataSource = _sources[source];
            if (dataSource == null) {
              throw Exception(
                "Data source implementation not found for $source",
              );
            }

            final data = await dataSource.fetchEarthquakes(
              minMagnitude: minMagnitude,
              days: days,
            );
            SecureLogger.info(
              "${source.name.toUpperCase()}: ${data.length} earthquakes",
            );
            return MapEntry(source, data);
          } catch (e) {
            errors.add("${source.name.toUpperCase()}: $e");
            SecureLogger.error("Error from ${source.name}", e);
            return MapEntry(source, <Earthquake>[]);
          }
        }),
        eagerError: false,
      );
      stopwatch.stop();

      SecureLogger.info(
        "Multi-source fetch (${sourcesKey.toUpperCase()}) completed in ${stopwatch.elapsedMilliseconds}ms",
      );

      List<Earthquake> allEarthquakes = [];

      for (final result in results) {
        allEarthquakes.addAll(result.value);
      }

      // Remove duplicates only if multiple sources
      if (sourcesList.length > 1 && allEarthquakes.isNotEmpty) {
        final beforeCount = allEarthquakes.length;
        // Use compute for duplicate removal
        allEarthquakes = await compute(
          _removeDuplicatesOptimized,
          allEarthquakes,
        );
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
          // Use compute for JSON encoding
          final encodedData = await compute(
            _encodeEarthquakesJson,
            allEarthquakes,
          );
          await cacheFile.writeAsString(encodedData);
          await _prefs.setInt(
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
          SecureLogger.warning(
            "All sources failed, attempting to load stale cache",
          );

          // Attempt to load stale cache
          final cachedTimestamp = _prefs.getInt(cacheTimestampKey);
          if (cachedTimestamp != null &&
              await _isCacheValid(
                cacheFile,
                cachedTimestamp,
                allowStale: true,
              )) {
            try {
              final String cachedData = await cacheFile.readAsString();
              // Use compute for JSON parsing
              final staleEarthquakes = await compute(
                _parseEarthquakesJson,
                cachedData,
              );

              SecureLogger.info(
                "Returning ${staleEarthquakes.length} earthquakes from STALE disk cache",
              );
              return staleEarthquakes;
            } catch (e) {
              SecureLogger.error("Error reading stale cache", e);
            }
          }

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
  Future<void> clearCache() async {
    try {
      _memoryCache.clear();

      // Clear all cache timestamps
      final allKeys =
          _prefs
              .getKeys()
              .where((key) => key.startsWith('multi_source_cache_timestamp_'))
              .toList();

      for (final key in allKeys) {
        await _prefs.remove(key);
      }

      // Remove old cache file
      final oldCacheFile = File('${_cacheDir.path}/$_cacheFilename');
      if (await oldCacheFile.exists()) {
        await oldCacheFile.delete();
      }
      await _prefs.remove(_cacheTimestampKey);

      // Remove all source-specific cache files
      final files = _cacheDir.listSync().where(
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

/// Top-level function for JSON decoding
List<Earthquake> _parseEarthquakesJson(String jsonStr) {
  final List<dynamic> decoded = json.decode(jsonStr);
  return decoded.map((e) => Earthquake.fromJson(e)).toList();
}

/// Top-level function for JSON encoding
String _encodeEarthquakesJson(List<Earthquake> earthquakes) {
  return json.encode(earthquakes.map((e) => e.toJson()).toList());
}

/// Top-level function for duplicate removal
List<Earthquake> _removeDuplicatesOptimized(List<Earthquake> earthquakes) {
  if (earthquakes.length <= 1) return earthquakes;

  // Constants needed for top-level function
  const double duplicateDistanceThreshold = 50.0; // km
  const int duplicateTimeThreshold = 600000; // 10 minutes in ms
  // Approx degrees for 50km (1 deg lat ~= 111km)
  const double latDegreeThreshold = 0.5;
  const double lonDegreeThreshold = 0.5;

  // Sort by time for better performance
  earthquakes.sort((a, b) => b.time.compareTo(a.time));

  final List<Earthquake> unique = [];

  for (final earthquake in earthquakes) {
    bool isDuplicate = false;

    // Iterate backwards through unique list (sliding window)
    // Since both lists are sorted by time (descending), recent items are at the end
    for (int i = unique.length - 1; i >= 0; i--) {
      final existing = unique[i];

      final timeDiff =
          (earthquake.time.millisecondsSinceEpoch -
                  existing.time.millisecondsSinceEpoch)
              .abs();

      // If time difference exceeds threshold, we can stop checking this branch
      // because all subsequent items in 'unique' will be even older
      if (timeDiff >= duplicateTimeThreshold) {
        break;
      }

      // Bounding box check (optimization)
      if ((earthquake.latitude - existing.latitude).abs() >
              latDegreeThreshold ||
          (earthquake.longitude - existing.longitude).abs() >
              lonDegreeThreshold) {
        continue;
      }

      final distance = _calculateDistanceHaversine(
        earthquake.latitude,
        earthquake.longitude,
        existing.latitude,
        existing.longitude,
      );

      if (distance < duplicateDistanceThreshold) {
        isDuplicate = true;

        // Replace if current is better
        // Prioritize USGS over EMSC
        bool shouldReplace = false;

        if (earthquake.source == 'USGS' && existing.source != 'USGS') {
          shouldReplace = true;
        } else if (earthquake.source != 'USGS' && existing.source == 'USGS') {
          shouldReplace = false;
        } else {
          // Same source or neither is USGS, use standard criteria
          if (earthquake.magnitude > existing.magnitude ||
              (earthquake.magnitude == existing.magnitude &&
                  earthquake.time.isAfter(existing.time))) {
            shouldReplace = true;
          }
        }

        if (shouldReplace) {
          unique[i] = earthquake;
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

/// Top-level function for Haversine distance calculation
double _calculateDistanceHaversine(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const double earthRadius = 6371.0; // km
  final double dLat = (lat2 - lat1) * (pi / 180);
  final double dLon = (lon2 - lon1) * (pi / 180);
  final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * (pi / 180)) *
          cos(lat2 * (pi / 180)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}
