import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:lastquake/utils/formatting.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:lastquake/widgets/components/zoom_controls.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class _EarthquakeData {
  final double magnitude;
  final String location;
  final int timestamp;
  final bool tsunami;
  final double depth;
  final double? lat;
  final double? lon;
  final String? url;

  const _EarthquakeData({
    required this.magnitude,
    required this.location,
    required this.timestamp,
    required this.tsunami,
    required this.depth,
    required this.lat,
    required this.lon,
    this.url,
  });
}

class EarthquakeDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> quakeData;

  const EarthquakeDetailsScreen({super.key, required this.quakeData});

  @override
  EarthquakeDetailsScreenState createState() => EarthquakeDetailsScreenState();
}

class EarthquakeDetailsScreenState extends State<EarthquakeDetailsScreen> {
  // State variables
  final GlobalKey _globalKey = GlobalKey();
  late final MapController _mapController;
  double _zoomLevel = 4.0; // Initial map zoom
  static const double _minZoom = 1.0;
  static const double _maxZoom = 8.0;

  // Processed earthquake data (memoized)
  late final _EarthquakeData _memoizedData = _extractEarthquakeData();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  // Extracts and processes earthquake data from the provided map
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
      url: properties["url"] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // --- Format data using utilities ---
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      _memoizedData.timestamp,
    );
    final formattedTime = FormattingUtils.formatDateTime(context, dateTime);
    final formattedDepth = FormattingUtils.formatDistance(
      context,
      _memoizedData.depth,
    );
    final displayLocationTitle = FormattingUtils.formatPlaceString(
      context,
      _memoizedData.location,
    );

    // Button states
    final bool hasValidUsgsUrl =
        _memoizedData.url != null && _memoizedData.url!.isNotEmpty;
    final bool hasCoordinates =
        _memoizedData.lat != null && _memoizedData.lon != null;

    return Scaffold(
      appBar: LastQuakesAppBar(
        title: "Earthquake Details",
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Earthquake Details',
            onPressed: _shareEarthquakeDetails,
          ),
        ],
      ),
      body: ListView(
        children: [
          // --- Main Information Card ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RepaintBoundary(
                    key: _globalKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Impact Section Header (Magnitude & Tsunami) ---
                        _buildMagnitudeHeader(
                          context,
                          magnitude: _memoizedData.magnitude,
                          tsunami: _memoizedData.tsunami,
                        ),

                        // --- Details Section ---
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- Location Title ---
                              Text(
                                displayLocationTitle,
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // --- Location Details Group ---
                              _buildSectionHeader(context, "LOCATION DETAILS"),
                              _buildDetailRow(
                                context: context,
                                icon: Icons.layers_outlined,
                                iconColor: colorScheme.secondary,
                                label: "Depth",
                                value: formattedDepth,
                              ),
                              _buildCoordinatesRow(
                                context: context,
                                lat: _memoizedData.lat,
                                lon: _memoizedData.lon,
                              ),
                              const SizedBox(height: 8),

                              // --- Time Details Group ---
                              _buildSectionHeader(context, "TIME"),
                              _buildDetailRow(
                                context: context,
                                icon: Icons.schedule_outlined,
                                iconColor: colorScheme.tertiary,
                                label: "Occurred",
                                value: formattedTime,
                              ),

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // --- Action Buttons ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    child: _buildActionButtons(
                      context: context,
                      hasValidUsgsUrl: hasValidUsgsUrl,
                      hasCoordinates: hasCoordinates,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Map Section (Below the main info card) ---
          if (hasCoordinates) _buildMapSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Builds the top header emphasizing magnitude and showing tsunami status
  Widget _buildMagnitudeHeader(
    BuildContext context, {
    required double magnitude,
    required bool tsunami,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    Color magColor = _getMagnitudeColor(magnitude);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: magColor.withValues(alpha: 0.15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Magnitude Display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MAGNITUDE",
                style: textTheme.labelSmall?.copyWith(
                  color: magColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                magnitude.toStringAsFixed(1),
                style: textTheme.displaySmall?.copyWith(
                  color: magColor,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ],
          ),
          // Tsunami Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                tsunami ? Icons.tsunami_rounded : Icons.safety_check_outlined,
                color:
                    tsunami ? Colors.blueAccent : colorScheme.onSurfaceVariant,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                tsunami ? "Tsunami Alert Likely" : "No Tsunami Alert",
                style: textTheme.bodySmall?.copyWith(
                  color:
                      tsunami
                          ? Colors.blueAccent
                          : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Builds a small section header (e.g., "LOCATION DETAILS")
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // For displaying a detail with an icon, label, and value
  Widget _buildDetailRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: textTheme.bodyLarge?.copyWith(height: 1.2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Specific row for displaying coordinates with a copy button
  Widget _buildCoordinatesRow({
    required BuildContext context,
    required double? lat,
    required double? lon,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final String latText = lat?.toStringAsFixed(4) ?? "N/A";
    final String lonText = lon?.toStringAsFixed(4) ?? "N/A";
    final bool canCopy = lat != null && lon != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.location_on_outlined,
            color: colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Coordinates",
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        "Lat: $latText, Lon: $lonText",
                        style: textTheme.bodyLarge?.copyWith(height: 1.2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (canCopy)
                      InkWell(
                        onTap: _copyCoordinates,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Icon(
                            Icons.copy_all_outlined,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds the action buttons section
  Widget _buildActionButtons({
    required BuildContext context,
    required bool hasValidUsgsUrl,
    required bool hasCoordinates,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
      child: Wrap(
        spacing: 12.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.center,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.public),
            label: const Text("View on USGS"),
            style: ElevatedButton.styleFrom(elevation: 1),
            onPressed:
                hasValidUsgsUrl ? () => _launchURL(_memoizedData.url!) : null,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.map_outlined),
            label: const Text("Open Map"),
            style: ElevatedButton.styleFrom(elevation: 1),
            onPressed: hasCoordinates ? _openMap : null,
          ),
        ],
      ),
    );
  }

  // --- Copy Coordinates ---
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

  // --- Share Details ---
  Future<void> _shareEarthquakeDetails() async {
    try {
      RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/earthquake_details.png').create();
      await imagePath.writeAsBytes(pngBytes);

      final magnitude = _memoizedData.magnitude.toStringAsFixed(1);
      final location = _memoizedData.location;

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        subject: 'Earthquake Information: M $magnitude near $location',
      );
    } catch (e) {
      debugPrint('Error sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not initiate sharing.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // --- Open External Map ---
  Future<void> _openMap() async {
    final double? lat = _memoizedData.lat;
    final double? lon = _memoizedData.lon;
    final String locationLabel = _memoizedData.location;

    if (lat == null || lon == null) {
      _showMapErrorSnackbar("Coordinates not available.");
      return;
    }

    Uri mapUri;
    final String encodedLabel = Uri.encodeComponent(locationLabel);
    mapUri = Uri.parse("geo:$lat,$lon?q=$lat,$lon($encodedLabel)");

    try {
      bool launched = await launchUrl(
        mapUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showMapErrorSnackbar("Could not open map application.");
      }
    } catch (e) {
      debugPrint("Error opening map: $e");
      _showMapErrorSnackbar("Error opening map.");
    }
  }

  // --- Launch USGS URL ---
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showUrlErrorSnackbar("Could not launch $urlString");
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      _showUrlErrorSnackbar("Could not launch URL. Invalid format?");
    }
  }

  // --- Snackbar Helpers ---
  void _showMapErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showUrlErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  // --- Get Magnitude Color ---
  Color _getMagnitudeColor(double magnitude) {
    if (magnitude >= 8.0) return Colors.red.shade900;
    if (magnitude >= 7.0) return Colors.red.shade700;
    if (magnitude >= 6.0) return Colors.orange.shade800;
    if (magnitude >= 5.0) return Colors.amber.shade700;
    return Colors.green.shade600;
  }

  Widget _buildMapSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      child: SizedBox(
        height: 250,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(_memoizedData.lat!, _memoizedData.lon!),
                  initialZoom: _zoomLevel,
                  minZoom: _minZoom,
                  maxZoom: _maxZoom,
                ),
                children: [
                  TileLayer(
                    /* urlTemplate:
                        "https://tile.openstreetmap.org/{z}/{x}/{y}.png", */
                    urlTemplate:
                        "https://basemap.nationalmap.gov/arcgis/rest/services/USGSTopo/MapServer/tile/{z}/{y}/{x}", // USGS Topo Alt
                    userAgentPackageName:
                        'com.example.lastquake', // Use your package name
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_memoizedData.lat!, _memoizedData.lon!),
                        width: 50,
                        height: 50,
                        child: Icon(
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
                // Zoom Controls
                bottom: 10,
                right: 10,
                child: ZoomControls(
                  zoomLevel: _zoomLevel,
                  mapController: _mapController,
                  minZoom: _minZoom,
                  maxZoom: _maxZoom,
                  onZoomChanged: (newZoom) {
                    setState(() {
                      _zoomLevel = newZoom;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
