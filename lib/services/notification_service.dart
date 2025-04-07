import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lastquake/services/location_service.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final LocationService locationService =
      LocationService(); // For getting user location

  // Update with your Firebase Function URL
  static const String _SERVER_URL = 'https://lastquakenotify.onrender.com';

  Future<void> initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(settings);
  }

  // Show notification when receiving FCM messages
  Future<void> showFCMNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'earthquake_channel', // Notification Channel ID
          'Earthquake Alerts', // Name shown in settings
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    // Extract data from FCM message
    final Map<String, dynamic> data = message.data;
    String title = message.notification?.title ?? "Earthquake Alert";
    String body = message.notification?.body ?? "An earthquake occurred!";
    String? id = data['id'];

    // Store to notification history
    if (id != null) {
      List<Map<String, String>> storedNotifications =
          await getStoredNotifications();

      // Avoid adding duplicates if the message somehow gets processed twice quickly
      bool alreadyExists = storedNotifications.any(
        (n) => n['id'] == id && n['title'] == title,
      );

      if (!alreadyExists) {
        storedNotifications.add({
          'id': id, // Use the actual earthquake ID
          'title': title,
          'body': body,
          'timestamp': DateTime.now().toIso8601String(),
        });
        await _saveNotifications(storedNotifications);
      }
    }

    await flutterLocalNotificationsPlugin.show(
      id?.hashCode ?? message.messageId.hashCode,
      title,
      body,
      details,
    );
  }

  // Register device with Firebase Cloud Function
  Future<void> registerDeviceWithServer() async {
    debugPrint("Attempting to register device with backend...");
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken == null) {
        debugPrint("FCM token is null, not registering device.");
        return;
      }

      // Get user preferences for server registration
      double magnitude = prefs.getDouble('notification_magnitude') ?? 5.0;
      String country = prefs.getString('notification_country') ?? "ALL";
      // Radius: Get value, treat 0 or null as "off" for sending to backend
      double? radiusSetting = prefs.getDouble('notification_radius');
      double? radiusToSend =
          (radiusSetting == null || radiusSetting <= 0) ? null : radiusSetting;
      bool notificationsEnabled =
          prefs.getBool('notifications_enabled') ?? false;

      // Get user location if available (with permission) ONLY if radius is enabled
      Position? position;
      if (radiusToSend != null) {
        position = await locationService.getCurrentLocation();
        if (position == null) {
          debugPrint(
            "Radius notifications enabled, but failed to get location.",
          );
        }
      }

      // Prepare data for server
      final Map<String, dynamic> preferences = {
        'magnitude': magnitude,
        'country': country,
        'notificationsEnabled': notificationsEnabled,
        // Only send radius/location if radius is enabled and location available
        if (radiusToSend != null) 'radius': radiusToSend,
        if (position != null) 'latitude': position.latitude,
        if (position != null) 'longitude': position.longitude,
      };

      // Send FCM token and user preferences to your server
      final Uri url = Uri.parse("$_SERVER_URL/api/devices/register");

      debugPrint("Registering device with server... $url");
      debugPrint("Token: ${fcmToken.substring(0, 15)}...");
      debugPrint("Prefs: ${json.encode(preferences)}");

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'token': fcmToken, 'preferences': preferences}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint("Device registered/updated successfully with server");
      } else {
        debugPrint(
          "Failed to register device: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      debugPrint("Error registering device: $e");
    }
  }

  // Method to update FCM subscriptions when settings change
  Future<void> updateFCMTopics() async {
    debugPrint("🔄 Settings changed, updating backend registration...");

    // Re-register with the server to update preferences (location, radius, mag etc.)
    // This ensures the backend has the latest settings for direct/radius notifications
    await registerDeviceWithServer();
  }

  // Method to show local notifications
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'earthquake_channel',
          'Earthquake Alerts',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(id, title, body, details);
  }

  // Methods for handling notification history storage
  // Method to get stored notification history
  Future<List<Map<String, String>>> getStoredNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notificationsJson = prefs.getString('notification_history');
    if (notificationsJson == null) return [];
    try {
      final List<dynamic> decoded = json.decode(notificationsJson);
      return decoded
          .map((item) {
            if (item is Map) {
              return Map<String, String>.from(
                item.map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                ),
              );
            }
            return <String, String>{};
          })
          .where((item) => item.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint("Error parsing notifications history: $e");
      await clearNotificationHistory();
      return [];
    }
  }

  Future<void> _saveNotifications(
    List<Map<String, String>> notifications,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Limit to last 50 notifications
    if (notifications.length > 50) {
      notifications = notifications.sublist(notifications.length - 50);
    }

    try {
      await prefs.setString('notification_history', json.encode(notifications));
    } catch (e) {
      //print("Error saving notifications: $e");
    }
  }

  Future<void> clearNotificationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_history');
    debugPrint("Notification history cleared.");
  }
}
