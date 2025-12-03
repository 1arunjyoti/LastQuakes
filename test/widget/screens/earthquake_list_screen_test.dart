import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/presentation/providers/earthquake_provider.dart';
import 'package:lastquakes/provider/theme_provider.dart';
import 'package:lastquakes/screens/earthquake_list.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockEarthquakeProvider extends Mock implements EarthquakeProvider {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class MockRoute extends Fake implements Route<dynamic> {}

void main() {
  late MockEarthquakeProvider mockProvider;
  late MockNavigatorObserver mockObserver;

  setUpAll(() {
    registerFallbackValue(MockRoute());
    registerFallbackValue(
      Earthquake(
        id: 'fallback',
        place: 'fallback',
        time: DateTime.now(),
        magnitude: 0,
        latitude: 0,
        longitude: 0,
        depth: 0,
        url: 'url',
        source: 'USGS',
        rawData: {},
      ),
    );
  });

  setUp(() {
    mockProvider = MockEarthquakeProvider();
    mockObserver = MockNavigatorObserver();

    // Default stubs
    when(() => mockProvider.isLoading).thenReturn(false);
    when(() => mockProvider.error).thenReturn(null);
    when(() => mockProvider.listEarthquakes).thenReturn([]);
    when(() => mockProvider.listVisibleEarthquakes).thenReturn([]);
    when(() => mockProvider.listIsLoadingMore).thenReturn(false);
    when(() => mockProvider.listHasMoreData).thenReturn(false);
    when(() => mockProvider.isLoadingLocation).thenReturn(false);
    when(() => mockProvider.listSelectedCountry).thenReturn("All");
    when(() => mockProvider.listSelectedMagnitude).thenReturn(3.0);
    when(() => mockProvider.countryList).thenReturn(["All"]);
    when(() => mockProvider.isListFiltering).thenReturn(false);
    when(() => mockProvider.getDistanceForQuake(any())).thenReturn(null);
    when(() => mockProvider.loadMoreList()).thenAnswer((_) async {});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EarthquakeProvider>.value(value: mockProvider),
          ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider(prefs: prefs)..loadPreferences(),
          ),
        ],
        child: MaterialApp(
          home: const EarthquakeListScreen(),
          navigatorObservers: [mockObserver],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders list of earthquakes', (WidgetTester tester) async {
    // Set a larger screen size to avoid overflows
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final earthquakes = [
      Earthquake(
        id: '1',
        place: 'Test Place 1',
        time: DateTime.now(),
        magnitude: 5.5,
        latitude: 0,
        longitude: 0,
        depth: 10,
        url: 'url',
        source: 'USGS',
        rawData: {},
      ),
      Earthquake(
        id: '2',
        place: 'Test Place 2',
        time: DateTime.now(),
        magnitude: 4.5,
        latitude: 0,
        longitude: 0,
        depth: 10,
        url: 'url',
        source: 'EMSC',
        rawData: {},
      ),
    ];

    when(() => mockProvider.listEarthquakes).thenReturn(earthquakes);
    when(() => mockProvider.listVisibleEarthquakes).thenReturn(earthquakes);

    await pumpScreen(tester);

    expect(find.text('Test Place 1'), findsOneWidget);
    expect(find.text('Test Place 2'), findsOneWidget);
    expect(find.text('5.5'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
  });

  testWidgets('renders empty state', (WidgetTester tester) async {
    when(() => mockProvider.listEarthquakes).thenReturn([]);
    when(() => mockProvider.listVisibleEarthquakes).thenReturn([]);

    await pumpScreen(tester);

    expect(
      find.text('No earthquakes found matching your criteria.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping an item navigates to details', (
    WidgetTester tester,
  ) async {
    // Set a larger screen size to avoid overflows
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final earthquake = Earthquake(
      id: '1',
      place: 'Test Place',
      time: DateTime.now(),
      magnitude: 5.5,
      latitude: 0,
      longitude: 0,
      depth: 10,
      url: 'url',
      source: 'USGS',
      rawData: {},
    );

    when(() => mockProvider.listEarthquakes).thenReturn([earthquake]);
    when(() => mockProvider.listVisibleEarthquakes).thenReturn([earthquake]);

    await pumpScreen(tester);

    await tester.tap(find.text('Test Place'));
    await tester.pumpAndSettle();

    verify(() => mockObserver.didPush(any(), any())).called(greaterThan(0));
  });
}
