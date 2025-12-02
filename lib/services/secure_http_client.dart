import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:lastquake/utils/secure_logger.dart';

/// Secure HTTP client with certificate pinning implementation
class SecureHttpClient {
  static SecureHttpClient? _instance;
  static SecureHttpClient get instance {
    _instance ??= SecureHttpClient._();
    return _instance!;
  }

  late final http.Client _client;

  SecureHttpClient._() {
    _client = _createSecureClient();
  }

  @visibleForTesting
  SecureHttpClient.testing(http.Client client) {
    _client = client;
  }

  // Certificate pins for your domains (SHA-256 hashes of certificates)
  // Generated on: 2025-09-18 using scripts/get_certificate_pins.dart
  static const Map<String, List<String>> _certificatePins = {
    'earthquake.usgs.gov': [
      // USGS certificate pin (valid until 2026-09-10)
      'sha256/y7fiv9+wdRY/ehETGMTQCuYF4sqW5tluP/0/vFRkBuQ=',
      // Backup pin - DigiCert Global G2 TLS RSA SHA256 2020 CA1 (issuer)
      // TODO: Add backup pin for certificate rotation
      'sha256/BACKUP_PIN_NEEDED_FOR_CERTIFICATE_ROTATION',
    ],
    'lastquakenotify.onrender.com': [
      // Render.com certificate pin (valid until 2025-11-02)
      'sha256/C82no4HIA5465NNkYie825ChqLn+XC3s/yCpY9Gn8zk=',
      // Backup pin - Google Trust Services WE1 (issuer)
      // TODO: Add backup pin for certificate rotation
      'sha256/BACKUP_PIN_NEEDED_FOR_CERTIFICATE_ROTATION',
    ],
  };

  /// Get certificate pins for a specific host (for debugging/setup)
  static List<String>? getPinsForHost(String host) {
    return _certificatePins[host];
  }

  /// Dispose of the HTTP client
  void dispose() {
    _client.close();
  }

  @visibleForTesting
  static void setMockInstance(SecureHttpClient? client) {
    if (client == null) {
      _instance?.dispose();
    }
    _instance = client;
  }

  /// Create HTTP client with certificate pinning
  http.Client _createSecureClient() {
    // Use a SecurityContext that trusts no roots to force badCertificateCallback
    // for ALL certificates, ensuring our pinning logic is always executed.
    final context = SecurityContext(withTrustedRoots: false);
    final httpClient = HttpClient(context: context);

    // Configure timeouts
    httpClient.idleTimeout = const Duration(seconds: 60);
    httpClient.connectionTimeout = const Duration(seconds: 60);

    // Configure certificate validation with pinning
    httpClient.badCertificateCallback = (
      X509Certificate cert,
      String host,
      int port,
    ) {
      // Verify certificate pin for the host
      final isValidPin = _verifyCertificatePin(host, cert);

      if (!isValidPin) {
        SecureLogger.security(
          'Certificate pinning failed for $host:$port - connection rejected',
        );
      }

      return isValidPin;
    };

    return IOClient(httpClient);
  }

  /// Verify certificate pin for a given host
  bool _verifyCertificatePin(String host, X509Certificate cert) {
    // In debug mode, we might want to bypass pinning for easier development
    // but still log a warning.
    if (kDebugMode) {
      SecureLogger.warning(
        'Debug mode: Bypassing certificate pinning for host: $host',
      );
      return true;
    }

    final pins = _certificatePins[host];
    if (pins == null || pins.isEmpty) {
      SecureLogger.warning(
        'No certificate pins configured for host: $host - allowing connection',
      );
      // In production, you should return false here if you want to enforce pinning for all hosts
      // For now, we allow it but log the warning.
      return true;
    }

    try {
      // Extract the public key from the certificate
      final publicKeyBytes = cert.der;
      final publicKeyHash = sha256.convert(publicKeyBytes);
      final publicKeyPin = 'sha256/${base64.encode(publicKeyHash.bytes)}';

      final isValid = pins.contains(publicKeyPin);

      if (isValid) {
        SecureLogger.security('Certificate pin verified for host: $host');
      } else {
        SecureLogger.security(
          'Certificate pin verification FAILED for host: $host',
        );
        SecureLogger.security('Expected one of: $pins');
        SecureLogger.security('Actual pin: $publicKeyPin');
      }

      return isValid;
    } catch (e) {
      SecureLogger.error('Error verifying certificate pin for $host', e);
      return false;
    }
  }

  /// Secure GET request with certificate pinning
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return _makeSecureRequest(
      () => _client.get(url, headers: headers),
      url.host,
      timeout ?? const Duration(seconds: 60),
    );
  }

  /// Secure POST request with certificate pinning
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return _makeSecureRequest(
      () => _client.post(url, headers: headers, body: body),
      url.host,
      timeout ?? const Duration(seconds: 60),
    );
  }

  /// Secure PUT request with certificate pinning
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return _makeSecureRequest(
      () => _client.put(url, headers: headers, body: body),
      url.host,
      timeout ?? const Duration(seconds: 60),
    );
  }

  /// Secure PATCH request with certificate pinning
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return _makeSecureRequest(
      () => _client.patch(url, headers: headers, body: body),
      url.host,
      timeout ?? const Duration(seconds: 60),
    );
  }

  /// Secure DELETE request with certificate pinning
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return _makeSecureRequest(
      () => _client.delete(url, headers: headers, body: body),
      url.host,
      timeout ?? const Duration(seconds: 60),
    );
  }

  /// Secure HEAD request with certificate pinning
  Future<http.Response> head(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return _makeSecureRequest(
      () => _client.head(url, headers: headers),
      url.host,
      timeout ?? const Duration(seconds: 60),
    );
  }

  /// Make a secure HTTP request with certificate validation
  Future<http.Response> _makeSecureRequest(
    Future<http.Response> Function() requestFunction,
    String host,
    Duration timeout,
  ) async {
    try {
      final response = await requestFunction().timeout(timeout);

      // Log successful secure request
      SecureLogger.security(
        'Secure HTTP request completed for host: $host (Status: ${response.statusCode})',
      );

      return response;
    } on SocketException catch (e) {
      SecureLogger.error('Network error for host $host', e);
      throw Exception('Network error: Unable to connect to $host');
    } on HandshakeException catch (e) {
      SecureLogger.security(
        'SSL/TLS handshake failed for host $host - possible certificate pinning rejection',
        e,
      );
      throw Exception('SSL/TLS error: Certificate validation failed for $host');
    } on TimeoutException catch (e) {
      SecureLogger.error('Request timeout for host $host', e);
      throw Exception(
        'Request timeout: $host did not respond within ${timeout.inSeconds} seconds',
      );
    } catch (e) {
      SecureLogger.error('Unexpected error for host $host', e);
      rethrow;
    }
  }

  @visibleForTesting
  static void reset() {
    setMockInstance(null);
  }
}
