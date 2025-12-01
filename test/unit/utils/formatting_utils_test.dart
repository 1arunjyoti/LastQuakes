import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lastquake/provider/theme_provider.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:lastquake/utils/formatting.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<T> _withFormattingContext<T>({
  required WidgetTester tester,
  required ThemeProvider provider,
  required T Function(BuildContext context) callback,
}) async {
  late T result;

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            result = callback(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  await tester.pump();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'en_US';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FormattingUtils.formatDistance', () {
    testWidgets('returns kilometers when the preference is km', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final provider = ThemeProvider(prefs: prefs);

      final result = await _withFormattingContext(
        tester: tester,
        provider: provider,
        callback: (context) => FormattingUtils.formatDistance(context, 12),
      );

      expect(result, '12 km');
    });

    testWidgets('converts kilometers to miles when the preference is miles', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final provider = ThemeProvider(prefs: prefs)..setDistanceUnit(DistanceUnit.miles);

      final result = await _withFormattingContext(
        tester: tester,
        provider: provider,
        callback: (context) => FormattingUtils.formatDistance(context, 10),
      );

      expect(result, '6.2 mi');
    });
  });

  group('FormattingUtils.formatDateTime', () {
    testWidgets('uses 24-hour format when enabled', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final provider = ThemeProvider(prefs: prefs)..setUse24HourClock(true);

      final dateTime = DateTime(2024, 1, 5, 14, 30);

      final result = await _withFormattingContext(
        tester: tester,
        provider: provider,
        callback: (context) => FormattingUtils.formatDateTime(context, dateTime),
      );

      expect(result, 'Jan 5, 2024, 14:30');
    });

    testWidgets('uses 12-hour format when disabled', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final provider = ThemeProvider(prefs: prefs);

      final dateTime = DateTime(2024, 1, 5, 14, 30);

      final result = await _withFormattingContext(
        tester: tester,
        provider: provider,
        callback: (context) => FormattingUtils.formatDateTime(context, dateTime),
      );

      expect(result, 'Jan 5, 2024, 2:30 PM');
    });
  });

  group('FormattingUtils.formatTimeOnly', () {
    testWidgets('uses 24-hour format when enabled', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final provider = ThemeProvider(prefs: prefs)..setUse24HourClock(true);

      final dateTime = DateTime(2024, 1, 5, 5, 7);

      final result = await _withFormattingContext(
        tester: tester,
        provider: provider,
        callback: (context) => FormattingUtils.formatTimeOnly(context, dateTime),
      );

      expect(result, '05:07');
    });

    testWidgets('uses 12-hour format when disabled', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final provider = ThemeProvider(prefs: prefs);

      final dateTime = DateTime(2024, 1, 5, 17, 45);

      final result = await _withFormattingContext(
        tester: tester,
        provider: provider,
        callback: (context) => FormattingUtils.formatTimeOnly(context, dateTime),
      );

      expect(result, '5:45\u202fPM');
    });
  });

  group('FormattingUtils.formatPlaceString', () {
    testWidgets('converts distance prefix to miles when preference is miles', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final provider = ThemeProvider(prefs: prefs)..setDistanceUnit(DistanceUnit.miles);

      final result = await _withFormattingContext(
        tester: tester,
        provider: provider,
        callback: (context) => FormattingUtils.formatPlaceString(
          context,
          '10 km NW of Rome',
        ),
      );

      expect(result, '6.2 mi NW of Rome');
    });

    testWidgets('returns the original string when no conversion is needed', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final provider = ThemeProvider(prefs: prefs)..setDistanceUnit(DistanceUnit.miles);

      final result = await _withFormattingContext(
        tester: tester,
        provider: provider,
        callback: (context) => FormattingUtils.formatPlaceString(
          context,
          'Downtown Los Angeles',
        ),
      );

      expect(result, 'Downtown Los Angeles');
    });
  });
}
