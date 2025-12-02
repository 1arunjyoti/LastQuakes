import 'package:flutter/material.dart';
import 'package:lastquake/models/safe_zone.dart';
import 'package:lastquake/screens/map_picker_screen.dart';
import 'package:lastquake/services/preferences_service.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationSettingsCard extends StatefulWidget {
  final PreferencesService prefsService;
  final VoidCallback onSettingsChanged;

  const NotificationSettingsCard({
    super.key,
    required this.prefsService,
    required this.onSettingsChanged,
  });

  @override
  State<NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState extends State<NotificationSettingsCard> {
  bool _expanded = true;

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

  static final List<double> _magnitudeOptions = List.generate(
    13,
    (i) => 3.0 + i * 0.5,
  );

  static final List<double> _radiusOptions = [
    100.0,
    200.0,
    500.0,
    1000.0,
    2000.0,
    5000.0,
  ];

  @override
  Widget build(BuildContext context) {
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
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterTypeDropdown(),
                  const Divider(height: 20),
                  AnimatedOpacity(
                    opacity:
                        widget.prefsService.filterType !=
                                NotificationFilterType.none
                            ? 1.0
                            : 0.5,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring:
                          widget.prefsService.filterType ==
                          NotificationFilterType.none,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMagnitudeSlider(),
                          const SizedBox(height: 16),
                          if (widget.prefsService.filterType ==
                              NotificationFilterType.country) ...[
                            _buildCountryDropdown(),
                            const SizedBox(height: 10),
                          ],
                          if (widget.prefsService.filterType ==
                              NotificationFilterType.distance) ...[
                            _buildRadiusSlider(),
                            const SizedBox(height: 10),
                            _buildUseCurrentLocationSwitch(),
                            const SizedBox(height: 10),
                            _buildSafeZonesSection(),
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

  Widget _buildFilterTypeDropdown() {
    return DropdownButtonFormField<NotificationFilterType>(
      initialValue: widget.prefsService.filterType,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: "Notification Type",
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items:
          NotificationFilterType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(_getFilterTypeName(type)),
            );
          }).toList(),
      onChanged: (value) async {
        if (value != null && value != widget.prefsService.filterType) {
          bool proceed = true;
          if (value == NotificationFilterType.distance &&
              widget.prefsService.useCurrentLocation) {
            proceed = await _checkLocationPermission();
          }

          if (proceed) {
            setState(() => widget.prefsService.filterType = value);
            if (value != NotificationFilterType.none) {
              await _requestNotificationPermission();
            }
            widget.onSettingsChanged();
          }
        }
      },
    );
  }

  String _getFilterTypeName(NotificationFilterType type) {
    switch (type) {
      case NotificationFilterType.none:
        return "None (Disabled)";
      case NotificationFilterType.country:
        return "By Country";
      case NotificationFilterType.distance:
        return "By Distance / Safe Zones";
      default:
        return "Unknown";
    }
  }

  Widget _buildMagnitudeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Minimum Magnitude (≥ ${widget.prefsService.magnitude.toStringAsFixed(1)})",
        ),
        Slider(
          value: widget.prefsService.magnitude,
          min: _magnitudeOptions.first,
          max: _magnitudeOptions.last,
          divisions: _magnitudeOptions.length - 1,
          label: "≥ ${widget.prefsService.magnitude.toStringAsFixed(1)}",
          onChanged: (value) {
            setState(() {
              widget.prefsService.magnitude = (value * 2).round() / 2;
            });
          },
          onChangeEnd: (_) => widget.onSettingsChanged(),
        ),
      ],
    );
  }

  Widget _buildCountryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: widget.prefsService.country,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: "Notify for Country",
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items:
          _countryList
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => widget.prefsService.country = value);
          widget.onSettingsChanged();
        }
      },
    );
  }

  Widget _buildRadiusSlider() {
    double closest = _radiusOptions.reduce(
      (a, b) =>
          (a - widget.prefsService.radius).abs() <
                  (b - widget.prefsService.radius).abs()
              ? a
              : b,
    );
    int currentIndex = _radiusOptions.indexOf(closest);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Notify within Radius (${widget.prefsService.radius.toStringAsFixed(0)} km)",
        ),
        Slider(
          value: currentIndex.toDouble(),
          min: 0,
          max: (_radiusOptions.length - 1).toDouble(),
          divisions: _radiusOptions.length - 1,
          label: "${_radiusOptions[currentIndex].toStringAsFixed(0)} km",
          onChanged: (value) {
            setState(() {
              widget.prefsService.radius = _radiusOptions[value.round()];
            });
          },
          onChangeEnd: (_) => widget.onSettingsChanged(),
        ),
      ],
    );
  }

  Widget _buildUseCurrentLocationSwitch() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text("Use Current Location"),
      subtitle: const Text("Also check distance from your live location"),
      value: widget.prefsService.useCurrentLocation,
      onChanged: (value) async {
        if (value) {
          if (await _checkLocationPermission()) {
            setState(() => widget.prefsService.useCurrentLocation = true);
            widget.onSettingsChanged();
          }
        } else {
          setState(() => widget.prefsService.useCurrentLocation = false);
          widget.onSettingsChanged();
        }
      },
    );
  }

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
              onPressed: _addSafeZone,
            ),
          ],
        ),
        if (widget.prefsService.safeZones.isEmpty)
          const Center(
            child: Text(
              "No safe zones added yet.",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        if (widget.prefsService.safeZones.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.prefsService.safeZones.length,
            itemBuilder: (context, index) {
              final zone = widget.prefsService.safeZones[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.pin_drop_outlined),
                title: Text(zone.name),
                subtitle: Text(
                  "Lat: ${zone.latitude.toStringAsFixed(4)}, Lon: ${zone.longitude.toStringAsFixed(4)}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      widget.prefsService.deleteSafeZone(index);
                    });
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _addSafeZone() async {
    final selectedLatLng = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (context) => const MapPickerScreen()),
    );

    if (selectedLatLng != null && mounted) {
      final String? zoneName = await showDialog<String>(
        context: context,
        builder: (context) => _EnterSafeZoneNameDialog(),
      );

      if (zoneName != null && zoneName.trim().isNotEmpty) {
        final newZone = SafeZone(
          name: zoneName.trim(),
          latitude: selectedLatLng.latitude,
          longitude: selectedLatLng.longitude,
        );
        setState(() {
          widget.prefsService.addSafeZone(newZone);
        });
      }
    }
  }

  Future<bool> _checkLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      status = await Permission.locationWhenInUse.request();
    }
    return status.isGranted;
  }

  Future<bool> _requestNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      status = await Permission.notification.request();
    }
    return status.isGranted;
  }
}

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
      title: const Text('Name this Safe Zone'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: "e.g., Home, Office"),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
