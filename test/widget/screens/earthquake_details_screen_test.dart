import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/provider/theme_provider.dart';
import 'package:lastquakes/screens/earthquake_details.dart';
import 'package:lastquakes/utils/enums.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock classes
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class MockThemeProvider extends Mock implements ThemeProvider {}

void main() {
  late MockNavigatorObserver mockObserver;
  late MockThemeProvider mockThemeProvider;

  setUp(() {
    mockObserver = MockNavigatorObserver();
    mockThemeProvider = MockThemeProvider();
    SharedPreferences.setMockInitialValues({});

    // Stub ThemeProvider
    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.system);
    when(() => mockThemeProvider.distanceUnit).thenReturn(DistanceUnit.km);
    when(() => mockThemeProvider.use24HourClock).thenReturn(false);
  });

  Future<void> pumpScreen(WidgetTester tester, Earthquake earthquake) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
        ],
        child: MaterialApp(
          home: EarthquakeDetailsScreen(earthquake: earthquake),
          navigatorObservers: [mockObserver],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders earthquake details', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final earthquake = Earthquake(
      id: '1',
      place: 'Test Place',
      time: DateTime.now(),
      magnitude: 5.5,
      latitude: 10.0,
      longitude: 20.0,
      depth: 10.0,
      url: 'https://example.com',
      source: 'USGS',
      rawData: {},
    );

    await pumpScreen(tester, earthquake);

    expect(find.text('Test Place'), findsOneWidget);
    expect(find.text('5.5'), findsOneWidget);
    expect(find.text('MAGNITUDE'), findsOneWidget);
    expect(find.text('Depth'), findsOneWidget);
    // Verify depth text exists (format may vary)
    expect(find.textContaining('km'), findsWidgets);
    expect(find.text('Coordinates'), findsOneWidget);
  });

  testWidgets('renders map widget', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final earthquake = Earthquake(
      id: '1',
      place: 'Test Place',
      time: DateTime.now(),
      magnitude: 5.5,
      latitude: 10.0,
      longitude: 20.0,
      depth: 10.0,
      url: 'https://example.com',
      source: 'USGS',
      rawData: {},
    );

    await pumpScreen(tester, earthquake);

    expect(find.byType(FlutterMap), findsOneWidget);
  });
}
