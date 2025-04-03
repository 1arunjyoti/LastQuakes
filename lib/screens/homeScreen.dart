import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lastquake/screens/earthquake_list.dart';
import 'package:lastquake/screens/earthquake_map_screen.dart';
import 'package:lastquake/screens/notification_screen.dart';
//import 'package:lastquake/services/notification_service.dart';

class NavigationHandler extends StatefulWidget {
  final List<Map<String, dynamic>> earthquakes;

  const NavigationHandler({Key? key, required this.earthquakes})
    : super(key: key);

  @override
  _NavigationHandlerState createState() => _NavigationHandlerState();
}

class _NavigationHandlerState extends State<NavigationHandler> {
  // Use a final list to store screen widgets for performance
  late final List<Widget?> _screens;
  int _currentIndex = 0;
  //final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // Initialize screens once in initState for better performance
    _screens = List.filled(3, null, growable: false);

    // Use the consolidated notification method from NotificationService
    //_processInitialEarthquakes();
  }

  // Process earthquakes when app starts, using the consolidated method
  /* void _processInitialEarthquakes() async {
    await _notificationService.processEarthquakeNotifications(
      widget.earthquakes,
    );
  } */

  Widget _loadScreen(int index) {
    if (_screens[index] == null) {
      switch (index) {
        case 0:
          _screens[index] = EarthquakeListScreen(
            earthquakes: widget.earthquakes,
          );
          break;
        case 1:
          _screens[index] = EarthquakeMapScreen(
            earthquakes: widget.earthquakes,
          );
          break;
        case 2:
          _screens[index] = const NotificationScreen();
          break;
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
            icon: FaIcon(FontAwesomeIcons.map),
            activeIcon: FaIcon(FontAwesomeIcons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.bell),
            activeIcon: FaIcon(FontAwesomeIcons.bell),
            label: 'Notifications',
          ),
        ],
      ),
    );
  }
}
