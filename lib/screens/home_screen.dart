import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lastquake/presentation/providers/earthquake_provider.dart';
import 'package:lastquake/screens/earthquake_list.dart';
import 'package:lastquake/screens/earthquake_map_screen.dart';
import 'package:provider/provider.dart';

class NavigationHandler extends StatefulWidget {
  const NavigationHandler({super.key});

  @override
  State<NavigationHandler> createState() => _NavigationHandlerState();
}

class _NavigationHandlerState extends State<NavigationHandler> {
  int _currentIndex = 0;

  // Cache for lazy-loaded screens (only load when needed)
  final Map<int, Widget> _screenCache = {};

  // Handle bottom navigation tap
  void _onBottomNavTap(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Trigger data loading when home screen is displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EarthquakeProvider>(
        context,
        listen: false,
      ).ensureDataLoaded();
    });
  }

  /// Factory method to create or retrieve cached screen widget
  Widget _getScreen(int index) {
    // Return cached screen if available
    if (_screenCache.containsKey(index)) {
      return _screenCache[index]!;
    }

    // Lazy-load screen on-demand
    final Widget screen;
    switch (index) {
      case 0:
        screen = const EarthquakeListScreen();
        break;
      case 1:
        screen = const EarthquakeMapScreen();
        break;
      default:
        screen = const EarthquakeListScreen();
    }

    // Cache for future use (avoid recreating)
    _screenCache[index] = screen;
    return screen;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate responsive height, e.g., 8% of screen height, clamped between 60 and 80
    final screenHeight = MediaQuery.of(context).size.height;
    final responsiveNavBarHeight = (screenHeight * 0.08).clamp(60.0, 80.0);

    return Scaffold(
      body: _getScreen(_currentIndex),
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
