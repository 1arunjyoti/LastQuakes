import 'package:flutter/widgets.dart';
import 'package:lastquakes/services/analytics_service.dart';

/// No-op implementation of AnalyticsService for FOSS builds.
class AnalyticsServiceNoop implements AnalyticsService {
  @override
  bool get isInitialized => true;

  @override
  NavigatorObserver get observer => NavigatorObserver();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logScreenView(String screenName, {String? screenClass}) async {}

  @override
  Future<void> logEarthquakeListView({
    required int earthquakeCount,
    required String filterType,
    double? minMagnitude,
  }) async {}

  @override
  Future<void> logEarthquakeDetailView({
    required String earthquakeId,
    required double magnitude,
    required String location,
    String? source,
  }) async {}

  @override
  Future<void> logMapInteraction({
    required String action,
    double? latitude,
    double? longitude,
    int? markerCount,
  }) async {}

  @override
  Future<void> logDataRefresh({
    required String source,
    required bool success,
    int? earthquakeCount,
    int? loadTimeMs,
  }) async {}

  @override
  Future<void> logNotificationPermission({required bool granted}) async {}

  @override
  Future<void> logNotificationSettingsChange({
    required bool enabled,
    double? minMagnitude,
    int? radiusKm,
  }) async {}

  @override
  Future<void> logNotificationReceived({
    required String type,
    double? magnitude,
  }) async {}

  @override
  Future<void> logThemeChange({required String theme}) async {}

  @override
  Future<void> logFilterChange({
    required String filterName,
    required dynamic value,
  }) async {}

  @override
  Future<void> logShare({
    required String contentType,
    required String method,
    String? earthquakeId,
  }) async {}

  @override
  Future<void> logAppOpen() async {}

  @override
  Future<void> logOnboardingComplete() async {}

  @override
  Future<void> logLocationPermission({
    required bool granted,
    required String precisionLevel,
  }) async {}

  @override
  Future<void> logError({
    required dynamic error,
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
    Map<String, String>? additionalContext,
  }) async {}

  @override
  Future<void> logMessage(String message) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> logApiCall({
    required String endpoint,
    required int responseTimeMs,
    required int statusCode,
    required bool success,
    String? errorMessage,
  }) async {}

  @override
  Future<void> logDataSourceSwitch({
    required String fromSource,
    required String toSource,
    required String reason,
  }) async {}
}
