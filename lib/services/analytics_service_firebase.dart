import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lastquakes/services/analytics_service.dart';
import 'package:lastquakes/utils/secure_logger.dart';

/// Firebase implementation of AnalyticsService
class AnalyticsServiceFirebase implements AnalyticsService {
  late final FirebaseAnalytics _analytics;
  late final FirebaseCrashlytics _crashlytics;
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  NavigatorObserver get observer =>
      _initialized
          ? FirebaseAnalyticsObserver(analytics: _analytics)
          : NavigatorObserver();

  @override
  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    try {
      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;

      // Enable crashlytics collection (can be toggled for GDPR compliance)
      await _crashlytics.setCrashlyticsCollectionEnabled(true);

      // Set up Flutter error handling for Crashlytics
      FlutterError.onError = (errorDetails) {
        _crashlytics.recordFlutterFatalError(errorDetails);
      };

      // Catch async errors that aren't handled by Flutter
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics.recordError(error, stack, fatal: true);
        return true;
      };

      _initialized = true;
      SecureLogger.success('Analytics and Crashlytics initialized');
    } catch (e) {
      SecureLogger.error('Failed to initialize analytics', e);
    }
  }

  @override
  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    if (!_initialized) return;
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      SecureLogger.error('Failed to log screen view: $screenName', e);
    }
  }

  @override
  Future<void> logEarthquakeListView({
    required int earthquakeCount,
    required String filterType,
    double? minMagnitude,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'earthquake_list_view',
        parameters: {
          'earthquake_count': earthquakeCount,
          'filter_type': filterType,
          if (minMagnitude != null) 'min_magnitude': minMagnitude,
        },
      );
    } catch (e) {
      SecureLogger.error('Failed to log earthquake list view', e);
    }
  }

  @override
  Future<void> logEarthquakeDetailView({
    required String earthquakeId,
    required double magnitude,
    required String location,
    String? source,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'earthquake_detail_view',
        parameters: {
          'earthquake_id': earthquakeId,
          'magnitude': magnitude,
          'location': _truncateForAnalytics(location),
          if (source != null) 'source': source,
        },
      );
    } catch (e) {
      SecureLogger.error('Failed to log earthquake detail view', e);
    }
  }

  @override
  Future<void> logMapInteraction({
    required String action,
    double? latitude,
    double? longitude,
    int? markerCount,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'map_interaction',
        parameters: {
          'action': action,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (markerCount != null) 'marker_count': markerCount,
        },
      );
    } catch (e) {
      SecureLogger.error('Failed to log map interaction', e);
    }
  }

  @override
  Future<void> logDataRefresh({
    required String source,
    required bool success,
    int? earthquakeCount,
    int? loadTimeMs,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'data_refresh',
        parameters: {
          'source': source,
          'success': success ? 1 : 0,
          if (earthquakeCount != null) 'earthquake_count': earthquakeCount,
          if (loadTimeMs != null) 'load_time_ms': loadTimeMs,
        },
      );
    } catch (e) {
      SecureLogger.error('Failed to log data refresh', e);
    }
  }

  @override
  Future<void> logNotificationPermission({required bool granted}) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'notification_permission',
        parameters: {'granted': granted ? 1 : 0},
      );
    } catch (e) {
      SecureLogger.error('Failed to log notification permission', e);
    }
  }

  @override
  Future<void> logNotificationSettingsChange({
    required bool enabled,
    double? minMagnitude,
    int? radiusKm,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'notification_settings_change',
        parameters: {
          'enabled': enabled ? 1 : 0,
          if (minMagnitude != null) 'min_magnitude': minMagnitude,
          if (radiusKm != null) 'radius_km': radiusKm,
        },
      );
    } catch (e) {
      SecureLogger.error('Failed to log notification settings change', e);
    }
  }

  @override
  Future<void> logNotificationReceived({
    required String type,
    double? magnitude,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'notification_received',
        parameters: {
          'type': type,
          if (magnitude != null) 'magnitude': magnitude,
        },
      );
    } catch (e) {
      SecureLogger.error('Failed to log notification received', e);
    }
  }

  @override
  Future<void> logThemeChange({required String theme}) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'theme_change',
        parameters: {'theme': theme},
      );
    } catch (e) {
      SecureLogger.error('Failed to log theme change', e);
    }
  }

  @override
  Future<void> logFilterChange({
    required String filterName,
    required dynamic value,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'filter_change',
        parameters: {'filter_name': filterName, 'value': value.toString()},
      );
    } catch (e) {
      SecureLogger.error('Failed to log filter change', e);
    }
  }

  @override
  Future<void> logShare({
    required String contentType,
    required String method,
    String? earthquakeId,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logShare(
        contentType: contentType,
        itemId: earthquakeId ?? 'unknown',
        method: method,
      );
    } catch (e) {
      SecureLogger.error('Failed to log share', e);
    }
  }

  @override
  Future<void> logAppOpen() async {
    if (!_initialized) return;
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      SecureLogger.error('Failed to log app open', e);
    }
  }

  @override
  Future<void> logOnboardingComplete() async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(name: 'onboarding_complete');
    } catch (e) {
      SecureLogger.error('Failed to log onboarding complete', e);
    }
  }

  @override
  Future<void> logLocationPermission({
    required bool granted,
    required String precisionLevel,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'location_permission',
        parameters: {
          'granted': granted ? 1 : 0,
          'precision_level': precisionLevel,
        },
      );
    } catch (e) {
      SecureLogger.error('Failed to log location permission', e);
    }
  }

  @override
  Future<void> logError({
    required dynamic error,
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
    Map<String, String>? additionalContext,
  }) async {
    if (!_initialized) return;
    try {
      if (additionalContext != null) {
        for (final entry in additionalContext.entries) {
          await _crashlytics.setCustomKey(entry.key, entry.value);
        }
      }
      if (reason != null) {
        await _crashlytics.setCustomKey('error_reason', reason);
      }
      await _crashlytics.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      SecureLogger.error('Failed to log error to Crashlytics', e);
    }
  }

  @override
  Future<void> logMessage(String message) async {
    if (!_initialized) return;
    try {
      await _crashlytics.log(message);
    } catch (e) {
      // Silently fail
    }
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      SecureLogger.error('Failed to set user property', e);
    }
  }

  @override
  Future<void> setUserId(String? userId) async {
    if (!_initialized) return;
    try {
      await _analytics.setUserId(id: userId);
      if (userId != null) {
        await _crashlytics.setUserIdentifier(userId);
      }
    } catch (e) {
      SecureLogger.error('Failed to set user ID', e);
    }
  }

  @override
  Future<void> logApiCall({
    required String endpoint,
    required int responseTimeMs,
    required int statusCode,
    required bool success,
    String? errorMessage,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'api_call',
        parameters: {
          'endpoint': _truncateForAnalytics(endpoint),
          'response_time_ms': responseTimeMs,
          'status_code': statusCode,
          'success': success ? 1 : 0,
          if (errorMessage != null)
            'error': _truncateForAnalytics(errorMessage),
        },
      );
    } catch (e) {
      SecureLogger.error('Failed to log API call', e);
    }
  }

  @override
  Future<void> logDataSourceSwitch({
    required String fromSource,
    required String toSource,
    required String reason,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'data_source_switch',
        parameters: {
          'from_source': fromSource,
          'to_source': toSource,
          'reason': reason,
        },
      );
    } catch (e) {
      SecureLogger.error('Failed to log data source switch', e);
    }
  }

  String _truncateForAnalytics(String value, {int maxLength = 100}) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 3)}...';
  }
}
