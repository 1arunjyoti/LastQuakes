import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquake/provider/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpWithProviders(
  WidgetTester tester,
  Widget child, {
  Map<String, Object> initialPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(prefs: prefs)..loadPreferences(),
      child: Builder(
        builder: (context) {
          return MaterialApp(
            themeMode: context.watch<ThemeProvider>().themeMode,
            theme: ThemeData.light(useMaterial3: false),
            darkTheme: ThemeData.dark(useMaterial3: false),
            home: child,
          );
        },
      ),
    ),
  );

  await tester.pumpAndSettle();
}
