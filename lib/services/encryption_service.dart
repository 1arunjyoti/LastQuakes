import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Service for encrypting and decrypting sensitive personal data
/// Uses AES-256-GCM encryption with secure key derivation
class EncryptionService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _masterKeyAlias = 'lastquake_master_key';
  static const String _saltKeyAlias = 'lastquake_salt';

  /// Initialize encryption service
  /// No longer generates keys as we rely on OS-level encryption
  static Future<void> initialize() async {
    // No-op for new implementation, but kept for API compatibility
    // and potentially for migration checks in SecureStorageService
  }

  /// Check if legacy custom encryption keys exist
  static Future<bool> isLegacyMode() async {
    final masterKey = await _storage.read(key: _masterKeyAlias);
    return masterKey != null;
  }

  /// Clear legacy keys after migration
  static Future<void> clearLegacyKeys() async {
    await _storage.delete(key: _masterKeyAlias);
    await _storage.delete(key: _saltKeyAlias);
  }

  /// Pass-through encryption (relies on FlutterSecureStorage)
  static Future<String> encryptData(String plaintext, String context) async {
    // We don't need to do anything here as FlutterSecureStorage handles encryption.
    // We just return the plaintext to be stored.
    return plaintext;
  }

  /// Pass-through decryption (relies on FlutterSecureStorage)
  static Future<String> decryptData(
    String encryptedData,
    String context,
  ) async {
    // We don't need to do anything here as FlutterSecureStorage handles decryption.
    return encryptedData;
  }

  /// LEGACY: Derive encryption key from master key and context
  static Future<Uint8List> _deriveLegacyKey(String context) async {
    final masterKeyBase64 = await _storage.read(key: _masterKeyAlias);
    final saltBase64 = await _storage.read(key: _saltKeyAlias);

    if (masterKeyBase64 == null || saltBase64 == null) {
      throw Exception('Legacy encryption keys not found');
    }

    final masterKey = base64Decode(masterKeyBase64);
    final salt = base64Decode(saltBase64);

    // Use PBKDF2 for key derivation with context
    final contextBytes = utf8.encode(context);
    final combinedSalt = Uint8List.fromList([...salt, ...contextBytes]);

    // Simple PBKDF2 implementation using HMAC-SHA256
    var derivedKey = Uint8List.fromList(masterKey);
    for (int i = 0; i < 10000; i++) {
      // 10,000 iterations
      final hmac = Hmac(sha256, derivedKey);
      derivedKey = Uint8List.fromList(hmac.convert(combinedSalt).bytes);
    }

    return derivedKey.sublist(0, 32); // Return 256-bit key
  }

  /// LEGACY: Decrypt data using old XOR logic
  static Future<String> decryptLegacy(
    String encryptedData,
    String context,
  ) async {
    try {
      final key = await _deriveLegacyKey(context);
      final combined = base64Decode(encryptedData);

      // Extract IV and encrypted data
      final iv = combined.sublist(0, 16);
      final encrypted = combined.sublist(16);

      // Decrypt using XOR
      final decrypted = Uint8List(encrypted.length);
      for (int i = 0; i < encrypted.length; i++) {
        decrypted[i] = encrypted[i] ^ key[i % key.length] ^ iv[i % iv.length];
      }

      return utf8.decode(decrypted);
    } catch (e) {
      if (kDebugMode) {
        print('Error decrypting legacy data: $e');
      }
      rethrow;
    }
  }

  /// Securely store encrypted data
  static Future<void> storeEncryptedData(
    String key,
    String data,
    String context,
  ) async {
    try {
      // Just write directly, FlutterSecureStorage encrypts it
      await _storage.write(key: key, value: data);
    } catch (e) {
      if (kDebugMode) {
        print('Error storing data: $e');
      }
      rethrow;
    }
  }

  /// Retrieve and decrypt data
  static Future<String?> retrieveDecryptedData(
    String key,
    String context,
  ) async {
    try {
      final data = await _storage.read(key: key);
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving data: $e');
      }
      return null;
    }
  }

  /// Delete encrypted data
  static Future<void> deleteEncryptedData(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting data: $e');
      }
      rethrow;
    }
  }

  /// Clear all encrypted data (use with caution)
  static Future<void> clearAllData() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing all data: $e');
      }
      rethrow;
    }
  }

  /// Check if encryption is properly initialized
  static Future<bool> isInitialized() async {
    // Always true now as we rely on the plugin
    return true;
  }
}
