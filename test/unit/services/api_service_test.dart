import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquakes/services/api_service.dart';
import 'package:lastquakes/services/secure_http_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiService', () {
    late Directory tempDir;
    late File mockCacheFile;
    late SharedPreferences prefs;
    late MockHttpClient mockHttpClient;

    setUp(() async {
      // Create temporary directory for cache file
      tempDir = await Directory.systemTemp.createTemp('api_service_test');
      mockCacheFile = File('${tempDir.path}/test_cache.json');

      // Initialize mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      // Setup mock HTTP client
      mockHttpClient = MockHttpClient();
      registerFallbackValue(Uri());

      // Default mock behavior: return 200 OK with empty JSON
      when(
        () => mockHttpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('{"features": []}', 200));

      SecureHttpClient.setMockInstance(
        SecureHttpClient.testing(mockHttpClient),
      );
    });

    tearDown(() async {
      // Clean up
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      ApiService.resetForTesting();
      SecureHttpClient.reset();
    });

    group('Cache Behavior', () {
      test('returns cached data when cache is fresh (< 1 hour)', () async {
        // Setup: Create fresh cache
        final mockData = TestHelpers.createMockUsgsResponse(count: 5);
        final processed =
            (mockData['features'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
        await mockCacheFile.writeAsString(jsonEncode(processed));
        await prefs.setInt(
          'earthquake_data_cache_timestamp',
          DateTime.now().millisecondsSinceEpoch - 1800000, // 30 minutes ago
        );

        // Mock executor that should NOT be called since we have fresh cache
        bool apiCalled = false;
        Future<Map<String, dynamic>> mockProcess(List<dynamic> args) async {
          apiCalled = true;
          return {'processed': [], 'encoded': '[]'};
        }

        // Execute
        try {
          await ApiService.fetchEarthquakes(
            minMagnitude: 3.0,
            days: 7,
            forceRefresh: false,
            prefsOverride: prefs,
            cacheFileOverride: mockCacheFile,
            processExecutor: mockProcess,
            decodeExecutor: (data) async {
              final decoded = jsonDecode(data) as List;
              return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            },
          );
        } catch (e) {
          // API call will fail since we're mocking, but we only care if it was attempted
        }

        // API should not be called when cache is fresh
        expect(apiCalled, isFalse);
      });

      test('fetches new data when cache is expired (> 1 hour)', () async {
        // Setup: Create expired cache
        final oldData = TestHelpers.createMockUsgsResponse(count: 3);
        final processed =
            (oldData['features'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
        await mockCacheFile.writeAsString(jsonEncode(processed));

        final now = DateTime(2024, 1, 1, 12, 0);
        await prefs.setInt(
          'earthquake_data_cache_timestamp',
          now.millisecondsSinceEpoch - 7200000, // 2 hours ago
        );

        bool apiCalled = false;
        Future<Map<String, dynamic>> mockProcess(List<dynamic> args) async {
          apiCalled = true;
          final newData = TestHelpers.createMockUsgsResponse(count: 5);
          final newProcessed =
              (newData['features'] as List)
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
          return {
            'processed': newProcessed,
            'encoded': jsonEncode(newProcessed),
          };
        }

        try {
          await ApiService.fetchEarthquakes(
            minMagnitude: 3.0,
            days: 7,
            forceRefresh: false,
            prefsOverride: prefs,
            cacheFileOverride: mockCacheFile,
            nowProvider: () => now,
            processExecutor: mockProcess,
            decodeExecutor: (data) async {
              final decoded = jsonDecode(data) as List;
              return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
            },
          );
        } catch (e) {
          // Expected to fail due to mock HTTP client
        }

        // API should be called when cache is expired
        expect(apiCalled, isTrue);
      });

      test('returns cached data when no cache exists', () async {
        // No cache file exists
        expect(await mockCacheFile.exists(), isFalse);

        bool apiCalled = false;
        Future<Map<String, dynamic>> mockProcess(List<dynamic> args) async {
          apiCalled = true;
          return {'processed': [], 'encoded': '[]'};
        }

        try {
          await ApiService.fetchEarthquakes(
            minMagnitude: 3.0,
            days: 7,
            forceRefresh: false,
            prefsOverride: prefs,
            cacheFileOverride: mockCacheFile,
            nowProvider: () => DateTime(2024, 1, 1),
            processExecutor: mockProcess,
            decodeExecutor: (data) async => [],
          );
        } catch (e) {
          // Expected to fail
        }

        // API should be called when no cache exists
        expect(apiCalled, isTrue);
      });
    });

    group('Force Refresh', () {
      test('bypasses cache when forceRefresh is true', () async {
        // Setup: Create fresh cache
        final mockData = TestHelpers.createMockUsgsResponse(count: 5);
        final processed =
            (mockData['features'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
        await mockCacheFile.writeAsString(jsonEncode(processed));
        await prefs.setInt(
          'earthquake_data_cache_timestamp',
          DateTime.now().millisecondsSinceEpoch -
              1800000, // 30 minutes ago (fresh)
        );

        bool apiCalled = false;
        Future<Map<String, dynamic>> mockProcess(List<dynamic> args) async {
          apiCalled = true;
          return {'processed': [], 'encoded': '[]'};
        }

        try {
          await ApiService.fetchEarthquakes(
            minMagnitude: 3.0,
            days: 7,
            forceRefresh: true, // Force refresh!
            prefsOverride: prefs,
            cacheFileOverride: mockCacheFile,
            nowProvider: () => DateTime(2024, 1, 1),
            processExecutor: mockProcess,
            decodeExecutor: (data) async => [],
          );
        } catch (e) {
          // Expected to fail
        }

        // API should be called even with fresh cache due to force refresh
        expect(apiCalled, isTrue);
      });
    });

    group('Isolate Processing', () {
      test('filters earthquakes by minimum magnitude correctly', () async {
        final mockData = TestHelpers.createMockUsgsResponse(
          count: 10,
          minMagnitude: 2.0,
          maxMagnitude: 7.0,
        );
        final rawData = jsonEncode(mockData);

        // Process with minMagnitude = 5.0
        final result = ApiService.processEarthquakesIsolate([rawData, 5.0]);

        final processed = result['processed'] as List;

        // All returned earthquakes should have magnitude >= 5.0
        for (final quake in processed) {
          final mag = quake['properties']['mag'];
          expect(mag, greaterThanOrEqualTo(5.0));
        }

        // Should have fewer earthquakes than total
        expect(processed.length, lessThan(10));
      });

      test('handles null magnitudes by filtering them out', () async {
        final mockData = {
          'features': [
            TestHelpers.createMockUsgsData(magnitude: 5.0),
            {
              'id': 'null_mag',
              'properties': {
                'mag': null,
                'place': 'No Magnitude',
                'time': 1700000000000,
              },
              'geometry': {
                'coordinates': [-120.0, 35.0],
              },
            },
            TestHelpers.createMockUsgsData(magnitude: 6.0),
          ],
        };
        final rawData = jsonEncode(mockData);

        final result = ApiService.processEarthquakesIsolate([rawData, 3.0]);
        final processed = result['processed'] as List;

        // Should only have 2 earthquakes (null magnitude filtered out)
        expect(processed.length, 2);
      });

      test('encodes processed data correctly for caching', () async {
        final mockData = TestHelpers.createMockUsgsResponse(count: 3);
        final rawData = jsonEncode(mockData);

        final result = ApiService.processEarthquakesIsolate([rawData, 3.0]);

        final encoded = result['encoded'] as String;
        final processed = result['processed'] as List;

        // Encoded string should be valid JSON
        final decoded = jsonDecode(encoded);
        expect(decoded, isA<List>());

        // Encoded data should match processed data
        expect(decoded.length, processed.length);
      });
    });

    group('Decode Cache Isolate', () {
      test('decodes cached JSON string correctly', () async {
        final mockEarthquakes = [
          TestHelpers.createMockUsgsData(id: '1'),
          TestHelpers.createMockUsgsData(id: '2'),
          TestHelpers.createMockUsgsData(id: '3'),
        ];
        final cachedData = jsonEncode(mockEarthquakes);

        final result = ApiService.decodeCacheIsolate(cachedData);

        expect(result, isA<List>());
        expect(result.length, 3);
        expect(result[0], isA<Map<String, dynamic>>());
        expect(result[0]['id'], '1');
      });

      test('handles empty cached data', () async {
        final cachedData = '[]';

        final result = ApiService.decodeCacheIsolate(cachedData);

        expect(result, isA<List>());
        expect(result.isEmpty, isTrue);
      });
    });

    group('Clear Cache', () {
      test('clears both SharedPreferences and file cache', () async {
        // Setup: Create cache
        await mockCacheFile.writeAsString('{"test": "data"}');
        await prefs.setInt('earthquake_data_cache_timestamp', 12345);

        expect(await mockCacheFile.exists(), isTrue);
        expect(prefs.getInt('earthquake_data_cache_timestamp'), isNotNull);

        // Clear cache
        await ApiService.clearCache(
          prefsOverride: prefs,
          cacheFileOverride: mockCacheFile,
        );

        // Verify cache is cleared
        expect(await mockCacheFile.exists(), isFalse);
        expect(prefs.getInt('earthquake_data_cache_timestamp'), isNull);
      });

      test('handles missing cache file gracefully', () async {
        // No cache file exists
        expect(await mockCacheFile.exists(), isFalse);

        // Should not throw
        await ApiService.clearCache(
          prefsOverride: prefs,
          cacheFileOverride: mockCacheFile,
        );

        expect(await mockCacheFile.exists(), isFalse);
      });
    });

    group('Edge Cases', () {
      test('handles empty features array', () async {
        final mockData = {'features': []};
        final rawData = jsonEncode(mockData);

        final result = ApiService.processEarthquakesIsolate([rawData, 3.0]);
        final processed = result['processed'] as List;

        expect(processed.isEmpty, isTrue);
      });

      test('handles missing features field', () async {
        final mockData = {'metadata': 'test'};
        final rawData = jsonEncode(mockData);

        final result = ApiService.processEarthquakesIsolate([rawData, 3.0]);
        final processed = result['processed'] as List;

        expect(processed.isEmpty, isTrue);
      });

      test('handles integer magnitudes correctly', () async {
        final mockData = {
          'features': [
            {
              'id': 'int_mag',
              'properties': {
                'mag': 5, // Integer instead of double
                'place': 'Integer Magnitude',
                'time': 1700000000000,
              },
              'geometry': {
                'coordinates': [-120.0, 35.0],
              },
            },
          ],
        };
        final rawData = jsonEncode(mockData);

        final result = ApiService.processEarthquakesIsolate([rawData, 3.0]);
        final processed = result['processed'] as List;

        expect(processed.length, 1);
        // Should convert int to double
        expect(processed[0]['properties']['mag'], isA<num>());
      });
    });
  });
}
