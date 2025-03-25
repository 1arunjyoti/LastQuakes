import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lastquake/provider/theme_provider.dart';
import 'package:lastquake/screens/homeScreen.dart';
import 'package:lastquake/services/api_service.dart';
import 'package:lastquake/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  // Ensure widget binding is initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations to improve performance
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

  // Load environment variables in the background without blocking
  /* dotenv
      .load(fileName: ".env")
      .then((_) {
        // Run the app after env is loaded
        runApp(const MyApp());
      })
      .catchError((error) {
        // Fallback if env loading fails
        print('Error loading .env file: $error');
        runApp(const MyApp());
      }); */
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
  late Future<dynamic> _earthquakeFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the future once in initState
    _earthquakeFuture = ApiService.fetchEarthquakes(
      minMagnitude: 3.0,
      days: 45,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _earthquakeFuture,
      builder: (context, snapshot) {
        // Use more specific error handling
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator.adaptive()),
            );
          case ConnectionState.done:
            if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text(
                    'Error loading earthquakes: ${snapshot.error}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              );
            }
            if (snapshot.hasData) {
              return NavigationHandler(earthquakes: snapshot.data!);
            }
            return const Scaffold(
              body: Center(child: Text('No earthquake data available')),
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
