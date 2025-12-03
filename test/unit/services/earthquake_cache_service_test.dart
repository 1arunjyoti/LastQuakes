import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/models/earthquake_adapter.dart';
import 'package:lastquakes/services/earthquake_cache_service.dart';
import '../../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EarthquakeCacheService', () {
    late Directory tempDir;

    setUp(() async {
      // Initialize Hive in a temporary directory for testing
      tempDir = await Directory.systemTemp.createTemp();
      Hive.init(tempDir.path);

      // Register the Earthquake adapter
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(EarthquakeAdapter());
      }
    });

    tearDown(() async {
      // Close and delete all boxes after each test
      if (Hive.isBoxOpen('earthquakes_cache')) {
        await Hive.box('earthquakes_cache').clear();
        await Hive.box('earthquakes_cache').close();
      }
      await Hive.deleteFromDisk();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Cache Hit/Miss Scenarios', () {
      test('getCachedData returns null when no cache exists', () async {
        final result = await EarthquakeCacheService.getCachedData();

        expect(result, isNull);
      });

      test('getCachedData returns earthquakes when cache is fresh', () async {
        // Setup: Cache some earthquakes
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 5);
        await EarthquakeCacheService.cacheData(mockEarthquakes);

        // Execute: Retrieve cached data immediately (should be fresh)
        final result = await EarthquakeCacheService.getCachedData();

        // Verify
        expect(result, isNotNull);
        expect(result!.length, 5);
        expect(result[0].id, mockEarthquakes[0].id);
      });

      test('getCachedData returns null when no timestamp exists', () async {
        // Setup: Put data without timestamp (corrupted cache)
        final box = await Hive.openBox('earthquakes_cache');
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 3);
        await box.put('cached_earthquakes', mockEarthquakes);
        // Don't put timestamp

        // Execute
        final result = await EarthquakeCacheService.getCachedData();

        // Verify: Should return null and clear cache
        expect(result, isNull);
      });
    });

    group('Cache Expiration', () {
      test(
        'getCachedData returns null when cache is expired (> 1 hour)',
        () async {
          // Setup: Cache data with old timestamp
          final box = await Hive.openBox('earthquakes_cache');
          final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 3);
          await box.put('cached_earthquakes', mockEarthquakes);

          // Set timestamp to 2 hours ago
          final twoHoursAgo =
              DateTime.now().millisecondsSinceEpoch - (2 * 60 * 60 * 1000);
          await box.put('cache_timestamp', twoHoursAgo);

          // Execute
          final result = await EarthquakeCacheService.getCachedData();

          // Verify: Should return null for expired cache
          expect(result, isNull);
        },
      );

      test(
        'getCachedData returns data when cache age is exactly at threshold',
        () async {
          // Setup: Cache data with timestamp exactly at 1 hour (edge case)
          final box = await Hive.openBox('earthquakes_cache');
          final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 3);
          await box.put('cached_earthquakes', mockEarthquakes);

          // Set timestamp to exactly 1 hour ago minus 1 second (still fresh)
          final almostOneHourAgo =
              DateTime.now().millisecondsSinceEpoch - (60 * 60 * 1000 - 1000);
          await box.put('cache_timestamp', almostOneHourAgo);

          // Execute
          final result = await EarthquakeCacheService.getCachedData();

          // Verify: Should return data (still fresh by 1 second)
          expect(result, isNotNull);
          expect(result!.length, 3);
        },
      );
    });

    group('Cache Data Storage', () {
      test('cacheData stores earthquakes with timestamp', () async {
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 5);

        await EarthquakeCacheService.cacheData(mockEarthquakes);

        final box = await Hive.openBox('earthquakes_cache');
        final cached = box.get('cached_earthquakes');
        final timestamp = box.get('cache_timestamp');

        expect(cached, isNotNull);
        expect((cached as List).length, 5);
        expect(timestamp, isNotNull);
        expect(timestamp, isA<int>());
      });

      test('cacheData overwrites existing cache', () async {
        // Setup: Cache initial data
        final initialEarthquakes = TestHelpers.createMockEarthquakes(count: 3);
        await EarthquakeCacheService.cacheData(initialEarthquakes);

        // Execute: Cache new data
        final newEarthquakes = TestHelpers.createMockEarthquakes(count: 7);
        await EarthquakeCacheService.cacheData(newEarthquakes);

        // Verify: Should have new data
        final result = await EarthquakeCacheService.getCachedData();
        expect(result, isNotNull);
        expect(result!.length, 7);
      });

      test('cacheData handles empty list', () async {
        await EarthquakeCacheService.cacheData([]);

        final result = await EarthquakeCacheService.getCachedData();

        expect(result, isNotNull);
        expect(result!.isEmpty, isTrue);
      });
    });

    group('Clear Cache', () {
      test('clearCache removes all cached data', () async {
        // Setup: Cache some data
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 5);
        await EarthquakeCacheService.cacheData(mockEarthquakes);

        // Verify data exists
        var result = await EarthquakeCacheService.getCachedData();
        expect(result, isNotNull);

        // Execute: Clear cache
        await EarthquakeCacheService.clearCache();

        // Verify: Data should be gone
        result = await EarthquakeCacheService.getCachedData();
        expect(result, isNull);
      });

      test('clearCache on empty cache does not throw', () async {
        // Should not throw when clearing empty cache
        await EarthquakeCacheService.clearCache();

        final result = await EarthquakeCacheService.getCachedData();
        expect(result, isNull);
      });
    });

    group('Cache Age', () {
      test('getCacheAge returns null when no cache exists', () async {
        final age = await EarthquakeCacheService.getCacheAge();

        expect(age, isNull);
      });

      test('getCacheAge returns age in milliseconds', () async {
        // Setup: Cache data
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 3);
        await EarthquakeCacheService.cacheData(mockEarthquakes);

        // Small delay to ensure age > 0
        await Future.delayed(const Duration(milliseconds: 10));

        // Execute
        final age = await EarthquakeCacheService.getCacheAge();

        // Verify: Age should be positive and relatively small
        expect(age, isNotNull);
        expect(age!, greaterThan(0));
        expect(age, lessThan(1000)); // Less than 1 second
      });

      test('getCacheAge calculates age correctly', () async {
        // Setup: Manually set timestamp to known value
        final box = await Hive.openBox('earthquakes_cache');
        final fiveMinutesAgo =
            DateTime.now().millisecondsSinceEpoch - (5 * 60 * 1000);
        await box.put('cache_timestamp', fiveMinutesAgo);

        // Execute
        final age = await EarthquakeCacheService.getCacheAge();

        // Verify: Age should be approximately 5 minutes (allowing for test execution time)
        expect(age, isNotNull);
        expect(age!, greaterThan(5 * 60 * 1000 - 1000)); // At least 4:59
        expect(age, lessThan(5 * 60 * 1000 + 2000)); // At most 5:02
      });
    });

    group('Error Recovery', () {
      test('getCachedData handles corrupted cache gracefully', () async {
        // Setup: Put invalid data in cache
        final box = await Hive.openBox('earthquakes_cache');
        await box.put(
          'cached_earthquakes',
          'invalid_data',
        ); // String instead of List
        await box.put('cache_timestamp', DateTime.now().millisecondsSinceEpoch);

        // Execute: Should not throw
        final result = await EarthquakeCacheService.getCachedData();

        // Verify: Should return null and clear bad cache
        expect(result, isNull);
      });

      test('cacheData handles Hive errors gracefully', () async {
        // Close the box to simulate error condition
        if (Hive.isBoxOpen('earthquakes_cache')) {
          await Hive.box('earthquakes_cache').close();
        }

        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 3);

        // Should not throw (may log error but handle gracefully)
        try {
          await EarthquakeCacheService.cacheData(mockEarthquakes);
          // If it succeeds, that's fine (box gets reopened)
        } catch (e) {
          // If it throws, verify it's handled
          fail('cacheData should handle errors gracefully');
        }
      });
    });

    group('Dispose', () {
      test('dispose closes the box when open', () async {
        // Setup: Open box by caching data
        final mockEarthquakes = TestHelpers.createMockEarthquakes(count: 2);
        await EarthquakeCacheService.cacheData(mockEarthquakes);

        expect(Hive.isBoxOpen('earthquakes_cache'), isTrue);

        // Execute
        await EarthquakeCacheService.dispose();

        // Verify: Box should be closed
        expect(Hive.isBoxOpen('earthquakes_cache'), isFalse);
      });

      test('dispose handles already closed box gracefully', () async {
        // Box is not open
        expect(Hive.isBoxOpen('earthquakes_cache'), isFalse);

        // Should not throw
        await EarthquakeCacheService.dispose();
      });
    });

    group('Data Type Integrity', () {
      test('cached earthquakes maintain all properties', () async {
        // Setup: Create earthquake with all properties
        final earthquake = TestHelpers.createMockEarthquake(
          id: 'test_123',
          magnitude: 6.5,
          place: 'Test Location',
          time: DateTime(2024, 6, 15, 10, 30),
          latitude: 35.123,
          longitude: -120.456,
          depth: 15.5,
          source: 'USGS',
        );

        await EarthquakeCacheService.cacheData([earthquake]);

        // Execute
        final result = await EarthquakeCacheService.getCachedData();

        // Verify: All properties preserved
        expect(result, isNotNull);
        expect(result!.length, 1);

        final cached = result[0];
        expect(cached.id, 'test_123');
        expect(cached.magnitude, 6.5);
        expect(cached.place, 'Test Location');
        expect(cached.time, DateTime(2024, 6, 15, 10, 30));
        expect(cached.latitude, 35.123);
        expect(cached.longitude, -120.456);
        expect(cached.depth, 15.5);
        expect(cached.source, 'USGS');
      });

      test(
        'cached earthquakes with null optional fields work correctly',
        () async {
          final earthquake = Earthquake(
            id: 'test_null',
            magnitude: 4.0,
            place: 'Null Test',
            time: DateTime(2024, 1, 1),
            latitude: 0.0,
            longitude: 0.0,
            depth: null, // Null depth
            url: null, // Null URL
            tsunami: null, // Null tsunami
            source: 'TEST',
            rawData: {},
          );

          await EarthquakeCacheService.cacheData([earthquake]);

          final result = await EarthquakeCacheService.getCachedData();

          expect(result, isNotNull);
          expect(result!.length, 1);
          expect(result[0].depth, isNull);
          expect(result[0].url, isNull);
          expect(result[0].tsunami, isNull);
        },
      );
    });
  });
}
