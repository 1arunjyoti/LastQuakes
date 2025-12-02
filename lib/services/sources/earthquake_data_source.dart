import 'package:lastquake/models/earthquake.dart';

/// Interface for earthquake data sources
abstract class EarthquakeDataSource {
  /// Fetch earthquakes from the source
  Future<List<Earthquake>> fetchEarthquakes({
    required double minMagnitude,
    required int days,
  });
}
