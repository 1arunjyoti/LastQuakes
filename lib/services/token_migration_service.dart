import 'package:lastquakes/utils/secure_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lastquakes/services/secure_token_service.dart';

class TokenMigrationService {
  static const String _migrationCompleteKey = 'token_migration_complete';
  static const String _legacyTokenKey = 'fcm_token';

  /// Migrate FCM token from SharedPreferences to secure storage
  /// This should be called once during app initialization
  /// Returns true if migration was performed, false otherwise
  static Future<bool> migrateTokenIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if migration has already been completed
      final migrationComplete = prefs.getBool(_migrationCompleteKey) ?? false;
      if (migrationComplete) {
        SecureLogger.migration("Token migration already completed");
        return false;
      }

      // Check if there's a legacy token in SharedPreferences
      final legacyToken = prefs.getString(_legacyTokenKey);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        SecureLogger.migration(
          "Migrating FCM token from SharedPreferences to secure storage",
        );

        // Store token securely
        await SecureTokenService.instance.storeFCMToken(legacyToken);

        // Remove the legacy token from SharedPreferences
        await prefs.remove(_legacyTokenKey);

        SecureLogger.success("FCM token migration completed successfully");
      } else {
        SecureLogger.migration("No legacy token found to migrate");
      }

      // Mark migration as complete
      await prefs.setBool(_migrationCompleteKey, true);

      return true;
    } catch (e) {
      SecureLogger.error("Error during token migration", e);
      // Don't rethrow - migration failure shouldn't break the app
      return false;
    }
  }

  /// Force clear legacy token data (for testing or cleanup)
  static Future<void> clearLegacyTokenData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyTokenKey);
      await prefs.remove(_migrationCompleteKey);
      SecureLogger.info("Legacy token data cleared");
    } catch (e) {
      SecureLogger.error("Error clearing legacy token data", e);
    }
  }
}
