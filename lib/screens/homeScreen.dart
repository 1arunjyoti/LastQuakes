import 'package:flutter/material.dart';
import 'package:lastquake/screens/earthquake_list.dart';
import 'package:lastquake/screens/earthquake_map_screen.dart';

class NavigationHandler extends StatefulWidget {
  final List earthquakes; // Pass earthquakes data

  const NavigationHandler({Key? key, required this.earthquakes})
    : super(key: key);

  @override
  _NavigationHandlerState createState() => _NavigationHandlerState();
}

class _NavigationHandlerState extends State<NavigationHandler> {
  int _currentIndex = 0;
  /* late List<Widget> _screens; // List to hold screen widgets

  @override
  void initState() {
    super.initState();
    _screens = [
      EarthquakeListScreen(),
      EarthquakeMapScreen(earthquakes: widget.earthquakes),
    ];
  } */

  @override
  Widget build(BuildContext context) {
    /* // Add a safety check here to ensure _screens is initialized
    if (_screens == null) {
      return const Center(
        child: CircularProgressIndicator(),
      ); // Or some other loading widget
    } */
    return Scaffold(
      body: IndexedStack(
        // Use IndexedStack to preserve state
        index: _currentIndex,
        children: [
          EarthquakeListScreen(earthquakes: widget.earthquakes),
          EarthquakeMapScreen(earthquakes: widget.earthquakes),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
        ],
      ),
    );
  }

  /* Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return EarthquakeListScreen();
      case 1:
        return EarthquakeMapScreen(earthquakes: widget.earthquakes);
      default:
        return EarthquakeListScreen(); // Default to list screen
    }
  } */
}
