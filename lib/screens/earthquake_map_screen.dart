import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui';

class EarthquakeMapScreen extends StatefulWidget {
  final List<Map<String, dynamic>> earthquakes;

  const EarthquakeMapScreen({Key? key, required this.earthquakes})
    : super(key: key);

  @override
  State<EarthquakeMapScreen> createState() => _EarthquakeMapScreenState();
}

class _EarthquakeMapScreenState extends State<EarthquakeMapScreen> {
  late final MapController _mapController;
  double _zoomLevel = 2.0;
  static const double _minZoom = 1.0;
  static const double _maxZoom = 18.0;

  // Memoize marker color to avoid repeated calculations
  final Map<double, Color> _markerColorCache = {};

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  /// Memoized marker color retrieval
  Color _getMarkerColor(double magnitude) {
    return _markerColorCache.putIfAbsent(magnitude, () {
      if (magnitude >= 8.0) return Colors.red.shade900;
      if (magnitude >= 7.0) return Colors.red;
      if (magnitude >= 6.0) return Colors.orange;
      if (magnitude >= 5.0) return Colors.amber;
      return Colors.green;
    });
  }

  /// Optimized marker building with null safety and early filtering
  List<Marker> _buildMarkers() {
    return widget.earthquakes
        .where(
          (quake) =>
              quake["properties"] != null &&
              quake["geometry"] != null &&
              quake["geometry"]["coordinates"] is List &&
              quake["geometry"]["coordinates"].length >= 2,
        )
        .map((quake) {
          final properties = quake["properties"];
          final geometry = quake["geometry"];
          final coordinates = geometry["coordinates"];

          final double longitude = coordinates[0].toDouble();
          final double latitude = coordinates[1].toDouble();
          final double magnitude =
              (properties["mag"] as num?)?.toDouble() ?? 0.0;

          return Marker(
            point: LatLng(latitude, longitude),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showEarthquakeDetails(properties),
              child: Icon(
                Icons.location_on,
                color: _getMarkerColor(magnitude),
                size: 10 + (magnitude * 1.5), // Dynamically size marker
              ),
            ),
          );
        })
        .toList();
  }

  /// Optimized dialog with reduced computation in builder
  void _showEarthquakeDetails(Map<String, dynamic> quake) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
      pageBuilder: (context, _, __) {
        return _EarthquakeDetailsDialog(quake: quake);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers(); // Pre-compute markers

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "LastQuakes Map",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(20.0, 78.9), // Center of India
              initialZoom: _zoomLevel,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
                maxZoom: _maxZoom,
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          _ZoomControls(
            zoomLevel: _zoomLevel,
            mapController: _mapController,
            onZoomChanged: (newZoom) {
              setState(() => _zoomLevel = newZoom);
            },
          ),
        ],
      ),
    );
  }
}

/// Extracted zoom controls widget for better separation of concerns
class _ZoomControls extends StatelessWidget {
  final double zoomLevel;
  final MapController mapController;
  final ValueChanged<double> onZoomChanged;

  const _ZoomControls({
    required this.zoomLevel,
    required this.mapController,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Column(
        children: [
          _ZoomButton(
            icon: Icons.add,
            isEnabled: zoomLevel <= 18.0,
            onPressed: () {
              final newZoom = (zoomLevel + 1).clamp(1.0, 18.0);
              mapController.move(mapController.camera.center, newZoom);
              onZoomChanged(newZoom);
            },
          ),
          const SizedBox(height: 8),
          _ZoomButton(
            icon: Icons.remove,
            isEnabled: zoomLevel >= 1.0,
            onPressed: () {
              final newZoom = (zoomLevel - 1).clamp(1.0, 18.0);
              mapController.move(mapController.camera.center, newZoom);
              onZoomChanged(newZoom);
            },
          ),
        ],
      ),
    );
  }
}

/// Simplified zoom button widget
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final bool isEnabled;
  final VoidCallback onPressed;

  const _ZoomButton({
    required this.icon,
    required this.isEnabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: icon.toString(), // Unique hero tag
      mini: true,
      backgroundColor: isEnabled ? Colors.white : Colors.grey.shade300,
      onPressed: isEnabled ? onPressed : null,
      child: Icon(icon, color: isEnabled ? Colors.black : Colors.grey),
    );
  }
}

/// Extracted details dialog for cleaner code
class _EarthquakeDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> quake;

  const _EarthquakeDetailsDialog({required this.quake});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.only(top: 50),
          padding: const EdgeInsets.all(16),
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Close Button
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.black54),
                    ),
                  ),

                  // Earthquake Location
                  Text(
                    quake["place"] ?? "Unknown Location",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Magnitude
                  _DetailRow(
                    icon: Icons.bar_chart,
                    iconColor: Colors.deepOrange,
                    text: "Magnitude: ${quake["mag"] ?? "N/A"}",
                  ),
                  const SizedBox(height: 6),

                  // Time
                  _DetailRow(
                    icon: Icons.access_time,
                    iconColor: Colors.blueAccent,
                    text:
                        "Time: ${DateTime.fromMillisecondsSinceEpoch(quake["time"])}",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper widget for details row
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
      ],
    );
  }
}
