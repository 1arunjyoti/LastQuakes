import 'package:flutter/material.dart';
import 'package:lastquake/widgets/appbar.dart'; // Your custom AppBar
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // For links

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appName = 'LastQuakes'; // Default App Name
  String _version = '...'; // Placeholder for version
  String _buildNumber = ''; // Placeholder for build number

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appName =
              info.appName.isNotEmpty
                  ? info.appName
                  : 'LastQuakes'; // Use package name if available
          _version = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (e) {
      debugPrint("Error loading package info: $e");
    }
  }

  // Helper to launch URL safely
  Future<void> _launchUrlHelper(String urlString, BuildContext context) async {
    final Uri url = Uri.parse(urlString);
    try {
      bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $urlString')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error launching URL: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: LastQuakesAppBar(title: 'About $_appName'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 20),

            // App Icon (Using a generic one here, replace with your actual logo)
            Icon(
              Icons
                  .track_changes_outlined, // Or Icons.public, or your custom logo asset
              size: 80,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),

            // App Name
            Text(
              _appName,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),

            // Version Info
            Text(
              'Version $_version${_buildNumber.isNotEmpty ? ' ($_buildNumber)' : ''}',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // App Description
            Text(
              'Providing near real-time earthquake information from around the globe to help you stay informed and prepared.', // Customize this
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Data Source Section
            _buildInfoSection(
              context: context,
              title: 'Data Source',
              icon: Icons.cloud_circle_outlined,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Earthquake data is provided by the U.S. Geological Survey (USGS).',
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap:
                        () => _launchUrlHelper(
                          'https://earthquake.usgs.gov/',
                          context,
                        ),
                    child: Text(
                      'Visit USGS Earthquake Hazards Program',
                      style: TextStyle(
                        color: colorScheme.primary, // Make it look like a link
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Open Source Licenses
            ListTile(
              leading: Icon(
                Icons.description_outlined,
                color: colorScheme.secondary,
              ),
              title: const Text('Open Source Licenses'),
              subtitle: const Text(
                'View licenses for packages used in this app.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => showLicensePage(
                    context: context,
                    applicationName: _appName,
                    applicationVersion: _version,
                    // Optional: Add your logo here too
                    // applicationIcon: Padding(
                    //   padding: const EdgeInsets.all(8.0),
                    //   child: Icon(Icons.track_changes_outlined, size: 40, color: colorScheme.primary),
                    // ),
                  ),
            ),

            // Optional: Add Privacy Policy / Terms of Service links if needed
            const SizedBox(height: 8),
            const Divider(),
            _buildLinkItem(
              context: context,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              url: 'YOUR_PRIVACY_POLICY_URL_HERE',
            ),
            _buildLinkItem(
              context: context,
              icon: Icons.gavel_outlined,
              title: 'Terms of Service',
              url: 'YOUR_TERMS_URL_HERE',
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Helper widget for sections like Data Source
  Widget _buildInfoSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.colorScheme.secondary, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 36.0), // Indent content
          child: DefaultTextStyle(
            // Ensure text style consistency
            style: theme.textTheme.bodyMedium!,
            child: content,
          ),
        ),
      ],
    );
  }

  // Optional helper for simple link list items
  Widget _buildLinkItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String url,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      title: Text(title),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => _launchUrlHelper(url, context),
    );
  }
}
