import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui';

class EarthquakeMapScreen extends StatefulWidget {
  final List earthquakes;

  const EarthquakeMapScreen({Key? key, required this.earthquakes})
    : super(key: key);

  @override
  State<EarthquakeMapScreen> createState() => _EarthquakeMapScreenState();
}

class _EarthquakeMapScreenState extends State<EarthquakeMapScreen> {
  late MapController _mapController;
  double _zoomLevel = 2.0;
  static const double minZoom = 1.0;
  static const double maxZoom = 18.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  Color getMarkerColor(double magnitude) {
    if (magnitude >= 8.0) return Colors.red.shade900; // Extreme (8.0+)
    if (magnitude >= 7.0) return Colors.red; // Major (7.0 - 7.9)
    if (magnitude >= 6.0) return Colors.orange; // Strong (6.0 - 6.9)
    if (magnitude >= 5.0) return Colors.amber; // Moderate (5.0 - 5.9)
    return Colors.green; // Light (Below 5.0)
  }

  /// Build earthquake markers from data
  List<Marker> _buildMarkers() {
    return widget.earthquakes
        .map((quake) {
          var properties = quake["properties"];
          var geometry = quake["geometry"];

          if (properties == null || geometry == null) return null;

          List coordinates = geometry["coordinates"];
          if (coordinates.length < 2) return null;

          double longitude = coordinates[0].toDouble();
          double latitude = coordinates[1].toDouble();
          double magnitude = (properties["mag"] as num?)?.toDouble() ?? 0.0;

          return Marker(
            point: LatLng(latitude, longitude),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () {
                _showEarthquakeDetails(properties);
              },
              child: Icon(
                Icons.location_on,
                color: getMarkerColor(magnitude),
                size: 30 + (magnitude * 1.5), // Dynamically size marker
              ),
            ),
          );
        })
        .where((marker) => marker != null)
        .toList()
        .cast<Marker>();
  }

  /// Show earthquake details in a pop-up at the top
  void _showEarthquakeDetails(Map quake) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true, // Close on tap outside
      barrierLabel: '',
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, -1), // Starts from top
            end: Offset(0, 0), // Ends at normal position
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: EdgeInsets.only(top: 50), // Spacing from top
              padding: EdgeInsets.all(16),
              width:
                  MediaQuery.of(context).size.width * 0.9, // Responsive width
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9), // Light background
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 10,
                    sigmaY: 10,
                  ), // Glass effect
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Close Button
                      Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.close, color: Colors.black54),
                        ),
                      ),

                      // Earthquake Location
                      Text(
                        quake["place"] ?? "Unknown Location",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),

                      // Magnitude
                      Row(
                        children: [
                          Icon(Icons.bar_chart, color: Colors.deepOrange),
                          SizedBox(width: 6),
                          Text(
                            "Magnitude: ${quake["mag"] ?? "N/A"}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),

                      // Time
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.blueAccent),
                          SizedBox(width: 6),
                          Text(
                            "Time: ${DateTime.fromMillisecondsSinceEpoch(quake["time"])}",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Earthquake Map"),
        backgroundColor: Color.fromRGBO(251, 248, 239, 1),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(20.0, 78.9), // Center of the India
              initialZoom: _zoomLevel,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          //zoom control buttons
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoom_in",
                  mini: true,
                  backgroundColor:
                      _zoomLevel > maxZoom
                          ? Colors.grey.shade300
                          : Colors.white,
                  onPressed:
                      _zoomLevel <= maxZoom
                          ? () {
                            setState(() {
                              _zoomLevel += 1; //Increase zoom level
                              _mapController.move(
                                _mapController.camera.center,
                                _zoomLevel,
                              );
                            });
                          }
                          : null,
                  child: Icon(
                    Icons.add,
                    color: _zoomLevel > maxZoom ? Colors.grey : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: "zoom_out",
                  mini: true,
                  backgroundColor:
                      _zoomLevel < minZoom
                          ? Colors.grey.shade300
                          : Colors.white,
                  onPressed:
                      _zoomLevel >= minZoom
                          ? () {
                            setState(() {
                              _zoomLevel -= 1; //Decrease zoom level
                              _mapController.move(
                                _mapController.camera.center,
                                _zoomLevel,
                              );
                            });
                          }
                          : null,
                  child: Icon(
                    Icons.remove,
                    color: _zoomLevel < minZoom ? Colors.grey : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      /* bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // Set the current index to 1 (Map)
        onTap: (index) {
          if (index == 0) {
            Navigator.pop(context); // Go back to EarthquakeListScreen
          }
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
        ],
      ), */
    );
  }
}
