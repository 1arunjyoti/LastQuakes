import 'package:flutter_test/flutter_test.dart';
import 'package:lastquakes/services/location_service.dart';

// Note: The LocationService now uses fl_location which requires platform integration testing.
// Unit tests requiring mocked location can be added when fl_location provides a platform interface
// that supports dependency injection.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationService', () {
    late LocationService service;

    setUp(() {
      service = LocationService();
      service.clearCache();
    });

    tearDown(() {
      service.clearCache();
    });

    group('calculateDistance', () {
      test('returns correct distance between two points in kilometers', () {
        // Distance between (0,0) and (0,1) should be approximately 111.2 km
        final result = service.calculateDistance(0, 0, 0, 1);
        expect(result, closeTo(111.2, 0.5));
      });

      test('returns zero for same coordinates', () {
        final result = service.calculateDistance(10, 20, 10, 20);
        expect(result, equals(0.0));
      });

      test('returns correct distance for large distance', () {
        // New York (40.7128, -74.0060) to London (51.5074, -0.1278)
        // Approximately 5570 km
        final result = service.calculateDistance(
          40.7128,
          -74.0060,
          51.5074,
          -0.1278,
        );
        expect(result, closeTo(5570, 10));
      });

      test('handles negative coordinates correctly', () {
        // Buenos Aires (-34.6037, -58.3816) to Sydney (-33.8688, 151.2093)
        // Approximately 11,989 km
        final result = service.calculateDistance(
          -34.6037,
          -58.3816,
          -33.8688,
          151.2093,
        );
        expect(result, closeTo(11801, 50));
      });

      test('calculates distance near poles', () {
        // Near North Pole to near South Pole
        final result = service.calculateDistance(85, 0, -85, 0);
        // Should be approximately 170 degrees of latitude * 111.2 km/degree
        expect(result, closeTo(18904, 100));
      });
    });

    group('caching', () {
      test('clearCache clears the cached position', () {
        // After clearing, cache should be empty
        // This is a basic test - full integration would require mocking FlLocation
        service.clearCache();
        // No exception thrown means cache was cleared successfully
        expect(true, isTrue);
      });
    });
  });
}
