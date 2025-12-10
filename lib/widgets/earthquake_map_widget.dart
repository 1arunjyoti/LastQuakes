import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap_plus/flutter_map_heatmap.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:lastquakes/models/earthquake.dart';
import 'package:lastquakes/presentation/providers/earthquake_provider.dart';
import 'package:lastquakes/screens/earthquake_details.dart';
import 'package:lastquakes/services/location_service.dart';
import 'package:lastquakes/utils/enums.dart';
import 'package:lastquakes/widgets/components/location_button.dart';
import 'package:lastquakes/widgets/components/map_layers_button.dart';
import 'package:lastquakes/widgets/components/map_legend.dart';
import 'package:lastquakes/widgets/components/zoom_controls.dart';
import 'package:lastquakes/widgets/earthquake_globe_widget.dart';
import 'package:lastquakes/utils/app_page_transitions.dart';
import 'package:lastquakes/widgets/components/earthquake_bottom_sheet.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:lastquakes/services/tile_cache_service.dart';

class EarthquakeMapWidget extends StatefulWidget {
  final MapController? mapController;

  const EarthquakeMapWidget({super.key, this.mapController});

  @override
  State<EarthquakeMapWidget> createState() => EarthquakeMapWidgetState();
}

class EarthquakeMapWidgetState extends State<EarthquakeMapWidget>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final MapController _mapController;
  double _zoomLevel = 2.0;
  static const double _minZoom = 2.0;
  static const double _maxZoom = 18.0;
  // Zoom level threshold for disabling clustering (individual markers shown above this)
  static const double _clusterDisableZoom = 4.0;
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
  Location? _userPosition;
  final LocationService _locationService = LocationService();

  // Heatmap reset stream
  final StreamController<void> _heatmapResetController =
      StreamController<void>.broadcast();

  // Plate label markers cache
  List<Marker> _plateLabelMarkers = [];
  List<FaultLineLabel>? _lastFaultLineLabels;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapController = widget.mapController ?? MapController();
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
    // Only dispose if we created it
    if (widget.mapController == null) {
      _mapController.dispose();
    }
    _heatmapResetController.close();
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

  void showFilters() {
    _showFilterBottomSheet();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<EarthquakeProvider>(
      builder: (context, provider, child) {
        return Stack(
          children: [
            // Conditionally show flat map or 3D globe
            if (provider.mapViewMode == MapViewMode.flat)
              _buildMap(provider)
            else
              EarthquakeGlobeWidget(earthquakes: provider.mapEarthquakes),
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
                  // Only show map layers button in flat map mode
                  if (provider.mapViewMode == MapViewMode.flat) ...[
                    MapLayersButton(
                      selectedMapType: provider.mapLayerType,
                      onMapTypeChanged: provider.setMapLayerType,
                      showFaultLines: provider.showFaultLines,
                      isLoadingFaultLines: provider.isLoadingFaultLines,
                      onFaultLinesToggled: provider.toggleFaultLines,
                      showHeatmap: provider.showHeatmap,
                      onHeatmapToggled: provider.toggleHeatmap,
                      showPlateLabels: provider.showPlateLabels,
                      onPlateLabelsToggled: provider.togglePlateLabels,
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Toggle between flat and 3D globe view
                  _buildViewModeToggle(provider),
                  // Only show map-specific controls when in flat map mode
                  if (provider.mapViewMode == MapViewMode.flat) ...[
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
                ],
              ),
            ),
          ],
        );
      },
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

        // Update plate label markers cache if labels changed
        _updatePlateLabelMarkers(provider.faultLineLabels);

        final attributionText = _getAttributionText(provider.mapLayerType);
        final faultLineAttribution =
            provider.showFaultLines ? 'Plate Boundaries: P. Bird, 2003' : null;

        return Stack(
          children: [
            FlutterMap(
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
                  // Update zoom level and rebuild to toggle cluster/marker layers
                  if (position.zoom != _zoomLevel) {
                    setState(() => _zoomLevel = position.zoom);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _getTileUrl(provider.mapLayerType),
                  userAgentPackageName: 'app.lastquakes',
                  tileProvider:
                      TileCacheService.instance.createCachedProvider(),
                ),
                if (provider.showFaultLines) ...[
                  PolylineLayer(polylines: provider.faultLines),
                  // Plate boundary labels (only show when enabled and zoomed in)
                  if (provider.showPlateLabels && _zoomLevel >= 4.0)
                    MarkerLayer(markers: _plateLabelMarkers),
                ],
                if (provider.showHeatmap && earthquakes.isNotEmpty)
                  HeatMapLayer(
                    heatMapDataSource: InMemoryHeatMapDataSource(
                      data:
                          earthquakes
                              .map(
                                (e) => WeightedLatLng(
                                  LatLng(e.latitude, e.longitude),
                                  e.magnitude,
                                ),
                              )
                              .toList(),
                    ),
                    heatMapOptions: HeatMapOptions(
                      gradient: HeatMapOptions.defaultGradient,
                      minOpacity: 0.3,
                    ),
                    reset: _heatmapResetController.stream,
                  ),
                // Hide clusters when heatmap is active for better visibility
                // Show clusters when zoomed out, individual markers when zoomed in past threshold
                if (!provider.showHeatmap && _zoomLevel < _clusterDisableZoom)
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 45,
                      size: const Size(40, 40),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(50),
                      maxZoom: _zoomLevel >= 3 ? _zoomLevel - 1 : 3,
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
                // Show individual markers when zoomed in past threshold
                if (!provider.showHeatmap && _zoomLevel >= _clusterDisableZoom)
                  MarkerLayer(markers: _currentMarkers),
                if (_userPosition != null)
                  MarkerLayer(markers: [_buildUserLocationMarker()]),
              ],
            ),
            if (attributionText.isNotEmpty || faultLineAttribution != null)
              Positioned(
                left: 16,
                bottom: 16,
                child: _buildAttributionBadge(
                  context,
                  attributionText,
                  faultLineAttribution: faultLineAttribution,
                ),
              ),
            Positioned(
              left: 16,
              top: 16,
              child: MapLegend(showFaultLines: provider.showFaultLines),
            ),
          ],
        );
      },
    );
  }

  String _getTileUrl(MapLayerType type) {
    switch (type) {
      case MapLayerType.osm:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
      case MapLayerType.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapLayerType.terrain:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Terrain_Base/MapServer/tile/{z}/{y}/{x}';
      case MapLayerType.dark:
        return 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png';
    }
  }

  /// Update plate label markers cache - only rebuilds when labels change
  void _updatePlateLabelMarkers(List<FaultLineLabel> labels) {
    // Skip if labels haven't changed
    if (identical(_lastFaultLineLabels, labels)) return;
    if (_lastFaultLineLabels != null &&
        _lastFaultLineLabels!.length == labels.length &&
        labels.isNotEmpty &&
        _lastFaultLineLabels!.isNotEmpty) {
      // Quick check if it's the same data
      return;
    }

    _lastFaultLineLabels = labels;

    // Build cached markers with simplified styling for performance
    _plateLabelMarkers =
        labels.map((label) {
          final color =
              label.boundaryType == 'subduction'
                  ? const Color(0xFFB71C1C)
                  : const Color(0xFF1B5E20);

          return Marker(
            point: label.position,
            width: 140,
            height: 20,
            child: Transform.rotate(
              angle: -label.angle,
              child: Text(
                label.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  // Simplified shadow for better performance (single shadow instead of 2)
                  shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
                ),
                overflow: TextOverflow.visible,
                softWrap: false,
              ),
            ),
          );
        }).toList();
  }

  String _getAttributionText(MapLayerType type) {
    switch (type) {
      case MapLayerType.osm:
        return '© Esri, ArcGIS & partners';
      case MapLayerType.satellite:
        return '© Esri, ArcGIS & partners';
      case MapLayerType.terrain:
        return '© Esri, ArcGIS & partners';
      case MapLayerType.dark:
        return '© CARTO & OpenStreetMap';
    }
  }

  Widget _buildAttributionBadge(
    BuildContext context,
    String attribution, {
    String? faultLineAttribution,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurface,
      fontSize: 10,
    );

    return Semantics(
      label: 'Map attribution',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attribution.isNotEmpty) Text(attribution, style: textStyle),
            if (faultLineAttribution != null)
              Text(faultLineAttribution, style: textStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeToggle(EarthquakeProvider provider) {
    final isGlobe = provider.mapViewMode == MapViewMode.globe;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: provider.toggleMapViewMode,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              isGlobe ? Icons.map : Icons.public,
              color: colorScheme.onSurface,
              size: 24,
            ),
          ),
        ),
      ),
    );
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
        // Trigger heatmap to rebuild with new data
        if (!_heatmapResetController.isClosed) {
          _heatmapResetController.add(null);
        }
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
    if (magnitude >= 7.0) {
      color = Colors.red.shade900;
    } else if (magnitude >= 5.0) {
      color = Colors.orange;
    } else {
      color = Colors.green;
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
      isScrollControlled: true,
      builder: (context) {
        return EarthquakeBottomSheet(
          earthquake: quake,
          onViewDetails: () {
            _showEarthquakeDetails(quake);
          },
        );
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer<EarthquakeProvider>(
          builder: (context, provider, _) {
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;

            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter Earthquakes',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Magnitude Slider (Compact)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Min Magnitude", style: textTheme.titleMedium),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "M ${provider.mapMinMagnitude.toStringAsFixed(1)}",
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: colorScheme.primary,
                        inactiveTrackColor: colorScheme.surfaceContainerHighest,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                      ),
                      child: Slider(
                        value: provider.mapMinMagnitude,
                        min: 1.0,
                        max: 9.0,
                        divisions: 80,
                        onChanged: (value) {
                          provider.setMapFilters(minMagnitude: value);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Time Range (Dropdown)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Time Range", style: textTheme.titleMedium),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<TimeWindow>(
                              value: provider.mapTimeWindow,
                              icon: const Icon(Icons.arrow_drop_down),
                              borderRadius: BorderRadius.circular(12),
                              items:
                                  [
                                    {
                                      'label': 'Last Hour',
                                      'value': TimeWindow.lastHour,
                                    },
                                    {
                                      'label': 'Last 24 Hours',
                                      'value': TimeWindow.last24Hours,
                                    },
                                    {
                                      'label': 'Last 7 Days',
                                      'value': TimeWindow.last7Days,
                                    },
                                    {
                                      'label': 'Last 45 Days',
                                      'value': TimeWindow.last45Days,
                                    },
                                  ].map((item) {
                                    return DropdownMenuItem<TimeWindow>(
                                      value: item['value'] as TimeWindow,
                                      child: Text(
                                        item['label'] as String,
                                        style: textTheme.bodyMedium,
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  provider.setMapFilters(timeWindow: value);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          provider.loadData(forceRefresh: true);
                          Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Apply Filters",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
