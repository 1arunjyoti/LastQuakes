import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lastquake/provider/theme_provider.dart';
import 'package:lastquake/services/notification_service.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification specific state
  bool _notificationEnabled = false;
  String _selectedCountry = "ALL";
  double _selectedMagnitude = 5.0;
  double? _selectedRadius;

  // Expansion state
  bool _settingsExpanded = false;
  bool _themeExpanded = false;
  bool _unitsExpanded = false;
  //bool _clockExpanded = false;

  // Data for dropdowns/sliders
  final List<String> _countryList = [
    "ALL",
    "India",
    "United States",
    "Japan",
    "Indonesia",
    "Mexico",
    "Turkey",
    "China",
    "New Zealand",
    "Italy",
    "Greece",
  ]; // Shortened for brevity

  static final List<double> _magnitudeOptions = [
    3.0,
    3.5,
    4.0,
    4.5,
    5.0,
    5.5,
    6.0,
    6.5,
    7.0,
    7.5,
    8.0,
    8.5,
    9.0,
    10.0,
  ];

  static final List<double> _radiusOptions = [
    0,
    10.0,
    25.0,
    50.0,
    100.0,
    200.0,
    500.0,
    1000.0,
  ];

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  // Load ONLY notification-related settings from SharedPreferences
  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // Check mounted before setState
    setState(() {
      _notificationEnabled = prefs.getBool('notifications_enabled') ?? false;
      _selectedCountry = prefs.getString('notification_country') ?? "ALL";
      _selectedMagnitude = prefs.getDouble('notification_magnitude') ?? 5.0;
      double? storedRadius = prefs.getDouble('notification_radius');
      _selectedRadius =
          storedRadius == null || storedRadius <= 0 ? 0 : storedRadius;

      if (!_countryList.contains(_selectedCountry)) {
        _selectedCountry = "ALL";
        prefs.setString('notification_country', _selectedCountry);
      }
    });
  }

  // Save ONLY notification-related settings
  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationEnabled);
    await prefs.setString('notification_country', _selectedCountry);
    await prefs.setDouble('notification_magnitude', _selectedMagnitude);
    // Save radius: store null if UI value is 0 ("Off")
    if (_selectedRadius != null && _selectedRadius! > 0) {
      await prefs.setDouble('notification_radius', _selectedRadius!);
    } else {
      await prefs.remove('notification_radius'); // Remove if set to 0/Off
    }

    // Update FCM topic subscriptions when settings change,now also calls registerDeviceWithServer
    await NotificationService().updateFCMTopics();

    // Optionally re-register with server when preferences change
    //await NotificationService().registerDeviceWithServer();

    // Show settings saved confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification settings saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the provider for theme, units, clock
    // Use listen: true here because the UI needs to rebuild when these change
    final prefsProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: LastQuakesAppBar(title: 'Settings'),
      //drawer: const CustomDrawer(),
      body: ListView(
        // Use ListView instead of SingleChildScrollView+Column for better scroll behavior with list
        padding: const EdgeInsets.all(12.0),
        children: [
          // --- Notification Settings Card ---
          _buildNotificationSettingsCard(),
          const SizedBox(height: 12),

          // --- Theme Settings Card ---
          _buildThemeSettingsCard(prefsProvider),
          const SizedBox(height: 12),

          // --- Units Settings Card ---
          _buildUnitsSettingsCard(prefsProvider),
          const SizedBox(height: 12),

          // --- Clock Format Settings Card ---
          _buildClockSettingsCard(prefsProvider),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // --- Build Methods for Cards (Refactored) ---

  Widget _buildNotificationSettingsCard() {
    return Card(
      margin: EdgeInsets.zero, // Let ListView handle spacing
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Notification Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: Icon(
                _settingsExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              onPressed:
                  () => setState(() => _settingsExpanded = !_settingsExpanded),
            ),
            onTap: () => setState(() => _settingsExpanded = !_settingsExpanded),
          ),
          if (_settingsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Enable Notifications"),
                    subtitle: Text(
                      _notificationEnabled
                          ? "Receiving alerts for relevant earthquakes"
                          : "Notifications are currently disabled",
                      style: TextStyle(
                        color: _notificationEnabled ? Colors.green : Colors.red,
                      ),
                    ),
                    value: _notificationEnabled,
                    onChanged: (bool value) async {
                      if (value == true) {
                        bool permissionGranted =
                            await _requestNotificationPermission();
                        if (permissionGranted) {
                          if (!mounted) return;
                          setState(() => _notificationEnabled = true);
                          await _saveNotificationSettings();
                        } else {
                          if (!mounted) return;
                          _showPermissionDeniedDialog();
                        }
                      } else {
                        if (!mounted) return;
                        setState(() => _notificationEnabled = false);
                        await _saveNotificationSettings();
                      }
                    },
                  ),
                  const Divider(height: 20),
                  AnimatedOpacity(
                    opacity: _notificationEnabled ? 1.0 : 0.5,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !_notificationEnabled,
                      child: Column(
                        children: [
                          _buildCountryDropdown(),
                          const SizedBox(height: 16),
                          _buildMagnitudeSlider(),
                          const SizedBox(height: 16),
                          _buildRadiusSlider(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThemeSettingsCard(ThemeProvider prefsProvider) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            title: const Text(
              "Theme",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: Icon(
                _themeExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              onPressed: () => setState(() => _themeExpanded = !_themeExpanded),
            ),
            onTap: () => setState(() => _themeExpanded = !_themeExpanded),
          ),
          if (_themeExpanded)
            Padding(
              padding: const EdgeInsets.only(
                bottom: 8.0,
              ), // Add padding below radios
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text("Same as Device"),
                    value: ThemeMode.system,
                    groupValue: prefsProvider.themeMode, // Read from provider
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        // Use listen: false for actions
                        Provider.of<ThemeProvider>(
                          context,
                          listen: false,
                        ).setThemeMode(value);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text("Always Light"),
                    value: ThemeMode.light,
                    groupValue: prefsProvider.themeMode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        Provider.of<ThemeProvider>(
                          context,
                          listen: false,
                        ).setThemeMode(value);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text("Always Dark"),
                    value: ThemeMode.dark,
                    groupValue: prefsProvider.themeMode,
                    onChanged: (ThemeMode? value) {
                      if (value != null) {
                        Provider.of<ThemeProvider>(
                          context,
                          listen: false,
                        ).setThemeMode(value);
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnitsSettingsCard(ThemeProvider prefsProvider) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            title: const Text(
              "Units of Measurement",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: Icon(
                _unitsExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              onPressed: () => setState(() => _unitsExpanded = !_unitsExpanded),
            ),
            onTap: () => setState(() => _unitsExpanded = !_unitsExpanded),
          ),
          if (_unitsExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                children: [
                  RadioListTile<DistanceUnit>(
                    title: const Text("Kilometers (km)"),
                    value: DistanceUnit.km,
                    groupValue:
                        prefsProvider.distanceUnit, // Read from provider
                    onChanged: (DistanceUnit? value) {
                      if (value != null) {
                        Provider.of<ThemeProvider>(
                          context,
                          listen: false,
                        ).setDistanceUnit(value);
                      }
                    },
                  ),
                  RadioListTile<DistanceUnit>(
                    title: const Text("Miles (mi)"),
                    value: DistanceUnit.miles,
                    groupValue: prefsProvider.distanceUnit,
                    onChanged: (DistanceUnit? value) {
                      if (value != null) {
                        Provider.of<ThemeProvider>(
                          context,
                          listen: false,
                        ).setDistanceUnit(value);
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClockSettingsCard(ThemeProvider prefsProvider) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: SwitchListTile(
        title: const Text(
          "Use 24-Hour Clock",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        value: prefsProvider.use24HourClock, // Read from provider
        onChanged: (bool value) {
          Provider.of<ThemeProvider>(
            context,
            listen: false,
          ).setUse24HourClock(value);
        },
        secondary: Icon(
          prefsProvider.use24HourClock
              ? Icons.access_time_filled
              : Icons.access_time,
        ),
      ),
      // Optionally wrap in expansion tile like others if desired
      /*
       child: Column(
         children: [
           ListTile( ... expansion logic ... ),
           if (_clockExpanded)
             Padding(...) // Put the SwitchListTile here
         ]
       )
       */
    );
  }

  Widget _buildCountryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCountry,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: "Country",
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items:
          _countryList.map((country) {
            return DropdownMenuItem<String>(
              value: country,
              child: Text(country),
            );
          }).toList(),
      onChanged:
          !_notificationEnabled
              ? null
              : (value) {
                // Disable if needed
                if (value != null && value != _selectedCountry) {
                  setState(() => _selectedCountry = value);
                  _saveNotificationSettings();
                }
              },
    );
  }

  Widget _buildMagnitudeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Minimum Magnitude (≥ ${_selectedMagnitude.toStringAsFixed(1)})"),
        Slider(
          value: _selectedMagnitude,
          min: _magnitudeOptions.first,
          max: _magnitudeOptions.last,
          divisions:
              ((_magnitudeOptions.last - _magnitudeOptions.first) * 2)
                  .toInt(), // Finer steps
          label: "≥ ${_selectedMagnitude.toStringAsFixed(1)}",
          onChanged:
              !_notificationEnabled
                  ? null
                  : (value) {
                    setState(() {
                      // Round to nearest 0.5 for label consistency if desired, or keep precise
                      _selectedMagnitude = (value * 2).round() / 2;
                    });
                  },
          onChangeEnd: (value) {
            // Save only when interaction ends
            if (_notificationEnabled) _saveNotificationSettings();
          },
        ),
      ],
    );
  }

  Widget _buildRadiusSlider() {
    String radiusLabel;
    if (_selectedRadius == null || _selectedRadius == 0) {
      radiusLabel = "Off";
    } else {
      radiusLabel = "${_selectedRadius!.toStringAsFixed(0)} km";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Notify within Radius ($radiusLabel)"),
        Slider(
          value: _selectedRadius ?? 0, // Use 0 if null
          min: _radiusOptions.first, // Should be 0 for "Off"
          max: _radiusOptions.last,
          divisions: _radiusOptions.length - 1,
          label: radiusLabel,
          onChanged:
              !_notificationEnabled
                  ? null
                  : (value) {
                    setState(() {
                      _selectedRadius =
                          value <= 0
                              ? 0
                              : _findClosestValue(value, _radiusOptions);
                    });
                  },
          onChangeEnd: (value) {
            // Save only when interaction ends
            if (_notificationEnabled) _saveNotificationSettings();
          },
        ),
      ],
    );
  }

  // Helper method to find the closest value in a list
  double _findClosestValue(double value, List<double> options) {
    return options.reduce(
      (a, b) => (a - value).abs() < (b - value).abs() ? a : b,
    );
  }

  // Dialog for permission denied
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Notifications cannot be enabled without permission. Please grant notification permission in your device settings for this app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Geolocator.openAppSettings(); // Open app settings
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }
}

Future<bool> _requestNotificationPermission() async {
  // For Flutter Local Notifications on Android 13+
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Return true if granted, false otherwise
  bool? permissionGranted; // Use nullable bool

  try {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      permissionGranted =
          await androidImplementation?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iosImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
      permissionGranted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  } catch (e) {
    debugPrint("Error requesting notification permission: $e");
    permissionGranted = false;
  }

  return permissionGranted ?? false;
}
