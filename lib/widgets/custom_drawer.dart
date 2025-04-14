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

    // Using NavigationDrawer for Material 3
    return Theme(
      data: Theme.of(context).copyWith(
        drawerTheme: const DrawerThemeData(
          // Ensure no rounded corners by setting shape here
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      child: NavigationDrawer(
        // Ensure no rounded corners
        // Shape is now handled by the Theme wrapper
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedIndex: _selectedIndex,
        // Use onDestinationSelected for navigation logic
        onDestinationSelected: (index) {
          // Update the state to show selection highlight
          setState(() {
            _selectedIndex = index;
          });

          // Close the drawer first
          Navigator.pop(context);

          // Navigate to the selected screen
          // Use a short delay to allow drawer to close before navigating,
          // preventing potential visual glitches.
          Future.delayed(const Duration(milliseconds: 150), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _destinations[index].screen,
              ),
            );
            // Optionally, reset selection after navigation if you don't
            // want the item to stay selected after returning to the main screen.
            // setState(() {
            //   _selectedIndex = null;
            // });
          });
        },
        children: [
          // Re-use the existing header, adapt padding if needed
          _buildDrawerHeader(context, themeProvider),
          Divider(),
          // Map ALL destinations, separating footer items with a Divider

          // Main destinations (first 3 items)
          ..._destinations
              .take(3)
              .map(
                (item) => NavigationDrawerDestination(
                  icon: Icon(item.icon),
                  label: Text(item.label),
                ),
              ),
          // Add padding and a divider before footer items
          Divider(),
          // Footer destinations (remaining items)
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

  Widget _buildDrawerHeader(BuildContext context, ThemeProvider themeProvider) {
    // Keep header, maybe adjust padding/color if needed for M3 look
    return Container(
      // Use M3 recommended padding for header content
      padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
      width: double.infinity,
      // Remove explicit color to use NavigationDrawer's surface color
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildAppInfo(context)],
      ),
    );
  }

  Widget _buildAppInfo(BuildContext context) {
    // Adjusted text styles slightly for M3 feel
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Earthquake App",
            style: TextStyle(
              // Use headlineSmall or titleLarge from theme?
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color:
                  Theme.of(
                    context,
                  ).colorScheme.onSurface, // Use onSurface color
            ),
          ),
          Text(
            "Stay Informed, Stay Safe",
            style: TextStyle(
              // Use bodyMedium from theme?
              color:
                  Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant, // Use onSurfaceVariant
            ),
          ),
        ],
      ),
    );
  }

  // _buildMenuItems is no longer needed as items are built directly in build()

  // _buildDrawerItem is no longer needed, replaced by NavigationDrawerDestination
}
