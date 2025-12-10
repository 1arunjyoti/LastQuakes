import 'package:lastquakes/domain/repositories/settings_repository.dart';
import 'package:lastquakes/services/multi_source_api_service.dart';
import 'package:lastquakes/utils/enums.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final MultiSourceApiService _apiService;

  SettingsRepositoryImpl(this._apiService);

  @override
  Future<Set<DataSource>> getSelectedDataSources() async {
    return _apiService.getSelectedSources();
  }

  @override
  Future<void> saveSelectedDataSources(Set<DataSource> sources) async {
    await _apiService.setSelectedSources(sources);
    await _apiService.clearCache();
  }
}
