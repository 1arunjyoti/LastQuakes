import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    switch (_themeMode) {
      case ThemeMode.light:
        _themeMode = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        _themeMode = ThemeMode.light;
        break;
      case ThemeMode.system:
        _themeMode =
            MediaQueryData.fromWindow(
                      WidgetsBinding.instance.window,
                    ).platformBrightnessValue ==
                    Brightness.dark
                ? ThemeMode.light
                : ThemeMode.dark;
        break;
    }
    _saveThemePreference();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveThemePreference();
    notifyListeners();
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', _themeMode.index);
  }

  Future<void> loadThemeFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getInt('theme_mode');

    if (savedTheme != null) {
      _themeMode = ThemeMode.values[savedTheme];
      notifyListeners();
    }
  }
}

// Extension to get Brightness from MediaQuery
extension on MediaQueryData {
  Brightness get platformBrightnessValue {
    return platformBrightness;
  }
}
