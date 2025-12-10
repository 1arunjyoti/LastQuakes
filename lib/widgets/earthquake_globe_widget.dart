import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/screens/earthquake_details.dart';
import 'package:lastquakes/utils/app_page_transitions.dart';
import 'package:lastquakes/widgets/components/map_legend.dart';
import 'package:lastquakes/services/globe_cluster_service.dart';
import 'package:lastquakes/widgets/components/earthquake_bottom_sheet.dart';
import 'dart:async';

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

  // Auto-rotation
  Timer? _idleTimer;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _controller = FlutterEarthGlobeController(
      rotationSpeed: 0.002, // Slower rotation
      isRotating: true, // Start rotating by default
      isBackgroundFollowingSphereRotation: true,
      background: const AssetImage('assets/globe/stars.png'),
      surface: const AssetImage('assets/globe/earth.jpg'),
      isZoomEnabled: true,
      zoom: 1.0,
      minZoom: _minZoom,
      maxZoom: _maxZoom,
    );

    // Start idle timer logic
    _startIdleTimer();
  }

  @override
  void dispose() {
    // Do NOT call _controller.dispose() here to prevent double-dispose error
    _debounceTimer?.cancel();
    _idleTimer?.cancel();
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
  Timer? _debounceTimer;
  final GlobeClusterService _clusterService = GlobeClusterService();

  void _addEarthquakePoints() {
    _pointsAdded = true;

    // Clear existing points first to handle re-clustering
    for (final id in _addedPointIds) {
      _controller.removePoint(id);
    }
    _addedPointIds.clear();

    final points = _clusterService.clusterEarthquakes(
      earthquakes: widget.earthquakes,
      zoom: _currentZoom,
      updateInfoPanel: _showEarthquakePopup,
      onZoomToCluster: (coordinates, newZoom) {
        setState(() {
          _currentZoom = newZoom.clamp(_minZoom, _maxZoom);
        });
        _controller.setZoom(_currentZoom);
        _controller.focusOnCoordinates(coordinates);
        // Reset idle timer on interaction
        _resetIdleTimer();
      },
    );

    for (final point in points) {
      _controller.addPoint(point);
      _addedPointIds.add(point.id);
    }
  }

  void _onZoomChanged(double zoom) {
    _currentZoom = zoom;

    // Debounce the clustering update
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          // Trigger rebuild of points with new zoom level
          _addEarthquakePoints();
        });
      }
    });

    // Reset idle timer on zoom interaction
    _resetIdleTimer();
  }

  void _onUserInteractionStart() {
    _isInteracting = true;
    _idleTimer?.cancel();
    _setRotation(false);
  }

  void _onUserInteractionEnd() {
    _isInteracting = false;
    _resetIdleTimer();
  }

  void _startIdleTimer() {
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    // Resume rotation after 3 seconds of inactivity
    _idleTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isInteracting) {
        _setRotation(true);
      }
    });
  }

  void _setRotation(bool rotate) {
    if (_controller.isRotating != rotate) {
      _controller.isRotating = rotate;
    }
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 0.3).clamp(_minZoom, _maxZoom);
    });
    _controller.setZoom(_currentZoom);
    _resetIdleTimer();
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 0.3).clamp(_minZoom, _maxZoom);
    });
    _controller.setZoom(_currentZoom);
    _resetIdleTimer();
  }

  void _showEarthquakeDetails(Earthquake quake) {
    _onUserInteractionStart(); // Pause rotation when nav away
    Navigator.push(
      context,
      AppPageTransitions.scaleRoute(
        page: EarthquakeDetailsScreen(earthquake: quake),
      ),
    ).then((_) => _onUserInteractionEnd()); // Resume when back
  }

  void _showEarthquakePopup(Earthquake quake) {
    _onUserInteractionStart(); // Pause rotation when interacting with popup
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return EarthquakeBottomSheet(
          earthquake: quake,
          onViewDetails: () {
            _showEarthquakeDetails(quake);
          },
        );
      },
    ).then((_) => _onUserInteractionEnd()); // Resume when popup closes
  }

  @override
  Widget build(BuildContext context) {
    // Add points after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.earthquakes.isNotEmpty && !_pointsAdded) {
        _addEarthquakePoints();
      }
    });

    return Stack(
      children: [
        Center(
          child: Listener(
            onPointerDown: (_) => _onUserInteractionStart(),
            onPointerUp: (_) => _onUserInteractionEnd(),
            onPointerCancel: (_) => _onUserInteractionEnd(),
            // Using HitTestBehavior to ensure we catch events
            behavior: HitTestBehavior.translucent,
            child: FlutterEarthGlobe(
              controller: _controller,
              radius: MediaQuery.of(context).size.width * 0.4,
              onZoomChanged: _onZoomChanged,
              onTap: (point) {
                _resetIdleTimer();
              },
            ),
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
