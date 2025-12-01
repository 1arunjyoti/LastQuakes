import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:lastquake/services/location_service.dart';
import 'package:lastquake/widgets/components/location_button.dart';
import 'package:latlong2/latlong.dart';

class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator({
    required this.serviceEnabled,
    required this.permission,
    this.position,
  });

  bool serviceEnabled;
  LocationPermission permission;
  Position? position;
  bool throwOnGetPosition = false;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    if (throwOnGetPosition || position == null) {
      throw Exception('Location unavailable');
    }
    return position!;
  }

  // Unused, but must be implemented for abstract class.
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    return const Stream.empty();
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GeolocatorPlatform originalPlatform;

  setUp(() {
    originalPlatform = GeolocatorPlatform.instance;
    LocationService().clearCache();
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalPlatform;
    LocationService().clearCache();
  });

  Widget _wrapWithMap({
    required MapController controller,
    required Widget child,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: const MapOptions(
                initialCenter: LatLng(0, 0),
                initialZoom: 5,
              ),
              children: const [],
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('centers map and shows success when location is found', (tester) async {
    final fakeGeolocator = _FakeGeolocator(
      serviceEnabled: true,
      permission: LocationPermission.always,
      position: Position(
        latitude: 51.5,
        longitude: -0.09,
        accuracy: 5,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        timestamp: DateTime(2024, 1, 1),
        altitudeAccuracy: 0,
        headingAccuracy: 0,
        isMocked: false,
      ),
    );
    GeolocatorPlatform.instance = fakeGeolocator;

    final mapController = MapController();
    Position? callbackPosition;

    await tester.pumpWidget(
      _wrapWithMap(
        controller: mapController,
        child: LocationButton(
          mapController: mapController,
          zoomLevel: 10,
          onLocationFound: (position) => callbackPosition = position,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.my_location_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final exception = tester.takeException();
    expect(exception, isNull, reason: 'Unexpected exception: $exception');

    expect(mapController.camera.center, equals(const LatLng(51.5, -0.09)));
    expect(mapController.camera.zoom, equals(10));
    expect(callbackPosition, isNotNull);
    expect(callbackPosition!.latitude, equals(51.5));
    expect(find.text('Location found!'), findsOneWidget);
  });

  testWidgets('shows dialog when location services are disabled', (tester) async {
    final fakeGeolocator = _FakeGeolocator(
      serviceEnabled: false,
      permission: LocationPermission.denied,
    );
    GeolocatorPlatform.instance = fakeGeolocator;

    final mapController = MapController();
    var errorCalled = false;

    await tester.pumpWidget(
      _wrapWithMap(
        controller: mapController,
        child: LocationButton(
          mapController: mapController,
          zoomLevel: 8,
          onLocationError: () => errorCalled = true,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.my_location_outlined));
    await tester.pumpAndSettle();

    final exception = tester.takeException();
    expect(exception, isNull, reason: 'Unexpected exception: $exception');

    expect(find.text('Location Services Disabled'), findsOneWidget);
    expect(errorCalled, isFalse);
  });
}
