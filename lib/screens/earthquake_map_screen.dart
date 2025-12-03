import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lastquake/models/earthquake.dart';
import 'package:lastquake/presentation/providers/earthquake_provider.dart';
import 'package:lastquake/screens/earthquake_details.dart';
import 'package:lastquake/services/location_service.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:lastquake/widgets/appbar.dart';
import 'package:lastquake/widgets/components/location_button.dart';
import 'package:lastquake/widgets/components/map_layers_button.dart';
import 'package:lastquake/widgets/components/zoom_controls.dart';
import 'package:lastquake/widgets/custom_drawer.dart';
import 'package:lastquake/utils/app_page_transitions.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class EarthquakeMapScreen extends StatefulWidget {
  const EarthquakeMapScreen({super.key});

  @override
  State<EarthquakeMapScreen> createState() => _EarthquakeMapScreenState();
}

class _EarthquakeMapScreenState extends State<EarthquakeMapScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final MapController _mapController;
  double _zoomLevel = 2.0;
  static const double _minZoom = 2.0;
  static const double _maxZoom = 18.0;
  // Markers
  List<Marker> _currentMarkers = [];
  static final Map<String, Marker> _markerCache = {};
  static final Map<double, Color> _markerColorCache = {};

  // Performance: Track last processed earthquakes to avoid unnecessary updates
  List<Earthquake>? _lastProcessedEarthquakes;
  bool _isUpdatingMarkers = false;

  // Performance
  Timer? _memoryCleanupTimer;
  bool _isDisposed = false;
  static const int _maxMarkersToRender = 5000;
  static const int _markerBatchSize = 100;
  static const Duration _memoryCleanupInterval = Duration(minutes: 5);

  // Location
  Position? _userPosition;
  final LocationService _locationService = LocationService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapController = MapController();
    _startMemoryCleanupTimer();

    // Initial data fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EarthquakeProvider>().init();
      _fetchUserLocation();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _memoryCleanupTimer?.cancel();
    _clearCaches();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _performMemoryCleanup();
    }
  }

  void _startMemoryCleanupTimer() {
    _memoryCleanupTimer = Timer.periodic(_memoryCleanupInterval, (_) {
      if (!_isDisposed) _performMemoryCleanup();
    });
  }

  void _performMemoryCleanup() {
    if (_markerCache.length > _maxMarkersToRender) {
      _markerCache.clear();
    } else if (_markerCache.length > 1000) {
      final keysToRemove =
          _markerCache.keys.take(_markerCache.length ~/ 2).toList();
      for (final key in keysToRemove) {
        _markerCache.remove(key);
      }
    }
    if (_markerColorCache.length > 100) _markerColorCache.clear();
  }

  void _clearCaches() {
    _markerCache.clear();
    _markerColorCache.clear();
  }

  Future<void> _fetchUserLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (mounted && position != null) {
        setState(() {
          _userPosition = position;
        });
      }
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: LastQuakesAppBar(
        title: "Earthquake Map",
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
            tooltip: 'Filter Earthquakes',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                () => context.read<EarthquakeProvider>().loadData(
                  forceRefresh: true,
                ),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: Consumer<EarthquakeProvider>(
        builder: (context, provider, child) {
          // Trigger marker update when filtered earthquakes change
          // This is a side effect in build, but manageable with a check or separate listener
          // Better approach: Use a Selector for earthquakes and rebuild a widget that handles markers
          // For now, let's call update markers if the list changed (simplified)
          // Actually, we can just rebuild markers here if we are careful about performance.
          // Or use a FutureBuilder/StreamBuilder pattern.
          // Let's use a post-frame callback to trigger marker update if needed, or just do it here if fast enough.
          // Given the optimization logic, we should probably trigger it.

          // Optimization: Only update markers if the list reference changed
          // We can't easily track previous list here without state.
          // So we will rely on a separate method triggered by the provider consumer below.

          return Stack(
            children: [
              _buildMap(provider),
              if (provider.isLoading)
                const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text("Loading Earthquakes..."),
                        ],
                      ),
                    ),
                  ),
                ),
              if (provider.error != null)
                Center(
                  child: Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            provider.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed:
                                () => provider.loadData(forceRefresh: true),
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Map Controls
              Positioned(
                bottom: 20,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MapLayersButton(
                      selectedMapType: provider.mapLayerType,
                      onMapTypeChanged: provider.setMapLayerType,
                      showFaultLines: provider.showFaultLines,
                      isLoadingFaultLines: provider.isLoadingFaultLines,
                      onFaultLinesToggled: provider.toggleFaultLines,
                    ),
                    const SizedBox(height: 10),
                    LocationButton(
                      mapController: _mapController,
                      zoomLevel: _zoomLevel,
                      onLocationFound: (position) {
                        setState(() {
                          _userPosition = position;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    ZoomControls(
                      mapController: _mapController,
                      zoomLevel: _zoomLevel,
                      minZoom: _minZoom,
                      maxZoom: _maxZoom,
                      onZoomChanged: (zoom) {
                        setState(() => _zoomLevel = zoom);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(EarthquakeProvider provider) {
    // Use Selector to only rebuild when mapEarthquakes changes
    return Selector<EarthquakeProvider, List<Earthquake>>(
      selector: (_, p) => p.mapEarthquakes,
      // Use shouldRebuild to check if we actually need to update
      shouldRebuild: (previous, next) => !identical(previous, next),
      builder: (context, earthquakes, child) {
        // Schedule marker update after build completes (not during build)
        _scheduleMarkerUpdate(earthquakes);

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(20.0, 0.0),
            initialZoom: _zoomLevel,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: (position, hasGesture) {
              if (hasGesture) {
                _zoomLevel = position.zoom;
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _getTileUrl(provider.mapLayerType),
              userAgentPackageName: 'com.example.lastquake',
            ),
            if (provider.showFaultLines)
              PolylineLayer(polylines: provider.faultLines),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 45,
                size: const Size(40, 40),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(50),
                maxZoom: 15,
                markers: _currentMarkers,
                builder: (context, markers) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        markers.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_userPosition != null)
              MarkerLayer(markers: [_buildUserLocationMarker()]),
          ],
        );
      },
    );
  }

  String _getTileUrl(MapLayerType type) {
    switch (type) {
      case MapLayerType.osm:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapLayerType.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapLayerType.terrain:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Terrain_Base/MapServer/tile/{z}/{y}/{x}';
      case MapLayerType.dark:
        return 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png';
    }
  }

  Marker _buildUserLocationMarker() {
    if (_userPosition == null) {
      return const Marker(point: LatLng(0, 0), child: SizedBox());
    }
    return Marker(
      point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
      width: 20,
      height: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
      ),
    );
  }

  /// Schedule marker update to run after build completes
  /// This avoids calling setState during build
  void _scheduleMarkerUpdate(List<Earthquake> earthquakes) {
    // Skip if already processing or if data hasn't changed
    if (_isUpdatingMarkers) return;
    if (identical(_lastProcessedEarthquakes, earthquakes)) return;

    // Check if content actually changed (quick check using length + first/last ids)
    if (_lastProcessedEarthquakes != null &&
        _lastProcessedEarthquakes!.length == earthquakes.length &&
        earthquakes.isNotEmpty &&
        _lastProcessedEarthquakes!.isNotEmpty &&
        _lastProcessedEarthquakes!.first.id == earthquakes.first.id &&
        _lastProcessedEarthquakes!.last.id == earthquakes.last.id) {
      return;
    }

    // Schedule update after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _updateMarkersOptimized(earthquakes);
      }
    });
  }

  /// Update markers with optimization - only creates new markers when needed
  Future<void> _updateMarkersOptimized(List<Earthquake> earthquakes) async {
    if (!mounted || _isDisposed || _isUpdatingMarkers) return;

    _isUpdatingMarkers = true;
    _lastProcessedEarthquakes = earthquakes;

    try {
      if (earthquakes.isEmpty) {
        if (_currentMarkers.isNotEmpty) {
          setState(() => _currentMarkers = []);
        }
        return;
      }

      final earthquakesToProcess =
          earthquakes.length > _maxMarkersToRender
              ? earthquakes.take(_maxMarkersToRender).toList()
              : earthquakes;

      // Build markers using cache where possible
      final List<Marker> newMarkers = [];

      for (int i = 0; i < earthquakesToProcess.length; i += _markerBatchSize) {
        if (!mounted || _isDisposed) return;

        final end = math.min(i + _markerBatchSize, earthquakesToProcess.length);
        final batch = earthquakesToProcess.sublist(i, end);

        for (final quake in batch) {
          final marker = _getOrCreateMarker(quake);
          if (marker != null) newMarkers.add(marker);
        }

        // Yield to UI thread periodically for large datasets
        if (i + _markerBatchSize < earthquakesToProcess.length) {
          await Future.delayed(Duration.zero);
        }
      }

      if (mounted && !_isDisposed) {
        setState(() => _currentMarkers = newMarkers);
      }
    } finally {
      _isUpdatingMarkers = false;
    }
  }

  /// Get marker from cache or create new one (synchronous for better performance)
  Marker? _getOrCreateMarker(Earthquake quake) {
    try {
      final String id = quake.id;

      // Return cached marker if available
      if (_markerCache.containsKey(id)) {
        return _markerCache[id];
      }

      final double markerSize = (2 + (quake.magnitude * 4.0)).clamp(4.0, 30.0);
      final Color markerColor = _getMarkerColorOptimized(quake.magnitude);

      final marker = Marker(
        point: LatLng(quake.latitude, quake.longitude),
        width: markerSize,
        height: markerSize,
        child: GestureDetector(
          onTap: () => _showEarthquakePopup(quake),
          child: Tooltip(
            message: 'M ${quake.magnitude.toStringAsFixed(1)}\n${quake.place}',
            preferBelow: false,
            child: Container(
              decoration: BoxDecoration(
                color: markerColor.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.5),
                  width: 1.0,
                ),
              ),
            ),
          ),
        ),
      );

      _markerCache[id] = marker;
      return marker;
    } catch (e) {
      return null;
    }
  }

  Color _getMarkerColorOptimized(double magnitude) {
    if (_markerColorCache.containsKey(magnitude)) {
      return _markerColorCache[magnitude]!;
    }

    Color color;
    if (magnitude < 4.0) {
      color = Colors.green;
    } else if (magnitude < 5.0) {
      color = Colors.yellow;
    } else if (magnitude < 6.0) {
      color = Colors.orange;
    } else if (magnitude < 7.0) {
      color = Colors.red;
    } else {
      color = Colors.purple;
    }

    _markerColorCache[magnitude] = color;
    return color;
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
                      // Magnitude badge
                      Container(
                        decoration: BoxDecoration(
                          color: _getMarkerColorOptimized(quake.magnitude),
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

                  // Source
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.source,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Source: ${quake.source}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),

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

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer<EarthquakeProvider>(
          builder: (context, provider, _) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Earthquakes',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Minimum Magnitude: ${provider.mapMinMagnitude.toStringAsFixed(1)}",
                  ),
                  Slider(
                    value: provider.mapMinMagnitude,
                    min: 3.0,
                    max: 9.0,
                    divisions: 12,
                    label: provider.mapMinMagnitude.toStringAsFixed(1),
                    onChanged:
                        (value) => provider.setMapFilters(minMagnitude: value),
                  ),
                  const SizedBox(height: 20),
                  const Text("Time Period"),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children:
                        TimeWindow.values.map((window) {
                          final isSelected = provider.mapTimeWindow == window;
                          return FilterChip(
                            label: Text(_getTimeWindowLabel(window)),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                provider.setMapFilters(timeWindow: window);
                              }
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getTimeWindowLabel(TimeWindow window) {
    switch (window) {
      case TimeWindow.lastHour:
        return "Last Hour";
      case TimeWindow.last24Hours:
        return "Last 24 Hrs";
      case TimeWindow.last7Days:
        return "Last 7 Days";
      case TimeWindow.last45Days:
        return "All (45 Days)";
    }
  }
}
