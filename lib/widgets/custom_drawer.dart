import 'package:flutter/material.dart';
import 'package:lastquakes/provider/theme_provider.dart';
import 'package:lastquakes/screens/bookmarks_screen.dart';
import 'package:lastquakes/screens/settings_screen.dart';
import 'package:lastquakes/screens/subscreens/about_screen.dart';
import 'package:lastquakes/screens/subscreens/emergency_contacts_screen.dart';
import 'package:lastquakes/screens/subscreens/preparedness_screen.dart';
import 'package:lastquakes/screens/subscreens/quiz_screen.dart';
import 'package:lastquakes/utils/app_page_transitions.dart';
import 'package:provider/provider.dart';

// Define a simple structure for navigation destinations
class NavigationItem {
  final IconData icon;
  final String label;
  final Widget screen;

  const NavigationItem(this.icon, this.label, this.screen);
}

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  int? _selectedIndex;

  // List of primary navigation destinations
  static final List<NavigationItem> _destinations = [
    const NavigationItem(
      Icons.warning_amber_rounded,
      "Preparedness & Safety",
      PreparednessScreen(),
    ),
    NavigationItem(
      Icons.phone,
      "Emergency Contacts",
      EmergencyContactsScreen(),
    ),
    const NavigationItem(Icons.quiz, "Test Your Knowledge", QuizScreen()),
    const NavigationItem(
      Icons.bookmark_rounded,
      "Saved Earthquakes",
      BookmarksScreen(),
    ),
    const NavigationItem(Icons.settings_outlined, "Settings", SettingsScreen()),
    const NavigationItem(Icons.info_outline, "About", AboutScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Theme(
      data: Theme.of(context).copyWith(
        drawerTheme: const DrawerThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      child: NavigationDrawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });

          // Close the drawer first
          // Close the drawer first
          final navigator = Navigator.of(context);
          navigator.pop();

          Future.delayed(const Duration(milliseconds: 150), () {
            navigator.push(
              AppPageTransitions.slideRoute(page: _destinations[index].screen),
            );
            // Reset selection after navigation if you don't
            // want the item to stay selected after returning to the main screen.
            // setState(() {
            //   _selectedIndex = null;
            // });
          });
        },
        children: [
          _buildDrawerHeader(context, themeProvider),
          Divider(),

          // Main destinations
          ..._destinations
              .take(4)
              .map(
                (item) => NavigationDrawerDestination(
                  icon: Icon(item.icon),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      item.label,
                      style: const TextStyle(fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ),
                ),
              ),
          Divider(),
          // Footer destinations
          ..._destinations
              .skip(4)
              .map(
                (item) => NavigationDrawerDestination(
                  icon: Icon(item.icon),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      item.label,
                      style: const TextStyle(fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  // Drawer header with app info
  Widget _buildDrawerHeader(BuildContext context, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildAppInfo(context)],
      ),
    );
  }

  // App info section in the drawer header
  Widget _buildAppInfo(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Earthquake App",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            "Stay Informed, Stay Safe",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
