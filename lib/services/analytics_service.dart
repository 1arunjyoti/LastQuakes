import 'package:flutter/widgets.dart';

/// Abstract interface for analytics and crash reporting.
abstract class AnalyticsService {
  /// Singleton instance accessor - to be set by main.dart based on flavor
  static late AnalyticsService instance;

  bool get isInitialized;
  NavigatorObserver get observer;

  Future<void> initialize();

  Future<void> logScreenView(String screenName, {String? screenClass});

  Future<void> logEarthquakeListView({
    required int earthquakeCount,
    required String filterType,
    double? minMagnitude,
  });

  Future<void> logEarthquakeDetailView({
    required String earthquakeId,
    required double magnitude,
    required String location,
    String? source,
  });

  Future<void> logMapInteraction({
    required String action,
    double? latitude,
    double? longitude,
    int? markerCount,
  });

  Future<void> logDataRefresh({
    required String source,
    required bool success,
    int? earthquakeCount,
    int? loadTimeMs,
  });

  Future<void> logNotificationPermission({required bool granted});

  Future<void> logNotificationSettingsChange({
    required bool enabled,
    double? minMagnitude,
    int? radiusKm,
  });

  Future<void> logNotificationReceived({
    required String type,
    double? magnitude,
  });

  Future<void> logThemeChange({required String theme});

  Future<void> logFilterChange({
    required String filterName,
    required dynamic value,
  });

  Future<void> logShare({
    required String contentType,
    required String method,
    String? earthquakeId,
  });

  Future<void> logAppOpen();

  Future<void> logOnboardingComplete();

  Future<void> logLocationPermission({
    required bool granted,
    required String precisionLevel,
  });

  Future<void> logError({
    required dynamic error,
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
    Map<String, String>? additionalContext,
  });

  Future<void> logMessage(String message);

  Future<void> setUserProperty({required String name, required String? value});

  Future<void> setUserId(String? userId);

  Future<void> logApiCall({
    required String endpoint,
    required int responseTimeMs,
    required int statusCode,
    required bool success,
    String? errorMessage,
  });

  Future<void> logDataSourceSwitch({
    required String fromSource,
    required String toSource,
    required String reason,
  });
}
