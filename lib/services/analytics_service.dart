import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:lastquakes/utils/secure_logger.dart';

/// Centralized analytics and crash reporting service for monitoring app usage and failures.
/// 
/// This service provides:
/// - Firebase Analytics for tracking user events and screen views
/// - Firebase Crashlytics for crash reporting and error tracking
/// - Custom event logging for earthquake-specific features
class AnalyticsService {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();
  
  late final FirebaseAnalytics _analytics;
  late final FirebaseCrashlytics _crashlytics;
  bool _initialized = false;
  
  AnalyticsService._();
  
  /// Initialize analytics and crashlytics services
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
  
  // ==================== Screen Tracking ====================
  
  /// Log a screen view event
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
  
  // ==================== Earthquake Events ====================
  
  /// Log when user views earthquake list
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
  
  /// Log when user views earthquake details
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
  
  /// Log when user interacts with earthquake map
  Future<void> logMapInteraction({
    required String action, // 'zoom', 'pan', 'marker_tap', 'cluster_tap'
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
  
  /// Log earthquake data refresh
  Future<void> logDataRefresh({
    required String source, // 'auto', 'manual', 'pull_to_refresh'
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
  
  // ==================== Notification Events ====================
  
  /// Log notification permission request result
  Future<void> logNotificationPermission({
    required bool granted,
  }) async {
    if (!_initialized) return;
    
    try {
      await _analytics.logEvent(
        name: 'notification_permission',
        parameters: {
          'granted': granted ? 1 : 0,
        },
      );
    } catch (e) {
      SecureLogger.error('Failed to log notification permission', e);
    }
  }
  
  /// Log when user changes notification settings
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
          'enabled': enabled ? 1 : 0, // Firebase Analytics requires string or number
          if (minMagnitude != null) 'min_magnitude': minMagnitude,
          if (radiusKm != null) 'radius_km': radiusKm,
        },
      );
    } catch (e) {
      SecureLogger.error('Failed to log notification settings change', e);
    }
  }
  
  /// Log when user receives/opens a notification
  Future<void> logNotificationReceived({
    required String type, // 'earthquake', 'update', etc.
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
  
  // ==================== User Preferences Events ====================
  
  /// Log theme change
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
  
  /// Log filter/settings change
  Future<void> logFilterChange({
    required String filterName,
    required dynamic value,
  }) async {
    if (!_initialized) return;
    
    try {
      await _analytics.logEvent(
        name: 'filter_change',
        parameters: {
          'filter_name': filterName,
          'value': value.toString(),
        },
      );
    } catch (e) {
      SecureLogger.error('Failed to log filter change', e);
    }
  }
  
  // ==================== Share Events ====================
  
  /// Log when user shares earthquake info
  Future<void> logShare({
    required String contentType, // 'earthquake', 'screenshot', 'link'
    required String method, // 'social', 'copy', 'email', etc.
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
  
  // ==================== App Lifecycle Events ====================
  
  /// Log app open/launch
  Future<void> logAppOpen() async {
    if (!_initialized) return;
    
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      SecureLogger.error('Failed to log app open', e);
    }
  }
  
  /// Log onboarding completion
  Future<void> logOnboardingComplete() async {
    if (!_initialized) return;
    
    try {
      await _analytics.logEvent(name: 'onboarding_complete');
    } catch (e) {
      SecureLogger.error('Failed to log onboarding complete', e);
    }
  }
  
  /// Log location permission request
  Future<void> logLocationPermission({
    required bool granted,
    required String precisionLevel, // 'precise', 'approximate', 'denied'
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
  
  // ==================== Error Tracking ====================
  
  /// Log a non-fatal error to Crashlytics
  Future<void> logError({
    required dynamic error,
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
    Map<String, String>? additionalContext,
  }) async {
    if (!_initialized) return;
    
    try {
      // Add additional context as custom keys
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
  
  /// Log a custom message to Crashlytics (for debugging context)
  Future<void> logMessage(String message) async {
    if (!_initialized) return;
    
    try {
      await _crashlytics.log(message);
    } catch (e) {
      // Silently fail for log messages
    }
  }
  
  // ==================== User Properties ====================
  
  /// Set a user property for analytics segmentation
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
  
  /// Set user ID for cross-device tracking (use hashed/anonymous ID)
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
  
  // ==================== API/Network Events ====================
  
  /// Log API call performance
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
          if (errorMessage != null) 'error': _truncateForAnalytics(errorMessage),
        },
      );
    } catch (e) {
      SecureLogger.error('Failed to log API call', e);
    }
  }
  
  /// Log data source switch (multi-source feature)
  Future<void> logDataSourceSwitch({
    required String fromSource,
    required String toSource,
    required String reason, // 'fallback', 'user_selection', 'error'
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
  
  // ==================== Helper Methods ====================
  
  /// Truncate strings to fit Firebase Analytics limits (100 chars for parameter values)
  String _truncateForAnalytics(String value, {int maxLength = 100}) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 3)}...';
  }
  
  /// Get analytics observer for navigation tracking
  FirebaseAnalyticsObserver get observer => 
      FirebaseAnalyticsObserver(analytics: _analytics);
  
  /// Check if analytics is enabled
  bool get isInitialized => _initialized;
  
  /// Force a test crash to verify Crashlytics is working
  /// WARNING: Only use this for testing! Remove before production.
  /* void forceCrash() {
    if (!_initialized) {
      SecureLogger.warning('Crashlytics not initialized, cannot force crash');
      return;
    }
    _crashlytics.crash();
  } */
}
