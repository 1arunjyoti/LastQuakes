import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class EarthquakeDetailsScreen extends StatefulWidget {
  final Map quakeData;

  const EarthquakeDetailsScreen({Key? key, required this.quakeData})
    : super(key: key);

  @override
  _EarthquakeDetailsScreenState createState() =>
      _EarthquakeDetailsScreenState();
}

class _EarthquakeDetailsScreenState extends State<EarthquakeDetailsScreen> {
  late MapController _mapController;
  double _zoomLevel = 4.0; // Initial zoom level
  static const double minZoom = 1.0;
  static const double maxZoom = 18.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    final properties = widget.quakeData["properties"];
    final geometry = widget.quakeData["geometry"];

    double magnitude = properties["mag"]?.toDouble() ?? 0.0;
    String location = properties["place"] ?? "Unknown Location";
    int timestamp = properties["time"] ?? 0;
    bool tsunami = properties["tsunami"] == 1;
    double depth =
        (geometry["coordinates"][2] ?? 0.0) > 2
            ? (geometry["coordinates"][2] ?? 0.0).toDouble()
            : 0.0;

    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    String formattedTime = DateFormat.yMMMd().add_jm().format(dateTime);

    /* double lat = geometry["coordinates"][1];
    double lon = geometry["coordinates"][0]; */

    double? lat =
        (geometry["coordinates"]?.length ?? 0) > 1
            ? geometry["coordinates"][1]?.toDouble()
            : null;
    double? lon =
        (geometry["coordinates"]?.length ?? 0) > 0
            ? geometry["coordinates"][0]?.toDouble()
            : null; // ✅ Added safety for missing coordinates

    return Scaffold(
      appBar: AppBar(
        title: const Text("Earthquake Details"),
        backgroundColor: Color.fromRGBO(251, 248, 239, 1),
      ),
      body: Column(
        children: [
          // Earthquake Info Section
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
                      location,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.grey.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.speed, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 5),
                        Text(
                          "Magnitude: ${magnitude.toStringAsFixed(1)}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.water, color: Colors.blue, size: 20),
                        const SizedBox(width: 5),
                        Text(
                          "Tsunami Alert: ${tsunami ? "Yes" : "No"}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.layers, color: Colors.green, size: 20),
                        const SizedBox(width: 5),
                        Text(
                          "Depth: ${depth.toStringAsFixed(1)} km",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // OpenStreetMap with Zoom Controls
          if (lat != null && lon != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: SizedBox(
                height: 300,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(lat, lon),
                          initialZoom: _zoomLevel,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                            subdomains: ['a', 'b', 'c'],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(lat, lon),
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

                      // Zoom Controls
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Column(
                          children: [
                            FloatingActionButton(
                              heroTag: "zoom_in",
                              mini: true,
                              backgroundColor:
                                  _zoomLevel >= maxZoom
                                      ? Colors.grey.shade300
                                      : Colors.white,
                              child: Icon(
                                Icons.add,
                                color:
                                    _zoomLevel >= maxZoom
                                        ? Colors.grey
                                        : Colors.black,
                              ),
                              onPressed: () {
                                if (_zoomLevel < maxZoom) {
                                  setState(() {
                                    _zoomLevel += 1;
                                    _mapController.moveAndRotate(
                                      _mapController.camera.center,
                                      _zoomLevel,
                                      0,
                                    );
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Max zoom level reached!"),
                                    ),
                                  ); // ✅ Show warning if zoom limit is reached
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton(
                              heroTag: "zoom_out",
                              mini: true,
                              backgroundColor:
                                  _zoomLevel <= minZoom
                                      ? Colors.grey.shade300
                                      : Colors.white,
                              child: Icon(
                                Icons.remove,
                                color:
                                    _zoomLevel <= minZoom
                                        ? Colors.grey
                                        : Colors.black,
                              ),
                              onPressed: () {
                                if (_zoomLevel > minZoom) {
                                  setState(() {
                                    _zoomLevel -= 1;
                                    _mapController.moveAndRotate(
                                      _mapController.camera.center,
                                      _zoomLevel,
                                      0,
                                    );
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Min zoom level reached!"),
                                    ),
                                  ); // ✅ Show warning if zoom limit is reached
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
