import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:lastquakes/models/earthquake.dart';

/// Service for managing Android home screen widget data.
///
/// This service handles:
/// - Serializing earthquake data for the native widget
/// - Triggering widget updates without blocking the main app
/// - Background refresh handling
class HomeWidgetService {
  static const String _widgetName = 'EarthquakeWidget';
  static const String _androidWidgetName = 'EarthquakeWidget';
  static const String _earthquakeDataKey = 'earthquake_data';
  static const String _lastUpdateKey = 'last_update';

  // Singleton pattern for efficient resource usage
  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  // Debounce timer to prevent rapid updates
  Timer? _updateDebounce;
  static const Duration _debounceDelay = Duration(milliseconds: 500);

  /// Initialize the home widget service.
  /// Called once during app startup.
  Future<void> initialize() async {
    try {
      // Set the app group for shared data (Android uses SharedPreferences)
      await HomeWidget.setAppGroupId('app.lastquakes');

      // Register callback for widget interactions
      HomeWidget.registerInteractivityCallback(backgroundCallback);

      debugPrint('HomeWidgetService: Initialized');
    } catch (e) {
      debugPrint('HomeWidgetService: Failed to initialize: $e');
    }
  }

  /// Update widget with new earthquake data.
  /// Uses debouncing to prevent excessive updates.
  void updateWidgetData(List<Earthquake> earthquakes) {
    // Cancel any pending update
    _updateDebounce?.cancel();

    // Debounce to prevent rapid consecutive updates
    _updateDebounce = Timer(_debounceDelay, () {
      _performUpdate(earthquakes);
    });
  }

  /// Perform the actual widget update (runs in background isolate-safe manner)
  Future<void> _performUpdate(List<Earthquake> earthquakes) async {
    try {
      // Filter to only earthquakes from the last 24 hours (all of them for scrollable list)
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(hours: 24));

      final last24HourQuakes =
          earthquakes
              .where((e) => e.time.isAfter(cutoffTime))
              .map((e) => _serializeEarthquake(e))
              .toList();

      // Store serialized data for the native widget
      final jsonData = jsonEncode(last24HourQuakes);
      await HomeWidget.saveWidgetData<String>(_earthquakeDataKey, jsonData);

      // Store last update timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await HomeWidget.saveWidgetData<int>(_lastUpdateKey, timestamp);

      // Request widget update
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _androidWidgetName,
        qualifiedAndroidName: 'app.lastquakes.$_androidWidgetName',
      );

      debugPrint(
        'HomeWidgetService: Updated widget with ${last24HourQuakes.length} earthquakes (last 24h)',
      );
    } catch (e) {
      debugPrint('HomeWidgetService: Failed to update widget: $e');
    }
  }

  /// Force immediate widget update (bypasses debounce).
  /// Use sparingly - only for user-triggered refresh.
  Future<void> forceUpdate(List<Earthquake> earthquakes) async {
    _updateDebounce?.cancel();
    await _performUpdate(earthquakes);
  }

  /// Serialize an Earthquake to a lightweight map for the widget.
  /// Only includes fields needed for display.
  Map<String, dynamic> _serializeEarthquake(Earthquake earthquake) {
    return {
      'id': earthquake.id,
      'magnitude': earthquake.magnitude,
      'place': _truncatePlace(earthquake.place),
      'time': earthquake.time.millisecondsSinceEpoch,
      'depth': earthquake.depth ?? 0.0,
      'tsunami': earthquake.tsunami ?? 0,
    };
  }

  /// Truncate place string for widget display.
  /// Keeps location concise for limited widget space.
  String _truncatePlace(String place) {
    if (place.length <= 30) return place;

    // Try to find a natural break point
    final commaIndex = place.indexOf(',');
    if (commaIndex > 0 && commaIndex <= 30) {
      return place.substring(0, commaIndex);
    }

    // Otherwise, just truncate
    return '${place.substring(0, 27)}...';
  }

  /// Clear widget data (e.g., when user logs out or clears cache).
  Future<void> clearWidgetData() async {
    try {
      await HomeWidget.saveWidgetData<String>(_earthquakeDataKey, '[]');
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _androidWidgetName,
        qualifiedAndroidName: 'app.lastquakes.$_androidWidgetName',
      );
      debugPrint('HomeWidgetService: Cleared widget data');
    } catch (e) {
      debugPrint('HomeWidgetService: Failed to clear widget: $e');
    }
  }

  /// Dispose resources.
  void dispose() {
    _updateDebounce?.cancel();
  }
}

/// Background callback for widget interactions.
/// This runs when user taps refresh button on the widget.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri == null) return;

  debugPrint('HomeWidgetService: Background callback: ${uri.host}');

  if (uri.host == 'refresh') {
    // The widget requested a refresh
    // This will be handled by the native code triggering app data reload
    // We just need to acknowledge the request
    await HomeWidget.saveWidgetData<bool>('refresh_requested', true);
  } else if (uri.host == 'open_app') {
    // Open the app - this is handled automatically by the widget's PendingIntent
  }
}
