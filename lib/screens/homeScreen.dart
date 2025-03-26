import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lastquake/screens/earthquake_list.dart';
import 'package:lastquake/screens/earthquake_map_screen.dart';
//import 'package:lastquake/screens/news/news_screen.dart';

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
      //const NewsScreen(),
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
        selectedItemColor: Color.fromRGBO(124, 122, 221, 1),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.house),
            activeIcon: FaIcon(FontAwesomeIcons.house),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.map),
            activeIcon: FaIcon(FontAwesomeIcons.map),
            label: 'Map',
          ),
          /* BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.newspaper),
            activeIcon: FaIcon(FontAwesomeIcons.newspaper),
            label: 'News',
          ), */
        ],
      ),
    );
  }
}
