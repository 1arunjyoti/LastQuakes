import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lastquake/services/notification_service.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  String _selectedCountry = "ALL";
  double _selectedMagnitude = 5.0;
  double? _selectedRadius; // Default to null
  bool _notificationEnabled = false;
  List<Map<String, String>> _notifications = [];
  bool _settingsExpanded = false;
  bool _isLoading = true;

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
    _loadSettingsAndNotifications();
  }

  Future<void> _loadSettingsAndNotifications() async {
    setState(() => _isLoading = true);
    await _loadSettings();
    await _loadNotifications();
    setState(() => _isLoading = false);
  }

  // Load user settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationEnabled = prefs.getBool('notifications_enabled') ?? false;
      _selectedCountry = prefs.getString('notification_country') ?? "ALL";
      _selectedMagnitude = prefs.getDouble('notification_magnitude') ?? 5.0;
      // Load radius, handle null case for "Off" (represented by 0 in UI)
      double? storedRadius = prefs.getDouble('notification_radius');
      _selectedRadius =
          storedRadius == null || storedRadius <= 0 ? 0 : storedRadius;
    });
  }

  // Load stored notifications
  Future<void> _loadNotifications() async {
    List<Map<String, String>> notifications =
        await NotificationService().getStoredNotifications();
    if (mounted) {
      setState(() {
        _notifications = notifications.reversed.toList(); // Show latest first
      });
    }
  }

  // Save user settings
  Future<void> _saveSettings() async {
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
    return Scaffold(
      appBar: LastQuakesAppBar(
        title: 'Notifications',
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed:
                _notifications.isEmpty
                    ? null
                    : () async {
                      await _showClearHistoryDialog();
                    },
            tooltip: 'Clear notification history',
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : RefreshIndicator(
                // Allow pull-to-refresh for notification list
                onRefresh: _loadNotifications,
                child: ListView(
                  // Use ListView instead of SingleChildScrollView+Column for better scroll behavior with list
                  padding: const EdgeInsets.all(12.0),
                  children: [
                    // Settings Section
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text(
                              'Notification Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                _settingsExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                              ),
                              onPressed: () {
                                setState(() {
                                  _settingsExpanded = !_settingsExpanded;
                                });
                              },
                            ),
                            onTap: () {
                              // Allow tapping row to expand/collapse
                              setState(() {
                                _settingsExpanded = !_settingsExpanded;
                              });
                            },
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
                                        color:
                                            _notificationEnabled
                                                ? Colors.green
                                                : Colors.red,
                                      ),
                                    ),
                                    value: _notificationEnabled,
                                    onChanged: (bool value) async {
                                      if (value == true) {
                                        // Request permission when enabling
                                        bool permissionGranted =
                                            await _requestNotificationPermission();
                                        if (permissionGranted) {
                                          setState(
                                            () => _notificationEnabled = true,
                                          );
                                          await _saveSettings(); // Save immediately
                                        } else {
                                          _showPermissionDeniedDialog();
                                        }
                                      } else {
                                        setState(
                                          () => _notificationEnabled = false,
                                        );
                                        await _saveSettings(); // Save immediately
                                      }
                                    },
                                  ),
                                  const Divider(height: 20),
                                  // Filters only relevant if notifications are enabled
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
                    ),

                    // Notification History Section Header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Notification History (${_notifications.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_notifications
                              .isNotEmpty) // Show refresh only if there's history
                            TextButton.icon(
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text("Refresh"),
                              onPressed: _loadNotifications,
                            ),
                        ],
                      ),
                    ),

                    // Notification List Area
                    _notifications.isEmpty
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.0),
                            child: Text('No notifications received yet.'),
                          ),
                        )
                        : ListView.builder(
                          // Build list directly in outer ListView
                          shrinkWrap:
                              true, // Important inside another scroll view
                          physics:
                              const NeverScrollableScrollPhysics(), // Disable its own scrolling
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            String formattedTime = 'Time unknown';
                            if (notification['timestamp'] != null) {
                              try {
                                formattedTime = DateFormat(
                                  'MMM d, h:mm a',
                                ).format(
                                  DateTime.parse(notification['timestamp']!),
                                );
                              } catch (_) {} // Ignore parsing errors
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              child: ListTile(
                                leading: CircleAvatar(
                                  // Add icon maybe?
                                  child: Icon(
                                    Icons.notifications_active_outlined,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  notification['title'] ?? 'No Title',
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(notification['body'] ?? 'No Body'),
                                    const SizedBox(height: 4),
                                    Text(
                                      formattedTime,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                dense: true,
                              ),
                            );
                          },
                        ),

                    const SizedBox(height: 20),

                    // Test Button (Optional) - Consider removing if not needed for users
                    ElevatedButton.icon(
                      icon: const Icon(
                        Icons.notification_important_outlined,
                        size: 16,
                      ),
                      label: const Text("Send Test Notification"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 36),
                      ), // Make wider
                      onPressed: () {
                        NotificationService().showNotification(
                          id: DateTime.now().millisecondsSinceEpoch.hashCode,
                          title: "Test Notification",
                          body: "This is a test local notification.",
                        );
                      },
                    ),

                    // --- REMOVED "Check Earthquakes" Button ---
                    const SizedBox(height: 20),
                  ],
                ),
              ),
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
                  _saveSettings();
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
            if (_notificationEnabled) _saveSettings();
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
            if (_notificationEnabled) _saveSettings();
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

  // Dialog to confirm clearing notification history
  Future<void> _showClearHistoryDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Notification History'),
          content: const Text(
            'Are you sure you want to clear all notification history? This cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Clear'),
              onPressed: () async {
                await NotificationService().clearNotificationHistory();
                Navigator.of(context).pop();
                _loadNotifications(); // Refresh the list

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification history cleared'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
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
    print("Error requesting notification permission: $e");
    permissionGranted = false;
  }

  return permissionGranted ?? false;
}
