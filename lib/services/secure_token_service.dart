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
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      // Use more secure accessibility option
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _fcmTokenKey = 'fcm_token_secure';

  // In-memory cache to reduce secure storage reads
  String? _cachedToken;

  /// Securely store FCM token
  Future<void> storeFCMToken(String token) async {
    try {
      await _secureStorage.write(key: _fcmTokenKey, value: token);
      _cachedToken = token; // Update cache
      SecureLogger.token("FCM token stored securely");
    } catch (e) {
      SecureLogger.error("Error storing FCM token securely", e);
      rethrow;
    }
  }

  /// Retrieve FCM token from secure storage
  Future<String?> getFCMToken() async {
    // Return cached token if available
    if (_cachedToken != null) {
      return _cachedToken;
    }

    try {
      final token = await _secureStorage.read(key: _fcmTokenKey);
      if (token != null) {
        _cachedToken = token; // Populate cache
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
      _cachedToken = null; // Clear cache
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

  /// Force reload token from secure storage (bypassing cache)
  Future<void> reload() async {
    _cachedToken = null;
    await getFCMToken();
  }

  /// Clear all secure storage (use with caution)
  Future<void> clearAllSecureData() async {
    try {
      await _secureStorage.deleteAll();
      _cachedToken = null; // Clear cache
      SecureLogger.warning("All secure data cleared");
    } catch (e) {
      SecureLogger.error("Error clearing secure data", e);
    }
  }
}
