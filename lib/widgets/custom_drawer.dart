import 'package:flutter/material.dart';
import 'package:lastquake/provider/theme_provider.dart';
import 'package:lastquake/screens/settings_screen.dart';
import 'package:lastquake/screens/subscreens/about_screen.dart';
import 'package:lastquake/screens/subscreens/emergency_contacts_screen.dart';
import 'package:lastquake/screens/subscreens/preparedness_screen.dart';
import 'package:lastquake/screens/subscreens/quiz_screen.dart';
import 'package:provider/provider.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDrawerHeader(context, themeProvider),
          Expanded(child: _buildMenuItems(context)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              // Use Column for footer items
              children: [
                _buildFooterItem(
                  // Example helper
                  context: context,
                  icon: Icons.settings_outlined,
                  text: "Settings",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildFooterItem(
                  context: context,
                  icon: Icons.info_outline,
                  text: "About",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      width: double.infinity,
      color: Theme.of(context).primaryColor,

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildAppInfo()],
      ),
    );
  }

  Widget _buildAppInfo() {
    return const Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.public,
            size: 40,
            color: Colors.white,
            semanticLabel: 'Earthquake App Icon',
          ),
          SizedBox(height: 10),
          Text(
            "Earthquake App",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            "Stay Informed, Stay Safe",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildDrawerItem(
          icon: Icons.warning_amber_rounded,
          text: "Preparedness & Safety",
          context: context,
          screen: const PreparednessScreen(),
        ),
        _buildDrawerItem(
          icon: Icons.phone,
          text: "Emergency Contacts",
          context: context,
          screen: EmergencyContactsScreen(),
        ),
        _buildDrawerItem(
          icon: Icons.quiz,
          text: "Test Your Knowledge",
          context: context,
          screen: const QuizScreen(),
        ),
      ],
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required BuildContext context,
    Widget? screen,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, semanticLabel: text),
      title: Text(text, style: const TextStyle(fontSize: 16)),
      onTap:
          onTap ??
          () {
            // Close the drawer first
            Navigator.pop(context);

            // Navigate to the specified screen
            if (screen != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => screen),
              );
            }
          },
    );
  }

  // Helper for footer items (similar to _buildDrawerItem but maybe simpler)
  Widget _buildFooterItem({
    required BuildContext context,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
