import 'package:flutter/foundation.dart';
import 'package:fl_location/fl_location.dart';
import 'package:lastquakes/domain/models/notification_settings_model.dart';
import 'package:lastquakes/domain/repositories/device_repository.dart';
import 'package:lastquakes/domain/repositories/settings_repository.dart';
import 'package:lastquakes/models/safe_zone.dart';
import 'package:lastquakes/services/analytics_service.dart';
import 'package:lastquakes/services/location_service.dart';
import 'package:lastquakes/services/secure_token_service.dart';
import 'package:lastquakes/utils/enums.dart';
import 'package:lastquakes/utils/notification_registration_coordinator.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepository;
  final DeviceRepository _deviceRepository;
  final LocationService _locationService;

  SettingsProvider({
    required SettingsRepository settingsRepository,
    required DeviceRepository deviceRepository,
    LocationService? locationService,
  }) : _settingsRepository = settingsRepository,
       _deviceRepository = deviceRepository,
       _locationService = locationService ?? LocationService();

  NotificationSettingsModel _settings = const NotificationSettingsModel();
  Set<DataSource> _selectedDataSources = {DataSource.usgs};
  bool _isLoading = true;
  String? _error;

  NotificationSettingsModel get settings => _settings;
  Set<DataSource> get selectedDataSources => _selectedDataSources;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = await _settingsRepository.getNotificationSettings();
      _selectedDataSources = await _settingsRepository.getSelectedDataSources();
      NotificationRegistrationCoordinator.registerSyncCallback(syncWithBackend);
    } catch (e) {
      _error = "Failed to load settings: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(NotificationSettingsModel newSettings) async {
    _settings = newSettings;
    notifyListeners(); // Optimistic update

    try {
      await _settingsRepository.saveNotificationSettings(newSettings);
      await _syncWithBackend();

      // Log notification settings change
      AnalyticsService.instance.logNotificationSettingsChange(
        enabled: newSettings.filterType != NotificationFilterType.none,
        minMagnitude: newSettings.magnitude,
        radiusKm:
            newSettings.filterType == NotificationFilterType.distance
                ? newSettings.radius.toInt()
                : null,
      );
    } catch (e) {
      _error = "Failed to save settings: $e";
      AnalyticsService.instance.logError(
        error: e,
        reason: 'Failed to save notification settings',
      );
      // Revert or reload could be done here
      notifyListeners();
    }
  }

  Future<void> updateDataSources(Set<DataSource> sources) async {
    _selectedDataSources = sources;
    notifyListeners();

    try {
      await _settingsRepository.saveSelectedDataSources(sources);
      await _syncWithBackend();
    } catch (e) {
      _error = "Failed to save data sources: $e";
      notifyListeners();
    }
  }

  Future<void> addSafeZone(SafeZone zone) async {
    final updatedZones = List<SafeZone>.from(_settings.safeZones)..add(zone);
    await updateSettings(_settings.copyWith(safeZones: updatedZones));
  }

  Future<void> removeSafeZone(int index) async {
    final updatedZones = List<SafeZone>.from(_settings.safeZones)
      ..removeAt(index);
    await updateSettings(_settings.copyWith(safeZones: updatedZones));
  }

  Future<void> _syncWithBackend() async {
    try {
      final token = await SecureTokenService.instance.getFCMToken();
      if (token == null) return;

      Location? currentPosition;
      if (_settings.filterType == NotificationFilterType.distance &&
          _settings.useCurrentLocation) {
        if (await Permission.locationWhenInUse.isGranted) {
          currentPosition = await _locationService.getCurrentLocation();
        }
      }

      final preferences = {
        'filterType': _settings.filterType.name,
        'minMagnitude': _settings.magnitude,
        if (_settings.filterType != NotificationFilterType.none) ...{
          if (_settings.filterType == NotificationFilterType.country)
            'country': _settings.country,
          if (_settings.filterType == NotificationFilterType.distance) ...{
            'radiusKm': _settings.radius,
            'useCurrentLocation': _settings.useCurrentLocation,
            'safeZones': _settings.safeZones.map((z) => z.toJson()).toList(),
            if (currentPosition != null) ...{
              'currentLatitude': currentPosition.latitude,
              'currentLongitude': currentPosition.longitude,
            },
          },
        },
      };

      await _deviceRepository.registerDevice(token, preferences);
    } catch (e) {
      // Log error but don't disrupt UI flow significantly
      if (kDebugMode) {
        print("Backend sync failed: $e");
      }
    }
  }

  Future<void> syncWithBackend() => _syncWithBackend();

  @override
  void dispose() {
    NotificationRegistrationCoordinator.unregisterSyncCallback(syncWithBackend);
    super.dispose();
  }
}
