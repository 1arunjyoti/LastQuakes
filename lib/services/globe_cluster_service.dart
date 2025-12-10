import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:lastquakes/models/earthquake.dart';

class GlobeClusterService {
  /// Clusters earthquakes based on zoom level using a grid system.
  List<Point> clusterEarthquakes({
    required List<Earthquake> earthquakes,
    required double zoom,
    required Function(Earthquake) updateInfoPanel,
    required Function(GlobeCoordinates, double) onZoomToCluster,
  }) {
    if (earthquakes.isEmpty) return [];

    // Base grid size in degrees. Lower = more clusters, Higher = fewer clusters.
    // Adjust this value to tune performance/visual density.
    const double baseGridSize = 20.0;

    // As zoom increases, grid size decreases effectively (more clusters)
    // We want the grid size to shrink as we zoom in.
    // Zoom 0.5 -> Very large grid
    // Zoom 3.0 -> Very small grid (no clustering ideally)
    final double gridSize = baseGridSize / (zoom * 2);

    final Map<String, List<Earthquake>> clusters = {};

    for (final quake in earthquakes) {
      // Calculate grid cell indices
      final int x = (quake.longitude / gridSize).floor();
      final int y = (quake.latitude / gridSize).floor();
      final String key = '$x,$y';

      clusters.putIfAbsent(key, () => []).add(quake);
    }

    final List<Point> points = [];

    clusters.forEach((key, clusterQuakes) {
      if (clusterQuakes.isEmpty) return;

      // Calculate centroid (average lat/lng)
      double sumLat = 0;
      double sumLng = 0;
      double maxMag = 0;

      for (final q in clusterQuakes) {
        sumLat += q.latitude;
        sumLng += q.longitude;
        if (q.magnitude > maxMag) maxMag = q.magnitude;
      }

      final double avgLat = sumLat / clusterQuakes.length;
      final double avgLng = sumLng / clusterQuakes.length;
      final center = GlobeCoordinates(avgLat, avgLng);
      final id = 'cluster_${key}_${clusterQuakes.length}';

      if (clusterQuakes.length == 1) {
        // Single Point
        final quake = clusterQuakes.first;
        points.add(
          Point(
            id: quake.id,
            coordinates: GlobeCoordinates(quake.latitude, quake.longitude),
            label: 'M ${quake.magnitude.toStringAsFixed(1)}',
            isLabelVisible: quake.magnitude >= 5.0,
            style: PointStyle(
              color: _getMarkerColor(quake.magnitude),
              size: _getMarkerSize(quake.magnitude),
            ),
            onTap: () => updateInfoPanel(quake),
          ),
        );
      } else {
        // Cluster Point
        points.add(
          Point(
            id: id,
            coordinates: center,
            label: '${clusterQuakes.length}', // Show count
            isLabelVisible: true,
            style: PointStyle(
              color: Colors.orange.withValues(alpha: 0.9),
              size: 3.0, // Fixed size matching normal markers
            ),
            onTap: () {
              // Zoom in to the cluster
              onZoomToCluster(center, zoom + 0.5);
            },
          ),
        );
      }
    });

    return points;
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
}
