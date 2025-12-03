import 'package:flutter_test/flutter_test.dart';
import 'package:lastquakes/domain/models/notification_settings_model.dart';
import 'package:lastquakes/domain/repositories/device_repository.dart';
import 'package:lastquakes/domain/repositories/settings_repository.dart';
import 'package:lastquakes/models/safe_zone.dart';
import 'package:lastquakes/presentation/providers/settings_provider.dart';
import 'package:lastquakes/services/location_service.dart';
import 'package:lastquakes/utils/enums.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockDeviceRepository extends Mock implements DeviceRepository {}

class MockLocationService extends Mock implements LocationService {}

void main() {
  late SettingsProvider provider;
  late MockSettingsRepository mockSettingsRepository;
  late MockDeviceRepository mockDeviceRepository;
  late MockLocationService mockLocationService;

  setUp(() {
    mockSettingsRepository = MockSettingsRepository();
    mockDeviceRepository = MockDeviceRepository();
    mockLocationService = MockLocationService();

    registerFallbackValue(const NotificationSettingsModel());
    registerFallbackValue(<DataSource>{});
    registerFallbackValue(
      SafeZone(name: 'fallback', latitude: 0, longitude: 0),
    );

    // Default stubs
    when(
      () => mockSettingsRepository.getNotificationSettings(),
    ).thenAnswer((_) async => const NotificationSettingsModel());
    when(
      () => mockSettingsRepository.getSelectedDataSources(),
    ).thenAnswer((_) async => {DataSource.usgs});
    when(
      () => mockSettingsRepository.saveNotificationSettings(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockSettingsRepository.saveSelectedDataSources(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockDeviceRepository.registerDevice(any(), any()),
    ).thenAnswer((_) async {});

    provider = SettingsProvider(
      settingsRepository: mockSettingsRepository,
      deviceRepository: mockDeviceRepository,
      locationService: mockLocationService,
    );
  });

  group('SettingsProvider Tests', () {
    test('loadSettings loads settings and data sources', () async {
      await provider.loadSettings();

      verify(() => mockSettingsRepository.getNotificationSettings()).called(1);
      verify(() => mockSettingsRepository.getSelectedDataSources()).called(1);
      expect(provider.isLoading, false);
      expect(provider.settings, isA<NotificationSettingsModel>());
      expect(provider.selectedDataSources, contains(DataSource.usgs));
    });

    test('updateSettings saves settings and notifies listeners', () async {
      const newSettings = NotificationSettingsModel(magnitude: 5.0);

      await provider.updateSettings(newSettings);

      expect(provider.settings.magnitude, 5.0);
      verify(
        () => mockSettingsRepository.saveNotificationSettings(newSettings),
      ).called(1);
    });

    test('updateDataSources saves sources and notifies listeners', () async {
      final newSources = {DataSource.emsc};

      await provider.updateDataSources(newSources);

      expect(provider.selectedDataSources, contains(DataSource.emsc));
      verify(
        () => mockSettingsRepository.saveSelectedDataSources(newSources),
      ).called(1);
    });

    test('addSafeZone adds a zone and updates settings', () async {
      // Ensure initial settings are loaded or set
      await provider.loadSettings();

      final zone = SafeZone(name: 'Home', latitude: 0, longitude: 0);

      await provider.addSafeZone(zone);

      expect(provider.settings.safeZones, contains(zone));
      verify(
        () => mockSettingsRepository.saveNotificationSettings(any()),
      ).called(1);
    });

    test('removeSafeZone removes a zone and updates settings', () async {
      final zone = SafeZone(name: 'Home', latitude: 0, longitude: 0);
      // Setup initial state with one zone
      when(
        () => mockSettingsRepository.getNotificationSettings(),
      ).thenAnswer((_) async => NotificationSettingsModel(safeZones: [zone]));

      await provider.loadSettings();
      expect(provider.settings.safeZones, contains(zone));

      await provider.removeSafeZone(0);

      expect(provider.settings.safeZones, isEmpty);
      verify(
        () => mockSettingsRepository.saveNotificationSettings(any()),
      ).called(1);
    });
  });
}
