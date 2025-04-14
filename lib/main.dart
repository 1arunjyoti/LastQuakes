import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lastquake/provider/theme_provider.dart';
import 'package:lastquake/screens/home_screen.dart';
import 'package:lastquake/services/notification_service.dart';
import 'package:lastquake/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Handle Firebase background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background handling
  await Firebase.initializeApp();
  // Use a try-catch block for robustness in background isolate
  try {
    await NotificationService.instance.showFCMNotification(message);
  } catch (e) {
    debugPrint('Error showing background notification: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first, as other services might depend on it
  await Firebase.initializeApp();

  // Set up background message handler *after* Firebase init
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Preload SharedPreferences - can happen concurrently
  final prefsFuture = SharedPreferences.getInstance();

  // Initialize notification service (local notifications part)
  // Moved initialization here, can happen concurrently with prefs
  final notificationInitFuture =
      NotificationService.instance.initNotifications();

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("Foreground message received: ${message.messageId}");
    NotificationService.instance.showFCMNotification(message);
  });

  // Handle token refresh - Update backend when token changes
  FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
    debugPrint("🔄 FCM Token refreshed: ${token.substring(0, 15)}...");
    // Update token in prefs and trigger backend update
    try {
      final prefs = await prefsFuture;
      await prefs.setString('fcm_token', token); // Store the new token
      await NotificationService.instance.updateBackendRegistration();
    } catch (e) {
      debugPrint("❌ Error handling token refresh: $e");
    }
  });

  // Wait for essential initializations to complete before running the app
  final prefs = await prefsFuture;
  await notificationInitFuture; // Ensure notification service init is done

  // Perform initial token storage and backend registration *after* main initializations
  _postFrameInitializations();

  runApp(
    ChangeNotifierProvider(
      // Pass the already awaited SharedPreferences instance
      create: (context) => ThemeProvider(prefs: prefs)..loadPreferences(),
      child: const MyApp(),
    ),
  );
}

// Non-blocking initializations that can run after the first frame
Future<void> _postFrameInitializations() async {
  debugPrint("🚀 Starting post-frame initializations...");
  // Store initial FCM token
  await _storeInitialFcmToken();

  // Perform initial backend registration
  await _requestPermissionAndRegister();
  debugPrint("✅ Post-frame initializations complete.");
}

// Helper function to store the initial FCM token
Future<void> _storeInitialFcmToken() async {
  try {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      debugPrint("📲 Initial FCM Token: ${fcmToken.substring(0, 15)}...");
      SharedPreferences prefs =
          await SharedPreferences.getInstance(); // Get instance again or pass from main
      await prefs.setString('fcm_token', fcmToken);
    } else {
      debugPrint("⚠️ Failed to get initial FCM token.");
    }
  } catch (e) {
    debugPrint("❌ Error getting initial FCM token: $e");
  }
}

// Helper function to request permissions and trigger initial registration
Future<void> _requestPermissionAndRegister() async {
  try {
    // Request FCM permission (required for receiving messages)
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional:
          false, // Set to true if you want silent pushes before explicit grant
    );
    debugPrint(
      "ℹ️ FCM Notification permission status: ${settings.authorizationStatus}",
    );

    // We attempt registration regardless of permission status initially.
    // The backend should ideally handle tokens from users who haven't granted
    // notification permission (e.g., by not sending them pushes).
    // The NotificationService.updateBackendRegistration already checks
    // location permissions internally if needed for the selected filter.
    // We don't need to explicitly check NotificationFilterType.none here,
    // as updateBackendRegistration sends the type to the backend.

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint("🚀 Triggering initial backend registration...");
      await NotificationService.instance.initialRegisterOrUpdate();
    } else {
      debugPrint(
        "⚠️ FCM permission denied. Backend registration will still be attempted, but notifications may not be received.",
      );
      // Still attempt registration, backend decides if it should store/use the token
      await NotificationService.instance.initialRegisterOrUpdate();
    }
  } catch (e) {
    debugPrint("❌ Error during permission request or initial registration: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // No need for initState or postFrameCallback here anymore
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LastQuakes',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const NavigationHandler(),
        );
      },
    );
  }
}
