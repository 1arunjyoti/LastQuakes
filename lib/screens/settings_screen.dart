import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lastquake/models/safe_zone.dart';
import 'package:lastquake/provider/theme_provider.dart';
import 'package:lastquake/services/notification_service.dart';
import 'package:lastquake/services/secure_storage_service.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:latlong2/latlong.dart';
import 'map_picker_screen.dart';

// Keys for SharedPreferences
const String prefNotificationFilterType = 'notification_filter_type';
const String prefNotificationMagnitude = 'notification_magnitude';
const String prefNotificationCountry = 'notification_country';
const String prefNotificationRadius = 'notification_radius';
const String prefNotificationUseCurrentLoc = 'notification_use_current_loc';
const String prefNotificationSafeZones =
    'notification_safe_zones'; // Stored as JSON string list

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  // --- State Variables ---
  NotificationFilterType _selectedFilterType = NotificationFilterType.none;
  double _selectedMagnitude = 5.0;
  String _selectedCountry = "ALL";
  double _selectedRadius = 500.0; // Default radius if distance type is selected
  bool _useCurrentLocationForDistance = false;
  List<SafeZone> _safeZones = [];

  bool _isLoaded = false;
  /* final LocationService _locationService =
      LocationService(); */ // Instance for permission/location checks

  // Expansion state
  bool _notificationSettingsExpanded = true;
  bool _themeExpanded = false;
  bool _unitsExpanded = false;
  //bool _clockExpanded = false;

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
    _initializeSettings();
  }

  // --- Initialization ---
  Future<void> _initializeSettings() async {
    await _loadNotificationSettings();
    _buildMemoizedItems();
    if (mounted) {
      setState(() {
        _isLoaded = true;
      });
    }
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

  // --- Load & Save Settings ---
  Future<void> _loadNotificationSettings() async {
    try {
      // Load from secure storage first, fallback to SharedPreferences for migration
      final secureSettings = await SecureStorageService.retrieveNotificationSettings();
      final secureSafeZones = await SecureStorageService.retrieveSafeZones();
      
      if (secureSettings != null) {
        // Use secure storage data
        if (!mounted) return;
        setState(() {
          _selectedFilterType = NotificationFilterType.values.firstWhere(
            (e) => e.name == secureSettings['filterType'],
            orElse: () => NotificationFilterType.none,
          );
          _selectedMagnitude = (secureSettings['magnitude'] as num?)?.toDouble() ?? 5.0;
          _selectedCountry = secureSettings['country'] as String? ?? "ALL";
          _selectedRadius = (secureSettings['radius'] as num?)?.toDouble() ?? 500.0;
          _useCurrentLocationForDistance = secureSettings['useCurrentLocation'] as bool? ?? false;
          _safeZones = secureSafeZones;

          // Ensure country selection is valid
          if (!_countryList.contains(_selectedCountry)) {
            _selectedCountry = "ALL";
          }
        });
      } else {
        // Migrate from SharedPreferences to secure storage
        await _migrateFromSharedPreferences();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading notification settings: $e');
      }
      // Fallback to SharedPreferences on error
      await _migrateFromSharedPreferences();
    }
  }

  // Migrate existing data from SharedPreferences to secure storage
  Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      setState(() {
        _selectedFilterType = NotificationFilterType.values.firstWhere(
          (e) => e.name == prefs.getString(prefNotificationFilterType),
          orElse: () => NotificationFilterType.none,
        );
        _selectedMagnitude = prefs.getDouble(prefNotificationMagnitude) ?? 5.0;
        _selectedCountry = prefs.getString(prefNotificationCountry) ?? "ALL";
        _selectedRadius = prefs.getDouble(prefNotificationRadius) ?? 500.0;
        _useCurrentLocationForDistance =
            prefs.getBool(prefNotificationUseCurrentLoc) ?? false;

        // Load safe zones from SharedPreferences
        final List<String>? safeZonesJson = prefs.getStringList(
          prefNotificationSafeZones,
        );
        if (safeZonesJson != null) {
          _safeZones =
              safeZonesJson
                  .map((jsonString) => SafeZone.fromJson(jsonDecode(jsonString)))
                  .toList();
        } else {
          _safeZones = [];
        }

        // Ensure country selection is valid
        if (!_countryList.contains(_selectedCountry)) {
          _selectedCountry = "ALL";
        }
      });

      // Save to secure storage and clear from SharedPreferences
      await _saveNotificationSettings(showSnackbar: false);
      
      // Clear sensitive data from SharedPreferences
      await prefs.remove(prefNotificationSafeZones);
      
      if (kDebugMode) {
        print('Successfully migrated notification settings to secure storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during migration: $e');
      }
    }
  }

  // Save settings to secure storage
  Future<void> _saveNotificationSettings({bool showSnackbar = true}) async {
    if (!_isLoaded) return; 

    try {
      // Save to secure storage
      final settings = {
        'filterType': _selectedFilterType.name,
        'magnitude': _selectedMagnitude,
        'country': _selectedCountry,
        'radius': _selectedRadius,
        'useCurrentLocation': _useCurrentLocationForDistance,
      };
      
      await SecureStorageService.storeNotificationSettings(settings);
      await SecureStorageService.storeSafeZones(_safeZones);

      // Also save non-sensitive settings to SharedPreferences for backward compatibility
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefNotificationFilterType, _selectedFilterType.name);
      await prefs.setDouble(prefNotificationMagnitude, _selectedMagnitude);
      await prefs.setString(prefNotificationCountry, _selectedCountry);
      await prefs.setDouble(prefNotificationRadius, _selectedRadius);
      await prefs.setBool(
        prefNotificationUseCurrentLoc,
        _useCurrentLocationForDistance,
      );

      // Notify the backend service about the changes
      await NotificationService.instance.updateBackendRegistration();

      // Show a snackbar confirmation
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings saved securely'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving notification settings: $e');
      }
      
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving settings. Please try again.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- UI Build Methods ---
  @override
  Widget build(BuildContext context) {
    final prefsProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: LastQuakesAppBar(title: 'Settings'),
      body:
          !_isLoaded
              ? const Center(
                child: CircularProgressIndicator(),
              ) // Show loading indicator
              : ListView(
                padding: const EdgeInsets.all(12.0),
                children: [
                  _buildNotificationSettingsCard(),
                  const SizedBox(height: 12),
                  _buildThemeSettingsCard(prefsProvider),
                  const SizedBox(height: 12),
                  _buildUnitsSettingsCard(prefsProvider),
                  const SizedBox(height: 12),
                  _buildClockSettingsCard(prefsProvider),
                  const SizedBox(height: 12),
                ],
              ),
    );
  }

  // --- Notification Settings Card ---
  Widget _buildNotificationSettingsCard() {
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
                  _buildFilterTypeDropdown(),
                  const Divider(height: 20),
                  // --- Conditional Settings based on Filter Type ---
                  AnimatedOpacity(
                    opacity:
                        _selectedFilterType != NotificationFilterType.none
                            ? 1.0
                            : 0.5,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring:
                          _selectedFilterType == NotificationFilterType.none,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMagnitudeSlider(),
                          const SizedBox(height: 16),
                          if (_selectedFilterType ==
                              NotificationFilterType.country) ...[
                            _buildCountryDropdown(),
                            const SizedBox(height: 10),
                          ],
                          if (_selectedFilterType ==
                              NotificationFilterType.distance) ...[
                            _buildRadiusSlider(),
                            const SizedBox(height: 10),
                            _buildUseCurrentLocationSwitch(),
                            const SizedBox(height: 10),
                            _buildSafeZonesSection(),
                            //const SizedBox(height: 16),
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
  Widget _buildFilterTypeDropdown() {
    return DropdownButtonFormField<NotificationFilterType>(
      value: _selectedFilterType,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: "Notification Type",
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: _memoizedFilterTypeItems,
      onChanged: (value) async {
        if (value != null && value != _selectedFilterType) {
          bool proceed = true;
          // Request permission if changing to Distance type and using current location
          if (value == NotificationFilterType.distance &&
              _useCurrentLocationForDistance) {
            proceed = await _checkAndRequestLocationPermissionIfNeeded();
          }

          if (proceed) {
            if (!mounted) return;
            setState(() => _selectedFilterType = value);
            // Request notification permission if turning notifications ON from NONE
            if (_selectedFilterType != NotificationFilterType.none) {
              bool permissionGranted = await _requestNotificationPermission();
              if (!mounted) return;
              if (!permissionGranted) {
                if (!mounted) return;
                _showPermissionDeniedDialog('Notification');
                setState(
                  () => _selectedFilterType = NotificationFilterType.none,
                ); // Revert if permission denied
              }
            }
            // Check mounted after potential awaits inside _saveNotificationSettings
            if (!mounted) return;
            await _saveNotificationSettings();
          }
        }
      },
    );
  }

  // Slider for minimum magnitude
  Widget _buildMagnitudeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Minimum Magnitude (≥ ${_selectedMagnitude.toStringAsFixed(1)})"),
        Slider(
          value: _selectedMagnitude,
          min: _magnitudeOptions.first,
          max: _magnitudeOptions.last,
          divisions: _magnitudeOptions.length - 1,
          label: "≥ ${_selectedMagnitude.toStringAsFixed(1)}",
          onChanged: (value) {
            setState(() {
              _selectedMagnitude =
                  (value * 2).round() / 2; // Snap to 0.5 increments
            });
          },
          onChangeEnd: (value) => _saveNotificationSettings(),
        ),
      ],
    );
  }

  // Dropdown for country selection
  Widget _buildCountryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCountry,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: "Notify for Country",
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: _memoizedCountryItems,
      onChanged: (value) {
        if (value != null && value != _selectedCountry) {
          setState(() => _selectedCountry = value);
          _saveNotificationSettings();
        }
      },
    );
  }

  // Slider for radius selection
  Widget _buildRadiusSlider() {
    // Find the index of the closest value in _radiusOptions to _selectedRadius
    int currentIndex = _radiusOptions.indexOf(
      _findClosestValue(_selectedRadius, _radiusOptions),
    );
    String radiusLabel = "${_selectedRadius.toStringAsFixed(0)} km";

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
            setState(() {
              _selectedRadius = _radiusOptions[value.round()];
            });
          },
          onChangeEnd: (value) => _saveNotificationSettings(),
        ),
      ],
    );
  }

  // Switch for using current location
  Widget _buildUseCurrentLocationSwitch() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text("Use Current Location"),
      subtitle: const Text("Also check distance from your live location"),
      value: _useCurrentLocationForDistance,
      onChanged: (value) async {
        bool proceed = true;
        if (value == true) {
          // Only check permission when enabling
          proceed = await _checkAndRequestLocationPermissionIfNeeded();
        }

        if (proceed) {
          if (!mounted) return;
          setState(() => _useCurrentLocationForDistance = value);
          if (!mounted) return;
          await _saveNotificationSettings();
        } else {
          // Revert the switch if permission was denied
          // setState(() => _useCurrentLocationForDistance = false);
        }
      },
    );
  }

  // --- Safe Zones Section ---
  Widget _buildSafeZonesSection() {
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
              onPressed: _addSafeZone,
            ),
          ],
        ),
        const Text(
          "Get alerts near these saved locations.",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        if (_safeZones.isEmpty)
          const Center(
            child: Text(
              "No safe zones added yet.",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        if (_safeZones.isNotEmpty)
          ListView.builder(
            shrinkWrap: true, 
            physics:
                const NeverScrollableScrollPhysics(),
            itemCount: _safeZones.length,
            itemBuilder: (context, index) {
              final zone = _safeZones[index];
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
                  onPressed: () => _deleteSafeZone(index),
                ),
              );
            },
          ),
      ],
    );
  }
  
  // --- Safe Zone Management ---
  Future<void> _addSafeZone() async {
    debugPrint("Opening map picker to add safe zone...");

    if (!mounted) return;

    // Open map picker screen
    final selectedLatLng = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                const MapPickerScreen(), 
      ),
    );

    if (!mounted) return;

    if (selectedLatLng != null) {
      if (kDebugMode) {
        debugPrint("Map picker returned coordinates");
      }
      final String? zoneName = await showDialog<String>(
        context: context,
        builder: (context) => _EnterSafeZoneNameDialog(),
      );

      if (!mounted) return;

      if (zoneName != null && zoneName.trim().isNotEmpty) {
        debugPrint("User entered name: $zoneName");
        final newZone = SafeZone(
          name: zoneName.trim(),
          latitude: selectedLatLng.latitude,
          longitude: selectedLatLng.longitude,
        );

        setState(() {
          _safeZones.add(newZone);
        });
        await _saveNotificationSettings();
        debugPrint("Safe zone added: $newZone");
      } else {
        debugPrint("User cancelled or entered empty name.");
      }
    } else {
      debugPrint("Map picker was cancelled.");
    }
  }

  // Delete a safe zone by index
  void _deleteSafeZone(int index) {
    setState(() {
      _safeZones.removeAt(index);
    });
    _saveNotificationSettings();
  }

  // --- Other Build Methods (Theme, Units, Clock) ---

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
              ), 
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text("Same as Device"),
                    value: ThemeMode.system,
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
                        prefsProvider.distanceUnit, 
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
        value: prefsProvider.use24HourClock,
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

  // --- Helper Methods ---

  String _getFilterTypeName(NotificationFilterType type) {
    switch (type) {
      case NotificationFilterType.none:
        return "None (Disabled)";
      case NotificationFilterType.distance:
        return "Nearby / Safe Zones";
      case NotificationFilterType.country:
        return "Specific Country";
      case NotificationFilterType.worldwide:
        return "Worldwide";
    }
  }

  double _findClosestValue(double value, List<double> options) {
    return options.reduce(
      (a, b) => (a - value).abs() < (b - value).abs() ? a : b,
    );
  }

  // --- Permission Handling ---

  Future<bool> _checkAndRequestLocationPermissionIfNeeded({
    bool showRationale = false,
  }) async {
    if (kDebugMode) {
      debugPrint("Checking location permission");
    }
    PermissionStatus status = await Permission.locationWhenInUse.status;
    if (kDebugMode) {
      debugPrint("Initial permission status: $status");
    } 

    if (status.isGranted) {
      debugPrint("Permission already granted."); 
      return true;
    }

    if (status.isPermanentlyDenied) {
      debugPrint("Permission permanently denied. Showing dialog."); 
      if (!mounted) return false; 
      _showPermissionDeniedDialog('Location');
      return false; // Cannot request if permanently denied
    }

    // Show rationale if requested and permission not determined yet
    if (showRationale) {
      // Rationale needed if isDenied or not determined yet
      debugPrint("Showing rationale dialog..."); 
      if (!mounted) return false;
      bool? userAgreed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Location Permission'),
              content: const Text(
                'This app needs access to your location to provide nearby earthquake alerts when using the "Distance" filter type.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      if (userAgreed != true) {
        debugPrint("User cancelled rationale."); 
        return false; 
      }
    }

    debugPrint("Requesting location permission..."); 
    // Request permission
    status = await Permission.locationWhenInUse.request();
    debugPrint("Status after request: $status"); 

    if (status.isGranted) {
      debugPrint("Permission granted after request."); 
      return true;
    } else {
      debugPrint("Permission denied after request. Showing dialog."); 
      // Show dialog *before* returning false
      if (!mounted) return false; 
      _showPermissionDeniedDialog('Location');
      return false;
    }
  }

  // Request notification permission
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

  // Show dialog guiding user to app settings
  void _showPermissionDeniedDialog(String permissionType) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('$permissionType Permission Required'),
            content: Text(
              '$permissionType permission is required for this feature. Please grant the permission in your device settings for this app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings(); 
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }
}

// --- Simple Dialog for entering Safe Zone Name ---
class _EnterSafeZoneNameDialog extends StatefulWidget {
  @override
  State<_EnterSafeZoneNameDialog> createState() =>
      _EnterSafeZoneNameDialogState();
}

class _EnterSafeZoneNameDialogState extends State<_EnterSafeZoneNameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submitName() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_nameController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Name Your Safe Zone"),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Name (e.g., Home, Office)",
            hintText: "Enter a descriptive name",
          ),
          validator:
              (value) =>
                  (value == null || value.trim().isEmpty)
                      ? 'Name cannot be empty'
                      : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _submitName, 
          child: const Text("Save"),
        ),
      ],
    );
  }
}
