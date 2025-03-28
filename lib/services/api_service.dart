import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _CACHE_KEY = 'earthquake_data_cache';
  static const String _CACHE_TIMESTAMP_KEY = 'earthquake_data_cache_timestamp';

  /// Process earthquakes in an isolate to improve performance
  static List<Map<String, dynamic>> processEarthquakes(List<dynamic> args) {
    List<dynamic> allEarthquakes = args[0];
    double minMagnitude = args[1];

    return allEarthquakes
        .where((quake) {
          var mag = quake["properties"]["mag"];
          if (mag == null) return false; // Handling null values safely
          double magnitude = (mag is int) ? mag.toDouble() : mag;
          return magnitude >= minMagnitude;
        })
        .map((quake) => Map<String, dynamic>.from(quake))
        .toList(); // Ensuring type safety
  }

  /// Fetches and caches earthquake data
  static Future<List<Map<String, dynamic>>> fetchEarthquakes({
    double minMagnitude = 3.0,
    int days = 45,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Check for cached data if not force refreshing
    if (!forceRefresh) {
      final cachedData = prefs.getString(_CACHE_KEY);
      final cachedTimestamp = prefs.getInt(_CACHE_TIMESTAMP_KEY);

      if (cachedData != null && cachedTimestamp != null) {
        // Check if cache is less than 1 hour old
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        if (currentTime - cachedTimestamp < 3600000) {
          final List<dynamic> decodedCache = json.decode(cachedData);
          return decodedCache.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    }

    final DateTime now = DateTime.now();
    final DateTime startDate = now.subtract(Duration(days: days));

    final Uri url = Uri.https("earthquake.usgs.gov", "/fdsnws/event/1/query", {
      "format": "geojson",
      "orderby": "time",
      "starttime": startDate.toIso8601String(),
      "endtime": now.toIso8601String(),
    });

    debugPrint("Fetching data from: $url");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      debugPrint("API Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["features"] == null || (data["features"] as List).isEmpty) {
          debugPrint("No earthquakes found.");
          return [];
        }

        // Process earthquakes in a separate isolate
        final processedEarthquakes = await compute(processEarthquakes, [
          data["features"],
          minMagnitude,
        ]);

        // Cache the processed data
        await prefs.setString(_CACHE_KEY, json.encode(processedEarthquakes));
        await prefs.setInt(
          _CACHE_TIMESTAMP_KEY,
          DateTime.now().millisecondsSinceEpoch,
        );

        return processedEarthquakes;
      } else {
        throw Exception("API Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");

      // Attempt to return cached data if network fails
      final cachedData = prefs.getString(_CACHE_KEY);
      if (cachedData != null) {
        final List<dynamic> decodedCache = json.decode(cachedData);
        return decodedCache.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      throw Exception("Error fetching earthquake data: $e");
    }
  }

  /// Clear cached earthquake data
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_CACHE_KEY);
    await prefs.remove(_CACHE_TIMESTAMP_KEY);
  }
}
