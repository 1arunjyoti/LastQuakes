import 'package:flutter/material.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
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

  // --- Theme Methods
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _saveThemePreference();
      notifyListeners();
    }
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    // Store as String for robustness against enum order changes
    String themeString;
    switch (_themeMode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
      default:
        themeString = 'system';
        break;
    }
    await prefs.setString(_themePrefKey, themeString);
  }

  // --- Unit Methods ---
  void setDistanceUnit(DistanceUnit unit) {
    if (_distanceUnit != unit) {
      _distanceUnit = unit;
      _saveDistanceUnitPreference();
      notifyListeners();
    }
  }

  Future<void> _saveDistanceUnitPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_unitPrefKey, _distanceUnit.name);
  }

  // --- Clock Format Methods ---
  void setUse24HourClock(bool use24Hour) {
    if (_use24HourClock != use24Hour) {
      _use24HourClock = use24Hour;
      _saveClockPreference();
      notifyListeners();
    }
  }

  Future<void> _saveClockPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clockPrefKey, _use24HourClock);
  }

  // --- Load All Preferences ---
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

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
      default: // Default to system if null or invalid
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
    _use24HourClock =
        prefs.getBool(_clockPrefKey) ?? false; // Default false (12-hour)

    // Important: Notify listeners after loading all preferences
    notifyListeners();
  }
}
