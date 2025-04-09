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
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        // Screens are loaded via _loadScreen which handles lazy initialization
        children: List.generate(_screens.length, (index) => _loadScreen(index)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.house),
            activeIcon: FaIcon(FontAwesomeIcons.house),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.earthAsia),
            activeIcon: FaIcon(FontAwesomeIcons.earthAsia),
            label: 'Map',
          ),
          /* BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.gear),
            activeIcon: FaIcon(FontAwesomeIcons.gear),
            label: 'Settings',
          ), */
        ],
      ),
    );
  }
}
