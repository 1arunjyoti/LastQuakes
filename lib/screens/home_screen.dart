import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lastquake/screens/earthquake_list.dart';
import 'package:lastquake/screens/earthquake_map_screen.dart';
//import 'package:lastquake/screens/settings_screen.dart';

class NavigationHandler extends StatefulWidget {
  const NavigationHandler({Key? key}) : super(key: key);

  @override
  _NavigationHandlerState createState() => _NavigationHandlerState();
}

class _NavigationHandlerState extends State<NavigationHandler> {
  // Use a final list to store screen widgets for performance
  late final List<Widget?> _screens;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _screens = List.filled(2, null, growable: false);
  }

  Widget _loadScreen(int index) {
    // Lazy load screens
    if (_screens[index] == null) {
      switch (index) {
        case 0:
          // Pass NO initial data, screen will fetch it
          _screens[index] = const EarthquakeListScreen();
          break;
        case 1:
          // Pass NO initial data, screen will fetch it
          _screens[index] = const EarthquakeMapScreen();
          break;
        /* case 2:
          _screens[index] = const SettingsScreen();
          break; */
        default: // Handle potential invalid index gracefully
          _screens[index] = Center(child: Text("Invalid Screen Index: $index"));
      }
    }
    return _screens[index]!;
  }

  void _onBottomNavTap(int index) {
    if (_currentIndex != index) {
      // Avoid unnecessary rebuilds if same tab tapped
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
      body: IndexedStack(
        index: _currentIndex,
        // Screens are loaded via _loadScreen which handles lazy initialization
        children: List.generate(_screens.length, (index) => _loadScreen(index)),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onBottomNavTap,
        height: responsiveNavBarHeight, // Use calculated responsive height
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
