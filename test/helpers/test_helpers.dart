import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/models/safe_zone.dart';

/// Shared test helpers and mock data generators for unit tests
class TestHelpers {
  /// Generate a mock USGS earthquake with customizable properties
  static Map<String, dynamic> createMockUsgsData({
    String id = 'test_usgs_001',
    double magnitude = 5.0,
    String place = 'Test Location',
    int timeMillis = 1700000000000,
    double latitude = 35.0,
    double longitude = -120.0,
    double? depth = 10.0,
    String? url,
  }) {
    return {
      'id': id,
      'properties': {
        'mag': magnitude,
        'place': place,
        'time': timeMillis,
        'url': url ?? 'https://earthquake.usgs.gov/earthquakes/eventpage/$id',
        'tsunami': 0,
      },
      'geometry': {
        'coordinates': [longitude, latitude, if (depth != null) depth],
      },
    };
  }

  /// Generate a mock EMSC earthquake with customizable properties
  static Map<String, dynamic> createMockEmscData({
    String id = 'test_emsc_001',
    double magnitude = 5.0,
    String region = 'Test Region',
    String time = '2024-01-01T00:00:00Z',
    double latitude = 35.0,
    double longitude = -120.0,
    double? depth = 10.0,
  }) {
    return {
      'unid': id,
      'mag': magnitude,
      'flynn_region': region,
      'time': time,
      'lat': latitude,
      'lon': longitude,
      if (depth != null) 'depth': depth,
      'source_catalog': 'EMSC',
    };
  }

  /// Generate a list of mock USGS features for API responses
  static Map<String, dynamic> createMockUsgsResponse({
    int count = 10,
    double minMagnitude = 3.0,
    double maxMagnitude = 7.0,
  }) {
    final features = List.generate(count, (index) {
      final magnitude =
          minMagnitude + (maxMagnitude - minMagnitude) * (index / count);
      return createMockUsgsData(
        id: 'usgs_${index.toString().padLeft(3, '0')}',
        magnitude: magnitude,
        place: 'Location $index',
        timeMillis: 1700000000000 + (index * 3600000),
        latitude: 35.0 + (index * 0.5),
        longitude: -120.0 + (index * 0.5),
      );
    });

    return {
      'type': 'FeatureCollection',
      'metadata': {
        'generated': DateTime.now().millisecondsSinceEpoch,
        'count': count,
      },
      'features': features,
    };
  }

  /// Create a mock Earthquake instance
  static Earthquake createMockEarthquake({
    String id = 'test_001',
    double magnitude = 5.0,
    String place = 'Test Location',
    DateTime? time,
    double latitude = 35.0,
    double longitude = -120.0,
    double? depth = 10.0,
    String source = 'USGS',
  }) {
    return Earthquake(
      id: id,
      magnitude: magnitude,
      place: place,
      time: time ?? DateTime(2024, 1, 1),
      latitude: latitude,
      longitude: longitude,
      depth: depth,
      url: 'https://example.com/$id',
      tsunami: 0,
      source: source,
      rawData: {},
    );
  }

  /// Create a list of mock earthquakes
  static List<Earthquake> createMockEarthquakes({
    int count = 10,
    double minMagnitude = 3.0,
    double maxMagnitude = 7.0,
  }) {
    return List.generate(count, (index) {
      final magnitude =
          minMagnitude + (maxMagnitude - minMagnitude) * (index / count);
      return createMockEarthquake(
        id: 'test_${index.toString().padLeft(3, '0')}',
        magnitude: magnitude,
        place: 'Location $index',
        time: DateTime(2024, 1, 1).add(Duration(hours: index)),
        latitude: 35.0 + (index * 0.5),
        longitude: -120.0 + (index * 0.5),
      );
    });
  }

  /// Create a mock SafeZone instance
  static SafeZone createMockSafeZone({
    String name = 'Test Safe Zone',
    double latitude = 35.0,
    double longitude = -120.0,
  }) {
    return SafeZone(name: name, latitude: latitude, longitude: longitude);
  }

  /// Create a list of mock safe zones
  static List<SafeZone> createMockSafeZones({int count = 3}) {
    return List.generate(count, (index) {
      return createMockSafeZone(
        name: 'Safe Zone $index',
        latitude: 35.0 + (index * 0.1),
        longitude: -120.0 + (index * 0.1),
      );
    });
  }

  /// Create a mock DateTime for consistent testing
  static DateTime createMockDateTime({
    int year = 2024,
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
  }) {
    return DateTime(year, month, day, hour, minute);
  }

  /// Generate a timestamp N days ago
  static DateTime daysAgo(int days) {
    return DateTime.now().subtract(Duration(days: days));
  }

  /// Generate a timestamp N hours ago
  static DateTime hoursAgo(int hours) {
    return DateTime.now().subtract(Duration(hours: hours));
  }

  /// Generate a timestamp N minutes ago
  static DateTime minutesAgo(int minutes) {
    return DateTime.now().subtract(Duration(minutes: minutes));
  }
}
