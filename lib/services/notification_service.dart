import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:lastquakes/services/location_service.dart';
import 'package:flutter/foundation.dart';

// Keys need to match settings_screen.dart
const String prefNotificationFilterType = 'notification_filter_type';
const String prefNotificationMagnitude = 'notification_magnitude';
const String prefNotificationCountry = 'notification_country';
const String prefNotificationRadius = 'notification_radius';
const String prefNotificationUseCurrentLoc = 'notification_use_current_loc';
const String prefNotificationSafeZones = 'notification_safe_zones';

class NotificationService {
  // Private static instance
  static NotificationService? _instance;

  // Public static getter for the instance
  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  // Private constructor
  NotificationService._({FlutterLocalNotificationsPlugin? plugin})
    : flutterLocalNotificationsPlugin =
          plugin ?? FlutterLocalNotificationsPlugin();

  @visibleForTesting
  factory NotificationService.test({
    required FlutterLocalNotificationsPlugin plugin,
  }) {
    return NotificationService._(plugin: plugin);
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  final LocationService locationService =
      LocationService(); // For getting user location

  Future<void> initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Add iOS/macOS initialization settings if needed
    // const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(...);

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      // iOS: iosSettings,
    );

    // Add onDidReceiveNotificationResponse for tap handling
    await flutterLocalNotificationsPlugin.initialize(settings);
  }

  // Show notification when receiving FCM messages
  Future<void> showFCMNotification(RemoteMessage message) async {
    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'earthquake_channel', // Channel ID
      'Earthquake Alerts', // Channel Name
      channelDescription:
          'Notifications about earthquakes based on your settings', // Channel Description
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );

    // Add iOS/macOS details if needed
    // const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(...);

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      // iOS: iosDetails,
    );

    final Map<String, dynamic> data = message.data;
    String title =
        data['title'] ?? message.notification?.title ?? "Earthquake Alert";
    String body =
        data['body'] ?? message.notification?.body ?? "An earthquake occurred!";
    // Use a stable ID from the backend if possible, otherwise use hash of content or time
    String id =
        data['earthquakeId']?.toString() ?? (title + body).hashCode.toString();

    await flutterLocalNotificationsPlugin.show(
      id.hashCode, // Use the stable ID's hash code for the notification ID
      title,
      body,
      notificationDetails,
      // Payload for notification tap handling (e.g., earthquake ID)
      payload: data['earthquakeId']?.toString(),
    );
  }
}
