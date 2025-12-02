import 'package:lastquake/domain/repositories/earthquake_repository.dart';
import 'package:lastquake/models/earthquake.dart';
import 'package:lastquake/services/multi_source_api_service.dart';

class EarthquakeRepositoryImpl implements EarthquakeRepository {
  final MultiSourceApiService _apiService;

  EarthquakeRepositoryImpl(this._apiService);

  @override
  Future<List<Earthquake>> getEarthquakes({
    double minMagnitude = 3.0,
    int days = 45,
    bool forceRefresh = false,
  }) async {
    return await _apiService.fetchEarthquakes(
      minMagnitude: minMagnitude,
      days: days,
      forceRefresh: forceRefresh,
    );
  }
}
