import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class EarthquakeDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> quakeData;

  const EarthquakeDetailsScreen({Key? key, required this.quakeData})
    : super(key: key);

  @override
  _EarthquakeDetailsScreenState createState() =>
      _EarthquakeDetailsScreenState();
}

class _EarthquakeDetailsScreenState extends State<EarthquakeDetailsScreen> {
  late final MapController _mapController;
  double _zoomLevel = 4.0;
  static const double _minZoom = 1.0;
  static const double _maxZoom = 18.0;

  // Memoize extracted data to avoid repeated map lookups
  late final _memoizedData = _extractEarthquakeData();

  // Extract and preprocess data once during initialization
  _EarthquakeData _extractEarthquakeData() {
    final properties = widget.quakeData["properties"] ?? {};
    final geometry = widget.quakeData["geometry"] ?? {};

    return _EarthquakeData(
      magnitude: (properties["mag"] as num?)?.toDouble() ?? 0.0,
      location: properties["place"] as String? ?? "Unknown Location",
      timestamp: (properties["time"] as int?) ?? 0,
      tsunami: properties["tsunami"] == 1,
      depth:
          (geometry["coordinates"] is List &&
                  geometry["coordinates"].length > 2)
              ? (geometry["coordinates"][2] as num?)?.toDouble() ?? 0.0
              : 0.0,
      lat:
          (geometry["coordinates"] is List &&
                  geometry["coordinates"].length > 1)
              ? (geometry["coordinates"][1] as num?)?.toDouble()
              : null,
      lon:
          (geometry["coordinates"] is List &&
                  geometry["coordinates"].length > 0)
              ? (geometry["coordinates"][0] as num?)?.toDouble()
              : null,
    );
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  void _zoomMap(bool zoomIn) {
    setState(() {
      if (zoomIn && _zoomLevel < _maxZoom) {
        _zoomLevel += 1;
      } else if (!zoomIn && _zoomLevel > _minZoom) {
        _zoomLevel -= 1;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              zoomIn ? "Max zoom level reached!" : "Min zoom level reached!",
            ),
            duration: const Duration(milliseconds: 500),
          ),
        );
        return;
      }

      _mapController.moveAndRotate(_mapController.camera.center, _zoomLevel, 0);
    });
  }

  void _copyCoordinates() {
    if (_memoizedData.lat != null && _memoizedData.lon != null) {
      Clipboard.setData(
        ClipboardData(text: "${_memoizedData.lat}, ${_memoizedData.lon}"),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Coordinates copied!"),
          duration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      _memoizedData.timestamp,
    );
    final formattedTime = DateFormat.yMMMd().add_jm().format(dateTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Earthquake Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _memoizedData.location,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.calendar_today,
                      iconColor: Colors.grey.shade600,
                      text: formattedTime,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.speed,
                      iconColor: Colors.redAccent,
                      text:
                          "Magnitude: ${_memoizedData.magnitude.toStringAsFixed(1)}",
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.water,
                      iconColor: Colors.blue,
                      text:
                          "Tsunami Alert: ${_memoizedData.tsunami ? 'Yes' : 'No'}",
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.layers,
                      iconColor: Colors.green,
                      text:
                          "Depth: ${_memoizedData.depth.toStringAsFixed(1)} km",
                    ),
                    const SizedBox(height: 8),
                    _buildLocationRow(formattedTime),
                  ],
                ),
              ),
            ),
          ),
          if (_memoizedData.lat != null && _memoizedData.lon != null)
            _buildMapSection(),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildLocationRow(String formattedTime) {
    return Row(
      children: [
        const Icon(Icons.location_on, color: Colors.blue, size: 20),
        const SizedBox(width: 5),
        Text(
          "Lat: ${_memoizedData.lat?.toStringAsFixed(4)}, Lon: ${_memoizedData.lon?.toStringAsFixed(4)}",
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 20,
          width: 20,
          child: IconButton(
            icon: const Icon(Icons.copy, size: 18, color: Colors.black),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _copyCoordinates,
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: SizedBox(
        height: 300,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(_memoizedData.lat!, _memoizedData.lon!),
                  initialZoom: _zoomLevel,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_memoizedData.lat!, _memoizedData.lon!),
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  children: [
                    _buildZoomButton(
                      icon: Icons.add,
                      heroTag: "zoom_in",
                      onPressed: () => _zoomMap(true),
                      isEnabled: _zoomLevel < _maxZoom,
                    ),
                    const SizedBox(height: 8),
                    _buildZoomButton(
                      icon: Icons.remove,
                      heroTag: "zoom_out",
                      onPressed: () => _zoomMap(false),
                      isEnabled: _zoomLevel > _minZoom,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required String heroTag,
    required VoidCallback onPressed,
    required bool isEnabled,
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: true,
      backgroundColor: isEnabled ? Colors.white : Colors.grey.shade300,
      onPressed: onPressed,
      child: Icon(icon, color: isEnabled ? Colors.black : Colors.grey),
    );
  }
}

// Dedicated data class for extracted earthquake data
class _EarthquakeData {
  final double magnitude;
  final String location;
  final int timestamp;
  final bool tsunami;
  final double depth;
  final double? lat;
  final double? lon;

  const _EarthquakeData({
    required this.magnitude,
    required this.location,
    required this.timestamp,
    required this.tsunami,
    required this.depth,
    required this.lat,
    required this.lon,
  });
}
