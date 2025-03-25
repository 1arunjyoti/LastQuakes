import 'package:flutter/material.dart';
import 'package:lastquake/screens/earthquake_list.dart';
import 'package:lastquake/screens/earthquake_map_screen.dart';
import 'package:lastquake/screens/news/news_screen.dart';

class NavigationHandler extends StatefulWidget {
  final List<Map<String, dynamic>> earthquakes;

  const NavigationHandler({Key? key, required this.earthquakes})
    : super(key: key);

  @override
  _NavigationHandlerState createState() => _NavigationHandlerState();
}

class _NavigationHandlerState extends State<NavigationHandler> {
  // Use a final list to store screen widgets for performance
  late final List<Widget> _screens;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize screens once in initState for better performance
    _screens = [
      EarthquakeListScreen(earthquakes: widget.earthquakes),
      EarthquakeMapScreen(earthquakes: widget.earthquakes),
      const NewsScreen(),
    ];
  }

  void _onBottomNavTap(int index) {
    // Extract navigation logic to a separate method
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
        // Add color and styling for better UX
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.newspaper_outlined),
            activeIcon: Icon(Icons.newspaper),
            label: 'News',
          ),
        ],
      ),
    );
  }
}
