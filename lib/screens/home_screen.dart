import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lastquake/screens/earthquake_list.dart';
import 'package:lastquake/screens/earthquake_map_screen.dart';

class NavigationHandler extends StatefulWidget {
  const NavigationHandler({super.key});

  @override
  State<NavigationHandler> createState() => _NavigationHandlerState();
}

class _NavigationHandlerState extends State<NavigationHandler> {
  int _currentIndex = 0;

  // Store the screen widgets in a final list.
  final List<Widget> _screens = const [
    EarthquakeListScreen(),
    EarthquakeMapScreen(),
  ];
  // Handle bottom navigation tap
  void _onBottomNavTap(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate responsive height, e.g., 8% of screen height, clamped between 60 and 80
    final screenHeight = MediaQuery.of(context).size.height;
    final responsiveNavBarHeight = (screenHeight * 0.08).clamp(60.0, 80.0);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onBottomNavTap,
        height: responsiveNavBarHeight, 
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: FaIcon(FontAwesomeIcons.earthAsia),
            selectedIcon: FaIcon(FontAwesomeIcons.earthAsia),
            label: 'Map',
          ),
        ],
      ),
    );
  }
}
