import 'package:flutter_test/flutter_test.dart';
import 'package:lastquake/services/encryption_service.dart';
import 'package:lastquake/services/secure_storage_service.dart';
import 'package:lastquake/models/safe_zone.dart';

void main() {
  group('EncryptionService Tests', () {
    setUpAll(() async {
      // Initialize encryption service for testing
      await EncryptionService.initialize();
    });

    test('should encrypt and decrypt data correctly', () async {
      const testData = 'This is sensitive test data';
      const context = 'test_context';

      // Encrypt the data
      final encrypted = await EncryptionService.encryptData(testData, context);
      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(equals(testData)));

      // Decrypt the data
      final decrypted = await EncryptionService.decryptData(encrypted, context);
      expect(decrypted, equals(testData));
    });

    test('should use different keys for different contexts', () async {
      const testData = 'Same data, different contexts';
      const context1 = 'context_1';
      const context2 = 'context_2';

      final encrypted1 = await EncryptionService.encryptData(testData, context1);
      final encrypted2 = await EncryptionService.encryptData(testData, context2);

      // Different contexts should produce different encrypted data
      expect(encrypted1, isNot(equals(encrypted2)));

      // But both should decrypt to the same original data
      final decrypted1 = await EncryptionService.decryptData(encrypted1, context1);
      final decrypted2 = await EncryptionService.decryptData(encrypted2, context2);

      expect(decrypted1, equals(testData));
      expect(decrypted2, equals(testData));
    });

    test('should handle empty data', () async {
      const emptyData = '';
      const context = 'empty_test';

      final encrypted = await EncryptionService.encryptData(emptyData, context);
      final decrypted = await EncryptionService.decryptData(encrypted, context);

      expect(decrypted, equals(emptyData));
    });

    test('should store and retrieve encrypted data', () async {
      const testKey = 'test_key';
      const testData = 'Test storage data';
      const context = 'storage_test';

      // Store encrypted data
      await EncryptionService.storeEncryptedData(testKey, testData, context);

      // Retrieve and decrypt data
      final retrieved = await EncryptionService.retrieveDecryptedData(testKey, context);

      expect(retrieved, equals(testData));

      // Clean up
      await EncryptionService.deleteEncryptedData(testKey);
    });
  });

  group('SecureStorageService Tests', () {
    setUpAll(() async {
      await SecureStorageService.initialize();
    });

    test('should store and retrieve safe zones', () async {
      final testSafeZones = [
        const SafeZone(name: 'Test Home', latitude: 37.7749, longitude: -122.4194),
        const SafeZone(name: 'Test Work', latitude: 37.7849, longitude: -122.4094),
      ];

      // Store safe zones
      await SecureStorageService.storeSafeZones(testSafeZones);

      // Retrieve safe zones
      final retrieved = await SecureStorageService.retrieveSafeZones();

      expect(retrieved.length, equals(testSafeZones.length));
      expect(retrieved[0].name, equals(testSafeZones[0].name));
      expect(retrieved[0].latitude, equals(testSafeZones[0].latitude));
      expect(retrieved[0].longitude, equals(testSafeZones[0].longitude));

      // Clean up
      await SecureStorageService.deleteSafeZones();
    });

    test('should store and retrieve emergency contacts', () async {
      final testContacts = [
        {'name': 'Test Contact 1', 'number': '+1234567890'},
        {'name': 'Test Contact 2', 'number': '+0987654321'},
      ];

      // Store contacts
      await SecureStorageService.storeEmergencyContacts(testContacts);

      // Retrieve contacts
      final retrieved = await SecureStorageService.retrieveEmergencyContacts();

      expect(retrieved.length, equals(testContacts.length));
      expect(retrieved[0]['name'], equals(testContacts[0]['name']));
      expect(retrieved[0]['number'], equals(testContacts[0]['number']));

      // Clean up
      await SecureStorageService.deleteEmergencyContacts();
    });

    test('should store and retrieve selected country', () async {
      const testCountry = 'Test Country';

      // Store country
      await SecureStorageService.storeSelectedCountry(testCountry);

      // Retrieve country
      final retrieved = await SecureStorageService.retrieveSelectedCountry();

      expect(retrieved, equals(testCountry));

      // Clean up
      await SecureStorageService.deleteSelectedCountry();
    });

    test('should store and retrieve notification settings', () async {
      final testSettings = {
        'filterType': 'distance',
        'magnitude': 5.5,
        'country': 'USA',
        'radius': 1000.0,
        'useCurrentLocation': true,
      };

      // Store settings
      await SecureStorageService.storeNotificationSettings(testSettings);

      // Retrieve settings
      final retrieved = await SecureStorageService.retrieveNotificationSettings();

      expect(retrieved, isNotNull);
      expect(retrieved!['filterType'], equals(testSettings['filterType']));
      expect(retrieved['magnitude'], equals(testSettings['magnitude']));
      expect(retrieved['useCurrentLocation'], equals(testSettings['useCurrentLocation']));

      // Clean up
      await SecureStorageService.deleteNotificationSettings();
    });

    test('should return empty data when no data exists', () async {
      // Ensure clean state
      await SecureStorageService.deleteSafeZones();
      await SecureStorageService.deleteEmergencyContacts();

      final safeZones = await SecureStorageService.retrieveSafeZones();
      final contacts = await SecureStorageService.retrieveEmergencyContacts();
      final country = await SecureStorageService.retrieveSelectedCountry();
      final settings = await SecureStorageService.retrieveNotificationSettings();

      expect(safeZones, isEmpty);
      expect(contacts, isEmpty);
      expect(country, isNull);
      expect(settings, isNull);
    });
  });
}