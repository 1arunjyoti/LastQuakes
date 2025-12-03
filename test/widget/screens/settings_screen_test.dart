import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquakes/domain/models/notification_settings_model.dart';
import 'package:lastquakes/presentation/providers/settings_provider.dart';
import 'package:lastquakes/provider/theme_provider.dart';
import 'package:lastquakes/screens/settings_screen.dart';
import 'package:lastquakes/utils/enums.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSettingsProvider extends Mock implements SettingsProvider {}

class MockThemeProvider extends Mock implements ThemeProvider {}

void main() {
  late MockSettingsProvider mockSettingsProvider;
  late MockThemeProvider mockThemeProvider;

  setUp(() {
    mockSettingsProvider = MockSettingsProvider();
    mockThemeProvider = MockThemeProvider();

    // Stub SettingsProvider
    when(() => mockSettingsProvider.isLoading).thenReturn(false);
    when(() => mockSettingsProvider.error).thenReturn(null);
    when(() => mockSettingsProvider.settings).thenReturn(
      const NotificationSettingsModel(
        filterType: NotificationFilterType.none,
        magnitude: 3.0,
        country: 'All',
        radius: 100.0,
        useCurrentLocation: false,
        safeZones: [],
      ),
    );
    when(
      () => mockSettingsProvider.selectedDataSources,
    ).thenReturn({DataSource.usgs});
    when(
      () => mockSettingsProvider.updateDataSources(any()),
    ).thenAnswer((_) async {});

    // Stub ThemeProvider
    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.system);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: mockSettingsProvider,
          ),
          ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
        ],
        child: MaterialApp(home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders settings cards', (WidgetTester tester) async {
    await pumpScreen(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Notification Settings'), findsOneWidget);
    expect(find.text('Data Sources'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
  });

  testWidgets('expands data sources card', (WidgetTester tester) async {
    await pumpScreen(tester);

    // Initial state: collapsed (assuming default is collapsed)
    // Actually _dataSourcesExpanded = false by default in code.

    // Tap to expand
    await tester.tap(find.text('Data Sources'));
    await tester.pumpAndSettle();

    expect(find.text('Select earthquake data sources:'), findsOneWidget);
    expect(find.text('USGS (United States Geological Survey)'), findsOneWidget);
  });

  testWidgets('toggles data source', (WidgetTester tester) async {
    await pumpScreen(tester);

    // Expand first
    await tester.tap(find.text('Data Sources'));
    await tester.pumpAndSettle();

    // Tap EMSC checkbox
    await tester.tap(
      find.text('EMSC (European-Mediterranean Seismological Centre)'),
    );
    await tester.pumpAndSettle();

    // Verify updateDataSources called
    verify(() => mockSettingsProvider.updateDataSources(any())).called(1);
  });
}
