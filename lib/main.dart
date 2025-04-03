import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lastquake/provider/theme_provider.dart';
import 'package:lastquake/screens/homeScreen.dart';
import 'package:lastquake/services/api_service.dart';
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
  //Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  //Initialize Firebase Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  //Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initNotifications();

  //Request FCM permission
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

  print("🔔 Notification permission: ${settings.authorizationStatus}");

  // Add topic subscription
  await notificationService.subscribeToEarthquakeTopics();

  // Register device with server initially
  await notificationService.registerDeviceWithServer();

  // Listen for foreground FCM messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("📱 Received foreground message: ${message.messageId}");
    print("   Data: ${message.data}");
    NotificationService().showFCMNotification(message);
  });

  // Get FCM token and handle refresh
  FirebaseMessaging.instance.getToken().then((String? fcmToken) async {
    if (fcmToken != null) {
      print("📲 Initial FCM Token: ${fcmToken.substring(0, 15)}...");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', fcmToken);
      // Initial registration done above, this is just for logging/storing
    } else {
      print("Failed to get initial FCM token.");
    }
  });

  // Listen for token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((String token) async {
    print("🔄 FCM Token refreshed: ${token.substring(0, 15)}...");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    // Re-register with the new token and current preferences
    await notificationService.registerDeviceWithServer();
    // Also update topic subscriptions if needed (registerDeviceWithServer might already handle this via updateFCMTopics implicitly if prefs change)
    // await notificationService.updateFCMTopics(); // Consider if needed separately
  });

  // Handle foreground messages
  /* FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("📱 Got a message whilst in the foreground!");
    print("📱 Message data: ${message.data}");

    if (message.notification != null) {
      print(
        "📱 Message also contained a notification: ${message.notification}",
      );
      notificationService.showFCMNotification(message);
    }
  }); */

  // 🔹 Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider()..loadThemeFromPreferences(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
          home: EarthquakeInitializer(),
        );
      },
    );
  }
}

class EarthquakeInitializer extends StatefulWidget {
  @override
  _EarthquakeInitializerState createState() => _EarthquakeInitializerState();
}

class _EarthquakeInitializerState extends State<EarthquakeInitializer> {
  late Future<List<Map<String, dynamic>>> _earthquakeFuture;

  @override
  void initState() {
    super.initState();
    _earthquakeFuture = _fetchEarthquakeData();
  }

  Future<List<Map<String, dynamic>>> _fetchEarthquakeData() async {
    final prefs = await SharedPreferences.getInstance();
    double initialMinMagnitude = 3.0;
    int days = 45;

    return ApiService.fetchEarthquakes(
      minMagnitude: initialMinMagnitude,
      days: days,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _earthquakeFuture,
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator.adaptive()),
            );
          case ConnectionState.done:
            if (snapshot.hasError) {
              print("Error loading earthquakes: ${snapshot.error}");
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Error loading initial earthquake data. Please check your connection and try restarting the app. \n(${snapshot.error})',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.red),
                    ),
                  ),
                ),
              );
            }
            // Pass data even if it's empty, let screens handle empty state
            return NavigationHandler(earthquakes: snapshot.data ?? []);
            /* if (snapshot.hasData) {
              return NavigationHandler(earthquakes: snapshot.data!);
            }
            return const Scaffold(
              body: Center(child: Text('No earthquake data available')),
            ) */
            ;
          default:
            return const Scaffold(
              body: Center(
                child: Text('Initializing...'),
              ), // Placeholder for other states
            );
        }
      },
    );
  }
}
