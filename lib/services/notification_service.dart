import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
//import 'package:lastquake/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lastquake/services/location_service.dart';
//import 'package:timezone/timezone.dart'; // Add this package for location

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

  // 🔹 Show notification when receiving FCM messages
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

    // If you need to extract custom data from message.data
    String? id = data['id'];
    /* String? magnitude = data['magnitude'];
    String? place = data['place']; */

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
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken == null) {
        print("FCM token is null, not registering device.");
        return;
      }

      // Get user preferences for server registration
      double magnitude = prefs.getDouble('notification_magnitude') ?? 5.0;
      String country = prefs.getString('notification_country') ?? "ALL";
      double? radius = prefs.getDouble('notification_radius');
      bool notificationsEnabled =
          prefs.getBool('notifications_enabled') ?? false; // Use setting

      // Get user location if available (with permission) ONLY if radius is enabled
      Position? position;
      if (radius != null && radius > 0) {
        position = await locationService.getCurrentLocation();
      }

      // Prepare data for server
      final Map<String, dynamic> preferences = {
        'magnitude': magnitude,
        'country': country,
        'notificationsEnabled':
            notificationsEnabled, // Inform server if user disabled locally
        // Only send radius/location if radius is enabled and location available
        if (radius != null && radius > 0) 'radius': radius,
        if (position != null) 'latitude': position.latitude,
        if (position != null) 'longitude': position.longitude,
      };

      // Send FCM token and user preferences to your server
      final Uri url = Uri.parse(
        "$_SERVER_URL/api/devices/register",
      ); // Append /register

      print("Registering device with server... $url");
      print("Token: ${fcmToken.substring(0, 15)}...");
      print("Prefs: ${json.encode(preferences)}");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': fcmToken, 'preferences': preferences}),
      );

      if (response.statusCode == 200) {
        print("Device registered/updated successfully with server");
      } else {
        print(
          "Failed to register device: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("Error registering device: $e");
    }
  }

  /* // Get user location (if permitted)
  Future<LocationData?> _getUserLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;
    
    // Check if location service is enabled
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return null;
      }
    }
    
    // Check if permission is granted
    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return null;
      }
    }
    
    try {
      return await location.getLocation();
    } catch (e) {
      print("Error getting location: $e");
      return null;
    }
  } */

  // Setup FCM topics based on preferences
  Future<void> subscribeToEarthquakeTopics() async {
    final prefs = await SharedPreferences.getInstance();
    double minMagnitude = prefs.getDouble('notification_magnitude') ?? 5.0;
    String country = prefs.getString('notification_country') ?? "ALL";
    bool notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;

    if (!notificationsEnabled) {
      print("🔕 Notifications disabled locally, skipping topic subscription.");
      // Consider unsubscribing from all topics here if desired when disabled
      await _unsubscribeFromAllKnownTopics(prefs);
      return;
    }

    print("🔄 Subscribing to FCM topics based on settings...");

    // Magnitude Topics (Matching Backend: earthquakes_magXplus)
    // Subscribe to all topics >= the user's minimum threshold
    if (minMagnitude <= 3.0) {
      await FirebaseMessaging.instance.subscribeToTopic('earthquakes_mag3plus');
    }
    if (minMagnitude <= 4.0) {
      await FirebaseMessaging.instance.subscribeToTopic('earthquakes_mag4plus');
    }
    if (minMagnitude <= 5.0) {
      await FirebaseMessaging.instance.subscribeToTopic('earthquakes_mag5plus');
    }
    if (minMagnitude <= 6.0) {
      await FirebaseMessaging.instance.subscribeToTopic('earthquakes_mag6plus');
    }
    // Add more if your backend supports them (e.g., mag7plus)

    print("   Subscribed to magnitude topics for >= M${minMagnitude}");

    // Country Topic (Matching Backend: region_xxx)
    if (country != "ALL") {
      // Convert country name to topic-friendly format
      String countryTopic =
          'region_${country.toLowerCase().replaceAll(' ', '_')}';
      await FirebaseMessaging.instance.subscribeToTopic(countryTopic);
      print("   Subscribed to country topic: $countryTopic");
    } else {
      print("   Subscribed to ALL countries (no specific country topic).");
    }
  }

  // Method to update FCM subscriptions when settings change
  Future<void> updateFCMTopics() async {
    final prefs = await SharedPreferences.getInstance();
    print("🔄 Updating FCM Topics...");

    // First unsubscribe from all known topics to ensure clean state
    await _unsubscribeFromAllKnownTopics(prefs);

    // Then resubscribe based on current settings (only if enabled)
    await subscribeToEarthquakeTopics();

    // Store current country for future reference when unsubscribing next time
    String currentCountry = prefs.getString('notification_country') ?? "ALL";
    await prefs.setString('previous_notification_country', currentCountry);

    // Re-register with the server to update preferences (location, radius, mag etc.)
    // This ensures the backend has the latest settings for direct/radius notifications
    await registerDeviceWithServer();
  }

  // Helper to unsubscribe from topics we manage
  Future<void> _unsubscribeFromAllKnownTopics(SharedPreferences prefs) async {
    print("   Unsubscribing from previous topics...");
    // Unsubscribe from all potential magnitude topics
    await FirebaseMessaging.instance.unsubscribeFromTopic(
      'earthquakes_mag3plus',
    );
    await FirebaseMessaging.instance.unsubscribeFromTopic(
      'earthquakes_mag4plus',
    );
    await FirebaseMessaging.instance.unsubscribeFromTopic(
      'earthquakes_mag5plus',
    );
    await FirebaseMessaging.instance.unsubscribeFromTopic(
      'earthquakes_mag6plus',
    );
    // Add more if needed

    // Unsubscribe from the previously selected country topic
    String oldCountry =
        prefs.getString('previous_notification_country') ??
        "ALL"; // Use stored previous country
    if (oldCountry != "ALL") {
      String oldCountryTopic =
          'region_${oldCountry.toLowerCase().replaceAll(' ', '_')}';
      await FirebaseMessaging.instance.unsubscribeFromTopic(oldCountryTopic);
      print("   Unsubscribed from old country topic: $oldCountryTopic");
    }
  }

  // Process earthquakes for local notifications
  /* Future<void> processEarthquakeNotifications(
    List<Map<String, dynamic>> earthquakes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    bool notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;

    if (!notificationsEnabled) return;

    double selectedMagnitude = prefs.getDouble('notification_magnitude') ?? 5.0;
    String selectedCountry = prefs.getString('notification_country') ?? "ALL";

    // Process only recent earthquakes (last 24 hours)
    final now = DateTime.now();
    final recentEarthquakes =
        earthquakes.where((quake) {
          final quakeTime = DateTime.fromMillisecondsSinceEpoch(
            quake["properties"]["time"] as int,
          );
          final difference = now.difference(quakeTime);
          return difference.inHours <= 24;
        }).toList();

    // Store notification history
    List<Map<String, String>> storedNotifications =
        await getStoredNotifications();

    for (final quake in recentEarthquakes) {
      final properties = quake["properties"];
      final geometry = quake["geometry"];

      double magnitude = properties["mag"] ?? 0.0;
      String place = properties["place"] ?? "Unknown location";
      int time = properties["time"] ?? 0;
      String id = properties["id"] ?? "";

      // Skip if magnitude is below threshold
      if (magnitude < selectedMagnitude) continue;

      // Handle country filtering
      if (selectedCountry != "ALL" && !place.contains(selectedCountry))
        continue;

      // Check if we've already notified about this earthquake
      bool alreadyNotified = storedNotifications.any(
        (notification) => notification['id'] == id,
      );

      if (!alreadyNotified) {
        // Format notification content
        String title = "M${magnitude.toStringAsFixed(1)} Earthquake";
        String body =
            "A magnitude ${magnitude.toStringAsFixed(1)} earthquake occurred near $place";

        // Store in notification history
        storedNotifications.add({
          'id': id,
          'title': title,
          'body': body,
          'timestamp': DateTime.now().toIso8601String(),
        });

        // Show local notification
        await showNotification(id: id.hashCode, title: title, body: body);
      }
    }

    // Save updated notification history
    await _saveNotifications(storedNotifications);
  } */

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

  // Method to check for new earthquakes
  /* Future<void> checkForEarthquakes({
    bool showStatusNotifications = false,
    bool isBackgroundTask = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      double minMagnitude = prefs.getDouble('notification_magnitude') ?? 5.0;

      // Force refresh from API
      final earthquakes = await ApiService.fetchEarthquakes(
        minMagnitude: minMagnitude,
        forceRefresh: true,
      );

      // Process notifications
      await processEarthquakeNotifications(earthquakes);

      if (showStatusNotifications) {
        await showNotification(
          id: DateTime.now().millisecondsSinceEpoch.hashCode,
          title: "Earthquake Check Complete",
          body: "Checked for new earthquakes: ${earthquakes.length} found",
        );
      }
    } catch (e) {
      print("Error checking for earthquakes: $e");
      if (showStatusNotifications) {
        await showNotification(
          id: DateTime.now().millisecondsSinceEpoch.hashCode,
          title: "Earthquake Check Failed",
          body: "Error checking for new earthquakes",
        );
      }
    }
  } */

  // Methods for handling notification history storage
  Future<List<Map<String, String>>> getStoredNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notificationsJson = prefs.getString('notification_history');

    if (notificationsJson == null) return [];

    try {
      final List<dynamic> decoded = json.decode(notificationsJson);
      // Ensure items are correctly typed Map<String, String>
      return decoded
          .map((item) {
            if (item is Map) {
              return Map<String, String>.from(
                item.map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                ),
              );
            }
            return <String, String>{}; // Return empty map if item is not a Map
          })
          .where((item) => item.isNotEmpty)
          .toList(); // Filter out empty maps
    } catch (e) {
      print("Error parsing notifications: $e");
      await clearNotificationHistory(); // Clear corrupted data
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
      print("Error saving notifications: $e");
    }
  }

  Future<void> clearNotificationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_history');
    print("Notification history cleared.");
  }
}
