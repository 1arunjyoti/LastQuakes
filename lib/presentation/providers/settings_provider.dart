import 'package:flutter/foundation.dart';
import 'package:lastquakes/domain/repositories/settings_repository.dart';
import 'package:lastquakes/utils/enums.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;

  SettingsProvider({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Set<DataSource> _selectedDataSources = {DataSource.usgs};
  bool _isLoading = true;
  String? _error;

  Set<DataSource> get selectedDataSources => _selectedDataSources;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedDataSources = await _settingsRepository.getSelectedDataSources();
    } catch (e) {
      _error = "Failed to load settings: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDataSources(Set<DataSource> sources) async {
    _selectedDataSources = sources;
    notifyListeners();

    try {
      await _settingsRepository.saveSelectedDataSources(sources);
    } catch (e) {
      _error = "Failed to save data sources: $e";
      notifyListeners();
    }
  }
}
