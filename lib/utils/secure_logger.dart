import 'package:flutter/foundation.dart';

/// Secure logging utility that prevents sensitive information leakage in production builds
class SecureLogger {
  /// Log general information (only in debug mode)
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ $message');
    }
  }

  /// Log success messages (only in debug mode)
  static void success(String message) {
    if (kDebugMode) {
      debugPrint('✅ $message');
    }
  }

  /// Log warning messages (only in debug mode)
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ $message');
    }
  }

  /// Log error messages (only in debug mode)
  static void error(String message, [Object? error]) {
    if (kDebugMode) {
      if (error != null) {
        debugPrint('❌ $message: $error');
      } else {
        debugPrint('❌ $message');
      }
    }
  }

  /// Log API-related information with sanitized data
  static void api(String endpoint, {int? statusCode, String? method}) {
    if (kDebugMode) {
      final methodStr = method != null ? '$method ' : '';
      final statusStr = statusCode != null ? ' (Status: $statusCode)' : '';
      debugPrint('🌐 API Call: $methodStr$endpoint$statusStr');
    }
  }

  /// Log token-related operations with sanitized token
  static void token(String operation, {String? token}) {
    if (kDebugMode) {
      if (token != null && token.length > 15) {
        debugPrint('🔐 Token $operation: ${token.substring(0, 15)}...');
      } else {
        debugPrint('🔐 Token $operation');
      }
    }
  }

  /// Log location-related operations without exposing coordinates
  static void location(String message, {bool hasCoordinates = false}) {
    if (kDebugMode) {
      final coordStr = hasCoordinates ? ' (coordinates available)' : '';
      debugPrint('📍 Location: $message$coordStr');
    }
  }

  /// Log Firebase/FCM operations
  static void firebase(String message) {
    if (kDebugMode) {
      debugPrint('🔥 Firebase: $message');
    }
  }

  /// Log notification operations
  static void notification(String message) {
    if (kDebugMode) {
      debugPrint('🔔 Notification: $message');
    }
  }

  /// Log migration operations
  static void migration(String message) {
    if (kDebugMode) {
      debugPrint('🔄 Migration: $message');
    }
  }

  /// Log permission-related operations
  static void permission(String permission, String status) {
    if (kDebugMode) {
      debugPrint('🔒 Permission [$permission]: $status');
    }
  }

  /// Log initialization steps
  static void init(String message) {
    if (kDebugMode) {
      debugPrint('🚀 Init: $message');
    }
  }

  /// Sanitize sensitive data for logging
  static String sanitizeData(Map<String, dynamic> data) {
    if (!kDebugMode) return '[REDACTED]';
    
    final sanitized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;
      
      // Redact sensitive fields
      if (key.contains('token') || 
          key.contains('password') || 
          key.contains('secret') ||
          key.contains('key') ||
          key.contains('latitude') ||
          key.contains('longitude')) {
        if (value is String && value.length > 10) {
          sanitized[entry.key] = '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
        } else {
          sanitized[entry.key] = '[REDACTED]';
        }
      } else {
        sanitized[entry.key] = value;
      }
    }
    
    return sanitized.toString();
  }
}