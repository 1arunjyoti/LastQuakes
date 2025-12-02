import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:lastquake/models/safe_zone.dart';
import 'package:lastquake/presentation/providers/settings_provider.dart';
import 'package:lastquake/provider/theme_provider.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:lastquake/widgets/settings/clock_settings_card.dart';
import 'package:lastquake/widgets/settings/theme_settings_card.dart';
import 'package:lastquake/widgets/settings/units_settings_card.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:latlong2/latlong.dart';
import 'package:lastquake/utils/app_page_transitions.dart';
import 'map_picker_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Expansion state
  bool _notificationSettingsExpanded = true;
  bool _dataSourcesExpanded = false;
  // bool _themeExpanded = false; // Handled in widget
  // bool _unitsExpanded = false; // Handled in widget
  // bool _clockExpanded = false; // Handled in widget

  // Data for dropdowns/sliders
  final List<String> _countryList = [
    "ALL",
    "India",
    "Japan",
    "Afghanistan",
    "Albania",
    "Algeria",
    "Argentina",
    "Canada",
    "Chile",
    "China",
    "Colombia",
    "Costa Rica",
    "Ecuador",
    "Ethiopia",
    "Fiji",
    "France",
    "Germany",
    "Greece",
    "Guatemala",
    "Iceland",
    "Indonesia",
    "Iran",
    "Italy",
    "Kyrgyzstan",
    "Malaysia",
    "Mexico",
    "Morocco",
    "Myanmar",
    "Nepal",
    "New Zealand",
    "Pakistan",
    "Papua New Guinea",
    "Peru",
    "Philippines",
    "Portugal",
    "Romania",
    "Russia",
    "Solomon Islands",
    "South Korea",
    "Spain",
    "Tajikistan",
    "Tanzania",
    "Taiwan",
    "Thailand",
    "Turkey",
    "United Kingdom",
    "United States",
    "Vanuatu",
    "Vietnam",
  ];

  // Magnitude options from 3.0 to 9.0 in 0.5 increments
  static final List<double> _magnitudeOptions = List.generate(
    13,
    (i) => 3.0 + i * 0.5,
  );

  // Radius options in kilometers
  static final List<double> _radiusOptions = [
    100.0,
    200.0,
    500.0,
    1000.0,
    2000.0,
    5000.0,
  ];

  // Memoized dropdown items
  List<DropdownMenuItem<String>>? _memoizedCountryItems;
  List<DropdownMenuItem<NotificationFilterType>>? _memoizedFilterTypeItems;

  @override
  void initState() {
    super.initState();
    _buildMemoizedItems();
  }

  // Build memoized dropdown items
  void _buildMemoizedItems() {
    _memoizedCountryItems =
        _countryList.map((country) {
          return DropdownMenuItem<String>(value: country, child: Text(country));
        }).toList();

    _memoizedFilterTypeItems =
        NotificationFilterType.values.map((type) {
          return DropdownMenuItem<NotificationFilterType>(
            value: type,
            child: Text(_getFilterTypeName(type)),
          );
        }).toList();
  }

  String _getFilterTypeName(NotificationFilterType type) {
    switch (type) {
      case NotificationFilterType.none:
        return "None (Notifications Disabled)";
      case NotificationFilterType.worldwide:
        return "Worldwide (All Earthquakes)";
      case NotificationFilterType.country:
        return "By Country";
      case NotificationFilterType.distance:
        return "By Distance / Safe Zones";
    }
  }

  // Helper to find closest value in a list
  double _findClosestValue(double target, List<double> options) {
    return options.reduce(
      (a, b) => (target - a).abs() < (target - b).abs() ? a : b,
    );
  }

  // --- Permission Helpers ---
  Future<bool> _requestNotificationPermission() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    bool? permissionGranted;

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

  Future<bool> _checkAndRequestLocationPermissionIfNeeded() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return true;

    final result = await Permission.locationWhenInUse.request();
    if (result.isGranted) return true;

    if (mounted) {
      _showPermissionDeniedDialog('Location');
    }
    return false;
  }

  void _showPermissionDeniedDialog(String permissionName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('$permissionName Permission Required'),
            content: Text(
              'Please enable $permissionName permission in settings to use this feature.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  // --- UI Build Methods ---
  @override
  Widget build(BuildContext context) {
    final prefsProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: LastQuakesAppBar(title: 'Settings'),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          if (settingsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (settingsProvider.error != null) {
            // Show error but allow interaction with other settings if possible,
            // or just show a retry button.
            // For now, let's show a snackbar (handled in provider usually, but here for safety)
            // and display content.
          }

          return ListView(
            padding: const EdgeInsets.all(12.0),
            children: [
              _buildNotificationSettingsCard(settingsProvider),
              const SizedBox(height: 12),
              _buildDataSourcesCard(settingsProvider),
              const SizedBox(height: 12),
              ThemeSettingsCard(
                themeProvider: prefsProvider,
                // expanded: _themeExpanded,
                // onExpand: (val) => setState(() => _themeExpanded = val),
              ),
              const SizedBox(height: 12),
              UnitsSettingsCard(
                themeProvider: prefsProvider,
                // expanded: _unitsExpanded,
                // onExpand: (val) => setState(() => _unitsExpanded = val),
              ),
              const SizedBox(height: 12),
              ClockSettingsCard(
                themeProvider: prefsProvider,
                // expanded: _clockExpanded,
                // onExpand: (val) => setState(() => _clockExpanded = val),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  // --- Notification Settings Card ---
  Widget _buildNotificationSettingsCard(SettingsProvider provider) {
    final settings = provider.settings;

    return Card(
      margin: EdgeInsets.zero,
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
                _notificationSettingsExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              onPressed:
                  () => setState(
                    () =>
                        _notificationSettingsExpanded =
                            !_notificationSettingsExpanded,
                  ),
            ),
            onTap:
                () => setState(
                  () =>
                      _notificationSettingsExpanded =
                          !_notificationSettingsExpanded,
                ),
          ),
          if (_notificationSettingsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterTypeDropdown(provider),
                  const Divider(height: 20),
                  // --- Conditional Settings based on Filter Type ---
                  AnimatedOpacity(
                    opacity:
                        settings.filterType != NotificationFilterType.none
                            ? 1.0
                            : 0.5,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring:
                          settings.filterType == NotificationFilterType.none,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMagnitudeSlider(provider),
                          const SizedBox(height: 16),
                          if (settings.filterType ==
                              NotificationFilterType.country) ...[
                            _buildCountryDropdown(provider),
                            const SizedBox(height: 10),
                          ],
                          if (settings.filterType ==
                              NotificationFilterType.distance) ...[
                            _buildRadiusSlider(provider),
                            const SizedBox(height: 10),
                            _buildUseCurrentLocationSwitch(provider),
                            const SizedBox(height: 10),
                            _buildSafeZonesSection(provider),
                          ],
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

  // --- Individual Setting Widgets ---
  Widget _buildFilterTypeDropdown(SettingsProvider provider) {
    return DropdownButtonFormField<NotificationFilterType>(
      initialValue: provider.settings.filterType,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: "Notification Type",
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: _memoizedFilterTypeItems,
      onChanged: (value) async {
        if (value != null && value != provider.settings.filterType) {
          bool proceed = true;
          // Request permission if changing to Distance type and using current location
          if (value == NotificationFilterType.distance &&
              provider.settings.useCurrentLocation) {
            proceed = await _checkAndRequestLocationPermissionIfNeeded();
          }

          if (proceed) {
            // Request notification permission if turning notifications ON from NONE
            if (value != NotificationFilterType.none) {
              bool permissionGranted = await _requestNotificationPermission();
              if (!permissionGranted) {
                if (mounted) _showPermissionDeniedDialog('Notification');
                return; // Do not update if permission denied
              }
            }
            await provider.updateSettings(
              provider.settings.copyWith(filterType: value),
            );
          }
        }
      },
    );
  }

  // Slider for minimum magnitude
  Widget _buildMagnitudeSlider(SettingsProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Minimum Magnitude (≥ ${provider.settings.magnitude.toStringAsFixed(1)})",
        ),
        Slider(
          value: provider.settings.magnitude,
          min: _magnitudeOptions.first,
          max: _magnitudeOptions.last,
          divisions: _magnitudeOptions.length - 1,
          label: "≥ ${provider.settings.magnitude.toStringAsFixed(1)}",
          onChanged: (value) {
            // Optimistic update handled by provider if we call updateSettings on change end
            // But for slider drag, we might want local state or frequent updates?
            // Provider's updateSettings does notifyListeners, so it should be fine.
            // To avoid too many backend calls, we can update local state or use onChangeEnd.
            // Here, let's just update the UI value via provider but only save on end?
            // The provider implementation saves on every updateSettings call.
            // So we should probably only call it on ChangeEnd.
            // But we need the UI to update while dragging.
            // Let's use a local state wrapper or just update on end.
            // For simplicity and responsiveness, let's update on end, but we need visual feedback.
            // Actually, Slider needs a value. If we don't update provider, it won't move.
            // We can use a local variable for the slider value if needed, but let's try direct update.
            // Ideally, separate "set" (memory) and "save" (persist).
            // For now, let's update on end.
          },
          onChangeEnd: (value) {
            final snapped = (value * 2).round() / 2;
            provider.updateSettings(
              provider.settings.copyWith(magnitude: snapped),
            );
          },
        ),
      ],
    );
  }

  // Dropdown for country selection
  Widget _buildCountryDropdown(SettingsProvider provider) {
    return DropdownButtonFormField<String>(
      initialValue: provider.settings.country,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: "Notify for Country",
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: _memoizedCountryItems,
      onChanged: (value) {
        if (value != null && value != provider.settings.country) {
          provider.updateSettings(provider.settings.copyWith(country: value));
        }
      },
    );
  }

  // Slider for radius selection
  Widget _buildRadiusSlider(SettingsProvider provider) {
    // Find the index of the closest value in _radiusOptions
    int currentIndex = _radiusOptions.indexOf(
      _findClosestValue(provider.settings.radius, _radiusOptions),
    );
    String radiusLabel = "${provider.settings.radius.toStringAsFixed(0)} km";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Notify within Radius ($radiusLabel)"),
        Slider(
          value: currentIndex.toDouble(),
          min: 0,
          max: (_radiusOptions.length - 1).toDouble(),
          divisions: _radiusOptions.length - 1,
          label: "${_radiusOptions[currentIndex].toStringAsFixed(0)} km",
          onChanged: (value) {
            // Update on end
          },
          onChangeEnd: (value) {
            final newRadius = _radiusOptions[value.round()];
            provider.updateSettings(
              provider.settings.copyWith(radius: newRadius),
            );
          },
        ),
      ],
    );
  }

  // Switch for using current location
  Widget _buildUseCurrentLocationSwitch(SettingsProvider provider) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text("Use Current Location"),
      subtitle: const Text("Also check distance from your live location"),
      value: provider.settings.useCurrentLocation,
      onChanged: (value) async {
        bool proceed = true;
        if (value == true) {
          proceed = await _checkAndRequestLocationPermissionIfNeeded();
        }

        if (proceed) {
          provider.updateSettings(
            provider.settings.copyWith(useCurrentLocation: value),
          );
        }
      },
    );
  }

  // --- Safe Zones Section ---
  Widget _buildSafeZonesSection(SettingsProvider provider) {
    final safeZones = provider.settings.safeZones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Safe Zones",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_location_alt_outlined),
              tooltip: "Add Safe Zone",
              onPressed: () => _addSafeZone(provider),
            ),
          ],
        ),
        const Text(
          "Get alerts near these saved locations.",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        if (safeZones.isEmpty)
          const Center(
            child: Text(
              "No safe zones added yet.",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        if (safeZones.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: safeZones.length,
            itemBuilder: (context, index) {
              final zone = safeZones[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.pin_drop_outlined),
                title: Text(zone.name),
                subtitle: Text(
                  "Lat: ${zone.latitude.toStringAsFixed(4)}, Lon: ${zone.longitude.toStringAsFixed(4)}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: "Delete Safe Zone",
                  onPressed: () => provider.removeSafeZone(index),
                ),
              );
            },
          ),
      ],
    );
  }

  // --- Safe Zone Management ---
  Future<void> _addSafeZone(SettingsProvider provider) async {
    debugPrint("Opening map picker to add safe zone...");

    // Open map picker screen
    final selectedLatLng = await Navigator.push<LatLng>(
      context,
      AppPageTransitions.fadeRoute(page: const MapPickerScreen()),
    );

    if (!mounted) return;

    if (selectedLatLng != null) {
      final String? zoneName = await showDialog<String>(
        context: context,
        builder: (context) => _EnterSafeZoneNameDialog(),
      );

      if (!mounted) return;

      if (zoneName != null && zoneName.trim().isNotEmpty) {
        final newZone = SafeZone(
          name: zoneName.trim(),
          latitude: selectedLatLng.latitude,
          longitude: selectedLatLng.longitude,
        );
        await provider.addSafeZone(newZone);
      }
    }
  }

  // --- Data Sources Settings Card ---
  Widget _buildDataSourcesCard(SettingsProvider provider) {
    final selectedSources = provider.selectedDataSources;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Data Sources',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${selectedSources.length} source${selectedSources.length != 1 ? 's' : ''} selected',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: IconButton(
              icon: Icon(
                _dataSourcesExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              onPressed:
                  () => setState(
                    () => _dataSourcesExpanded = !_dataSourcesExpanded,
                  ),
            ),
            onTap:
                () => setState(
                  () => _dataSourcesExpanded = !_dataSourcesExpanded,
                ),
          ),
          if (_dataSourcesExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select earthquake data sources:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('USGS (United States Geological Survey)'),
                    subtitle: const Text(
                      'Comprehensive global earthquake data',
                    ),
                    value: selectedSources.contains(DataSource.usgs),
                    onChanged: (bool? value) {
                      final newSources = Set<DataSource>.from(selectedSources);
                      if (value == true) {
                        newSources.add(DataSource.usgs);
                      } else {
                        if (newSources.length > 1) {
                          newSources.remove(DataSource.usgs);
                        }
                      }
                      provider.updateDataSources(newSources);
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'EMSC (European-Mediterranean Seismological Centre)',
                    ),
                    subtitle: const Text(
                      'European and Mediterranean region focus',
                    ),
                    value: selectedSources.contains(DataSource.emsc),
                    onChanged: (bool? value) {
                      final newSources = Set<DataSource>.from(selectedSources);
                      if (value == true) {
                        newSources.add(DataSource.emsc);
                      } else {
                        if (newSources.length > 1) {
                          newSources.remove(DataSource.emsc);
                        }
                      }
                      provider.updateDataSources(newSources);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Dialog for entering safe zone name
class _EnterSafeZoneNameDialog extends StatefulWidget {
  @override
  _EnterSafeZoneNameDialogState createState() =>
      _EnterSafeZoneNameDialogState();
}

class _EnterSafeZoneNameDialogState extends State<_EnterSafeZoneNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name Safe Zone'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: "e.g., Home, Office"),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
