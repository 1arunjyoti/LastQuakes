import 'package:lastquake/domain/repositories/earthquake_repository.dart';
import 'package:lastquake/models/earthquake.dart';

class GetEarthquakesUseCase {
  final EarthquakeRepository repository;

  GetEarthquakesUseCase(this.repository);

  Future<List<Earthquake>> call({
    double minMagnitude = 3.0,
    int days = 45,
    bool forceRefresh = false,
  }) {
    return repository.getEarthquakes(
      minMagnitude: minMagnitude,
      days: days,
      forceRefresh: forceRefresh,
    );
  }
}
