import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:path_provider/path_provider.dart';

/// Service for managing map tile caching using Hive storage backend.
///
/// This service provides cached tile providers to all map screens in the app,
/// reducing network requests, improving performance, and enabling offline
/// viewing of previously visited map areas.
class TileCacheService {
  TileCacheService._();

  static final TileCacheService _instance = TileCacheService._();

  /// Singleton instance for app-wide cache sharing
  static TileCacheService get instance => _instance;

  HiveCacheStore? _cacheStore;
  bool _isInitialized = false;
  String? _cachePath;

  /// Whether the cache service has been initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the tile cache store.
  /// Should be called once during app startup after Hive.initFlutter().
  Future<void> init() async {
    if (_isInitialized) return;

    // Web doesn't support file-based caching
    if (kIsWeb) {
      debugPrint('TileCacheService: Skipping init on web platform');
      _isInitialized = true;
      return;
    }

    try {
      final cacheDir = await getTemporaryDirectory();
      _cachePath = '${cacheDir.path}/map_tiles';

      _cacheStore = HiveCacheStore(_cachePath!, hiveBoxName: 'tile_cache');

      _isInitialized = true;
      debugPrint('TileCacheService: Initialized at $_cachePath');
    } catch (e) {
      debugPrint('TileCacheService: Failed to initialize - $e');
      // Continue without caching - maps will still work
      _isInitialized = true;
    }
  }

  /// Get the Hive cache store (null if not initialized or on web)
  HiveCacheStore? get cacheStore => _cacheStore;

  /// Create a cached tile provider for use in TileLayer.
  ///
  /// If caching is not available (web or init failed), returns null
  /// and the TileLayer will use default network provider.
  ///
  /// [maxStale] - How long tiles remain valid in cache.
  /// Default is 14 days which balances freshness with storage efficiency.
  TileProvider? createCachedProvider({
    Duration maxStale = const Duration(days: 14),
  }) {
    if (_cacheStore == null) {
      return null;
    }

    return CachedTileProvider(maxStale: maxStale, store: _cacheStore!);
  }

  /// Get estimated cache size in bytes.
  /// Returns 0 if cache is not available.
  Future<int> getCacheSize() async {
    if (_cachePath == null || kIsWeb) return 0;

    try {
      final cacheDir = await getTemporaryDirectory();
      final tileCacheDir = cacheDir.listSync().where(
        (entity) => entity.path.contains('map_tiles'),
      );

      int totalSize = 0;
      for (final entity in tileCacheDir) {
        if (entity is! Directory) continue;
        await for (final file in (entity).list(recursive: true)) {
          if (file is! File) continue;
          totalSize += await (file).length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('TileCacheService: Failed to get cache size - $e');
      return 0;
    }
  }

  /// Clear all cached tiles.
  Future<void> clearCache() async {
    if (_cacheStore == null) return;

    try {
      await _cacheStore!.clean();
      debugPrint('TileCacheService: Cache cleared');
    } catch (e) {
      debugPrint('TileCacheService: Failed to clear cache - $e');
    }
  }

  /// Dispose resources. Call on app shutdown if needed.
  Future<void> dispose() async {
    try {
      await _cacheStore?.close();
      _cacheStore = null;
      _isInitialized = false;
      debugPrint('TileCacheService: Disposed');
    } catch (e) {
      debugPrint('TileCacheService: Error during dispose - $e');
    }
  }
}
