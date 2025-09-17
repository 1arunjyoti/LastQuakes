import 'package:flutter/material.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  // Make SharedPreferences instance available
  final SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  static const String _themePrefKey = 'theme_mode_v2';

  // --- Units ---
  DistanceUnit _distanceUnit = DistanceUnit.km;
  DistanceUnit get distanceUnit => _distanceUnit;
  static const String _unitPrefKey = 'distance_unit';

  // --- Clock Format ---
  bool _use24HourClock = false; // Default to 12-hour
  bool get use24HourClock => _use24HourClock;
  static const String _clockPrefKey = 'use_24_hour_clock';

  // Constructor accepts SharedPreferences instance
  ThemeProvider({SharedPreferences? prefs}) : _prefs = prefs;

  // --- Methods for saving preferences (use the instance variable) ---

  Future<void> _saveThemePreference() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    String themeString;
    switch (_themeMode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
        themeString = 'system';
        break;
    }
    await prefs.setString(_themePrefKey, themeString);
  }

  Future<void> _saveDistanceUnitPreference() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_unitPrefKey, _distanceUnit.name);
  }

  Future<void> _saveClockPreference() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(_clockPrefKey, _use24HourClock);
  }

  // --- Methods for setting values (trigger save and notify) ---

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _saveThemePreference();
      notifyListeners();
    }
  }

  void setDistanceUnit(DistanceUnit unit) {
    if (_distanceUnit != unit) {
      _distanceUnit = unit;
      _saveDistanceUnitPreference();
      notifyListeners();
    }
  }

  void setUse24HourClock(bool use24Hour) {
    if (_use24HourClock != use24Hour) {
      _use24HourClock = use24Hour;
      _saveClockPreference();
      notifyListeners();
    }
  }

  // --- Load Preferences (use the instance variable) ---

  void loadPreferences() {
    if (_prefs == null) {
      debugPrint(
        "Warning: ThemeProvider created without SharedPreferences instance. Cannot load preferences.",
      );
      return;
    }
    final prefs = _prefs;

    // Load Theme
    final savedThemeString = prefs.getString(_themePrefKey);
    switch (savedThemeString) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      case 'system':
      default:
        _themeMode = ThemeMode.system;
        break;
    }

    // Load Distance Unit
    final savedUnitString = prefs.getString(_unitPrefKey);
    if (savedUnitString == DistanceUnit.miles.name) {
      _distanceUnit = DistanceUnit.miles;
    } else {
      _distanceUnit = DistanceUnit.km; // Default to km
    }

    // Load Clock Format
    _use24HourClock = prefs.getBool(_clockPrefKey) ?? false;

    // No need to notify listeners here if loadPreferences is called
    // immediately after construction, as the initial build will use these values.
    // If called later, uncomment the line below.
    // notifyListeners();
  }
}
