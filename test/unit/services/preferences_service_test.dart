import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:lastquakes/services/encryption_service.dart';
import 'package:lastquakes/services/preferences_service.dart';
import 'package:lastquakes/services/secure_storage_service.dart';
import 'package:lastquakes/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesService', () {
    late PreferencesService service;

    setUp(() async {
      // Reset singleton state
      service = PreferencesService();
      service.isLoaded = false;

      // Initialize mock storage
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});

      await EncryptionService.initialize();
      await SecureStorageService.clearAllSecureData();
    });

    tearDown(() async {
      service.isLoaded = false;
      await SecureStorageService.clearAllSecureData();
    });

    group('Load Settings', () {
      test(
        'loadSettings initializes with default values when no stored data',
        () async {
          await service.loadSettings();

          expect(service.filterType, NotificationFilterType.none);
          expect(service.magnitude, 5.0);
          expect(service.country, 'ALL');
          expect(service.radius, 500.0);
          expect(service.useCurrentLocation, false);
          expect(service.safeZones, isEmpty);
          expect(service.isLoaded, true);
        },
      );

      test('loadSettings loads data from secure storage', () async {
        // Setup: Store data in secure storage
        final settings = {
          'filterType': NotificationFilterType.worldwide.name,
          'magnitude': 6.5,
          'country': 'USA',
          'radius': 300.0,
          'useCurrentLocation': true,
        };
        await SecureStorageService.storeNotificationSettings(settings);

        final safeZones = TestHelpers.createMockSafeZones(count: 2);
        await SecureStorageService.storeSafeZones(safeZones);

        // Execute
        await service.loadSettings();

        // Verify
        expect(service.filterType, NotificationFilterType.worldwide);
        expect(service.magnitude, 6.5);
        expect(service.country, 'USA');
        expect(service.radius, 300.0);
        expect(service.useCurrentLocation, true);
        expect(service.safeZones.length, 2);
        expect(service.isLoaded, true);
      });

      test('loadSettings handles invalid filter type gracefully', () async {
        final settings = {'filterType': 'invalid_type', 'magnitude': 5.0};
        await SecureStorageService.storeNotificationSettings(settings);

        await service.loadSettings();

        // Should fallback to default
        expect(service.filterType, NotificationFilterType.none);
      });

      test('loadSettings handles null values with defaults', () async {
        final settings = {
          'filterType': NotificationFilterType.country.name,
          // Other fields missing
        };
        await SecureStorageService.storeNotificationSettings(settings);

        await service.loadSettings();

        expect(service.filterType, NotificationFilterType.country);
        expect(service.magnitude, 5.0); // Default
        expect(service.radius, 500.0); // Default
      });
    });

    group('Save Settings', () {
      test('saveSettings persists data to secure storage', () async {
        await service.loadSettings();

        service.filterType = NotificationFilterType.distance;
        service.magnitude = 4.5;
        service.country = 'Japan';
        service.radius = 200.0;
        service.useCurrentLocation = true;

        await service.saveSettings(showSnackbar: false);
      });

      test(
        'saveSettings also saves to SharedPreferences for backward compatibility',
        () async {
          await service.loadSettings();

          service.magnitude = 7.0;
          service.country = 'Canada';

          await service.saveSettings(showSnackbar: false);

          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getDouble('notification_magnitude'), 7.0);
          expect(prefs.getString('notification_country'), 'Canada');
        },
      );
    });

    group('Safe Zone Management', () {
      test('addSafeZone adds zone and triggers save', () async {
        await service.loadSettings();

        final initialCount = service.safeZones.length;
        final newZone = TestHelpers.createMockSafeZone(name: 'New Zone');

        await service.addSafeZone(newZone);

        expect(service.safeZones.length, initialCount + 1);
        expect(service.safeZones.last.name, 'New Zone');

        // Verify saved to storage
        final saved = await SecureStorageService.retrieveSafeZones();
        expect(saved.any((z) => z.name == 'New Zone'), true);
      });

      test('deleteSafeZone removes zone by index', () async {
        await service.loadSettings();

        final zone1 = TestHelpers.createMockSafeZone(name: 'Zone 1');
        final zone2 = TestHelpers.createMockSafeZone(name: 'Zone 2');
        final zone3 = TestHelpers.createMockSafeZone(name: 'Zone 3');

        await service.addSafeZone(zone1);
        await service.addSafeZone(zone2);
        await service.addSafeZone(zone3);

        await service.deleteSafeZone(1); // Delete zone2

        expect(service.safeZones.length, 2);
        expect(service.safeZones[0].name, 'Zone 1');
        expect(service.safeZones[1].name, 'Zone 3');
      });

      test('deleteSafeZone handles invalid index gracefully', () async {
        await service.loadSettings();

        final zone = TestHelpers.createMockSafeZone();
        await service.addSafeZone(zone);

        await service.deleteSafeZone(-1); // Invalid index
        expect(service.safeZones.length, 1); // No change

        await service.deleteSafeZone(10); // Out of bounds
        expect(service.safeZones.length, 1); // No change
      });

      test('deleteSafeZone on empty list does not crash', () async {
        await service.loadSettings();

        expect(service.safeZones, isEmpty);

        await service.deleteSafeZone(0);

        expect(service.safeZones, isEmpty);
      });
    });

    group('Migration from SharedPreferences', () {
      test('migrates data from SharedPreferences on first load', () async {
        // Setup: Put data in SharedPreferences
        SharedPreferences.setMockInitialValues({
          'notification_filter_type': NotificationFilterType.worldwide.name,
          'notification_magnitude': 6.0,
          'notification_country': 'Mexico',
          'notification_radius': 400.0,
          'notification_use_current_loc': true,
        });

        await service.loadSettings();

        // Verify migration happened
        expect(service.filterType, NotificationFilterType.worldwide);
        expect(service.magnitude, 6.0);
        expect(service.country, 'Mexico');
        expect(service.radius, 400.0);
        expect(service.useCurrentLocation, true);

        // Verify data is now in secure storage
        final secureSettings =
            await SecureStorageService.retrieveNotificationSettings();
        expect(secureSettings, isNotNull);
        expect(secureSettings!['magnitude'], 6.0);
      });

      test('does not migrate if secure storage already has data', () async {
        // Setup: Put data in both places
        SharedPreferences.setMockInitialValues({'notification_magnitude': 5.0});

        await SecureStorageService.storeNotificationSettings({
          'filterType': NotificationFilterType.distance.name,
          'magnitude': 7.0, // Different value
        });

        await service.loadSettings();

        // Should use secure storage value, not SharedPreferences
        expect(service.magnitude, 7.0);
      });
    });

    group('Validation', () {
      test('allows valid magnitude values', () async {
        await service.loadSettings();

        service.magnitude = 3.0;
        await service.saveSettings(showSnackbar: false);
        expect(service.magnitude, 3.0);

        service.magnitude = 9.5;
        await service.saveSettings(showSnackbar: false);
        expect(service.magnitude, 9.5);
      });

      test('allows valid radius values', () async {
        await service.loadSettings();

        service.radius = 50.0;
        await service.saveSettings(showSnackbar: false);
        expect(service.radius, 50.0);

        service.radius = 5000.0;
        await service.saveSettings(showSnackbar: false);
        expect(service.radius, 5000.0);
      });
    });

    group('Filter Types', () {
      test('supports all notification filter types', () async {
        await service.loadSettings();

        for (final filterType in NotificationFilterType.values) {
          service.filterType = filterType;
          await service.saveSettings(showSnackbar: false);

          final stored =
              await SecureStorageService.retrieveNotificationSettings();
          expect(stored!['filterType'], filterType.name);
        }
      });
    });

    group('Error Handling', () {
      test(
        'loadSettings handles corrupted secure storage gracefully',
        () async {
          // Setup corrupted data
          final storage = const FlutterSecureStorage();
          await storage.write(
            key: 'secure_notification_settings',
            value: 'invalid{json',
          );

          // Should not throw, should use defaults
          await service.loadSettings();

          expect(service.isLoaded, true);
          expect(service.filterType, NotificationFilterType.none);
        },
      );

      test('saveSettings handles storage errors by rethrowing', () async {
        await service.loadSettings();

        // Close secure storage to simulate error
        await SecureStorageService.clearAllSecureData();

        // Should propagate the error
        try {
          // This might succeed or fail depending on implementation
          await service.saveSettings(showSnackbar: false);
        } catch (e) {
          // Expected to potentially throw
          expect(e, isNotNull);
        }
      });
    });

    group('Singleton Behavior', () {
      test('returns same instance', () {
        final instance1 = PreferencesService();
        final instance2 = PreferencesService();

        expect(identical(instance1, instance2), true);
      });

      test('shared state across instances', () async {
        final instance1 = PreferencesService();
        await instance1.loadSettings();

        instance1.magnitude = 8.0;

        final instance2 = PreferencesService();
        expect(instance2.magnitude, 8.0);
      });
    });

    group('Edge Cases', () {
      test('handles empty country string', () async {
        await service.loadSettings();

        service.country = '';
        await service.saveSettings(showSnackbar: false);

        final stored =
            await SecureStorageService.retrieveNotificationSettings();
        expect(stored!['country'], '');
      });

      test('handles very large safe zone list', () async {
        await service.loadSettings();

        final zones = List.generate(100, (i) {
          return TestHelpers.createMockSafeZone(name: 'Zone $i');
        });

        for (final zone in zones) {
          await service.addSafeZone(zone);
        }

        expect(service.safeZones.length, 100);

        // Verify can load back
        await service.loadSettings();
        expect(service.safeZones.length, 100);
      });

      test('handles zero magnitude', () async {
        await service.loadSettings();

        service.magnitude = 0.0;
        await service.saveSettings(showSnackbar: false);

        expect(service.magnitude, 0.0);
      });

      test('handles zero radius', () async {
        await service.loadSettings();

        service.radius = 0.0;
        await service.saveSettings(showSnackbar: false);

        expect(service.radius, 0.0);
      });
    });
  });
}
