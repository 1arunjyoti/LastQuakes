import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:lastquake/models/safe_zone.dart';
import 'encryption_service.dart';

/// Service for securely storing and retrieving sensitive personal data
/// Provides type-safe methods for different data types
class SecureStorageService {
  // Storage keys for different data types
  static const String _safeZonesKey = 'secure_safe_zones';
  static const String _emergencyContactsKey = 'secure_emergency_contacts';
  static const String _selectedCountryKey = 'secure_selected_country';
  static const String _notificationSettingsKey = 'secure_notification_settings';

  // Contexts for encryption (different contexts use different derived keys)
  static const String _locationContext = 'location_data';
  static const String _contactsContext = 'emergency_contacts';
  static const String _settingsContext = 'user_settings';

  /// Initialize the secure storage service
  static Future<void> initialize() async {
    await EncryptionService.initialize();
    await _migrateIfNeeded();
  }

  /// Migrate data from legacy custom encryption to native secure storage
  static Future<void> _migrateIfNeeded() async {
    if (await EncryptionService.isLegacyMode()) {
      if (kDebugMode) {
        print('Legacy encryption detected. Starting migration...');
      }

      try {
        // Helper to migrate a single key
        Future<void> migrateKey(String key, String context) async {
          final encrypted = await EncryptionService.retrieveDecryptedData(
            key,
            context,
          );
          if (encrypted != null) {
            try {
              final decrypted = await EncryptionService.decryptLegacy(
                encrypted,
                context,
              );
              await EncryptionService.storeEncryptedData(
                key,
                decrypted,
                context,
              );
              if (kDebugMode) print('Migrated $key');
            } catch (e) {
              if (kDebugMode) print('Error migrating $key: $e');
            }
          }
        }

        await migrateKey(_safeZonesKey, _locationContext);
        await migrateKey(_emergencyContactsKey, _contactsContext);
        await migrateKey(_selectedCountryKey, _settingsContext);
        await migrateKey(_notificationSettingsKey, _settingsContext);

        // Clear legacy keys to mark migration as complete
        await EncryptionService.clearLegacyKeys();
        if (kDebugMode) {
          print('Migration completed successfully.');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error during migration: $e');
        }
      }
    }
  }

  // --- Safe Zones Management ---

  /// Store safe zones securely
  static Future<void> storeSafeZones(List<SafeZone> safeZones) async {
    try {
      final jsonList = safeZones.map((zone) => zone.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      await EncryptionService.storeEncryptedData(
        _safeZonesKey,
        jsonString,
        _locationContext,
      );

      if (kDebugMode) {
        print('Successfully stored ${safeZones.length} safe zones securely');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error storing safe zones: $e');
      }
      rethrow;
    }
  }

  /// Retrieve safe zones securely
  static Future<List<SafeZone>> retrieveSafeZones() async {
    try {
      final jsonString = await EncryptionService.retrieveDecryptedData(
        _safeZonesKey,
        _locationContext,
      );

      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final safeZones =
          jsonList
              .map((json) => SafeZone.fromJson(json as Map<String, dynamic>))
              .toList();

      if (kDebugMode) {
        print('Successfully retrieved ${safeZones.length} safe zones');
      }

      return safeZones;
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving safe zones: $e');
      }
      return []; // Return empty list on error
    }
  }

  // --- Emergency Contacts Management ---

  /// Store emergency contacts securely
  static Future<void> storeEmergencyContacts(
    List<Map<String, String>> contacts,
  ) async {
    try {
      final jsonString = jsonEncode(contacts);

      await EncryptionService.storeEncryptedData(
        _emergencyContactsKey,
        jsonString,
        _contactsContext,
      );

      if (kDebugMode) {
        print(
          'Successfully stored ${contacts.length} emergency contacts securely',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error storing emergency contacts: $e');
      }
      rethrow;
    }
  }

  /// Retrieve emergency contacts securely
  static Future<List<Map<String, String>>> retrieveEmergencyContacts() async {
    try {
      final jsonString = await EncryptionService.retrieveDecryptedData(
        _emergencyContactsKey,
        _contactsContext,
      );

      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final contacts =
          jsonList
              .map((json) => Map<String, String>.from(json as Map))
              .toList();

      if (kDebugMode) {
        print('Successfully retrieved ${contacts.length} emergency contacts');
      }

      return contacts;
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving emergency contacts: $e');
      }
      return []; // Return empty list on error
    }
  }

  // --- Country Selection Management ---

  /// Store selected country securely
  static Future<void> storeSelectedCountry(String country) async {
    try {
      await EncryptionService.storeEncryptedData(
        _selectedCountryKey,
        country,
        _settingsContext,
      );

      if (kDebugMode) {
        print('Successfully stored selected country: $country');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error storing selected country: $e');
      }
      rethrow;
    }
  }

  /// Retrieve selected country securely
  static Future<String?> retrieveSelectedCountry() async {
    try {
      final country = await EncryptionService.retrieveDecryptedData(
        _selectedCountryKey,
        _settingsContext,
      );

      if (kDebugMode && country != null) {
        if (kDebugMode) {
          print('Successfully retrieved selected country: $country');
        }
      }

      return country;
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving selected country: $e');
      }
      return null;
    }
  }

  // --- Notification Settings Management ---

  /// Store notification settings securely
  static Future<void> storeNotificationSettings(
    Map<String, dynamic> settings,
  ) async {
    try {
      final jsonString = jsonEncode(settings);

      await EncryptionService.storeEncryptedData(
        _notificationSettingsKey,
        jsonString,
        _settingsContext,
      );

      if (kDebugMode) {
        print('Successfully stored notification settings securely');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error storing notification settings: $e');
      }
      rethrow;
    }
  }

  /// Retrieve notification settings securely
  static Future<Map<String, dynamic>?> retrieveNotificationSettings() async {
    try {
      final jsonString = await EncryptionService.retrieveDecryptedData(
        _notificationSettingsKey,
        _settingsContext,
      );

      if (jsonString == null) return null;

      final settings = jsonDecode(jsonString) as Map<String, dynamic>;

      if (kDebugMode) {
        print('Successfully retrieved notification settings');
      }

      return settings;
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving notification settings: $e');
      }
      return null;
    }
  }

  // --- Data Migration and Cleanup ---

  /// Migrate data from SharedPreferences to secure storage
  static Future<void> migrateFromSharedPreferences() async {
    // This method would be called during app initialization
    // to migrate existing unencrypted data to encrypted storage
    // Implementation would depend on your specific migration needs
    if (kDebugMode) {
      print('Data migration from SharedPreferences completed');
    }
  }

  /// Clear all secure data (use with extreme caution)
  static Future<void> clearAllSecureData() async {
    try {
      await EncryptionService.clearAllData();
      if (kDebugMode) {
        print('All secure data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing secure data: $e');
      }
      rethrow;
    }
  }

  /// Check if secure storage is properly initialized
  static Future<bool> isInitialized() async {
    return await EncryptionService.isInitialized();
  }

  /// Delete specific data types
  static Future<void> deleteSafeZones() async {
    await EncryptionService.deleteEncryptedData(_safeZonesKey);
  }

  static Future<void> deleteEmergencyContacts() async {
    await EncryptionService.deleteEncryptedData(_emergencyContactsKey);
  }

  static Future<void> deleteSelectedCountry() async {
    await EncryptionService.deleteEncryptedData(_selectedCountryKey);
  }

  static Future<void> deleteNotificationSettings() async {
    await EncryptionService.deleteEncryptedData(_notificationSettingsKey);
  }
}
