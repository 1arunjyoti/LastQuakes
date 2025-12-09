import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lastquakes/models/earthquake_adapter.dart';
import 'package:lastquakes/presentation/providers/bookmark_provider.dart';
import 'package:lastquakes/provider/theme_provider.dart';
import 'package:lastquakes/screens/home_screen.dart';
import 'package:lastquakes/screens/onboarding_screen.dart';
import 'package:lastquakes/services/analytics_service.dart';
import 'package:lastquakes/services/analytics_service_firebase.dart';
import 'package:lastquakes/services/bookmark_service.dart';
import 'package:lastquakes/services/earthquake_cache_service.dart';
import 'package:lastquakes/services/multi_source_api_service.dart';
import 'package:lastquakes/services/notification_service.dart';
import 'package:lastquakes/services/push_notification_service.dart';
import 'package:lastquakes/services/push_notification_service_firebase.dart';
import 'package:lastquakes/services/secure_storage_service.dart';
import 'package:lastquakes/services/secure_token_service.dart';
import 'package:lastquakes/services/tile_cache_service.dart';
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
import 'package:lastquakes/data/repositories/device_repository_noop.dart';
import 'package:lastquakes/services/home_widget_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SecureLogger.info("Starting app in PROD mode with Firebase");

  // Production build - use Firebase services
  AnalyticsService.instance = AnalyticsServiceFirebase();
  PushNotificationService.instance = PushNotificationServiceFirebase();

  // Initialize Hive first (requires platform channels to be ready)
  await Hive.initFlutter();
  Hive.registerAdapter(EarthquakeAdapter());
  SecureLogger.success("Hive initialized with Earthquake adapter");

  // Parallelize independent Phase 1 initializations
  final phase1Results = await Future.wait<dynamic>([
    // Load .env file for production configuration
    dotenv.load(fileName: ".env").catchError((e) {
      SecureLogger.warning(
        "Warning: .env file not found or failed to load.",
      );
      return null;
    }),
    // Initialize Firebase/Push services (Mobile only)
    !kIsWeb
        ? PushNotificationService.instance.initialize().catchError((e) {
          SecureLogger.error(
            "Push notification service initialization failed",
            e,
          );
          return null;
        })
        : Future.value(null),
    SharedPreferences.getInstance(),
    !kIsWeb
        ? Future.wait([
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]),
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: SystemUiOverlay.values,
          ),
        ])
        : Future.value(null),
  ]);

  // Extract results from parallel operations
  final prefs = phase1Results[2] as SharedPreferences;

  // Initialize Analytics (after Firebase init if applicable)
  if (!kIsWeb) {
    await AnalyticsService.instance.initialize();
    await AnalyticsService.instance.logAppOpen();
  }

  // Parallelize Phase 2: Secure storage and local notifications initialization
  await Future.wait([
    SecureStorageService.initialize().catchError((e) {
      SecureLogger.error("Secure storage initialization failed", e);
    }),
    TileCacheService.instance.init().catchError((e) {
      SecureLogger.error("Tile cache initialization failed", e);
    }),
    BookmarkService.instance.init().catchError((e) {
      SecureLogger.error("Bookmark service initialization failed", e);
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

    // Initialize home screen widget (Android only, non-blocking)
    if (Platform.isAndroid) {
      HomeWidgetService().initialize();
    }
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
                deviceRepository: DeviceRepositoryNoop(),
              )..loadSettings(),
        ),
        ChangeNotifierProvider(create: (_) => MapPickerProvider()),
        ChangeNotifierProvider(
          create: (_) => BookmarkProvider()..loadBookmarks(),
        ),
      ],
      child: MyApp(seenOnboarding: seenOnboarding, prefs: prefs),
    ),
  );
}

/// Run background initializations that don't block app startup
Future<void> _runBackgroundInitializations() async {
  if (kIsWeb) return;

  // Get initial token
  String? fcmToken = await PushNotificationService.instance.getToken();
  if (fcmToken != null) {
    SecureLogger.token("Initial FCM Token obtained", token: fcmToken);
    await SecureTokenService.instance.storeFCMToken(fcmToken);
    await NotificationRegistrationCoordinator.requestSync();
  }

  // Request permissions
  await PushNotificationService.instance.requestPermission();
  await NotificationRegistrationCoordinator.requestSync();
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
          navigatorKey: PushNotificationServiceFirebase.navigatorKey,
          home:
              widget.seenOnboarding || kIsWeb
                  ? const NavigationHandler()
                  : OnboardingScreen(prefs: widget.prefs),
          debugShowCheckedModeBanner: false,
          navigatorObservers: [AnalyticsService.instance.observer],
        );
      },
    );
  }
}
