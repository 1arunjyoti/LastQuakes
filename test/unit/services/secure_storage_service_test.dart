import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lastquakes/models/safe_zone.dart';
import 'package:lastquakes/services/encryption_service.dart';
import 'package:lastquakes/services/secure_storage_service.dart';
import '../../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageService', () {
    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      await EncryptionService.initialize();
    });

    tearDown(() async {
      await SecureStorageService.clearAllSecureData();
    });

    group('Safe Zones Management', () {
      test(
        'storeSafeZones and retrieveSafeZones roundtrip correctly',
        () async {
          final safeZones = TestHelpers.createMockSafeZones(count: 3);

          await SecureStorageService.storeSafeZones(safeZones);
          final retrieved = await SecureStorageService.retrieveSafeZones();

          expect(retrieved.length, 3);
          expect(retrieved[0].name, safeZones[0].name);
          expect(retrieved[0].latitude, safeZones[0].latitude);
          expect(retrieved[0].longitude, safeZones[0].longitude);
        },
      );

      test('storeSafeZones overwrites existing data', () async {
        final initialZones = TestHelpers.createMockSafeZones(count: 2);
        await SecureStorageService.storeSafeZones(initialZones);

        final newZones = TestHelpers.createMockSafeZones(count: 4);
        await SecureStorageService.storeSafeZones(newZones);

        final retrieved = await SecureStorageService.retrieveSafeZones();
        expect(retrieved.length, 4);
      });

      test(
        'retrieveSafeZones returns empty list when no data exists',
        () async {
          final retrieved = await SecureStorageService.retrieveSafeZones();

          expect(retrieved, isEmpty);
        },
      );

      test('storeSafeZones handles empty list', () async {
        await SecureStorageService.storeSafeZones([]);

        final retrieved = await SecureStorageService.retrieveSafeZones();
        expect(retrieved, isEmpty);
      });

      test('deleteSafeZones clears stored data', () async {
        final safeZones = TestHelpers.createMockSafeZones(count: 2);
        await SecureStorageService.storeSafeZones(safeZones);

        await SecureStorageService.deleteSafeZones();

        final retrieved = await SecureStorageService.retrieveSafeZones();
        expect(retrieved, isEmpty);
      });
    });

    group('Emergency Contacts Management', () {
      test(
        'storeEmergencyContacts and retrieveEmergencyContacts work correctly',
        () async {
          final contacts = [
            {'name': 'Police', 'number': '911'},
            {'name': 'Hospital', 'number': '555-1234'},
            {'name': 'Family', 'number': '555-5678'},
          ];

          await SecureStorageService.storeEmergencyContacts(contacts);
          final retrieved =
              await SecureStorageService.retrieveEmergencyContacts();

          expect(retrieved.length, 3);
          expect(retrieved[0]['name'], 'Police');
          expect(retrieved[0]['number'], '911');
        },
      );

      test(
        'retrieveEmergencyContacts returns empty when no data exists',
        () async {
          final retrieved =
              await SecureStorageService.retrieveEmergencyContacts();

          expect(retrieved, isEmpty);
        },
      );

      test('storeEmergencyContacts handles empty list', () async {
        await SecureStorageService.storeEmergencyContacts([]);

        final retrieved =
            await SecureStorageService.retrieveEmergencyContacts();
        expect(retrieved, isEmpty);
      });

      test('deleteEmergencyContacts clears stored data', () async {
        final contacts = [
          {'name': 'Test', 'number': '123'},
        ];
        await SecureStorageService.storeEmergencyContacts(contacts);

        await SecureStorageService.deleteEmergencyContacts();

        final retrieved =
            await SecureStorageService.retrieveEmergencyContacts();
        expect(retrieved, isEmpty);
      });
    });

    group('Country Selection Management', () {
      test(
        'storeSelectedCountry and retrieveSelectedCountry work correctly',
        () async {
          await SecureStorageService.storeSelectedCountry('United States');

          final retrieved =
              await SecureStorageService.retrieveSelectedCountry();

          expect(retrieved, 'United States');
        },
      );

      test(
        'retrieveSelectedCountry returns null when no data exists',
        () async {
          final retrieved =
              await SecureStorageService.retrieveSelectedCountry();

          expect(retrieved, isNull);
        },
      );

      test('storeSelectedCountry overwrites existing value', () async {
        await SecureStorageService.storeSelectedCountry('Canada');
        await SecureStorageService.storeSelectedCountry('Mexico');

        final retrieved = await SecureStorageService.retrieveSelectedCountry();
        expect(retrieved, 'Mexico');
      });

      test('deleteSelectedCountry clears stored data', () async {
        await SecureStorageService.storeSelectedCountry('Japan');

        await SecureStorageService.deleteSelectedCountry();

        final retrieved = await SecureStorageService.retrieveSelectedCountry();
        expect(retrieved, isNull);
      });
    });

    group('Notification Settings Management', () {
      test(
        'storeNotificationSettings and retrieveNotificationSettings work correctly',
        () async {
          final settings = {
            'filterType': 'magnitude',
            'magnitude': 5.0,
            'radius': 500.0,
            'useCurrentLocation': true,
            'country': 'ALL',
          };

          await SecureStorageService.storeNotificationSettings(settings);
          final retrieved =
              await SecureStorageService.retrieveNotificationSettings();

          expect(retrieved, isNotNull);
          expect(retrieved!['filterType'], 'magnitude');
          expect(retrieved['magnitude'], 5.0);
          expect(retrieved['radius'], 500.0);
          expect(retrieved['useCurrentLocation'], true);
        },
      );

      test(
        'retrieveNotificationSettings returns null when no data exists',
        () async {
          final retrieved =
              await SecureStorageService.retrieveNotificationSettings();

          expect(retrieved, isNull);
        },
      );

      test('storeNotificationSettings handles complex nested data', () async {
        final settings = {
          'nested': {
            'value': 123,
            'array': [1, 2, 3],
          },
        };

        await SecureStorageService.storeNotificationSettings(settings);
        final retrieved =
            await SecureStorageService.retrieveNotificationSettings();

        expect(retrieved, isNotNull);
        expect(retrieved!['nested']['value'], 123);
        expect(retrieved['nested']['array'], [1, 2, 3]);
      });

      test('deleteNotificationSettings clears stored data', () async {
        final settings = {'test': 'value'};
        await SecureStorageService.storeNotificationSettings(settings);

        await SecureStorageService.deleteNotificationSettings();

        final retrieved =
            await SecureStorageService.retrieveNotificationSettings();
        expect(retrieved, isNull);
      });
    });

    group('Data Type Integrity', () {
      test('safe zones preserve all properties through storage', () async {
        final zone = SafeZone(
          name: 'Test Zone',
          latitude: 35.123456789,
          longitude: -120.987654321,
        );

        await SecureStorageService.storeSafeZones([zone]);
        final retrieved = await SecureStorageService.retrieveSafeZones();

        expect(retrieved[0].name, 'Test Zone');
        expect(retrieved[0].latitude, 35.123456789);
        expect(retrieved[0].longitude, -120.987654321);
      });

      test('emergency contacts preserve special characters', () async {
        final contacts = [
          {'name': 'Test & Name', 'number': '+1 (555) 123-4567'},
          {'name': 'Name with "quotes"', 'number': '555.123.4567'},
        ];

        await SecureStorageService.storeEmergencyContacts(contacts);
        final retrieved =
            await SecureStorageService.retrieveEmergencyContacts();

        expect(retrieved[0]['name'], 'Test & Name');
        expect(retrieved[0]['number'], '+1 (555) 123-4567');
        expect(retrieved[1]['name'], 'Name with "quotes"');
      });

      test('notification settings preserve different data types', () async {
        final settings = {
          'stringValue': 'test',
          'intValue': 42,
          'doubleValue': 3.14159,
          'boolValue': true,
          'nullValue': null,
        };

        await SecureStorageService.storeNotificationSettings(settings);
        final retrieved =
            await SecureStorageService.retrieveNotificationSettings();

        expect(retrieved!['stringValue'], 'test');
        expect(retrieved['intValue'], 42);
        expect(retrieved['doubleValue'], 3.14159);
        expect(retrieved['boolValue'], true);
        expect(retrieved['nullValue'], isNull);
      });
    });

    group('Clear All Data', () {
      test('clearAllSecureData removes all stored data', () async {
        // Store various types of data
        await SecureStorageService.storeSafeZones(
          TestHelpers.createMockSafeZones(count: 2),
        );
        await SecureStorageService.storeEmergencyContacts([
          {'name': 'Test', 'number': '123'},
        ]);
        await SecureStorageService.storeSelectedCountry('USA');
        await SecureStorageService.storeNotificationSettings({'test': 'value'});

        // Clear all
        await SecureStorageService.clearAllSecureData();

        // Verify all cleared
        expect(await SecureStorageService.retrieveSafeZones(), isEmpty);
        expect(await SecureStorageService.retrieveEmergencyContacts(), isEmpty);
        expect(await SecureStorageService.retrieveSelectedCountry(), isNull);
        expect(
          await SecureStorageService.retrieveNotificationSettings(),
          isNull,
        );
      });
    });

    group('Initialization', () {
      test('isInitialized returns true after initialization', () async {
        final initialized = await SecureStorageService.isInitialized();

        expect(initialized, isTrue);
      });
    });

    group('Error Handling', () {
      test(
        'retrieveSafeZones returns empty list on corrupted data',
        () async {
          // Manually corrupt the storage
          final storage = const FlutterSecureStorage();
          await storage.write(
            key: 'secure_safe_zones',
            value: 'invalid_json{{{',
          );

          final retrieved = await SecureStorageService.retrieveSafeZones();

          // Should handle gracefully and return empty list
          expect(retrieved, isEmpty);
        },
        skip: kIsWeb,
      ); // Skip on web as direct storage manipulation might not work

      test(
        'retrieveNotificationSettings returns null on corrupted data',
        () async {
          final storage = const FlutterSecureStorage();
          await storage.write(
            key: 'secure_notification_settings',
            value: 'invalid_json',
          );

          final retrieved =
              await SecureStorageService.retrieveNotificationSettings();

          expect(retrieved, isNull);
        },
        skip: kIsWeb,
      );
    });

    group('Concurrent Operations', () {
      test('handles concurrent writes to same key', () async {
        final futures = List.generate(10, (i) {
          return SecureStorageService.storeSelectedCountry('Country$i');
        });

        await Future.wait(futures);

        // Should not crash, one value should win
        final result = await SecureStorageService.retrieveSelectedCountry();
        expect(result, isNotNull);
        expect(result, startsWith('Country'));
      });

      test('handles concurrent writes to different keys', () async {
        final futures = [
          SecureStorageService.storeSafeZones(
            TestHelpers.createMockSafeZones(count: 1),
          ),
          SecureStorageService.storeSelectedCountry('USA'),
          SecureStorageService.storeNotificationSettings({'test': 'value'}),
        ];

        await Future.wait(futures);

        // All should be stored successfully
        final zones = await SecureStorageService.retrieveSafeZones();
        final country = await SecureStorageService.retrieveSelectedCountry();
        final settings =
            await SecureStorageService.retrieveNotificationSettings();

        expect(zones.length, 1);
        expect(country, 'USA');
        expect(settings, isNotNull);
      });
    });
  });
}
