import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:lastquake/widgets/components/map_layers_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  testWidgets('selecting map type calls callback and persists preference', (tester) async {
    MapLayerType? selectedType;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MapLayersButton(
              selectedMapType: MapLayerType.osm,
              showFaultLines: false,
              isLoadingFaultLines: false,
              onMapTypeChanged: (type) => selectedType = type,
              onFaultLinesToggled: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.layers_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Satellite'));
    await tester.pumpAndSettle();

    expect(selectedType, MapLayerType.satellite);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('map_layer_type_preference_v2'), 'satellite');
  });

  testWidgets('toggling fault lines calls callback with updated value', (tester) async {
    bool? toggledValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MapLayersButton(
              selectedMapType: MapLayerType.osm,
              showFaultLines: false,
              isLoadingFaultLines: false,
              onMapTypeChanged: (_) {},
              onFaultLinesToggled: (value) => toggledValue = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.layers_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fault Lines'));
    await tester.pump();

    expect(toggledValue, isTrue);
  });
}
