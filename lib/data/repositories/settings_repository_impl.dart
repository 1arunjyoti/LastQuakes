import 'package:flutter/foundation.dart';
import 'package:lastquakes/domain/models/notification_settings_model.dart';
import 'package:lastquakes/domain/repositories/settings_repository.dart';
import 'package:lastquakes/models/safe_zone.dart';
import 'package:lastquakes/services/multi_source_api_service.dart';
import 'package:lastquakes/services/secure_storage_service.dart';
import 'package:lastquakes/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final MultiSourceApiService _apiService;

  SettingsRepositoryImpl(this._apiService);

  @override
  Future<NotificationSettingsModel> getNotificationSettings() async {
    try {
      final secureSettings =
          await SecureStorageService.retrieveNotificationSettings();
      final secureSafeZones = await SecureStorageService.retrieveSafeZones();

      if (secureSettings != null) {
        return NotificationSettingsModel(
          filterType: NotificationFilterType.values.firstWhere(
            (e) => e.name == secureSettings['filterType'],
            orElse: () => NotificationFilterType.none,
          ),
          magnitude: (secureSettings['magnitude'] as num?)?.toDouble() ?? 5.0,
          country: secureSettings['country'] as String? ?? "ALL",
          radius: (secureSettings['radius'] as num?)?.toDouble() ?? 500.0,
          useCurrentLocation:
              secureSettings['useCurrentLocation'] as bool? ?? false,
          safeZones: secureSafeZones,
        );
      } else {
        // Fallback to defaults or migration logic if needed
        // For now, return default
        return const NotificationSettingsModel();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading notification settings: $e');
      }
      return const NotificationSettingsModel();
    }
  }

  @override
  Future<void> saveNotificationSettings(
    NotificationSettingsModel settings,
  ) async {
    try {
      final settingsMap = {
        'filterType': settings.filterType.name,
        'magnitude': settings.magnitude,
        'country': settings.country,
        'radius': settings.radius,
        'useCurrentLocation': settings.useCurrentLocation,
      };

      await SecureStorageService.storeNotificationSettings(settingsMap);
      await SecureStorageService.storeSafeZones(settings.safeZones);

      // Save non-sensitive data to SharedPreferences for backward compatibility/other uses
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'notification_filter_type',
        settings.filterType.name,
      );
      await prefs.setDouble('notification_magnitude', settings.magnitude);
      await prefs.setString('notification_country', settings.country);
      await prefs.setDouble('notification_radius', settings.radius);
      await prefs.setBool(
        'notification_use_current_loc',
        settings.useCurrentLocation,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving notification settings: $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<SafeZone>> getSafeZones() async {
    return await SecureStorageService.retrieveSafeZones();
  }

  @override
  Future<void> saveSafeZones(List<SafeZone> safeZones) async {
    await SecureStorageService.storeSafeZones(safeZones);
  }

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
