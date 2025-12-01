import 'package:flutter_test/flutter_test.dart';
import 'package:lastquake/models/safe_zone.dart';

void main() {
  group('SafeZone.fromJson', () {
    test('creates instance from json map', () {
      final json = {
        'name': 'Home',
        'latitude': 12.3456,
        'longitude': 65.4321,
      };

      final safeZone = SafeZone.fromJson(json);

      expect(safeZone.name, 'Home');
      expect(safeZone.latitude, 12.3456);
      expect(safeZone.longitude, 65.4321);
    });

    test('handles numeric values as int', () {
      final json = {
        'name': 'Office',
        'latitude': 15,
        'longitude': 80,
      };

      final safeZone = SafeZone.fromJson(json);

      expect(safeZone.latitude, 15.0);
      expect(safeZone.longitude, 80.0);
    });
  });

  group('SafeZone.toJson', () {
    test('serializes instance to map', () {
      const safeZone = SafeZone(
        name: 'Shelter',
        latitude: -10.25,
        longitude: 120.75,
      );

      final json = safeZone.toJson();

      expect(json, {
        'name': 'Shelter',
        'latitude': -10.25,
        'longitude': 120.75,
      });
    });

    test('roundtrip conversion maintains equality', () {
      const original = SafeZone(
        name: 'Park',
        latitude: 45.0,
        longitude: -90.0,
      );

      final reconstructed = SafeZone.fromJson(original.toJson());

      expect(reconstructed, original);
      expect(reconstructed.hashCode, original.hashCode);
    });
  });
}
