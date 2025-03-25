import 'package:flutter/material.dart';
import 'package:lastquake/provider/theme_provider.dart';
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
          _buildCloseButton(context),
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
        children: [
          _buildAppInfo(),
          _buildDarkModeToggle(context, themeProvider),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return const Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildDarkModeToggle(
    BuildContext context,
    ThemeProvider themeProvider,
  ) {
    return IconButton(
      icon: Icon(
        themeProvider.themeMode == ThemeMode.dark
            ? Icons.light_mode
            : Icons.dark_mode,
        color: Colors.white,
      ),
      tooltip: 'Toggle Theme',
      onPressed: () {
        // Directly call toggle method
        themeProvider.toggleTheme();
      },
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
      leading: Icon(icon, color: Colors.blueGrey.shade800, semanticLabel: text),
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

  Widget _buildCloseButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        icon: const Icon(Icons.keyboard_double_arrow_left),
        label: const Text("Close"),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }
}
