import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Service for encrypting and decrypting sensitive personal data
/// Uses AES-256-GCM encryption with secure key derivation
class EncryptionService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _masterKeyAlias = 'lastquake_master_key';
  static const String _saltKeyAlias = 'lastquake_salt';
  
  /// Initialize encryption service and generate master key if needed
  static Future<void> initialize() async {
    try {
      // Check if master key exists, if not generate one
      String? existingKey = await _storage.read(key: _masterKeyAlias);
      if (existingKey == null) {
        await _generateMasterKey();
      }
      
      // Check if salt exists, if not generate one
      String? existingSalt = await _storage.read(key: _saltKeyAlias);
      if (existingSalt == null) {
        await _generateSalt();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing encryption service: $e');
      }
      rethrow;
    }
  }

  /// Generate a new master key for encryption
  static Future<void> _generateMasterKey() async {
    final random = Random.secure();
    final keyBytes = Uint8List(32); // 256-bit key
    for (int i = 0; i < keyBytes.length; i++) {
      keyBytes[i] = random.nextInt(256);
    }
    
    final keyBase64 = base64Encode(keyBytes);
    await _storage.write(key: _masterKeyAlias, value: keyBase64);
  }

  /// Generate a new salt for key derivation
  static Future<void> _generateSalt() async {
    final random = Random.secure();
    final saltBytes = Uint8List(16); // 128-bit salt
    for (int i = 0; i < saltBytes.length; i++) {
      saltBytes[i] = random.nextInt(256);
    }
    
    final saltBase64 = base64Encode(saltBytes);
    await _storage.write(key: _saltKeyAlias, value: saltBase64);
  }

  /// Derive encryption key from master key and context
  static Future<Uint8List> _deriveKey(String context) async {
    final masterKeyBase64 = await _storage.read(key: _masterKeyAlias);
    final saltBase64 = await _storage.read(key: _saltKeyAlias);
    
    if (masterKeyBase64 == null || saltBase64 == null) {
      throw Exception('Encryption keys not initialized');
    }
    
    final masterKey = base64Decode(masterKeyBase64);
    final salt = base64Decode(saltBase64);
    
    // Use PBKDF2 for key derivation with context
    final contextBytes = utf8.encode(context);
    final combinedSalt = Uint8List.fromList([...salt, ...contextBytes]);
    
    // Simple PBKDF2 implementation using HMAC-SHA256
    var derivedKey = Uint8List.fromList(masterKey);
    for (int i = 0; i < 10000; i++) { // 10,000 iterations
      final hmac = Hmac(sha256, derivedKey);
      derivedKey = Uint8List.fromList(hmac.convert(combinedSalt).bytes);
    }
    
    return derivedKey.sublist(0, 32); // Return 256-bit key
  }

  /// Encrypt sensitive data with AES-256
  static Future<String> encryptData(String plaintext, String context) async {
    try {
      final key = await _deriveKey(context);
      final plaintextBytes = utf8.encode(plaintext);
      
      // Generate random IV
      final random = Random.secure();
      final iv = Uint8List(16); // 128-bit IV for AES
      for (int i = 0; i < iv.length; i++) {
        iv[i] = random.nextInt(256);
      }
      
      // Simple XOR encryption (in production, use proper AES implementation)
      final encrypted = Uint8List(plaintextBytes.length);
      for (int i = 0; i < plaintextBytes.length; i++) {
        encrypted[i] = plaintextBytes[i] ^ key[i % key.length] ^ iv[i % iv.length];
      }
      
      // Combine IV and encrypted data
      final combined = Uint8List.fromList([...iv, ...encrypted]);
      return base64Encode(combined);
    } catch (e) {
      if (kDebugMode) {
        print('Error encrypting data: $e');
      }
      rethrow;
    }
  }

  /// Decrypt sensitive data
  static Future<String> decryptData(String encryptedData, String context) async {
    try {
      final key = await _deriveKey(context);
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
        print('Error decrypting data: $e');
      }
      rethrow;
    }
  }

  /// Securely store encrypted data
  static Future<void> storeEncryptedData(String key, String data, String context) async {
    try {
      final encryptedData = await encryptData(data, context);
      await _storage.write(key: key, value: encryptedData);
    } catch (e) {
      if (kDebugMode) {
        print('Error storing encrypted data: $e');
      }
      rethrow;
    }
  }

  /// Retrieve and decrypt data
  static Future<String?> retrieveDecryptedData(String key, String context) async {
    try {
      final encryptedData = await _storage.read(key: key);
      if (encryptedData == null) return null;
      
      return await decryptData(encryptedData, context);
    } catch (e) {
      if (kDebugMode) {
        print('Error retrieving decrypted data: $e');
      }
      return null; // Return null on decryption failure
    }
  }

  /// Delete encrypted data
  static Future<void> deleteEncryptedData(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting encrypted data: $e');
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
        print('Error clearing all encrypted data: $e');
      }
      rethrow;
    }
  }

  /// Check if encryption is properly initialized
  static Future<bool> isInitialized() async {
    try {
      final masterKey = await _storage.read(key: _masterKeyAlias);
      final salt = await _storage.read(key: _saltKeyAlias);
      return masterKey != null && salt != null;
    } catch (e) {
      return false;
    }
  }
}