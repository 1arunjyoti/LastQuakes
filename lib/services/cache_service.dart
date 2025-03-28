import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _earthquakesCacheKey = 'cached_earthquakes';
  static const String _lastFetchTimeKey = 'last_fetch_time';

  // Save earthquakes to cache
  static Future<void> cacheEarthquakes(
    List<Map<String, dynamic>> earthquakes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_earthquakesCacheKey, json.encode(earthquakes));
    await prefs.setInt(
      _lastFetchTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // Retrieve cached earthquakes
  static Future<List<Map<String, dynamic>>> getCachedEarthquakes() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(_earthquakesCacheKey);

    if (cachedData != null) {
      final List<dynamic> decoded = json.decode(cachedData);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return [];
  }

  // Check if cached data is fresh (within 15 minutes)
  static Future<bool> isCacheFresh() async {
    final prefs = await SharedPreferences.getInstance();
    final lastFetchTime = prefs.getInt(_lastFetchTimeKey);

    if (lastFetchTime == null) return false;

    final timeDifference =
        DateTime.now().millisecondsSinceEpoch - lastFetchTime;
    return timeDifference < Duration(minutes: 15).inMilliseconds;
  }
}
