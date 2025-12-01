import 'package:flutter_test/flutter_test.dart';
import 'package:lastquake/models/earthquake.dart';

void main() {
  group('Earthquake.fromUsgs', () {
    test('parses mandatory fields from USGS payload', () {
      final usgsData = {
        'id': 'us12345678',
        'properties': {
          'mag': 5.6,
          'place': '100 km SE of Sample City',
          'time': 1700000000000,
          'url': 'https://earthquake.usgs.gov/earthquakes/eventpage/us12345678',
        },
        'geometry': {
          'coordinates': [-115.1234, 32.5678, 12.3],
        },
      };

      final quake = Earthquake.fromUsgs(usgsData);

      expect(quake.id, 'us12345678');
      expect(quake.magnitude, 5.6);
      expect(quake.place, '100 km SE of Sample City');
      expect(quake.time.millisecondsSinceEpoch, 1700000000000);
      expect(quake.latitude, 32.5678);
      expect(quake.longitude, -115.1234);
      expect(quake.depth, 12.3);
      expect(quake.url, 'https://earthquake.usgs.gov/earthquakes/eventpage/us12345678');
      expect(quake.source, 'USGS');
      expect(identical(quake.rawData, usgsData), isTrue);
    });

    test('sets depth to null when coordinate array lacks depth', () {
      final usgsData = {
        'id': 'us98765432',
        'properties': {
          'mag': 4.2,
          'place': 'Near the coast of Somewhere',
          'time': 1700001000000,
          'url': null,
        },
        'geometry': {
          'coordinates': [140.0, -20.0],
        },
      };

      final quake = Earthquake.fromUsgs(usgsData);

      expect(quake.depth, isNull);
      expect(quake.url, isNull);
      expect(quake.source, 'USGS');
    });
  });

  group('Earthquake.fromEmsc', () {
    test('parses various field aliases and constructs EMSC url', () {
      final emscData = {
        'unid': 'em1234567',
        'mag': 6.1,
        'flynn_region': 'OFFSHORE REGION',
        'time': '2024-01-05T12:34:56Z',
        'lat': 45.1234,
        'lon': 10.5678,
        'depth': 15.0,
        'source_catalog': 'EMSC',
      };

      final quake = Earthquake.fromEmsc(emscData);

      expect(quake.id, 'em1234567');
      expect(quake.magnitude, 6.1);
      expect(quake.place, 'OFFSHORE REGION');
      expect(quake.time.toIso8601String(), '2024-01-05T12:34:56.000Z');
      expect(quake.latitude, 45.1234);
      expect(quake.longitude, 10.5678);
      expect(quake.depth, 15.0);
      expect(quake.url, 'https://www.emsc-csem.org/Earthquake/earthquake.php?id=em1234567');
      expect(quake.source, 'EMSC');
      expect(identical(quake.rawData, emscData), isTrue);
    });

    test('falls back to defaults when optional fields missing', () {
      final emscData = {
        'magnitude': 3.4,
        'region': 'Some Region',
        'datetime': '2024-02-10T08:00:00Z',
        'latitude': 12.0,
        'longitude': 45.0,
      };

      final quake = Earthquake.fromEmsc(emscData);

      expect(quake.id, isNotEmpty);
      expect(quake.place, 'Some Region');
      expect(quake.url, isNull);
      expect(quake.source, 'EMSC');
    });
  });

  group('Earthquake serialization', () {
    test('toJson serializes fields correctly', () {
      final quake = Earthquake(
        id: 'test123',
        magnitude: 4.5,
        place: 'Test Place',
        time: DateTime.utc(2024, 1, 5, 10, 0, 0),
        latitude: 1.23,
        longitude: 3.21,
        depth: 10.5,
        url: 'https://example.com',
        source: 'USGS',
        rawData: {'foo': 'bar'},
      );

      final json = quake.toJson();

      expect(json['id'], 'test123');
      expect(json['magnitude'], 4.5);
      expect(json['place'], 'Test Place');
      expect(json['time'], '2024-01-05T10:00:00.000Z');
      expect(json['latitude'], 1.23);
      expect(json['longitude'], 3.21);
      expect(json['depth'], 10.5);
      expect(json['url'], 'https://example.com');
      expect(json['source'], 'USGS');
      expect(json['rawData'], {'foo': 'bar'});
    });

    test('fromJson recreates Earthquake instance', () {
      final json = {
        'id': 'test456',
        'magnitude': 2.3,
        'place': 'Another Place',
        'time': '2024-03-01T00:00:00.000Z',
        'latitude': 9.87,
        'longitude': 6.54,
        'depth': null,
        'url': null,
        'source': 'EMSC',
        'rawData': {'baz': 1},
      };

      final quake = Earthquake.fromJson(json);

      expect(quake.id, 'test456');
      expect(quake.magnitude, 2.3);
      expect(quake.place, 'Another Place');
      expect(quake.time.toIso8601String(), '2024-03-01T00:00:00.000Z');
      expect(quake.latitude, 9.87);
      expect(quake.longitude, 6.54);
      expect(quake.depth, isNull);
      expect(quake.url, isNull);
      expect(quake.source, 'EMSC');
      expect(quake.rawData, {'baz': 1});
    });

    test('fromJson(toJson(quake)) is consistent', () {
      final original = Earthquake(
        id: 'roundtrip',
        magnitude: 7.0,
        place: 'Round Trip Place',
        time: DateTime.utc(2024, 4, 20, 5, 30),
        latitude: -10.0,
        longitude: 50.0,
        depth: 30.0,
        url: 'https://roundtrip.example',
        source: 'USGS',
        rawData: {'source': 'test'},
      );

      final copy = Earthquake.fromJson(original.toJson());

      expect(copy.id, original.id);
      expect(copy.magnitude, original.magnitude);
      expect(copy.place, original.place);
      expect(copy.time, original.time);
      expect(copy.latitude, original.latitude);
      expect(copy.longitude, original.longitude);
      expect(copy.depth, original.depth);
      expect(copy.url, original.url);
      expect(copy.source, original.source);
      expect(copy.rawData, original.rawData);
    });
  });
}
