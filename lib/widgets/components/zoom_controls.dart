import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Modern Zoom Controls Widget
class ZoomControls extends StatelessWidget {
  final double zoomLevel;
  final MapController mapController;
  final ValueChanged<double> onZoomChanged;
  final double minZoom;
  final double maxZoom;

  const ZoomControls({
    super.key,
    required this.zoomLevel,
    required this.mapController,
    required this.onZoomChanged,
    this.minZoom = 2.0,
    this.maxZoom = 18.0,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              onTap: zoomLevel < maxZoom ? () {
                final newZoom = (zoomLevel + 1).clamp(minZoom, maxZoom);
                mapController.move(mapController.camera.center, newZoom);
                onZoomChanged(newZoom);
              } : null,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.add,
                  size: 24,
                  color: zoomLevel < maxZoom 
                      ? colorScheme.onSurface 
                      : colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          Container(
            height: 1,
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              onTap: zoomLevel > minZoom ? () {
                final newZoom = (zoomLevel - 1).clamp(minZoom, maxZoom);
                mapController.move(mapController.camera.center, newZoom);
                onZoomChanged(newZoom);
              } : null,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.remove,
                  size: 24,
                  color: zoomLevel > minZoom 
                      ? colorScheme.onSurface 
                      : colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}