import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastquake/services/encryption_service.dart';
import 'package:lastquake/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const masterKeyAlias = 'lastquake_master_key';
  const saltKeyAlias = 'lastquake_salt';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('EncryptionService', () {
    test('encryptData returns plaintext (pass-through)', () async {
      const plaintext = 'secret data';
      final encrypted = await EncryptionService.encryptData(
        plaintext,
        'context',
      );
      expect(encrypted, plaintext);
    });

    test('decryptData returns input (pass-through)', () async {
      const encrypted = 'secret data';
      final decrypted = await EncryptionService.decryptData(
        encrypted,
        'context',
      );
      expect(decrypted, encrypted);
    });

    test('isLegacyMode returns false when no keys exist', () async {
      expect(await EncryptionService.isLegacyMode(), isFalse);
    });

    test('isLegacyMode returns true when master key exists', () async {
      FlutterSecureStorage.setMockInitialValues({masterKeyAlias: 'some_key'});
      expect(await EncryptionService.isLegacyMode(), isTrue);
    });

    test('decryptLegacy decrypts XOR encrypted data correctly', () async {
      // 1. Setup legacy keys manually (simulating old app state)
      final random = Random(12345); // Fixed seed for reproducibility
      final keyBytes = Uint8List(32);
      for (int i = 0; i < keyBytes.length; i++)
        keyBytes[i] = random.nextInt(256);
      final masterKeyBase64 = base64Encode(keyBytes);

      final saltBytes = Uint8List(16);
      for (int i = 0; i < saltBytes.length; i++)
        saltBytes[i] = random.nextInt(256);
      final saltBase64 = base64Encode(saltBytes);

      FlutterSecureStorage.setMockInitialValues({
        masterKeyAlias: masterKeyBase64,
        saltKeyAlias: saltBase64,
      });

      // 2. Manually encrypt data using the OLD logic (replicated here for test setup)
      // We need to derive the key first to encrypt
      final context = 'test_context';
      final contextBytes = utf8.encode(context);
      final combinedSalt = Uint8List.fromList([...saltBytes, ...contextBytes]);

      var derivedKey = Uint8List.fromList(keyBytes);
      for (int i = 0; i < 10000; i++) {
        final hmac = Hmac(sha256, derivedKey);
        derivedKey = Uint8List.fromList(hmac.convert(combinedSalt).bytes);
      }
      final key = derivedKey.sublist(0, 32);

      final plaintext = 'legacy secret';
      final plaintextBytes = utf8.encode(plaintext);
      final iv = Uint8List(16);
      for (int i = 0; i < 16; i++) iv[i] = 0; // Simple IV for test

      final encryptedBytes = Uint8List(plaintextBytes.length);
      for (int i = 0; i < plaintextBytes.length; i++) {
        encryptedBytes[i] =
            plaintextBytes[i] ^ key[i % key.length] ^ iv[i % iv.length];
      }
      final combined = Uint8List.fromList([...iv, ...encryptedBytes]);
      final encryptedString = base64Encode(combined);

      // 3. Test decryptLegacy
      final decrypted = await EncryptionService.decryptLegacy(
        encryptedString,
        context,
      );
      expect(decrypted, plaintext);
    });
  });
}
