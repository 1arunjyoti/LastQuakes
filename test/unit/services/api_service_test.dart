import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lastquake/services/api_service.dart';
import 'package:lastquake/services/secure_http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, dynamic>> _processStub(List<dynamic> args) async {
  final rawData = args[0] as String;
  final minMagnitude = (args[1] as num).toDouble();
  final decoded = jsonDecode(rawData) as Map<String, dynamic>;
  final features = (decoded['features'] as List<dynamic>?) ?? [];

  final processed = features
      .map((feature) => Map<String, dynamic>.from(feature as Map<String, dynamic>))
      .where((feature) {
        final props = feature['properties'] as Map<String, dynamic>?;
        final mag = props?['mag'];
        if (mag == null) return false;
        final magnitude = mag is num ? mag.toDouble() : double.tryParse(mag.toString()) ?? 0.0;
        return magnitude >= minMagnitude;
      })
      .toList();

  return {
    'processed': processed,
    'encoded': jsonEncode(processed),
  };
}

Future<List<Map<String, dynamic>>> _decodeStub(String cachedData) async {
  final decoded = jsonDecode(cachedData) as List<dynamic>;
  return decoded
      .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File cacheFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('api_service_test');
    cacheFile = File('${tempDir.path}/cache.json');
  });

  tearDown(() async {
    SecureHttpClient.reset();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ApiService.fetchEarthquakes', () {
    test('returns cached data when cache is fresh', () async {
      final cachedList = [
        {
          'properties': {'mag': 4.5},
          'geometry': {'coordinates': [10.0, 20.0, 5.0]},
        }
      ];
      await cacheFile.writeAsString(jsonEncode(cachedList));

      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'earthquake_data_cache_timestamp': now,
      });
      final prefs = await SharedPreferences.getInstance();

      var networkCalled = false;
      final mockClient = MockClient((request) async {
        networkCalled = true;
        return http.Response('Internal error', 500);
      });
      SecureHttpClient.setMockInstance(SecureHttpClient.testing(mockClient));

      final result = await ApiService.fetchEarthquakes(
        prefsOverride: prefs,
        cacheFileOverride: cacheFile,
        processExecutor: _processStub,
        decodeExecutor: _decodeStub,
      );

      expect(networkCalled, isFalse);
      expect(result, hasLength(1));
      expect(result.first['properties']['mag'], 4.5);
    });

    test('fetches from network, filters by magnitude, and caches result', () async {
      final prefs = await SharedPreferences.getInstance();
      final apiResponse = jsonEncode({
        'features': [
          {
            'properties': {'mag': 2.9},
            'geometry': {'coordinates': [0, 0, 0]},
          },
          {
            'properties': {'mag': 5.1},
            'geometry': {'coordinates': [1, 1, 10]},
          },
        ],
      });

      final mockClient = MockClient((request) async {
        expect(request.url.host, 'earthquake.usgs.gov');
        return http.Response(apiResponse, 200);
      });
      SecureHttpClient.setMockInstance(SecureHttpClient.testing(mockClient));

      final result = await ApiService.fetchEarthquakes(
        minMagnitude: 3.0,
        forceRefresh: true,
        prefsOverride: prefs,
        cacheFileOverride: cacheFile,
        processExecutor: _processStub,
        decodeExecutor: _decodeStub,
        nowProvider: () => DateTime.utc(2024, 1, 1),
      );

      expect(result, hasLength(1));
      expect(result.first['properties']['mag'], 5.1);
      expect(await cacheFile.exists(), isTrue);

      final cached = await cacheFile.readAsString();
      final cachedList = await _decodeStub(cached);
      expect(cachedList, hasLength(1));
      expect(cachedList.first['properties']['mag'], 5.1);
      expect(prefs.getInt('earthquake_data_cache_timestamp'), isNotNull);
    });

    test('falls back to cache when network request fails', () async {
      final prefs = await SharedPreferences.getInstance();
      await cacheFile.writeAsString(jsonEncode([
        {
          'properties': {'mag': 4.0},
          'geometry': {'coordinates': [2, 3, 4]},
        }
      ]));

      final mockClient = MockClient((request) async {
        throw http.ClientException('Network down');
      });
      SecureHttpClient.setMockInstance(SecureHttpClient.testing(mockClient));

      final result = await ApiService.fetchEarthquakes(
        forceRefresh: true,
        prefsOverride: prefs,
        cacheFileOverride: cacheFile,
        processExecutor: _processStub,
        decodeExecutor: _decodeStub,
      );

      expect(result, hasLength(1));
      expect(result.first['properties']['mag'], 4.0);
    });
  });

  group('ApiService.clearCache', () {
    test('removes cache file and timestamp', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('earthquake_data_cache_timestamp', 123456789);
      await cacheFile.writeAsString('cached');

      await ApiService.clearCache(
        prefsOverride: prefs,
        cacheFileOverride: cacheFile,
      );

      expect(prefs.containsKey('earthquake_data_cache_timestamp'), isFalse);
      expect(await cacheFile.exists(), isFalse);
    });
  });
}
