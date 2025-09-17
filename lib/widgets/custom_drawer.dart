import 'package:flutter/material.dart';
import 'package:lastquake/provider/theme_provider.dart';
import 'package:lastquake/screens/settings_screen.dart';
import 'package:lastquake/screens/subscreens/about_screen.dart';
import 'package:lastquake/screens/subscreens/emergency_contacts_screen.dart';
import 'package:lastquake/screens/subscreens/preparedness_screen.dart';
import 'package:lastquake/screens/subscreens/quiz_screen.dart';
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
          Navigator.pop(context);

          Future.delayed(const Duration(milliseconds: 150), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _destinations[index].screen,
              ),
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
              .take(3)
              .map(
                (item) => NavigationDrawerDestination(
                  icon: Icon(item.icon),
                  label: Text(item.label),
                ),
              ),
          Divider(),
          // Footer destinations
          ..._destinations
              .skip(3)
              .map(
                (item) => NavigationDrawerDestination(
                  icon: Icon(item.icon),
                  label: Text(item.label),
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
              color:
                  Theme.of(
                    context,
                  ).colorScheme.onSurface, 
            ),
          ),
          Text(
            "Stay Informed, Stay Safe",
            style: TextStyle(
              color:
                  Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant, 
            ),
          ),
        ],
      ),
    );
  }
}
