import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:lastquake/widgets/components/zoom_controls.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
              alignment: Alignment.centerRight,
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

  testWidgets('zoom in increments zoom level within bounds', (tester) async {
    final controller = MapController();
    double? lastZoom;

    await tester.pumpWidget(
      _wrapWithMap(
        controller: controller,
        child: ZoomControls(
          mapController: controller,
          zoomLevel: 5,
          onZoomChanged: (value) => lastZoom = value,
          minZoom: 2,
          maxZoom: 6,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(lastZoom, equals(6));
    expect(controller.camera.zoom, equals(6));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(controller.camera.zoom, equals(6));
    expect(lastZoom, equals(6));
  });

  testWidgets('zoom out decrements zoom level within bounds', (tester) async {
    final controller = MapController();
    double? lastZoom;

    await tester.pumpWidget(
      _wrapWithMap(
        controller: controller,
        child: ZoomControls(
          mapController: controller,
          zoomLevel: 3,
          onZoomChanged: (value) => lastZoom = value,
          minZoom: 2,
          maxZoom: 6,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    expect(controller.camera.zoom, equals(2));
    expect(lastZoom, equals(2));

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    expect(controller.camera.zoom, equals(2));
    expect(lastZoom, equals(2));
  });
}
