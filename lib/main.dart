import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lastquakes/models/earthquake_adapter.dart';
import 'package:lastquakes/provider/theme_provider.dart';
import 'package:lastquakes/screens/home_screen.dart';
import 'package:lastquakes/screens/onboarding_screen.dart';
import 'package:lastquakes/services/analytics_service.dart';
import 'package:lastquakes/services/earthquake_cache_service.dart';
import 'package:lastquakes/services/multi_source_api_service.dart';
import 'package:lastquakes/services/notification_service.dart';
import 'package:lastquakes/services/secure_storage_service.dart';
import 'package:lastquakes/services/secure_token_service.dart';
import 'package:lastquakes/services/token_migration_service.dart';
import 'package:lastquakes/theme/app_theme.dart';
import 'package:lastquakes/utils/notification_registration_coordinator.dart';
import 'package:lastquakes/utils/secure_logger.dart';
import 'package:lastquakes/data/repositories/earthquake_repository_impl.dart';
import 'package:lastquakes/domain/usecases/get_earthquakes_usecase.dart';
import 'package:lastquakes/presentation/providers/earthquake_provider.dart';
import 'package:lastquakes/presentation/providers/settings_provider.dart';
import 'package:lastquakes/presentation/providers/map_picker_provider.dart';
import 'package:lastquakes/data/repositories/settings_repository_impl.dart';
import 'package:lastquakes/data/repositories/device_repository_impl.dart';
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
    SecureLogger.error('Error showing background notification', e);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Parallelize independent Phase 1 initializations
  final phase1Results = await Future.wait<dynamic>([
    dotenv.load(fileName: ".env"),
    Hive.initFlutter(),
    // Initialize Firebase if supported or configured (Mobile only)
    !kIsWeb
        ? (Firebase.initializeApp() as Future<dynamic>).catchError((e) {
          SecureLogger.error("Firebase initialization failed", e);
          return null;
        })
        : Future.value(null),
    SharedPreferences.getInstance(),
    !kIsWeb
        ? SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ])
        : Future.value(null),
  ]);

  // Extract results from parallel operations
  final prefs = phase1Results[3] as SharedPreferences;

  // Register Hive adapters (must happen after Hive init)
  Hive.registerAdapter(EarthquakeAdapter());
  SecureLogger.success("Hive initialized with Earthquake adapter");

  // Initialize Analytics and Crashlytics (after Firebase init)
  if (!kIsWeb) {
    await AnalyticsService.instance.initialize();
    await AnalyticsService.instance.logAppOpen();
  }

  // Set up Firebase background message handler
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Parallelize Phase 2: Secure storage and local notifications initialization
  await Future.wait([
    SecureStorageService.initialize().catchError((e) {
      SecureLogger.error("Secure storage initialization failed", e);
    }),
    if (!kIsWeb)
      NotificationService.instance.initNotifications().catchError((e) {
        SecureLogger.error("Notification initialization failed", e);
      }),
  ]);
  SecureLogger.success("Secure storage service initialized");

  // Migrate tokens (depends on secure storage being initialized)
  await TokenMigrationService.migrateTokenIfNeeded();

  // Start background initializations (non-blocking)
  if (!kIsWeb) {
    _runBackgroundInitializations();
  }

  final bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  // Initialize MultiSourceApiService
  final apiService = await MultiSourceApiService.create();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => ThemeProvider(prefs: prefs)..loadPreferences(),
        ),
        ChangeNotifierProvider(
          create:
              (context) => EarthquakeProvider(
                getEarthquakesUseCase: GetEarthquakesUseCase(
                  EarthquakeRepositoryImpl(apiService),
                ),
              )..init(), // Only loads preferences, not data
        ),
        ChangeNotifierProvider(
          create:
              (context) => SettingsProvider(
                settingsRepository: SettingsRepositoryImpl(apiService),
                deviceRepository: DeviceRepositoryImpl(),
              )..loadSettings(),
        ),
        ChangeNotifierProvider(create: (_) => MapPickerProvider()),
      ],
      child: MyApp(seenOnboarding: seenOnboarding, prefs: prefs),
    ),
  );
}

/// Run background initializations that don't block app startup
Future<void> _runBackgroundInitializations() async {
  if (kIsWeb) return;

  // Store initial FCM token securely
  String? fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken != null) {
    SecureLogger.token("Initial FCM Token obtained", token: fcmToken);
    await SecureTokenService.instance.storeFCMToken(fcmToken);
    await NotificationRegistrationCoordinator.requestSync();
  }

  // Request permissions and perform initial backend registration
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

  await NotificationRegistrationCoordinator.requestSync();

  // Set up foreground message listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    SecureLogger.firebase("Foreground message received");
    NotificationService.instance.showFCMNotification(message);
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
}

class MyApp extends StatefulWidget {
  final bool seenOnboarding;
  final SharedPreferences prefs;

  const MyApp({super.key, required this.seenOnboarding, required this.prefs});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    EarthquakeCacheService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'LastQuakes',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home:
              widget.seenOnboarding
                  ? const NavigationHandler()
                  : OnboardingScreen(prefs: widget.prefs),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
