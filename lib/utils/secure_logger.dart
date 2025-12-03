import 'package:flutter/foundation.dart';

/// Secure logging utility that prevents sensitive information leakage in production builds.
/// 
/// All logging methods are disabled in release builds (when kDebugMode is false).
/// Sensitive data like tokens, coordinates, emails, and device IDs are automatically
/// sanitized to prevent PII leakage even in debug builds.
class SecureLogger {
  /// Maximum characters to show for partially redacted tokens
  static const int _tokenPreviewLength = 8;
  
  /// Patterns that indicate sensitive content in messages
  static final RegExp _coordinatePattern = RegExp(
    r'[-+]?\d{1,3}\.\d{4,}',
    caseSensitive: false,
  );
  static final RegExp _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );
  static final RegExp _phonePattern = RegExp(
    r'(?:\+\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}',
    caseSensitive: false,
  );
  static final RegExp _ipPattern = RegExp(
    r'\b(?:\d{1,3}\.){3}\d{1,3}\b',
    caseSensitive: false,
  );

  /// Sanitize a message by removing potential PII patterns
  static String _sanitizeMessage(String message) {
    var sanitized = message;
    
    // Redact potential coordinates (high precision decimal numbers)
    sanitized = sanitized.replaceAll(_coordinatePattern, '[COORD]');
    
    // Redact email addresses
    sanitized = sanitized.replaceAll(_emailPattern, '[EMAIL]');
    
    // Redact phone numbers
    sanitized = sanitized.replaceAll(_phonePattern, '[PHONE]');
    
    // Redact IP addresses
    sanitized = sanitized.replaceAll(_ipPattern, '[IP]');
    
    return sanitized;
  }

  /// Sanitize error objects to prevent PII leakage in stack traces
  static String _sanitizeError(Object error) {
    final errorStr = error.toString();
    return _sanitizeMessage(errorStr);
  }

  /// Log general information (only in debug mode)
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ ${_sanitizeMessage(message)}');
    }
  }

  /// Log success messages (only in debug mode)
  static void success(String message) {
    if (kDebugMode) {
      debugPrint('✅ ${_sanitizeMessage(message)}');
    }
  }

  /// Log warning messages (only in debug mode)
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ ${_sanitizeMessage(message)}');
    }
  }

  /// Log error messages (only in debug mode)
  /// Error objects are sanitized to prevent PII leakage in stack traces
  static void error(String message, [Object? error]) {
    if (kDebugMode) {
      if (error != null) {
        debugPrint('❌ ${_sanitizeMessage(message)}: ${_sanitizeError(error)}');
      } else {
        debugPrint('❌ ${_sanitizeMessage(message)}');
      }
    }
  }

  /// Log API-related information with sanitized data
  static void api(String endpoint, {int? statusCode, String? method}) {
    if (kDebugMode) {
      final methodStr = method != null ? '$method ' : '';
      final statusStr = statusCode != null ? ' (Status: $statusCode)' : '';
      // Sanitize endpoint to remove any query parameters that might contain PII
      final sanitizedEndpoint = _sanitizeEndpoint(endpoint);
      debugPrint('🌐 API Call: $methodStr$sanitizedEndpoint$statusStr');
    }
  }

  /// Sanitize API endpoint by removing potentially sensitive query parameters
  static String _sanitizeEndpoint(String endpoint) {
    try {
      final uri = Uri.parse(endpoint);
      if (uri.queryParameters.isEmpty) {
        return endpoint;
      }
      // Only show path, not query parameters which might contain tokens/keys
      return '${uri.path}?[params]';
    } catch (_) {
      return _sanitizeMessage(endpoint);
    }
  }

  /// Log token-related operations with sanitized token
  /// Only shows first 8 characters of token to prevent identification
  static void token(String operation, {String? token}) {
    if (kDebugMode) {
      if (token != null && token.length > _tokenPreviewLength) {
        debugPrint('🔐 Token $operation: ${token.substring(0, _tokenPreviewLength)}...[REDACTED]');
      } else {
        debugPrint('🔐 Token $operation');
      }
    }
  }

  /// Log location-related operations without exposing coordinates
  static void location(String message, {bool hasCoordinates = false}) {
    if (kDebugMode) {
      // Sanitize message in case coordinates were accidentally included
      final sanitizedMessage = _sanitizeMessage(message);
      final coordStr = hasCoordinates ? ' (coordinates available)' : '';
      debugPrint('📍 Location: $sanitizedMessage$coordStr');
    }
  }

  /// Log Firebase/FCM operations
  static void firebase(String message) {
    if (kDebugMode) {
      debugPrint('🔥 Firebase: ${_sanitizeMessage(message)}');
    }
  }

  /// Log notification operations
  static void notification(String message) {
    if (kDebugMode) {
      debugPrint('🔔 Notification: ${_sanitizeMessage(message)}');
    }
  }

  /// Log migration operations
  static void migration(String message) {
    if (kDebugMode) {
      debugPrint('🔄 Migration: ${_sanitizeMessage(message)}');
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
      debugPrint('🚀 Init: ${_sanitizeMessage(message)}');
    }
  }

  /// Log security-related operations (certificate pinning, SSL/TLS, etc.)
  static void security(String message, [Object? error]) {
    if (kDebugMode) {
      if (error != null) {
        debugPrint('🔐 Security: ${_sanitizeMessage(message)}: ${_sanitizeError(error)}');
      } else {
        debugPrint('🔐 Security: ${_sanitizeMessage(message)}');
      }
    }
  }

  /// Sensitive field patterns for data sanitization
  static final Set<String> _sensitivePatterns = {
    'token',
    'password',
    'secret',
    'key',
    'latitude',
    'longitude',
    'lat',
    'lng',
    'lon',
    'email',
    'phone',
    'mobile',
    'device_id',
    'deviceid',
    'user_id',
    'userid',
    'ip',
    'address',
    'auth',
    'credential',
    'session',
    'cookie',
  };

  /// Check if a field name contains sensitive patterns
  static bool _isSensitiveField(String fieldName) {
    final lowerName = fieldName.toLowerCase();
    return _sensitivePatterns.any((pattern) => lowerName.contains(pattern));
  }

  /// Sanitize sensitive data for logging
  /// In release mode, returns '[REDACTED]' for all data
  /// In debug mode, sensitive fields are partially redacted
  static String sanitizeData(Map<String, dynamic> data) {
    if (!kDebugMode) return '[REDACTED]';
    
    final sanitized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final value = entry.value;
      
      // Redact sensitive fields
      if (_isSensitiveField(entry.key)) {
        if (value is String && value.length > 10) {
          sanitized[entry.key] = '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
        } else {
          sanitized[entry.key] = '[REDACTED]';
        }
      } else if (value is String) {
        // Sanitize string values for potential PII even if field name isn't sensitive
        sanitized[entry.key] = _sanitizeMessage(value);
      } else {
        sanitized[entry.key] = value;
      }
    }
    
    return sanitized.toString();
  }
}