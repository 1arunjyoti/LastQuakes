import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lastquake/provider/theme_provider.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:lastquake/widgets/earthquake_list_item.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ThemeProvider themeProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    themeProvider = ThemeProvider(prefs: prefs)..loadPreferences();
  });

  Widget _buildTestApp(Widget child) {
    return ChangeNotifierProvider<ThemeProvider>.value(
      value: themeProvider,
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('displays magnitude, formatted distance, time, and source', (tester) async {
    const location = '100 km NW of Sample City';
    const distanceKm = 10.0;
    const magnitude = 5.4;
    final timestamp = DateTime.utc(2024, 1, 1, 12, 0);

    await tester.pumpWidget(
      _buildTestApp(
        EarthquakeListItem(
          location: location,
          magnitude: magnitude,
          magnitudeColor: Colors.red,
          onTap: () {},
          timestamp: timestamp,
          distanceKm: distanceKm,
          source: 'USGS',
        ),
      ),
    );

    await tester.pump();

    final expectedDistance = '10 km from your location';
    final expectedTime = DateFormat('MMM d, yyyy, h:mm a').format(timestamp);

    expect(find.text(expectedDistance), findsOneWidget);
    expect(find.text(location), findsOneWidget);
    expect(find.text(expectedTime), findsOneWidget);
    expect(find.text('5.4'), findsOneWidget);
    expect(find.text('USGS'), findsOneWidget);
  });

  testWidgets('shows fallback text when distance unavailable', (tester) async {
    const location = 'Unknown Region';

    await tester.pumpWidget(
      _buildTestApp(
        EarthquakeListItem(
          location: location,
          magnitude: 3.2,
          magnitudeColor: Colors.orange,
          onTap: () {},
          timestamp: DateTime.utc(2024, 1, 2, 6, 30),
          distanceKm: null,
          source: null,
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Enable location for distance'), findsOneWidget);
    expect(find.text(location), findsOneWidget);
  });

  testWidgets('invokes onTap callback', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      _buildTestApp(
        EarthquakeListItem(
          location: 'Tap City',
          magnitude: 4.0,
          magnitudeColor: Colors.blue,
          onTap: () {
            tapped = true;
          },
          timestamp: DateTime.utc(2024, 1, 3),
          distanceKm: 25,
          source: 'EMSC',
        ),
      ),
    );

    await tester.pump();

    await tester.tap(find.byType(EarthquakeListItem));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('respects distance unit preference for miles', (tester) async {
    themeProvider.setDistanceUnit(DistanceUnit.miles);
    const distanceKm = 8.0;

    await tester.pumpWidget(
      _buildTestApp(
        EarthquakeListItem(
          location: 'Miles City',
          magnitude: 4.8,
          magnitudeColor: Colors.purple,
          onTap: () {},
          timestamp: DateTime.utc(2024, 5, 1, 14),
          distanceKm: distanceKm,
          source: 'USGS',
        ),
      ),
    );

    await tester.pump();

    final expectedDistance = '5 mi from your location';
    expect(find.text(expectedDistance), findsOneWidget);
  });
}
