import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:lastquake/services/secure_http_client.dart';
import 'package:lastquake/utils/secure_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class ApiService {
  static const String _cacheTimestampKey = 'earthquake_data_cache_timestamp';
  static const String _cacheFilename = 'earthquake_data_cache.json';

  /// Process earthquakes data in an isolate
  static Map<String, dynamic> _processEarthquakesIsolate(List<dynamic> args) {
    String rawData = args[0];
    double minMagnitude = args[1];

    // Decode JSON within the isolate
    final data = json.decode(rawData);
    if (data["features"] == null) return {"processed": [], "encoded": "[]"};

    final List<Map<String, dynamic>> processed =
        (data["features"] as List)
            .where((quake) {
              var mag = quake["properties"]["mag"];
              if (mag == null) return false;
              double magnitude = (mag is int) ? mag.toDouble() : mag;
              return magnitude >= minMagnitude;
            })
            .map((quake) => Map<String, dynamic>.from(quake))
            .toList();

    // Encode the processed data for caching within the isolate
    final String encodedData = json.encode(processed);

    return {"processed": processed, "encoded": encodedData};
  }

  /// Decode cached data in isolate
  static List<Map<String, dynamic>> _decodeCacheIsolate(String cachedData) {
    final List<dynamic> decoded = json.decode(cachedData);
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Get cache file path
  static Future<File> _getCacheFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_cacheFilename');
  }

  /// Fetches and caches earthquake data
  static Future<List<Map<String, dynamic>>> fetchEarthquakes({
    double minMagnitude = 3.0,
    int days = 45,
    bool forceRefresh = false,
    SharedPreferences? prefsOverride,
    File? cacheFileOverride,
    DateTime Function()? nowProvider,
    Future<Map<String, dynamic>> Function(List<dynamic> args)? processExecutor,
    Future<List<Map<String, dynamic>>> Function(String cachedData)?
    decodeExecutor,
  }) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final cacheFile = cacheFileOverride ?? await _getCacheFile();
    final process =
        processExecutor ??
        ((args) => compute<List<dynamic>, Map<String, dynamic>>(
          _processEarthquakesIsolate,
          args,
        ));
    final decode =
        decodeExecutor ??
        ((data) => compute<String, List<Map<String, dynamic>>>(
          _decodeCacheIsolate,
          data,
        ));

    // Check for cached data if not force refreshing
    if (!forceRefresh) {
      final cachedTimestamp = prefs.getInt(_cacheTimestampKey);
      if (cachedTimestamp != null && await cacheFile.exists()) {
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        if (currentTime - cachedTimestamp < 3600000) {
          // 1 hour cache
          final String cachedData = await cacheFile.readAsString();
          return await decode(cachedData);
        }
      }
    }

    final DateTime now = nowProvider?.call() ?? DateTime.now();
    final DateTime startDate = now.subtract(Duration(days: days));

    final Uri url = Uri.https("earthquake.usgs.gov", "/fdsnws/event/1/query", {
      "format": "geojson",
      "orderby": "time",
      "starttime": startDate.toIso8601String(),
      "endtime": now.toIso8601String(),
    });

    try {
      final response = await SecureHttpClient.instance.get(
        url,
        timeout: const Duration(seconds: 10),
      );
      SecureLogger.api(
        "earthquake.usgs.gov/fdsnws/event/1/query",
        statusCode: response.statusCode,
        method: "GET",
      );

      if (response.statusCode == 200) {
        // Process response in isolate
        final result = await process([response.body, minMagnitude]);

        // Save processed data to file cache
        await cacheFile.writeAsString(result["encoded"] as String);
        await prefs.setInt(
          _cacheTimestampKey,
          DateTime.now().millisecondsSinceEpoch,
        );

        return (result["processed"] as List).cast<Map<String, dynamic>>();
      } else {
        throw Exception("API Error: ${response.statusCode}");
      }
    } catch (e) {
      SecureLogger.error("Error fetching earthquake data", e);

      // Try to return cached data if network fails
      if (await cacheFile.exists()) {
        final String cachedData = await cacheFile.readAsString();
        return await decode(cachedData);
      }

      throw Exception("Error fetching earthquake data: $e");
    }
  }

  /// Clear cached earthquake data
  static Future<void> clearCache({
    SharedPreferences? prefsOverride,
    File? cacheFileOverride,
  }) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final cacheFile = cacheFileOverride ?? await _getCacheFile();
    await prefs.remove(_cacheTimestampKey);
    if (await cacheFile.exists()) {
      await cacheFile.delete();
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    // no-op: helper to signal static dependencies can be reset elsewhere
  }
}
