import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lastquakes/widgets/appbar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appName = 'LastQuakes'; // Default App Name
  String _version = '...'; // Placeholder for version
  String _buildNumber = ''; // Placeholder for build number

  static const List<_PolicyItem> _privacyPolicySections = [
    _PolicyItem(
      heading: 'Information We Collect',
      body:
          'We access your precise or approximate location only when you enable location-based alerts. Basic, non-personal device metadata such as operating system version and language preferences may also be gathered so we can correctly display notifications.',
    ),
    _PolicyItem(
      heading: 'How Your Data Is Used',
      body:
          'Location inputs are used to personalize nearby earthquake alerts and to help you understand regional risk. Aggregated analytics help us improve reliability, and we never sell your information or use it for advertising.',
    ),
    _PolicyItem(
      heading: 'Data Sharing & Storage',
      body:
          'Earthquake information is sourced from the U.S. Geological Survey (USGS). We only share limited, anonymized data with infrastructure providers that host notifications so they can deliver messages on our behalf.',
    ),
    _PolicyItem(
      heading: 'Your Choices',
      body:
          'You can revoke location access at any time through your system settings. Notification preferences can be adjusted inside the app, and deleting the app removes cached data from your device.',
    ),
    _PolicyItem(
      heading: 'Contact',
      body:
          'Questions about privacy can be directed to https://github.com/1arunjyoti/LastQuakes. We will respond within 30 days of receiving your message.',
    ),
  ];

  static const List<_PolicyItem> _termsOfServiceSections = [
    _PolicyItem(
      heading: 'Service Description',
      body:
          'LastQuakes delivers near real-time earthquake reports and preparedness tips. The service is informational and not a substitute for official emergency directives.',
    ),
    _PolicyItem(
      heading: 'Acceptable Use',
      body:
          'You agree not to misuse the app, interfere with its infrastructure, or redistribute its data without attribution. Access may be revoked if suspicious activity is detected.',
    ),
    _PolicyItem(
      heading: 'Accounts & Notifications',
      body:
          'You are responsible for managing your device permissions and ensuring notifications are enabled if you rely on alerts. Wireless carriers may charge fees for data or push delivery.',
    ),
    _PolicyItem(
      heading: 'Disclaimer of Warranties',
      body:
          'While we strive for accuracy, earthquake reporting depends on third-party sensors and networks. We do not guarantee uninterrupted service or perfectly precise alerts.',
    ),
    _PolicyItem(
      heading: 'Changes & Contact',
      body:
          'We may update these terms to reflect new features or legal requirements. Material updates will be announced inside the app, and questions can be sent to support@lastquake.app.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  // Load app info asynchronously
  Future<void> _loadAppInfo() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          // Always use "LastQuakes" as the display name for consistency
          _appName = 'LastQuakes';
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
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
                      'Providing near real-time earthquake information from around the globe to help you stay informed and prepared.',
                      style: textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Data Source Section
                    _buildInfoSection(
                      context: context,
                      title: 'Data Source',
                      icon: Icons.cloud_circle_outlined,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Earthquake data is provided by the U.S. Geological Survey (USGS) and European-Mediterranean Seismological Centre (EMSC).',
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
                                color: colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap:
                                () => _launchUrlHelper(
                                  "https://www.emsc-csem.org/",
                                  context,
                                ),
                            child: Text(
                              'Visit EMSC Seismicity Catalog',
                              style: TextStyle(
                                color: colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),

                    const SizedBox(height: 8),
                    const Divider(),

                    // Project License
                    ListTile(
                      leading: Icon(
                        Icons.description_outlined,
                        color: colorScheme.secondary,
                      ),
                      title: const Text('Project License'),
                      subtitle: const Text(
                        'GNU General Public License v3.0',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap:
                          () => _showProjectLicense(context),
                    ),

                    const SizedBox(height: 8),
                    const Divider(),

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
                          ),
                    ),

                    const SizedBox(height: 8),
                    const Divider(),

                    // Privacy Policy & Terms of Service
                    _buildPolicyTile(
                      context: context,
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      sections: _privacyPolicySections,
                    ),
                    _buildPolicyTile(
                      context: context,
                      icon: Icons.gavel_outlined,
                      title: 'Terms of Service',
                      sections: _termsOfServiceSections,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
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
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Column(
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
            padding: const EdgeInsets.only(left: 36.0),
            child: DefaultTextStyle(
              style: theme.textTheme.bodyMedium!,
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required List<_PolicyItem> sections,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.secondary),
        title: Text(title),
        subtitle: const Text('Tap to read details'),
        trailing: const Icon(Icons.menu_book_outlined),
        onTap:
            () => _showPolicySheet(
              context: context,
              title: title,
              sections: sections,
              icon: icon,
            ),
      ),
    );
  }

  Future<void> _showPolicySheet({
    required BuildContext context,
    required String title,
    required List<_PolicyItem> sections,
    IconData? icon,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.9,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: colorScheme.secondary),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemBuilder: (_, index) {
                        final section = sections[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.heading,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              section.body,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(height: 24),
                      itemCount: sections.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showProjectLicense(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String licenseText = '';
    try {
      licenseText = await rootBundle.loadString('LICENSE');
    } catch (e) {
      licenseText = 'Failed to load LICENSE file: $e';
    }

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.9,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Project License',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'GNU General Public License v3.0',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          licenseText,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
  }
}

class _PolicyItem {
  final String heading;
  final String body;

  const _PolicyItem({required this.heading, required this.body});
}
