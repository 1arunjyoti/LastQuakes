import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fl_location/fl_location.dart';
import 'package:lastquakes/services/location_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Location Button Widget for Map Controls
class LocationButton extends StatefulWidget {
  final MapController mapController;
  final double zoomLevel;
  final ValueChanged<Location>? onLocationFound;
  final VoidCallback? onLocationError;

  const LocationButton({
    super.key,
    required this.mapController,
    required this.zoomLevel,
    this.onLocationFound,
    this.onLocationError,
  });

  @override
  State<LocationButton> createState() => _LocationButtonState();
}

class _LocationButtonState extends State<LocationButton> {
  bool _isLoadingLocation = false;
  final LocationService _locationService = LocationService();

  Future<void> _fetchUserLocation() async {
    if (!mounted) return;

    bool serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _showLocationServicesDisabledDialog();
        return;
      }
    }

    setState(() => _isLoadingLocation = true);

    try {
      final position = await _locationService.getCurrentLocation(
        forceRefresh: true,
      );
      if (!mounted) return;

      if (position != null) {
        setState(() {
          _isLoadingLocation = false;
        });

        widget.mapController.move(
          LatLng(position.latitude, position.longitude),
          widget.zoomLevel,
        );
        _showLocationSuccessSnackBar();

        // Notify parent about location found
        widget.onLocationFound?.call(position);
      } else {
        setState(() => _isLoadingLocation = false);
        _showLocationErrorDialog();
        widget.onLocationError?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _showLocationErrorDialog();
        widget.onLocationError?.call();
      }
    }
  }

  void _showLocationServicesDisabledDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text(
              'Please enable location services on your device to use this feature. '
              'Go to your device settings and turn on location services.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  // Open device settings
                  await launchUrl(Uri.parse('app-settings:'));
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  void _showLocationErrorDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Location Error'),
            content: const Text(
              'Unable to get your current location. Please check your location '
              'permissions and try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showLocationSuccessSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location found!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'My Location',
      child: Container(
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
            borderRadius: BorderRadius.circular(20),
            onTap: _isLoadingLocation ? null : _fetchUserLocation,
            child: Container(
              padding: const EdgeInsets.all(12),
              child:
                  _isLoadingLocation
                      ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      )
                      : Icon(
                        Icons.my_location_outlined,
                        size: 24,
                        color: colorScheme.onSurface,
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
