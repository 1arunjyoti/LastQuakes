import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lastquake/models/earthquake.dart';
import 'package:lastquake/services/multi_source_api_service.dart';
import 'package:lastquake/services/secure_http_client.dart';
import 'package:lastquake/services/sources/earthquake_data_source.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHttpClient extends SecureHttpClient {
  _FakeHttpClient(super.client) : super.testing();
}

class MockDataSource implements EarthquakeDataSource {
  final List<Earthquake> earthquakes;
  final bool shouldThrow;

  MockDataSource({this.earthquakes = const [], this.shouldThrow = false});

  @override
  Future<List<Earthquake>> fetchEarthquakes({
    required double minMagnitude,
    required int days,
  }) async {
    if (shouldThrow) throw Exception('Mock error');
    return earthquakes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File usgsCacheFile;
  late File multiCacheFile;
  late MultiSourceApiService service;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = await Directory.systemTemp.createTemp('multi_service_test');
    usgsCacheFile = File('${tempDir.path}/multi_source_cache_usgs.json');
    multiCacheFile = File('${tempDir.path}/multi_source_cache_emsc_usgs.json');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('getSelectedSources / setSelectedSources', () {
    test('defaults to USGS and persists selections', () async {
      final mockClient = MockClient(
        (request) async => http.Response('[]', 200),
      );
      service = MultiSourceApiService(
        prefs: prefs,
        client: _FakeHttpClient(mockClient),
        cacheDir: tempDir,
      );

      expect(service.getSelectedSources(), {DataSource.usgs});

      await service.setSelectedSources({DataSource.emsc});
      expect(service.getSelectedSources(), {DataSource.emsc});

      final stored = prefs.getStringList('selected_data_sources');
      expect(stored, ['emsc']);
    });
  });

  group('fetchEarthquakes', () {
    test('returns cached data when disk cache valid', () async {
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

      final mockClient = MockClient(
        (request) async => http.Response('[]', 200),
      );
      service = MultiSourceApiService(
        prefs: prefs,
        client: _FakeHttpClient(mockClient),
        cacheDir: tempDir,
      );

      final result = await service.fetchEarthquakes(
        forceRefresh: false,
        sources: {DataSource.usgs},
      );

      expect(result, hasLength(1));
      expect(result.first.id, 'usgs1');
    });

    test('fetches from both sources, merges, and removes duplicates', () async {
      final usgsQuake = Earthquake(
        id: 'us1',
        magnitude: 5.0,
        place: 'USGS Location',
        time: DateTime.utc(2024, 1, 1),
        latitude: 10,
        longitude: 20,
        depth: 5,
        url: 'usgs-url',
        source: 'USGS',
        rawData: const {},
      );

      final emscQuake = Earthquake(
        id: 'em1',
        magnitude: 5.0,
        place: 'EMSC Location',
        time: DateTime.utc(2024, 1, 1).add(const Duration(seconds: 30)),
        latitude: 10.1,
        longitude: 20.1,
        depth: 6,
        url: 'emsc-url',
        source: 'EMSC',
        rawData: const {},
      );

      final mockClient = MockClient(
        (request) async => http.Response('[]', 200),
      );

      service = MultiSourceApiService(
        prefs: prefs,
        client: _FakeHttpClient(mockClient),
        cacheDir: tempDir,
        sources: {
          DataSource.usgs: MockDataSource(earthquakes: [usgsQuake]),
          DataSource.emsc: MockDataSource(earthquakes: [emscQuake]),
        },
      );

      final result = await service.fetchEarthquakes(
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

    test(
      'returns stale cache when all sources fail and stale cache is valid',
      () async {
        final timestampKey = 'multi_source_cache_timestamp_usgs';
        // Set timestamp to 2 hours ago (expired for normal cache, valid for stale)
        await prefs.setInt(
          timestampKey,
          DateTime.now()
              .subtract(const Duration(hours: 2))
              .millisecondsSinceEpoch,
        );

        final earthquake = Earthquake(
          id: 'usgs1',
          magnitude: 4.5,
          place: 'Stale Place',
          time: DateTime.utc(2024, 1, 1),
          latitude: 10,
          longitude: 20,
          depth: 5,
          url: 'https://example.com',
          source: 'USGS',
          rawData: const {},
        );
        await usgsCacheFile.writeAsString(jsonEncode([earthquake.toJson()]));

        final mockClient = MockClient(
          (request) async => http.Response('[]', 200),
        );

        service = MultiSourceApiService(
          prefs: prefs,
          client: _FakeHttpClient(mockClient),
          cacheDir: tempDir,
          sources: {DataSource.usgs: MockDataSource(shouldThrow: true)},
        );

        final result = await service.fetchEarthquakes(
          forceRefresh: true, // Force refresh to trigger network
          sources: {DataSource.usgs},
        );

        expect(result, hasLength(1));
        expect(result.first.place, 'Stale Place');
      },
    );

    test('throws when all sources fail and no stale cache available', () async {
      final mockClient = MockClient(
        (request) async => http.Response('[]', 200),
      );

      service = MultiSourceApiService(
        prefs: prefs,
        client: _FakeHttpClient(mockClient),
        cacheDir: tempDir,
        sources: {DataSource.usgs: MockDataSource(shouldThrow: true)},
      );

      expect(
        () => service.fetchEarthquakes(
          forceRefresh: true,
          sources: {DataSource.usgs},
        ),
        throwsException,
      );
    });
  });

  test('prioritizes USGS over EMSC for duplicates', () async {
    final usgsQuake = Earthquake(
      id: 'us1',
      magnitude: 4.0, // Lower magnitude
      place: 'USGS Location',
      time: DateTime.utc(2024, 1, 1),
      latitude: 10,
      longitude: 20,
      depth: 5,
      url: 'usgs-url',
      source: 'USGS',
      rawData: const {},
    );

    final emscQuake = Earthquake(
      id: 'em1',
      magnitude: 5.0, // Higher magnitude
      place: 'EMSC Location',
      time: DateTime.utc(2024, 1, 1), // Same time
      latitude: 10, // Same location
      longitude: 20,
      depth: 5,
      url: 'emsc-url',
      source: 'EMSC',
      rawData: const {},
    );

    final mockClient = MockClient((request) async => http.Response('[]', 200));

    service = MultiSourceApiService(
      prefs: prefs,
      client: _FakeHttpClient(mockClient),
      cacheDir: tempDir,
      sources: {
        DataSource.usgs: MockDataSource(earthquakes: [usgsQuake]),
        DataSource.emsc: MockDataSource(earthquakes: [emscQuake]),
      },
    );

    final result = await service.fetchEarthquakes(
      forceRefresh: true,
      sources: {DataSource.usgs, DataSource.emsc},
      minMagnitude: 3.0,
      days: 1,
    );

    expect(result, hasLength(1));
    expect(result.first.source, 'USGS');
    expect(
      result.first.magnitude,
      4.0,
    ); // Should keep USGS even if lower magnitude
  });

  group('clearCache', () {
    test('removes cache files and timestamps', () async {
      await prefs.setInt('multi_source_cache_timestamp_usgs', 1);
      await prefs.setInt('multi_source_cache_timestamp_emsc_usgs', 1);
      await usgsCacheFile.writeAsString('usgs');
      await multiCacheFile.writeAsString('multi');

      final mockClient = MockClient(
        (request) async => http.Response('[]', 200),
      );
      service = MultiSourceApiService(
        prefs: prefs,
        client: _FakeHttpClient(mockClient),
        cacheDir: tempDir,
      );

      await service.clearCache();

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
