import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lastquake/models/earthquake.dart';
import 'package:lastquake/services/multi_source_api_service.dart';
import 'package:lastquake/services/secure_http_client.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHttpClient extends SecureHttpClient {
  _FakeHttpClient(super.client) : super.testing();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File usgsCacheFile;
  late File multiCacheFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('multi_service_test');
    usgsCacheFile = File('${tempDir.path}/multi_source_cache_usgs.json');
    multiCacheFile = File('${tempDir.path}/multi_source_cache_emsc_usgs.json');

    MultiSourceApiService.setPrefsProvider(
      () async => SharedPreferences.getInstance(),
    );
    MultiSourceApiService.setDirectoryProvider(() async => tempDir);
    MultiSourceApiService.resetCaches();
  });

  tearDown(() async {
    await MultiSourceApiService.clearCache();
    MultiSourceApiService.setPrefsProvider(null);
    MultiSourceApiService.setDirectoryProvider(null);
    MultiSourceApiService.setHttpClientOverride(null);
    MultiSourceApiService.resetCaches();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('getSelectedSources / setSelectedSources', () {
    test('defaults to USGS and persists selections', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(await MultiSourceApiService.getSelectedSources(), {
        DataSource.usgs,
      });

      await MultiSourceApiService.setSelectedSources({DataSource.emsc});
      expect(await MultiSourceApiService.getSelectedSources(), {
        DataSource.emsc,
      });

      final stored = prefs.getStringList('selected_data_sources');
      expect(stored, ['emsc']);
    });
  });

  group('fetchEarthquakes', () {
    test('returns cached data when disk cache valid', () async {
      final prefs = await SharedPreferences.getInstance();
      final timestampKey = 'multi_source_cache_timestamp_usgs';
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

      final earthquake = Earthquake(
        id: 'usgs1',
        magnitude: 4.5,
        place: 'Test Place',
        time: DateTime.utc(2024, 1, 1),
        latitude: 10,
        longitude: 20,
        depth: 5,
        url: 'https://example.com',
        source: 'USGS',
        rawData: const {},
      );
      await usgsCacheFile.writeAsString(jsonEncode([earthquake.toJson()]));

      final result = await MultiSourceApiService.fetchEarthquakes(
        forceRefresh: false,
        sources: {DataSource.usgs},
      );

      expect(result, hasLength(1));
      expect(result.first.id, 'usgs1');
    });

    test('fetches from both sources, merges, and removes duplicates', () async {
      final prefs = await SharedPreferences.getInstance();
      final mockClient = MockClient((request) async {
        if (request.url.host == 'earthquake.usgs.gov') {
          final response = {
            'features': [
              {
                'id': 'us1',
                'properties': {
                  'mag': 5.0,
                  'place': 'USGS Location',
                  'time': DateTime.utc(2024, 1, 1).millisecondsSinceEpoch,
                  'url': 'usgs-url',
                },
                'geometry': {
                  'coordinates': [10, 20, 5],
                },
              },
            ],
          };
          return http.Response(jsonEncode(response), 200);
        } else {
          final response = {
            'features': [
              {
                'properties': {
                  'unid': 'em1',
                  'mag': 5.0,
                  'flynn_region': 'EMSC Location',
                  'time': '2024-01-01T00:00:30Z',
                  'lat': 10.1,
                  'lon': 20.1,
                  'depth': 6.0,
                  'source_catalog': 'EMSC',
                },
              },
            ],
          };
          return http.Response(jsonEncode(response), 200);
        }
      });

      MultiSourceApiService.setHttpClientOverride(_FakeHttpClient(mockClient));

      final result = await MultiSourceApiService.fetchEarthquakes(
        forceRefresh: true,
        sources: {DataSource.usgs, DataSource.emsc},
        minMagnitude: 3.0,
        days: 1,
      );

      expect(result, hasLength(1));
      expect(result.first.source, anyOf('USGS', 'EMSC'));
      expect(await multiCacheFile.exists(), isTrue);
      expect(
        prefs.getKeys().any(
          (k) => k.startsWith('multi_source_cache_timestamp_'),
        ),
        isTrue,
      );
    });

    test('throws when all sources fail', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal error', 500);
      });
      MultiSourceApiService.setHttpClientOverride(_FakeHttpClient(mockClient));

      expect(
        () => MultiSourceApiService.fetchEarthquakes(
          forceRefresh: true,
          sources: {DataSource.usgs},
        ),
        throwsException,
      );
    });
  });

  group('clearCache', () {
    test('removes cache files and timestamps', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('multi_source_cache_timestamp_usgs', 1);
      await prefs.setInt('multi_source_cache_timestamp_emsc_usgs', 1);
      await usgsCacheFile.writeAsString('usgs');
      await multiCacheFile.writeAsString('multi');

      await MultiSourceApiService.clearCache();

      expect(
        prefs.getKeys().where(
          (k) => k.startsWith('multi_source_cache_timestamp_'),
        ),
        isEmpty,
      );
      expect(await usgsCacheFile.exists(), isFalse);
      expect(await multiCacheFile.exists(), isFalse);
    });
  });
}
