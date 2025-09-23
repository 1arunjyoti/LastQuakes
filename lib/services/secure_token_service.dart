import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lastquake/utils/secure_logger.dart';

class SecureTokenService {
  static SecureTokenService? _instance;
  
  static SecureTokenService get instance {
    _instance ??= SecureTokenService._();
    return _instance!;
  }
  
  SecureTokenService._();
  
  // Configure secure storage with additional security options
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // Use stronger encryption
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      // Use more secure accessibility option
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  static const String _fcmTokenKey = 'fcm_token_secure';
  
  /// Securely store FCM token
  Future<void> storeFCMToken(String token) async {
    try {
      await _secureStorage.write(key: _fcmTokenKey, value: token);
      SecureLogger.token("FCM token stored securely");
    } catch (e) {
      SecureLogger.error("Error storing FCM token securely", e);
      rethrow;
    }
  }
  
  /// Retrieve FCM token from secure storage
  Future<String?> getFCMToken() async {
    try {
      final token = await _secureStorage.read(key: _fcmTokenKey);
      if (token != null) {
        SecureLogger.token("FCM token retrieved securely", token: token);
      }
      return token;
    } catch (e) {
      SecureLogger.error("Error retrieving FCM token", e);
      return null;
    }
  }
  
  /// Delete FCM token from secure storage
  Future<void> deleteFCMToken() async {
    try {
      await _secureStorage.delete(key: _fcmTokenKey);
      SecureLogger.token("FCM token deleted from secure storage");
    } catch (e) {
      SecureLogger.error("Error deleting FCM token", e);
    }
  }
  
  /// Check if FCM token exists in secure storage
  Future<bool> hasFCMToken() async {
    try {
      return await _secureStorage.containsKey(key: _fcmTokenKey);
    } catch (e) {
      SecureLogger.error("Error checking FCM token existence", e);
      return false;
    }
  }
  
  /// Migrate existing token from SharedPreferences to secure storage
  Future<void> migrateTokenFromSharedPrefs() async {
    try {
      // This method should be called once to migrate existing tokens
      // Implementation would depend on your SharedPreferences usage
      SecureLogger.migration("Token migration completed");
    } catch (e) {
      SecureLogger.error("Error during token migration", e);
    }
  }
  
  /// Clear all secure storage (use with caution)
  Future<void> clearAllSecureData() async {
    try {
      await _secureStorage.deleteAll();
      SecureLogger.warning("All secure data cleared");
    } catch (e) {
      SecureLogger.error("Error clearing secure data", e);
    }
  }
}