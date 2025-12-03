import 'package:lastquakes/models/earthquake.dart';

abstract class EarthquakeRepository {
  Future<List<Earthquake>> getEarthquakes({
    double minMagnitude = 3.0,
    int days = 45,
    bool forceRefresh = false,
  });
}
