import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:lastquakes/screens/bookmarks_screen.dart';
import 'package:lastquakes/screens/settings_screen.dart';
import 'package:lastquakes/screens/subscreens/about_screen.dart';
import 'package:lastquakes/screens/subscreens/emergency_contacts_screen.dart';
import 'package:lastquakes/screens/subscreens/preparedness_screen.dart';
import 'package:lastquakes/screens/subscreens/quiz_screen.dart';
import 'package:lastquakes/utils/app_page_transitions.dart';

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
  // List of primary navigation destinations
  static final List<NavigationItem> _mainDestinations = [
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
  ];

  // List of secondary navigation destinations (footer)
  static final List<NavigationItem> _footerDestinations = [
    const NavigationItem(Icons.settings_outlined, "Settings", SettingsScreen()),
    const NavigationItem(Icons.info_outline, "About", AboutScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          _buildDrawerHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                ..._mainDestinations.map(
                  (item) => _buildDrawerItem(context, item, isFooter: false),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(),
                ),
                ..._footerDestinations.map(
                  (item) => _buildDrawerItem(context, item, isFooter: true),
                ),
              ],
            ),
          ),
          _buildVersionInfo(context),
        ],
      ),
    );
  }

  // Improved Gradient Header
  Widget _buildDrawerHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 24,
        bottom: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primaryContainer, colorScheme.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "LastQuakes",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Global Earthquake Monitor",
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    NavigationItem item, {
    required bool isFooter,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isFooter ? colorScheme.onSurfaceVariant : colorScheme.primary,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            fontWeight: isFooter ? FontWeight.normal : FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
        onTap: () {
          // Close the drawer first
          final navigator = Navigator.of(context);
          navigator.pop();

          // Wait for drawer close animation
          Future.delayed(const Duration(milliseconds: 200), () {
            navigator.push(AppPageTransitions.slideRoute(page: item.screen));
          });
        },
      ),
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }
          final info = snapshot.data!;
          return Text(
            "v${info.version} (${info.buildNumber})",
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 12,
            ),
          );
        },
      ),
    );
  }
}
