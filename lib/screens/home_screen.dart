import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lastquake/presentation/providers/earthquake_provider.dart';
import 'package:lastquake/screens/earthquake_list.dart';
import 'package:lastquake/screens/earthquake_map_screen.dart';
import 'package:lastquake/screens/statistics_screen.dart';
import 'package:lastquake/screens/web_dashboard_screen.dart';
import 'package:provider/provider.dart';

class NavigationHandler extends StatefulWidget {
  const NavigationHandler({super.key});

  @override
  State<NavigationHandler> createState() => _NavigationHandlerState();
}

class _NavigationHandlerState extends State<NavigationHandler> {
  int _currentIndex = 0;

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

  /// Factory method to create screen widget
  Widget _getScreen(int index, bool isWide) {
    // For wide screens, show Dashboard for index 0, Map for index 1
    if (isWide && index == 0) {
      return const WebDashboardScreen();
    }

    switch (index) {
      case 0:
        return const EarthquakeListScreen();
      case 1:
        return const EarthquakeMapScreen();
      case 2:
        return const StatisticsScreen();
      default:
        return const EarthquakeListScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      bottomNavigationBar:
          isWide
              ? null
              : NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onBottomNavTap,
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
                  NavigationDestination(
                    icon: Icon(Icons.analytics_outlined),
                    selectedIcon: Icon(Icons.analytics),
                    label: 'Stats',
                  ),
                ],
              ),
      body:
          isWide
              ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _onBottomNavTap,
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: Text('Dashboard'),
                      ),
                      NavigationRailDestination(
                        icon: FaIcon(FontAwesomeIcons.map),
                        selectedIcon: FaIcon(FontAwesomeIcons.map),
                        label: Text('Map'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.analytics_outlined),
                        selectedIcon: Icon(Icons.analytics),
                        label: Text('Stats'),
                      ),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(child: _getScreen(_currentIndex, true)),
                ],
              )
              : _getScreen(_currentIndex, false),
    );
  }
}
