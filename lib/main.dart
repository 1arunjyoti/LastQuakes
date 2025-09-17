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
  try {
    await NotificationService.instance.showFCMNotification(message);
  } catch (e) {
    debugPrint('Error showing background notification: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first
  await Firebase.initializeApp();

  // Set up background message handler right after Firebase init
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Preload SharedPreferences for synchronous access (e.g., for ThemeProvider)
  final prefs = await SharedPreferences.getInstance();

  // Set up foreground message listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("Foreground message received: \${message.messageId}");
    NotificationService.instance.showFCMNotification(message);
  });

  // Set up token refresh listener
  FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
    debugPrint("🔄 FCM Token refreshed: \${token.substring(0, 15)}...");
    try {
      await prefs.setString('fcm_token', token);
      await NotificationService.instance.updateBackendRegistration();
    } catch (e) {
      debugPrint("❌ Error handling token refresh: \$e");
    }
  });
  // End of Firebase Messaging setup
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(prefs: prefs)..loadPreferences(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Defer non-critical initializations until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }
  // Consolidated initialization logic
  Future<void> _initializeServices() async {
    debugPrint("🚀 Starting post-frame initializations...");
    try {
      // Initialize local notifications
      await NotificationService.instance.initNotifications();

      // Store initial FCM token
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        debugPrint("📲 Initial FCM Token: \${fcmToken.substring(0, 15)}...");
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', fcmToken);
      }

      // Request permissions and perform initial backend registration
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint(
        "ℹ️ FCM Notification permission status: \${settings.authorizationStatus}",
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint("🚀 Triggering initial backend registration...");
        await NotificationService.instance.initialRegisterOrUpdate();
      } else {
        debugPrint(
          "⚠️ FCM permission denied. Registration will be attempted, but notifications may not be received.",
        );
        await NotificationService.instance.initialRegisterOrUpdate();
      }
    } catch (e) {
      debugPrint("❌ Error during post-frame initializations: \$e");
    }
    debugPrint("✅ Post-frame initializations complete.");
  }

  // Build method with theme management
  @override
  Widget build(BuildContext context) {
    return Selector<ThemeProvider, ThemeMode>(
      selector: (context, provider) => provider.themeMode,
      builder: (context, themeMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LastQuakes',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: child,
        );
      },
      // Pre-build child widget to avoid unnecessary rebuilds
      child: const NavigationHandler(),
    );
  }
}
