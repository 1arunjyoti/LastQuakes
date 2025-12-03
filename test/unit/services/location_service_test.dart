import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:lastquakes/services/location_service.dart';

class _FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled;
  LocationPermission permission;
  Position? currentPosition;
  bool shouldThrow = false;
  bool shouldTimeout = false;
  int callCount = 0;

  _FakeGeolocator({
    required this.serviceEnabled,
    required this.permission,
    this.currentPosition,
  });

  Position? lastKnownPosition;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    callCount++;
    if (shouldTimeout && callCount == 1) {
      throw TimeoutException('Mock timeout');
    }
    if (shouldThrow || currentPosition == null) {
      throw Exception('Location unavailable');
    }
    return currentPosition!;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    return lastKnownPosition;
  }

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(endLatitude - startLatitude);
    final dLon = _degToRad(endLongitude - startLongitude);

    final a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_degToRad(startLatitude)) *
            math.cos(_degToRad(endLatitude)) *
            (math.sin(dLon / 2) * math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c * 1000;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationService', () {
    late LocationService service;
    late _FakeGeolocator fakeGeolocator;
    late GeolocatorPlatform originalInstance;

    setUp(() {
      originalInstance = GeolocatorPlatform.instance;
      service = LocationService();
      service.clearCache();
      fakeGeolocator = _FakeGeolocator(
        serviceEnabled: true,
        permission: LocationPermission.always,
        currentPosition: Position(
          latitude: 12.34,
          longitude: 56.78,
          accuracy: 5,
          altitude: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          timestamp: DateTime(2024, 1, 1),
          isMocked: false,
        ),
      );
      GeolocatorPlatform.instance = fakeGeolocator;
    });

    tearDown(() {
      GeolocatorPlatform.instance = originalInstance;
      service.clearCache();
    });

    test('returns cached position when cache is valid', () async {
      final first = await service.getCurrentLocation();
      expect(first, isNotNull);

      fakeGeolocator.currentPosition = Position(
        latitude: 0,
        longitude: 0,
        accuracy: 5,
        altitude: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        timestamp: DateTime(2024, 1, 1, 12),
        isMocked: false,
      );

      final cached = await service.getCurrentLocation();

      expect(cached, same(first));
    });

    test('returns new position when forceRefresh is true', () async {
      final first = await service.getCurrentLocation();
      expect(first, isNotNull);

      final newPosition = Position(
        latitude: -1,
        longitude: -1,
        accuracy: 5,
        altitude: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        timestamp: DateTime(2024, 1, 2),
        isMocked: false,
      );
      fakeGeolocator.currentPosition = newPosition;

      final refreshed = await service.getCurrentLocation(forceRefresh: true);

      expect(refreshed, isNotNull);
      expect(refreshed!.latitude, newPosition.latitude);
      expect(refreshed.longitude, newPosition.longitude);
    });

    test('returns null when permission is denied', () async {
      fakeGeolocator.permission = LocationPermission.denied;

      final result = await service.getCurrentLocation();

      expect(result, isNull);
    });

    test(
      'returns null when fetching throws and no last known position',
      () async {
        fakeGeolocator.shouldThrow = true;

        final result = await service.getCurrentLocation(forceRefresh: true);

        expect(result, isNull);
      },
    );

    test('returns last known position when fetching throws', () async {
      fakeGeolocator.shouldThrow = true;
      final lastKnown = Position(
        latitude: 20,
        longitude: 30,
        accuracy: 5,
        altitude: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        timestamp: DateTime(2024, 1, 1),
        isMocked: false,
      );
      fakeGeolocator.lastKnownPosition = lastKnown;

      final result = await service.getCurrentLocation(forceRefresh: true);

      expect(result, isNotNull);
      expect(result!.latitude, 20);
      expect(result.longitude, 30);
    });

    test(
      'retries with low accuracy on timeout if no last known position',
      () async {
        fakeGeolocator.shouldTimeout = true;

        final result = await service.getCurrentLocation(forceRefresh: true);

        expect(result, isNotNull);
        expect(fakeGeolocator.callCount, 2); // Should be called twice
      },
    );

    test('calculateDistance returns value in kilometers', () {
      final result = service.calculateDistance(0, 0, 0, 1);

      expect(result, closeTo(111.2, 0.5));
    });
  });
}
