import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lastquakes/models/push_message.dart';
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
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // Add iOS/macOS initialization settings if needed
    // const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(...);

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      // iOS: iosSettings,
    );

    // Add onDidReceiveNotificationResponse for tap handling
    await flutterLocalNotificationsPlugin.initialize(settings);
  }

  /// Show notification from a push message.
  /// Uses platform-agnostic [PushMessage] to avoid Firebase dependency in shared code.
  Future<void> showPushNotification(PushMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'earthquake_channel', // Channel ID
          'Earthquake Alerts', // Channel Name
          channelDescription:
              'Notifications about earthquakes based on your settings',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'ticker',
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    String title =
        message.data['title']?.toString() ??
        message.title ??
        "Earthquake Alert";
    String body =
        message.data['body']?.toString() ??
        message.body ??
        "An earthquake occurred!";
    String id =
        message.data['earthquakeId']?.toString() ??
        (title + body).hashCode.toString();

    await flutterLocalNotificationsPlugin.show(
      id.hashCode,
      title,
      body,
      notificationDetails,
      payload: message.data['earthquakeId']?.toString(),
    );
  }
}
