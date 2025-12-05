import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:lastquakes/models/push_message.dart';
import 'package:lastquakes/services/push_notification_service.dart';
import 'package:lastquakes/services/notification_service.dart';
import 'package:lastquakes/services/secure_token_service.dart';
import 'package:lastquakes/utils/notification_registration_coordinator.dart';
import 'package:lastquakes/utils/secure_logger.dart';

/// Convert Firebase RemoteMessage to platform-agnostic PushMessage
PushMessage _convertToPushMessage(RemoteMessage message) {
  return PushMessage(
    title: message.notification?.title,
    body: message.notification?.body,
    data: message.data,
  );
}

// Handle Firebase background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background handling
  await Firebase.initializeApp();
  try {
    await NotificationService.instance.showPushNotification(
      _convertToPushMessage(message),
    );
  } catch (e) {
    SecureLogger.error('Error showing background notification', e);
  }
}

class PushNotificationServiceFirebase implements PushNotificationService {
  @override
  Future<void> initialize() async {
    if (kIsWeb) return;

    try {
      await Firebase.initializeApp();

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Set up foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        SecureLogger.firebase("Foreground message received");
        NotificationService.instance.showPushNotification(
          _convertToPushMessage(message),
        );
      });

      // Set up token refresh listener
      FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
        SecureLogger.token("FCM Token refreshed", token: token);
        try {
          await SecureTokenService.instance.storeFCMToken(token);
          await NotificationRegistrationCoordinator.requestSync();
        } catch (e) {
          SecureLogger.error("Error handling token refresh", e);
        }
      });
    } catch (e) {
      SecureLogger.error("Firebase initialization failed", e);
    }
  }

  @override
  Future<void> requestPermission() async {
    if (kIsWeb) return;

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    SecureLogger.permission(
      "FCM Notification",
      settings.authorizationStatus.toString(),
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      SecureLogger.init("Notification permission granted");
    } else {
      SecureLogger.warning(
        "FCM permission denied. Registration will be attempted, but notifications may not be received",
      );
    }
  }

  @override
  Future<String?> getToken() async {
    if (kIsWeb) return null;
    return await FirebaseMessaging.instance.getToken();
  }
}
