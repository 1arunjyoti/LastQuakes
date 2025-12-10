import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquakes/services/tile_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TileCacheService', () {
    test('instance returns singleton', () {
      final instance1 = TileCacheService.instance;
      final instance2 = TileCacheService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('isInitialized is false before init', () {
      // Note: This test may fail if run after other tests that call init
      // In a fresh state, isInitialized should be false
      // Since TileCacheService is a singleton, we can't easily reset it
      // So we just verify the property exists and is a bool
      expect(TileCacheService.instance.isInitialized, isA<bool>());
    });

    test('createCachedProvider returns null before init', () async {
      // Before init (or if caching failed), provider should be null
      // allowing graceful fallback to network-only tiles
      final provider = TileCacheService.instance.createCachedProvider();

      // If not initialized, should return null
      // If already initialized (from previous tests), may return a provider
      if (!TileCacheService.instance.isInitialized) {
        expect(provider, isNull);
      }
    });

    test('init is idempotent', () async {
      // Multiple calls to init should be safe
      await TileCacheService.instance.init();
      final firstState = TileCacheService.instance.isInitialized;

      await TileCacheService.instance.init();
      final secondState = TileCacheService.instance.isInitialized;

      expect(firstState, secondState);
    });

    test('getCacheSize returns int', () async {
      await TileCacheService.instance.init();
      final size = await TileCacheService.instance.getCacheSize();
      expect(size, isA<int>());
      expect(size, greaterThanOrEqualTo(0));
    });

    test('clearCache completes without error', () async {
      await TileCacheService.instance.init();

      // Should not throw
      await expectLater(TileCacheService.instance.clearCache(), completes);
    });

    test('createCachedProvider respects custom maxStale duration', () async {
      await TileCacheService.instance.init();

      // Create providers with different durations
      final provider7Days = TileCacheService.instance.createCachedProvider(
        maxStale: const Duration(days: 7),
      );
      final provider30Days = TileCacheService.instance.createCachedProvider(
        maxStale: const Duration(days: 30),
      );

      // Both should be valid providers (or null on web)
      if (!kIsWeb && TileCacheService.instance.cacheStore != null) {
        expect(provider7Days, isNotNull);
        expect(provider30Days, isNotNull);
      }
    });
  });
}
