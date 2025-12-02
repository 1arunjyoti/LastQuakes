import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lastquake/domain/repositories/device_repository.dart';
import 'package:lastquake/services/secure_http_client.dart';
import 'package:lastquake/utils/secure_logger.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  static String? get serverUrl => dotenv.env['SERVER_URL'];

  @override
  Future<void> registerDevice(
    String token,
    Map<String, dynamic> preferences,
  ) async {
    final Uri url = Uri.parse("$serverUrl/api/devices/register");
    final body = json.encode({'token': token, 'preferences': preferences});

    SecureLogger.api("/api/devices/register", method: "POST");
    SecureLogger.token("Sending registration with token", token: token);
    SecureLogger.info("Preferences: ${SecureLogger.sanitizeData(preferences)}");

    try {
      final response = await SecureHttpClient.instance.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
        timeout: const Duration(seconds: 90),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        SecureLogger.success(
          "Device registered/updated successfully with backend",
        );
      } else {
        SecureLogger.error(
          "Failed to register/update device with backend: ${response.statusCode}",
        );
        throw Exception("Failed to register device: ${response.statusCode}");
      }
    } catch (e) {
      SecureLogger.error("Error sending registration update to backend", e);
      rethrow;
    }
  }
}
