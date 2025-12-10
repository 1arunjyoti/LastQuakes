import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/models/push_message.dart';
import 'package:lastquakes/presentation/providers/earthquake_provider.dart';
import 'package:lastquakes/screens/earthquake_details.dart';
import 'package:lastquakes/services/notification_service.dart';
import 'package:lastquakes/services/push_notification_service.dart';
import 'package:lastquakes/services/secure_token_service.dart';
import 'package:lastquakes/utils/app_page_transitions.dart';
import 'package:lastquakes/utils/notification_registration_coordinator.dart';
import 'package:lastquakes/utils/secure_logger.dart';
import 'package:provider/provider.dart';

/// Background message handler must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp();
  
  SecureLogger.info(
    "Handling background message: ${message.messageId}",
  );
  
  // Convert to platform-agnostic PushMessage and show notification
  final pushMessage = PushMessage(
    title: message.notification?.title,
    body: message.notification?.body,
    data: message.data,
  );
  
  // Show local notification
  await NotificationService.instance.showPushNotification(pushMessage);
}

/// Firebase implementation of PushNotificationService for production builds.
class PushNotificationServiceFirebase implements PushNotificationService {
  /// Global navigator key for handling deep linking from notifications
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  FirebaseMessaging? _messaging;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    try {
      // Initialize Firebase if not already done
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
        SecureLogger.success("Firebase initialized");
      }

      _messaging = FirebaseMessaging.instance;

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permission first
      await requestPermission();

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        SecureLogger.info(
          "Received foreground message: ${message.messageId}",
        );

        // Convert to platform-agnostic PushMessage
        final pushMessage = PushMessage(
          title: message.notification?.title,
          body: message.notification?.body,
          data: message.data,
        );

        // Show local notification
        NotificationService.instance.showPushNotification(pushMessage);
      });

      // Handle message opened app (from terminated state)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        SecureLogger.info(
          "Message opened app: ${message.messageId}",
        );
        _handleMessageTap(message);
      });

      // Check if app was opened from a notification while terminated
      final initialMessage = await _messaging?.getInitialMessage();
      if (initialMessage != null) {
        SecureLogger.info(
          "App opened from notification: ${initialMessage.messageId}",
        );
        _handleMessageTap(initialMessage);
      }

      _isInitialized = true;
      SecureLogger.success("Firebase Messaging initialized");
    } catch (e) {
      SecureLogger.error(
        "Failed to initialize Firebase Messaging",
        e,
      );
      _isInitialized = false;
    }
  }

  @override
  Future<void> requestPermission() async {
    if (_messaging == null) {
      SecureLogger.warning("Firebase Messaging not initialized");
      return;
    }

    try {
      // Request permission for iOS and web
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        SecureLogger.success("User granted notification permission");
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        SecureLogger.info("User granted provisional notification permission");
      } else {
        SecureLogger.warning("User declined notification permission");
      }

      // For Android 13+, the permission is handled by the system
      // The flutter_local_notifications plugin handles the runtime permission request
    } catch (e) {
      SecureLogger.error(
        "Failed to request notification permission",
        e,
      );
    }
  }

  @override
  Future<String?> getToken() async {
    if (!_isInitialized || _messaging == null) {
      SecureLogger.warning(
        "Cannot get token: Firebase Messaging not initialized",
      );
      return null;
    }

    try {
      // Get FCM token
      String? token;
      
      if (kIsWeb) {
        // Web requires VAPID key - this should be configured in your Firebase project
        // You can get the VAPID key from Firebase Console > Project Settings > Cloud Messaging
        token = await _messaging!.getToken(
          vapidKey: 'YOUR_VAPID_KEY_HERE', // TODO: Replace with actual VAPID key
        );
      } else {
        token = await _messaging!.getToken();
      }

      if (token != null) {
        SecureLogger.success("FCM token retrieved: ${token.substring(0, 20)}...");
        
        // Store token securely
        await SecureTokenService.instance.storeFCMToken(token);
        
        // Trigger backend sync with new token
        await NotificationRegistrationCoordinator.requestSync();
        
        // Listen for token refresh
        _messaging!.onTokenRefresh.listen((newToken) {
          SecureLogger.info("FCM token refreshed");
          _sendTokenToServer(newToken);
        });
        
        return token;
      } else {
        SecureLogger.warning("Failed to get FCM token");
        return null;
      }
    } catch (e) {
      SecureLogger.error("Failed to get FCM token", e);
      return null;
    }
  }

  /// Handle notification tap to navigate to appropriate screen
  /// 
  /// Extracts earthquake data from the notification and navigates to the
  /// earthquake details screen. Searches for the earthquake in the cached
  /// data from EarthquakeProvider.
  void _handleMessageTap(RemoteMessage message) {
    // Extract earthquake ID from message data
    final earthquakeId = message.data['earthquakeId']?.toString();
    
    if (earthquakeId == null) {
      SecureLogger.warning("No earthquake ID in notification data");
      return;
    }
    
    SecureLogger.info("Navigating to earthquake details: $earthquakeId");
    
    // Get the navigator context
    final context = navigatorKey.currentContext;
    if (context == null) {
      SecureLogger.warning("Navigator context not available");
      return;
    }
    
    // Try to find the earthquake in the provider's data
    final earthquakeProvider = Provider.of<EarthquakeProvider>(context, listen: false);
    
    // Search in all earthquakes (both list and map filtered data)
    Earthquake? earthquake;
    
    // First try list earthquakes
    try {
      earthquake = earthquakeProvider.listEarthquakes.firstWhere(
        (eq) => eq.id == earthquakeId,
      );
    } catch (e) {
      // Not found in list, try map earthquakes
      try {
        earthquake = earthquakeProvider.mapEarthquakes.firstWhere(
          (eq) => eq.id == earthquakeId,
        );
      } catch (e) {
        SecureLogger.warning("Earthquake $earthquakeId not found in cached data");
      }
    }
    
    if (earthquake != null) {
      // Navigate to earthquake details screen
      Navigator.of(context).push(
        AppPageTransitions.slideRoute(
          page: EarthquakeDetailsScreen(earthquake: earthquake),
        ),
      );
      SecureLogger.success("Navigated to earthquake details: ${earthquake.place}");
    } else {
      // If earthquake not found, reload data and show a message
      SecureLogger.info("Earthquake not in cache, triggering data reload");
      earthquakeProvider.loadData().then((_) {
        // Check if context is still mounted after async operation
        final currentContext = navigatorKey.currentContext;
        if (currentContext == null || !currentContext.mounted) {
          SecureLogger.warning("Context no longer valid after data reload");
          return;
        }
        
        // Try again after reload
        try {
          final reloadedEarthquake = earthquakeProvider.listEarthquakes.firstWhere(
            (eq) => eq.id == earthquakeId,
          );
          Navigator.of(currentContext).push(
            AppPageTransitions.slideRoute(
              page: EarthquakeDetailsScreen(earthquake: reloadedEarthquake),
            ),
          );
          SecureLogger.success("Navigated to earthquake after reload");
        } catch (e) {
          SecureLogger.error("Earthquake not found even after reload", e);
          _showEarthquakeNotFoundSnackbar(currentContext);
        }
      }).catchError((error) {
        SecureLogger.error("Failed to reload earthquake data", error);
        final currentContext = navigatorKey.currentContext;
        if (currentContext != null && currentContext.mounted) {
          _showEarthquakeNotFoundSnackbar(currentContext);
        }
      });
    }
  }
  
  /// Show a snackbar when earthquake cannot be found
  void _showEarthquakeNotFoundSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Earthquake details not available'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Send token to your backend server for targeted notifications
  /// 
  /// This method provides complete backend integration using the existing
  /// app infrastructure:
  /// 
  /// Flow:
  /// 1. Token is stored securely using SecureTokenService (AES-256 encrypted)
  /// 2. NotificationRegistrationCoordinator.requestSync() is called
  /// 3. Coordinator triggers SettingsProvider.syncWithBackend()
  /// 4. SettingsProvider uses DeviceRepository.registerDevice()
  /// 5. DeviceRepository sends POST to backend: /api/devices/register
  /// 6. Request body: {token: string, preferences: object}
  /// 
  /// Backend Configuration:
  /// - Set SERVER_URL in .env file
  /// - Backend should handle POST /api/devices/register
  /// - Returns 200/201 on success
  /// 
  /// This method stores the token securely and triggers a backend sync
  /// through the NotificationRegistrationCoordinator, which uses DeviceRepository
  Future<void> _sendTokenToServer(String token) async {
    try {
      // Store token securely in encrypted storage
      await SecureTokenService.instance.storeFCMToken(token);
      SecureLogger.success("FCM token stored securely");
      
      // Trigger backend sync through NotificationRegistrationCoordinator
      // This will call SettingsProvider.syncWithBackend() which uses
      // DeviceRepository.registerDevice() to send token and preferences
      await NotificationRegistrationCoordinator.requestSync();
      SecureLogger.success("Backend sync requested for new token");
    } catch (e) {
      SecureLogger.error("Failed to send token to server", e);
    }
  }

  /// Subscribe to a topic for receiving notifications
  Future<void> subscribeToTopic(String topic) async {
    if (!_isInitialized || _messaging == null) {
      SecureLogger.warning(
        "Cannot subscribe to topic: Firebase Messaging not initialized",
      );
      return;
    }

    try {
      await _messaging!.subscribeToTopic(topic);
      SecureLogger.success("Subscribed to topic: $topic");
    } catch (e) {
      SecureLogger.error("Failed to subscribe to topic", e);
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_isInitialized || _messaging == null) {
      SecureLogger.warning(
        "Cannot unsubscribe from topic: Firebase Messaging not initialized",
      );
      return;
    }

    try {
      await _messaging!.unsubscribeFromTopic(topic);
      SecureLogger.success("Unsubscribed from topic: $topic");
    } catch (e) {
      SecureLogger.error("Failed to unsubscribe from topic", e);
    }
  }
}
