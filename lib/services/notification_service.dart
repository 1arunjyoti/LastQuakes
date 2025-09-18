import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lastquake/models/safe_zone.dart';
import 'package:lastquake/services/secure_http_client.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:lastquake/utils/secure_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lastquake/services/location_service.dart';
import 'package:lastquake/services/secure_token_service.dart';
import 'package:permission_handler/permission_handler.dart';

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
  NotificationService._();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final LocationService locationService =
      LocationService(); // For getting user location

  // Get server URL from environment variables
  static String? get serverUrl => dotenv.env['SERVER_URL'];

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

  // Send the new preference structure
  Future<void> updateBackendRegistration() async {
    SecureLogger.info("Attempting to update backend registration");

    // Get FCM Token from secure storage first, fallback to Firebase if needed
    String? fcmToken = await SecureTokenService.instance.getFCMToken();
    if (fcmToken == null) {
      // Fallback: get fresh token from Firebase and store it securely
      fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await SecureTokenService.instance.storeFCMToken(fcmToken);
      }
    }
    
    if (fcmToken == null) {
      SecureLogger.error("FCM token is null, cannot update registration");
      return;
    }

    // Load Preferences from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final filterType = NotificationFilterType.values.firstWhere(
      (e) => e.name == prefs.getString(prefNotificationFilterType),
      orElse: () => NotificationFilterType.none,
    );

    // If notifications are disabled, send the disabled state.

    final magnitude = prefs.getDouble(prefNotificationMagnitude) ?? 5.0;
    final country = prefs.getString(prefNotificationCountry) ?? "ALL";
    final radius = prefs.getDouble(prefNotificationRadius) ?? 500.0;
    final useCurrentLocation =
        prefs.getBool(prefNotificationUseCurrentLoc) ?? false;
    final safeZonesJson = prefs.getStringList(prefNotificationSafeZones) ?? [];
    final safeZones =
        safeZonesJson
            .map((json) => SafeZone.fromJson(jsonDecode(json)))
            .toList();

    // Get Current Location
    Position? currentPosition;
    bool locationPermissionOk = false;
    if (filterType == NotificationFilterType.distance && useCurrentLocation) {
      // Check permission status first
      PermissionStatus status = await Permission.locationWhenInUse.status;
      if (status.isGranted) {
        locationPermissionOk = true;
        try {
          currentPosition = await locationService.getCurrentLocation();
          if (currentPosition == null) {
            SecureLogger.warning("Filter type is Distance+Current, but failed to get location");
          }
        } catch (e) {
          SecureLogger.error("Error getting current location for registration", e);
        }
      } else {
        SecureLogger.warning("Location permission not granted for Distance+Current filter");
      }
    }

    // Prepare Data Payload for Backend
    final Map<String, dynamic> preferencesPayload = {
      'filterType': filterType.name, // e.g., "distance", "country", "none"
      'minMagnitude': magnitude,
      // Only include other fields if filterType is not 'none'
      if (filterType != NotificationFilterType.none) ...{
        if (filterType == NotificationFilterType.country) 'country': country,
        if (filterType == NotificationFilterType.distance) ...{
          'radiusKm': radius,
          'useCurrentLocation': useCurrentLocation,
          'safeZones': safeZones.map((z) => z.toJson()).toList(),
          // Send current location ONLY if obtained successfully and feature is enabled
          if (useCurrentLocation &&
              currentPosition != null &&
              locationPermissionOk) ...{
            'currentLatitude': currentPosition.latitude,
            'currentLongitude': currentPosition.longitude,
          },
        },
      },
    };

    // Send to Backend
    final Uri url = Uri.parse("$serverUrl/api/devices/register");
    final body = json.encode({
      'token': fcmToken,
      'preferences': preferencesPayload,
    });

    SecureLogger.api("/api/devices/register", method: "POST");
    SecureLogger.token("Sending registration with token", token: fcmToken);
    SecureLogger.info("Preferences: ${SecureLogger.sanitizeData(preferencesPayload)}");

    try {
      final response = await SecureHttpClient.instance.post(
        url, 
        headers: {'Content-Type': 'application/json'}, 
        body: body,
        timeout: const Duration(seconds: 20),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        SecureLogger.success("Device registered/updated successfully with backend");
      } else {
        SecureLogger.error("Failed to register/update device with backend: ${response.statusCode}");
      }
    } catch (e) {
      SecureLogger.error("Error sending registration update to backend", e);
    }
  }

  // Method to be called on app start and potentially on token refresh
  Future<void> initialRegisterOrUpdate() async {
    // This ensures the backend gets the latest token and settings on launch
    await updateBackendRegistration();
  }
}
