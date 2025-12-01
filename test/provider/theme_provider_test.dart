import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquake/provider/theme_provider.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider', () {
    late SharedPreferences prefs;
    late ThemeProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      provider = ThemeProvider(prefs: prefs);
      provider.loadPreferences();
    });

    test('defaults to system theme and km distance unit when no preferences stored', () {
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.distanceUnit, DistanceUnit.km);
      expect(provider.use24HourClock, isFalse);
    });

    test('setThemeMode persists value and notifies listeners once', () async {
      int notificationCount = 0;
      provider.addListener(() {
        notificationCount++;
      });

      provider.setThemeMode(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);

      expect(provider.themeMode, ThemeMode.dark);
      expect(prefs.getString('theme_mode_v2'), equals('dark'));
      expect(notificationCount, 1);

      // Setting the same value again should not notify listeners
      provider.setThemeMode(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      expect(notificationCount, 1);
    });

    test('setDistanceUnit persists value and notifies listeners', () async {
      int notificationCount = 0;
      provider.addListener(() {
        notificationCount++;
      });

      provider.setDistanceUnit(DistanceUnit.miles);
      await Future<void>.delayed(Duration.zero);

      expect(provider.distanceUnit, DistanceUnit.miles);
      expect(prefs.getString('distance_unit'), equals(DistanceUnit.miles.name));
      expect(notificationCount, 1);
    });

    test('setUse24HourClock persists preference and notifies listeners', () async {
      int notificationCount = 0;
      provider.addListener(() {
        notificationCount++;
      });

      provider.setUse24HourClock(true);
      await Future<void>.delayed(Duration.zero);

      expect(provider.use24HourClock, isTrue);
      expect(prefs.getBool('use_24_hour_clock'), isTrue);
      expect(notificationCount, 1);
    });

    test('loadPreferences reads stored values correctly', () async {
      await prefs.setString('theme_mode_v2', 'dark');
      await prefs.setString('distance_unit', DistanceUnit.miles.name);
      await prefs.setBool('use_24_hour_clock', true);

      provider = ThemeProvider(prefs: prefs);
      provider.loadPreferences();

      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.distanceUnit, DistanceUnit.miles);
      expect(provider.use24HourClock, isTrue);
    });
  });
}
