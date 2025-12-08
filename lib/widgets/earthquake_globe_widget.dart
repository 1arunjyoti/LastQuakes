import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/screens/earthquake_details.dart';
import 'package:lastquakes/utils/app_page_transitions.dart';
import 'package:lastquakes/widgets/components/map_legend.dart';

class EarthquakeGlobeWidget extends StatefulWidget {
  final List<Earthquake> earthquakes;

  const EarthquakeGlobeWidget({super.key, required this.earthquakes});

  @override
  State<EarthquakeGlobeWidget> createState() => _EarthquakeGlobeWidgetState();
}

class _EarthquakeGlobeWidgetState extends State<EarthquakeGlobeWidget> {
  late FlutterEarthGlobeController _controller;
  bool _pointsAdded = false;
  double _currentZoom = 1.0;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 3.0;

  @override
  void initState() {
    super.initState();
    _controller = FlutterEarthGlobeController(
      rotationSpeed: 0.02,
      isRotating: false,
      isBackgroundFollowingSphereRotation: true,
      background: const AssetImage('assets/globe/stars.png'),
      surface: const AssetImage('assets/globe/earth.jpg'),
      isZoomEnabled: true,
      zoom: 1.0,
      minZoom: _minZoom,
      maxZoom: _maxZoom,
    );
  }

  @override
  void dispose() {
    // Note: FlutterEarthGlobeController is disposed internally by the widget
    // Do NOT call _controller.dispose() here to prevent double-dispose error
    super.dispose();
  }

  @override
  void didUpdateWidget(EarthquakeGlobeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if earthquake list changed by comparing lengths and first item
    if (oldWidget.earthquakes.length != widget.earthquakes.length ||
        (oldWidget.earthquakes.isNotEmpty &&
            widget.earthquakes.isNotEmpty &&
            oldWidget.earthquakes.first.id != widget.earthquakes.first.id)) {
      _rebuildPoints();
    }
  }

  void _rebuildPoints() {
    // Remove all existing points by their IDs
    for (final id in _addedPointIds) {
      _controller.removePoint(id);
    }
    _addedPointIds.clear();
    _pointsAdded = false;

    // Add new points
    _addEarthquakePoints();
  }

  // Track which point IDs have been added
  final Set<String> _addedPointIds = {};

  void _addEarthquakePoints() {
    if (_pointsAdded) return;
    _pointsAdded = true;

    for (final quake in widget.earthquakes) {
      if (_addedPointIds.contains(quake.id)) continue;

      _controller.addPoint(
        Point(
          id: quake.id,
          coordinates: GlobeCoordinates(quake.latitude, quake.longitude),
          label: 'M ${quake.magnitude.toStringAsFixed(1)}',
          isLabelVisible: quake.magnitude >= 5.0,
          style: PointStyle(
            color: _getMarkerColor(quake.magnitude),
            size: _getMarkerSize(quake.magnitude),
          ),
          onTap: () => _showEarthquakePopup(quake),
        ),
      );
      _addedPointIds.add(quake.id);
    }
  }

  Color _getMarkerColor(double magnitude) {
    if (magnitude >= 7.0) {
      return Colors.red.shade900;
    } else if (magnitude >= 5.0) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  double _getMarkerSize(double magnitude) {
    return (0.5 + (magnitude * 0.4)).clamp(1.0, 4.0);
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 0.3).clamp(_minZoom, _maxZoom);
    });
    _controller.setZoom(_currentZoom);
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 0.3).clamp(_minZoom, _maxZoom);
    });
    _controller.setZoom(_currentZoom);
  }

  void _showEarthquakeDetails(Earthquake quake) {
    Navigator.push(
      context,
      AppPageTransitions.scaleRoute(
        page: EarthquakeDetailsScreen(earthquake: quake),
      ),
    );
  }

  void _showEarthquakePopup(Earthquake quake) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with magnitude and close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: _getMarkerColor(quake.magnitude),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          'M ${quake.magnitude.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          quake.place,
                          style: Theme.of(context).textTheme.bodyLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Time
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatDateTime(quake.time),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Coordinates
                  Row(
                    children: [
                      Icon(
                        Icons.map,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${quake.latitude.toStringAsFixed(2)}°, ${quake.longitude.toStringAsFixed(2)}°',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),

                  // Depth if available
                  if (quake.depth != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_downward,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Depth: ${quake.depth!.toStringAsFixed(1)} km',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // View More button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEarthquakeDetails(quake);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: const Text(
                        'View More Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add points after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.earthquakes.isNotEmpty) {
        _addEarthquakePoints();
      }
    });

    return Stack(
      children: [
        Center(
          child: FlutterEarthGlobe(
            controller: _controller,
            radius: MediaQuery.of(context).size.width * 0.4,
            onZoomChanged: (zoom) {
              _currentZoom = zoom;
            },
          ),
        ),
        // Zoom controls - matching flat map button style
        Positioned(
          bottom: 80,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    onTap:
                        _currentZoom < _maxZoom
                            ? () {
                              _zoomIn();
                            }
                            : null,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.add,
                        size: 24,
                        color:
                            _currentZoom < _maxZoom
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                    onTap:
                        _currentZoom > _minZoom
                            ? () {
                              _zoomOut();
                            }
                            : null,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.remove,
                        size: 24,
                        color:
                            _currentZoom > _minZoom
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Attribution badge
        Positioned(
          left: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '© NASA Blue Marble',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 10,
              ),
            ),
          ),
        ),
        Positioned(left: 16, top: 16, child: const MapLegend()),
      ],
    );
  }
}
