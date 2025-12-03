import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createClient() {
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

bool checkSocketException(Object e) {
  return e is SocketException;
}

bool checkHandshakeException(Object e) {
  return e is HandshakeException;
}
