import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:lastquakes/presentation/providers/map_picker_provider.dart';
import 'package:lastquakes/services/tile_cache_service.dart';
import 'package:lastquakes/widgets/appbar.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

// Define min/max zoom levels for button enabling/disabling
const double _minZoom = 3.0;
const double _maxZoom = 18.0;

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialCenter;

  const MapPickerScreen({super.key, this.initialCenter});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Initialize provider with initial center
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<MapPickerProvider>(context, listen: false);
      provider.initialize(widget.initialCenter);

      // Mark map as ready after first frame (though FlutterMap might need its own onMapReady)
      // But for our zoom buttons, we just need to know the widget is mounted and controller is bound.
      // FlutterMap's mapController is usable immediately after build in recent versions if passed.
      // But to be safe and consistent with previous logic:
      provider.setMapReady(true);

      // Check permissions and potentially center
      provider.checkPermissionAndCenter();
    });
  }

  // Handle map tap to select location
  void _handleTap(TapPosition tapPosition, LatLng location) {
    Provider.of<MapPickerProvider>(
      context,
      listen: false,
    ).selectLocation(location);
  }

  void _confirmSelection(MapPickerProvider provider) {
    if (provider.selectedLocation != null) {
      Navigator.of(context).pop(provider.selectedLocation);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap on the map to select a location first.'),
        ),
      );
    }
  }

  // --- Zoom Methods ---
  void _zoomIn(MapPickerProvider provider) {
    if (!provider.mapReady) return;
    final currentZoom = _mapController.camera.zoom;
    final newZoom = currentZoom + 1;
    if (newZoom <= _maxZoom) {
      _mapController.move(_mapController.camera.center, newZoom);
    }
  }

  void _zoomOut(MapPickerProvider provider) {
    if (!provider.mapReady) return;
    final currentZoom = _mapController.camera.zoom;
    final newZoom = currentZoom - 1;
    if (newZoom >= _minZoom) {
      _mapController.move(_mapController.camera.center, newZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LastQuakesAppBar(title: 'Select Safe Zone Location'),
      body: Consumer<MapPickerProvider>(
        builder: (context, provider, child) {
          // Listen for error messages
          if (provider.error != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(provider.error!)));
              provider.clearError();
            });
          }

          // If provider changes currentCenter (e.g. from "My Location"), move the map
          // Note: This might conflict if user is panning.
          // Ideally, we only move if the *intent* was to center.
          // The provider updates currentCenter when "My Location" is clicked.
          // We can check if the map center is different from provider center significantly?
          // Or better, just use a listener on the "My Location" button to call controller.move
          // But we want to keep logic in provider.
          // Let's rely on the fact that provider.currentCenter is the source of truth for "initial" or "re-centered" position.
          // But FlutterMap options.initialCenter is only for init.
          // We need to move controller if provider says so.
          // A simple way is to check if we just finished loading location.
          // But for now, let's keep it simple: The "My Location" button in UI calls provider,
          // and THEN we move the map.
          // Actually, the previous implementation moved the map inside _centerOnUserLocation.
          // Here, the provider updates state. We need to react to it.
          // We can use a separate effect or just handle the move in the button callback *after* provider updates?
          // Or, we can just let the provider handle the logic and expose a stream of "MoveEvents".
          // For simplicity in this refactor, let's just move the map when the "My Location" button is pressed in the UI,
          // using the location from the provider.

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: provider.currentCenter,
                  initialZoom:
                      provider.currentCenter == widget.initialCenter
                          ? 5.0
                          : 13.0,
                  onTap: _handleTap,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'app.lastquakes',
                    tileProvider:
                        TileCacheService.instance.createCachedProvider(),
                  ),
                  if (provider.selectedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: provider.selectedLocation!,
                          width: 80,
                          height: 80,
                          child: Icon(
                            Icons.location_pin,
                            size: 50,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (provider.isLoadingLocation)
                const Center(
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text("Fetching location..."),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 30,
                right: 30,
                child: FloatingActionButton.extended(
                  onPressed: () => _confirmSelection(provider),
                  label: const Text('Confirm Location'),
                  icon: const Icon(Icons.check),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: FloatingActionButton(
                  heroTag: 'centerLocationMapPicker',
                  mini: true,
                  onPressed:
                      provider.locationPermissionGranted
                          ? () async {
                            await provider.centerOnUserLocation();
                            // Move map to new center if successful
                            if (!provider.isLoadingLocation &&
                                provider.error == null) {
                              _mapController.move(provider.currentCenter, 13.0);
                            }
                          }
                          : null,
                  tooltip:
                      provider.locationPermissionGranted
                          ? 'Center on my location'
                          : 'Location permission needed',
                  backgroundColor:
                      provider.locationPermissionGranted
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Colors.grey,
                  child:
                      provider.isLoadingLocation
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Icon(
                            Icons.my_location,
                            color:
                                provider.locationPermissionGranted
                                    ? null
                                    : Colors.white54,
                          ),
                ),
              ),

              // --- Zoom Buttons ---
              Positioned(
                bottom: 30,
                left: 30,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'zoomInMapPicker',
                      tooltip: 'Zoom In',
                      onPressed:
                          provider.mapReady &&
                                  (_mapController.camera.zoom < _maxZoom)
                              ? () => _zoomIn(provider)
                              : null,
                      backgroundColor:
                          provider.mapReady &&
                                  (_mapController.camera.zoom < _maxZoom)
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : Colors.grey,
                      child: Icon(
                        Icons.add,
                        color:
                            provider.mapReady &&
                                    (_mapController.camera.zoom < _maxZoom)
                                ? null
                                : Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'zoomOutMapPicker',
                      tooltip: 'Zoom Out',
                      onPressed:
                          provider.mapReady &&
                                  (_mapController.camera.zoom > _minZoom)
                              ? () => _zoomOut(provider)
                              : null,
                      backgroundColor:
                          provider.mapReady &&
                                  (_mapController.camera.zoom > _minZoom)
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : Colors.grey,
                      child: Icon(
                        Icons.remove,
                        color:
                            provider.mapReady &&
                                    (_mapController.camera.zoom > _minZoom)
                                ? null
                                : Colors.white54,
                      ),
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
}
