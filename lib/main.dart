import 'package:flutter/material.dart';
//import 'package:lastquake/screens/earthquake_list.dart';
import 'package:lastquake/screens/homeScreen.dart';
import 'package:lastquake/services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LastQuakes',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FutureBuilder(
        future: ApiService.fetchEarthquakes(minMagnitude: 3.0, days: 45),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ); // Show loading only once
          } else if (snapshot.hasError) {
            return const Scaffold(body: Center(child: Text('Error')));
          } else if (snapshot.hasData) {
            return NavigationHandler(earthquakes: snapshot.data!);
          } else {
            return const Scaffold(body: Center(child: Text('No data')));
          }
        },
      ),
    );
  }
}
