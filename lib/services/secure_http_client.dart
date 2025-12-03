import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:lastquake/utils/secure_logger.dart';

/// HTTP client implementation
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

  /// Create HTTP client without certificate validation
  http.Client _createSecureClient() {
    final httpClient = HttpClient();

    // Configure timeouts
    httpClient.idleTimeout = const Duration(seconds: 60);
    httpClient.connectionTimeout = const Duration(seconds: 60);

    // Accept all certificates (certificate validation disabled)
    httpClient.badCertificateCallback = (
      X509Certificate cert,
      String host,
      int port,
    ) {
      return true;
    };

    return IOClient(httpClient);
  }

  /// GET request
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

  /// POST request
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

  /// PUT request
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

  /// PATCH request
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

  /// DELETE request
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

  /// HEAD request
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

  /// Make an HTTP request with timeout handling
  Future<http.Response> _makeSecureRequest(
    Future<http.Response> Function() requestFunction,
    String host,
    Duration timeout,
  ) async {
    try {
      final response = await requestFunction().timeout(timeout);

      // Log successful request
      SecureLogger.security(
        'HTTP request completed for host: $host (Status: ${response.statusCode})',
      );

      return response;
    } on SocketException catch (e) {
      SecureLogger.error('Network error for host $host', e);
      throw Exception('Network error: Unable to connect to $host');
    } on HandshakeException catch (e) {
      SecureLogger.error(
        'SSL/TLS handshake failed for host $host',
        e,
      );
      throw Exception('SSL/TLS error: Connection failed for $host');
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
