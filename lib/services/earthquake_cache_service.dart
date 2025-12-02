import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:lastquake/models/earthquake.dart';

/// Service for caching earthquake data using Hive for ultra-fast performance
class EarthquakeCacheService {
  static const String _boxName = 'earthquakes_cache';
  static const String _cacheKey = 'cached_earthquakes';
  static const String _timestampKey = 'cache_timestamp';
  static const Duration _cacheMaxAge = Duration(hours: 1);

  /// Get the Hive box (lazy initialization)
  static Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  /// Get cached earthquake data if available and fresh
  static Future<List<Earthquake>?> getCachedData() async {
    try {
      final box = await _getBox();

      // Check if we have cached data
      final cachedList = box.get(_cacheKey);
      if (cachedList == null) {
        debugPrint('Hive Cache: No cached data found');
        return null;
      }

      // Check cache timestamp
      final timestamp = box.get(_timestampKey);
      if (timestamp == null) {
        debugPrint('Hive Cache: No timestamp found, invalidating cache');
        await _clearCache();
        return null;
      }

      final cacheAge =
          DateTime.now().millisecondsSinceEpoch - (timestamp as int);
      final isFresh = cacheAge < _cacheMaxAge.inMilliseconds;

      if (!isFresh) {
        debugPrint('Hive Cache: Cache expired (age: ${cacheAge}ms)');
        return null;
      }

      // Return typed list
      final earthquakes = (cachedList as List).cast<Earthquake>();
      debugPrint(
        'Hive Cache: Loaded ${earthquakes.length} earthquakes from cache',
      );
      return earthquakes;
    } catch (e) {
      debugPrint('Hive Cache: Error loading cache: $e');
      await _clearCache();
      return null;
    }
  }

  /// Cache earthquake data for future app starts
  static Future<void> cacheData(List<Earthquake> earthquakes) async {
    try {
      final box = await _getBox();

      // Store earthquake list (Hive handles serialization via adapter)
      await box.put(_cacheKey, earthquakes);
      await box.put(_timestampKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('Hive Cache: Cached ${earthquakes.length} earthquakes');
    } catch (e) {
      debugPrint('Hive Cache: Error caching data: $e');
    }
  }

  /// Clear the cache
  static Future<void> _clearCache() async {
    try {
      final box = await _getBox();
      await box.delete(_cacheKey);
      await box.delete(_timestampKey);
      debugPrint('Hive Cache: Cache cleared');
    } catch (e) {
      debugPrint('Hive Cache: Error clearing cache: $e');
    }
  }

  /// Manually clear cache (for testing or user action)
  static Future<void> clearCache() async {
    await _clearCache();
  }

  /// Get cache age in milliseconds, null if no cache
  static Future<int?> getCacheAge() async {
    try {
      final box = await _getBox();
      final timestamp = box.get(_timestampKey);
      if (timestamp == null) return null;

      return DateTime.now().millisecondsSinceEpoch - (timestamp as int);
    } catch (e) {
      return null;
    }
  }

  /// Close the Hive box (call on app dispose)
  static Future<void> dispose() async {
    try {
      if (Hive.isBoxOpen(_boxName)) {
        await Hive.box(_boxName).close();
      }
    } catch (e) {
      debugPrint('Hive Cache: Error closing box: $e');
    }
  }
}
