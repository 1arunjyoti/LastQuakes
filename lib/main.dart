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

//Handle Firebase background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService().showFCMNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  //Initialize Firebase Messaging Background Handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Listen for foreground FCM messages (essential early setup)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("Received foreground message: ${message.messageId}");
    NotificationService().showFCMNotification(message);
  });

  // Listen for token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
    debugPrint("FCM Token refreshed: ${token.substring(0, 15)}...");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    // Re-register with the new token and current preferences
    // Ensure NotificationService can be instantiated or use a static method
    await NotificationService().registerDeviceWithServer();
  });

  // Get initial FCM token and store it (can run in parallel with UI)
  _storeInitialFcmToken();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider()..loadPreferences(),
      child: const MyApp(),
    ),
  );
}

// Helper function to store initial token without blocking main
Future<void> _storeInitialFcmToken() async {
  try {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      debugPrint(
        "📲 Initial FCM Token (async): ${fcmToken.substring(0, 15)}...",
      );
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', fcmToken);
      // Initial registration will be handled later in _initializeNotificationsAndRegistration
    } else {
      debugPrint("Failed to get initial FCM token (async).");
    }
  } catch (e) {
    debugPrint("Error getting initial FCM token (async): $e");
  }
}

// Helper function to perform deferred initializations
Future<void> _initializeNotificationsAndRegistration(
  BuildContext context,
) async {
  debugPrint("Starting deferred initialization...");
  try {
    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initNotifications(); // Local notifications init

    // Request FCM permission
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint("Notification permission: ${settings.authorizationStatus}");

    // Only proceed if permission is granted (or potentially provisional)
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Register device with server initially
      // This ensures the token stored earlier (or fetched now if needed) is registered
      await notificationService.registerDeviceWithServer();
    } else {
      debugPrint(
        "Notification permission denied. Skipping topic subscription and registration.",
      );
    }
    debugPrint("Deferred initialization complete.");
  } catch (e) {
    debugPrint("Error during deferred initialization: $e");
  }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotificationsAndRegistration(context);
    });
  }

  @override
  Widget build(BuildContext context) {
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
