import 'dart:convert';
import 'package:lastquake/models/safe_zone.dart';
import 'package:lastquake/services/notification_service.dart';
import 'package:lastquake/services/secure_storage_service.dart';
import 'package:lastquake/utils/enums.dart';
import 'package:lastquake/utils/secure_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys for SharedPreferences (kept for backward compatibility/migration)
const String prefNotificationFilterType = 'notification_filter_type';
const String prefNotificationMagnitude = 'notification_magnitude';
const String prefNotificationCountry = 'notification_country';
const String prefNotificationRadius = 'notification_radius';
const String prefNotificationUseCurrentLoc = 'notification_use_current_loc';
const String prefNotificationSafeZones = 'notification_safe_zones';

class PreferencesService {
  // Singleton instance
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  // State
  NotificationFilterType filterType = NotificationFilterType.none;
  double magnitude = 5.0;
  String country = "ALL";
  double radius = 500.0;
  bool useCurrentLocation = false;
  List<SafeZone> safeZones = [];
  bool isLoaded = false;

  // Load settings
  Future<void> loadSettings() async {
    try {
      // Load from secure storage first
      final secureSettings =
          await SecureStorageService.retrieveNotificationSettings();
      final secureSafeZones = await SecureStorageService.retrieveSafeZones();

      if (secureSettings != null) {
        filterType = NotificationFilterType.values.firstWhere(
          (e) => e.name == secureSettings['filterType'],
          orElse: () => NotificationFilterType.none,
        );
        magnitude = (secureSettings['magnitude'] as num?)?.toDouble() ?? 5.0;
        country = secureSettings['country'] as String? ?? "ALL";
        radius = (secureSettings['radius'] as num?)?.toDouble() ?? 500.0;
        useCurrentLocation =
            secureSettings['useCurrentLocation'] as bool? ?? false;
        safeZones = secureSafeZones;
      } else {
        // Migrate from SharedPreferences
        await _migrateFromSharedPreferences();
      }
      isLoaded = true;
    } catch (e) {
      SecureLogger.error("Error loading settings", e);
      // Fallback
      await _migrateFromSharedPreferences();
      isLoaded = true;
    }
  }

  // Migrate from SharedPreferences
  Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      filterType = NotificationFilterType.values.firstWhere(
        (e) => e.name == prefs.getString(prefNotificationFilterType),
        orElse: () => NotificationFilterType.none,
      );
      magnitude = prefs.getDouble(prefNotificationMagnitude) ?? 5.0;
      country = prefs.getString(prefNotificationCountry) ?? "ALL";
      radius = prefs.getDouble(prefNotificationRadius) ?? 500.0;
      useCurrentLocation =
          prefs.getBool(prefNotificationUseCurrentLoc) ?? false;

      final List<String>? safeZonesJson = prefs.getStringList(
        prefNotificationSafeZones,
      );
      if (safeZonesJson != null) {
        safeZones =
            safeZonesJson
                .map((jsonString) => SafeZone.fromJson(jsonDecode(jsonString)))
                .toList();
      } else {
        safeZones = [];
      }

      // Save to secure storage
      await saveSettings(showSnackbar: false);

      // Clear sensitive data from SharedPreferences
      await prefs.remove(prefNotificationSafeZones);

      SecureLogger.info("Migrated settings to secure storage");
    } catch (e) {
      SecureLogger.error("Error migrating settings", e);
    }
  }

  // Save settings
  Future<void> saveSettings({bool showSnackbar = true}) async {
    try {
      final settings = {
        'filterType': filterType.name,
        'magnitude': magnitude,
        'country': country,
        'radius': radius,
        'useCurrentLocation': useCurrentLocation,
      };

      await SecureStorageService.storeNotificationSettings(settings);
      await SecureStorageService.storeSafeZones(safeZones);

      // Save non-sensitive to SharedPreferences for backward compatibility/other uses
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefNotificationFilterType, filterType.name);
      await prefs.setDouble(prefNotificationMagnitude, magnitude);
      await prefs.setString(prefNotificationCountry, country);
      await prefs.setDouble(prefNotificationRadius, radius);
      await prefs.setBool(prefNotificationUseCurrentLoc, useCurrentLocation);

      // Update backend
      await NotificationService.instance.updateBackendRegistration();

      SecureLogger.success("Settings saved successfully");
    } catch (e) {
      SecureLogger.error("Error saving settings", e);
      rethrow;
    }
  }

  // Safe Zone Management
  Future<void> addSafeZone(SafeZone zone) async {
    safeZones.add(zone);
    await saveSettings();
  }

  Future<void> deleteSafeZone(int index) async {
    if (index >= 0 && index < safeZones.length) {
      safeZones.removeAt(index);
      await saveSettings();
    }
  }
}
